// ARMOR-IOS-CONTROL - the Bluetooth Low Energy link to a field node: finds it, connects, and carries the framed JSON of its configuration channel.
// The protocol is in ARMOR-NODE-RADAR's docs/BLE_PROVISIONING.md and its framing in ArmorCore (NodeBle.swift, tested without a phone). This file is the part that needs a radio:
// it has not been run against a node or an iPhone.
//
// Everything here runs on the main queue (the central manager is given the main queue and the screen calls it from the main actor), so the state needs no lock. The operations take
// a completion closure instead of being `async`, because an `async` method of a plain class would leave the main actor and race with the delegate callbacks.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import CoreBluetooth
import ArmorCore

/// A node heard while scanning.
struct FoundNode: Identifiable {
    let id: UUID
    let name: String
    let rssi: Int
    let peripheral: CBPeripheral
}

final class NodeBleClient: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let serviceId = CBUUID(string: NodeGatt.service)
    private static let rxId = CBUUID(string: NodeGatt.rx)
    private static let txId = CBUUID(string: NodeGatt.tx)

    /// How many times a write is tried again while the system pairs (it answers "insufficient authentication" until the person has accepted).
    private static let writeAttempts = 12

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var rx: CBCharacteristic?
    private var tx: CBCharacteristic?
    private let assembler = BleAssembler()
    private var waiting: [Int: (NodeReply) -> Void] = [:]
    private var nextId = 1
    private var onFound: ((FoundNode) -> Void)?
    private var stateWaiters: [(CBManagerState) -> Void] = []
    private var connectDone: ((Bool) -> Void)?
    private var notifyReady = false
    private var pendingWrite: ((Error?) -> Void)?
    private var scanWanted = false

    // MARK: state of the radio

    /// The state of the radio; the manager (and with it the system's Bluetooth permission question) is only made the first time it is asked for.
    func state() -> CBManagerState { manager().state }

    /// Calls back once the radio is known (powered on, off, unauthorized...): at once when it already is, after at most `timeout` seconds otherwise.
    func whenReady(timeout: TimeInterval = 4, _ done: @escaping (CBManagerState) -> Void) {
        let current = manager().state
        if current != .unknown && current != .resetting { done(current); return }
        var finished = false
        let once: (CBManagerState) -> Void = { state in if !finished { finished = true; done(state) } }
        stateWaiters.append(once)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in once(self?.central?.state ?? .unknown) }
    }

    private func manager() -> CBCentralManager {
        if let central { return central }
        let made = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        central = made
        return made
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let waiters = stateWaiters
        stateWaiters = []
        for waiter in waiters { waiter(central.state) }
        if central.state != .poweredOn { failAll("disconnected") }
    }

    // MARK: finding nodes

    /// Starts looking for nodes; `onFound` is called each time one is heard (more than once for the same node, with a fresher signal). False when the radio is not on.
    func startScan(_ onFound: @escaping (FoundNode) -> Void) -> Bool {
        let radio = manager()
        guard radio.state == .poweredOn else { return false }
        stopScan()
        self.onFound = onFound
        scanWanted = true
        radio.scanForPeripherals(withServices: [Self.serviceId], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        return true
    }

    func stopScan() {
        guard scanWanted else { return }
        scanWanted = false
        onFound = nil
        central?.stopScan()
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? ""
        guard name.hasPrefix(NodeGatt.namePrefix) else { return }
        onFound?(FoundNode(id: peripheral.identifier, name: name, rssi: RSSI.intValue, peripheral: peripheral))
    }

    // MARK: the connection

    /// Connects and gets the channel ready (services, characteristics, notifications). False when the node cannot be reached or is not an A.R.M.O.R. node.
    func connect(_ node: FoundNode, timeout: TimeInterval = 20, _ done: @escaping (Bool) -> Void) {
        stopScan()
        disconnect()
        assembler.reset()
        let radio = manager()
        guard radio.state == .poweredOn else { done(false); return }
        var finished = false
        let once: (Bool) -> Void = { [weak self] ok in
            guard !finished else { return }
            finished = true
            self?.connectDone = nil
            if !ok { self?.disconnect() }
            done(ok)
        }
        connectDone = once
        peripheral = node.peripheral
        node.peripheral.delegate = self
        radio.connect(node.peripheral, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { once(false) }
    }

    func disconnect() {
        if let peripheral, let central { central.cancelPeripheralConnection(peripheral) }
        peripheral = nil; rx = nil; tx = nil; notifyReady = false
        if let step = pendingWrite { pendingWrite = nil; step(NSError(domain: "armor.ble", code: -1)) }
        failAll("disconnected")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([Self.serviceId])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { connectDone?(false) }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }
        connectDone?(false)
        if let step = pendingWrite { pendingWrite = nil; step(NSError(domain: "armor.ble", code: -1)) }
        self.peripheral = nil; rx = nil; tx = nil; notifyReady = false
        failAll("disconnected")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.serviceId }) else { connectDone?(false); return }
        peripheral.discoverCharacteristics([Self.rxId, Self.txId], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        rx = service.characteristics?.first { $0.uuid == Self.rxId }
        tx = service.characteristics?.first { $0.uuid == Self.txId }
        guard error == nil, rx != nil, let notifier = tx else { connectDone?(false); return }
        peripheral.setNotifyValue(true, for: notifier)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.txId else { return }
        notifyReady = error == nil && characteristic.isNotifying
        connectDone?(notifyReady)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, characteristic.uuid == Self.txId, let value = characteristic.value else { return }
        for text in assembler.feed([UInt8](value)) {
            guard let reply = NodeProtocol.reply(text), let done = waiting.removeValue(forKey: reply.id) else { continue }
            done(reply)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let step = pendingWrite else { return }
        pendingWrite = nil
        step(error)
    }

    private func failAll(_ code: String) {
        let all = waiting
        waiting = [:]
        for (id, done) in all { done(NodeReply(id: id, ok: false, error: code)) }
    }

    // MARK: requests

    /// Sends one request and calls back with its answer (or with an error code: `timeout`, `disconnected`, `invalid`). The first write can meet the pairing: iOS asks the person when the node
    /// asks for it, and until it is done a write fails with "insufficient authentication or encryption", so a failed write is tried again for a few seconds.
    func request(_ op: String, args: JSON? = nil, timeout: TimeInterval = 30, _ done: @escaping (NodeReply) -> Void) {
        guard let peripheral, let target = rx, notifyReady else { done(NodeReply(id: 0, ok: false, error: "disconnected")); return }
        let id = nextId
        nextId += 1
        guard let framed = BleFrame.frame(NodeProtocol.request(id: id, op: op, args: args)) else { done(NodeReply(id: id, ok: false, error: "invalid")); return }
        waiting[id] = done
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            if let late = self?.waiting.removeValue(forKey: id) { late(NodeReply(id: id, ok: false, error: "timeout")) }
        }
        let size = max(20, peripheral.maximumWriteValueLength(for: .withResponse))
        write(BleFrame.chunks(framed, size: size), at: 0, attempt: 0, to: target, id: id)
    }

    private func write(_ pieces: [[UInt8]], at index: Int, attempt: Int, to target: CBCharacteristic, id: Int) {
        guard index < pieces.count else { return }
        guard let peripheral, peripheral.state == .connected, waiting[id] != nil else { return }
        pendingWrite = { [weak self] error in
            guard let self else { return }
            if error == nil { self.write(pieces, at: index + 1, attempt: 0, to: target, id: id); return }
            if attempt + 1 < Self.writeAttempts, self.peripheral != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.write(pieces, at: index, attempt: attempt + 1, to: target, id: id) }
            } else if let done = self.waiting.removeValue(forKey: id) {
                done(NodeReply(id: id, ok: false, error: "disconnected"))
            }
        }
        peripheral.writeValue(Data(pieces[index]), for: target, type: .withResponse)
    }
}
