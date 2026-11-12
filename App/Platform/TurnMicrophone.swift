// ARMOR-IOS-CONTROL - the microphone of the spoken turn: one phrase recorded with AVAudioEngine and handed over as 16 kHz mono 16-bit sound.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
//
// The rules (the switch, the voice token, the permission, the number of the challenge) are in ArmorCore/SpokenTurn.swift and are tested without a phone. This file is what needs one. It is called only
// by the controller of the spoken turn, after the switch, the token and the permission have been checked, and it keeps nothing: the sound goes back to the controller and nowhere else.
import AVFoundation
import ArmorCore

final class TurnMicrophone: TurnRecorder, @unchecked Sendable {
    /// Asks the person (the system's own dialog, the first time) and says whether the app may record.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
        }
    }

    func record(shouldStop: @escaping @Sendable () -> Bool) async -> Data {
        await Task.detached(priority: .userInitiated) { Self.capture(shouldStop) }.value
    }

    private static func capture(_ shouldStop: () -> Bool) -> Data {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true)
        } catch { return Data() }
        defer { try? session.setActive(false, options: .notifyOthersOnDeactivation) }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000, channels: 1, interleaved: true),
              let converter = AVAudioConverter(from: inputFormat, to: target) else { return Data() }

        let lock = NSLock()
        var sound = Data()
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * 16_000 / inputFormat.sampleRate) + 16
            guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var supplied = false
            var failure: NSError?
            converter.convert(to: converted, error: &failure) { _, status in
                if supplied { status.pointee = .noDataNow; return nil }
                supplied = true
                status.pointee = .haveData
                return buffer
            }
            if failure == nil, converted.frameLength > 0, let channel = converted.int16ChannelData {
                let chunk = Data(bytes: channel[0], count: Int(converted.frameLength) * 2)
                lock.lock(); sound.append(chunk); lock.unlock()
            }
        }
        do { try engine.start() } catch { input.removeTap(onBus: 0); return Data() }

        let deadline = Date().addingTimeInterval(11)
        while !shouldStop(), Date() < deadline {
            lock.lock(); let size = sound.count; lock.unlock()
            if size >= SpokenTurnController.maxBytes { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
        engine.stop()
        input.removeTap(onBus: 0)
        lock.lock(); defer { lock.unlock() }
        return sound
    }
}
