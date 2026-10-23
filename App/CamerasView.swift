// ARMOR-IOS-CONTROL - the cameras: a grid of live pictures (only the tiles on screen run, at most six), a full view with a pad to move the camera, and a snapshot.
// The picture comes from the server, never from the camera: the app has no camera password. The stream is asked again, waiting longer each time, if it drops.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import UIKit
import ArmorCore

@MainActor
final class CameraList: ObservableObject {
    @Published var cameras: [CameraView] = []
    @Published var health: [String: String] = [:]
    @Published var loaded = false

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        let api = model.controller.api
        cameras = (try? await api.cameraViews(origin)) ?? cameras
        let list = (try? await api.cameraStatus(origin)) ?? []
        health = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0.status) })
        loaded = true
    }
}

struct CamerasView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var list = CameraList()
    @State private var visible: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if list.cameras.isEmpty && list.loaded {
                    Text(model.tr("Sin cámaras")).foregroundColor(Theme.muted).padding()
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                    ForEach(list.cameras) { camera in
                        NavigationLink {
                            CameraDetail(camera: camera)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                CameraTile(camera: camera, live: CameraGrid.live(visible: visible).contains(camera.id))
                                    .onAppear { if !visible.contains(camera.id) { visible.append(camera.id) } }
                                    .onDisappear { visible.removeAll { $0 == camera.id } }
                                HStack {
                                    Text(camera.name).font(.caption.weight(.semibold)).foregroundColor(.white)
                                    Spacer()
                                    Circle().fill(list.health[camera.id] == "online" ? Theme.ok : Theme.amber).frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                }.padding()
            }
            .background(Theme.background)
            .navigationTitle(model.tr("Cámaras"))
            .task { await list.load(model: model) }
            .refreshable { await list.load(model: model) }
        }
    }
}

struct CameraTile: View {
    @EnvironmentObject var model: AppModel
    let camera: CameraView
    let live: Bool
    @StateObject private var stream = MjpegStream()

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.surface)
            if let image = stream.image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: camera.liveVideoAvailable ? "video" : "video.slash").foregroundColor(Theme.muted)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onChange(of: live) { _ in update() }
        .onAppear { update() }
        .onDisappear { stream.stop() }
    }

    private func update() {
        if live && camera.liveVideoAvailable, let origin = model.activeOrigin {
            stream.start(api: model.controller.api, trust: model.trust, origin: origin, cameraId: camera.id, quality: CameraQuality.requested(away: model.place == .away, tile: true))
        } else { stream.stop() }
    }
}

struct CameraDetail: View {
    @EnvironmentObject var model: AppModel
    let camera: CameraView
    @StateObject private var stream = MjpegStream()
    @State private var pad = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Rectangle().fill(Theme.surface)
                if let image = stream.image { Image(uiImage: image).resizable().scaledToFit() }
                else { ProgressView().tint(Theme.accent) }
            }
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            HStack {
                Button { Task { await snapshot() } } label: { Label(model.tr("Foto"), systemImage: "camera") }
                Button { pad.toggle() } label: { Label(model.tr("Mover la cámara"), systemImage: "dpad") }
            }.buttonStyle(.bordered).tint(Theme.accent).disabled(!model.state.facts.canChange)
            if pad { PtzPad { command in Task { await ptz(command) } } }
            Spacer()
        }
        .padding()
        .background(Theme.background)
        .navigationTitle(camera.name)
        .onAppear { if let origin = model.activeOrigin { stream.start(api: model.controller.api, trust: model.trust, origin: origin, cameraId: camera.id) } }
        .onDisappear { stream.stop() }
    }

    private func snapshot() async {
        guard let origin = model.activeOrigin else { return }
        await model.order(model.tr("Foto guardada.")) { _ in try await model.controller.api.snapshot(origin, cameraId: camera.id) }
    }

    private func ptz(_ command: String) async {
        guard let origin = model.activeOrigin else { return }
        try? await model.controller.api.ptz(origin, cameraId: camera.id, command: command)
    }
}

struct PtzPad: View {
    @EnvironmentObject var model: AppModel
    let action: (String) -> Void
    var body: some View {
        VStack(spacing: 6) {
            key("chevron.up", "up", model.tr("Arriba"))
            HStack(spacing: 6) { key("chevron.left", "left", model.tr("Izquierda")); key("stop.fill", "stop", model.tr("Parar")); key("chevron.right", "right", model.tr("Derecha")) }
            key("chevron.down", "down", model.tr("Abajo"))
            HStack(spacing: 6) { key("minus.magnifyingglass", "zoomOut", model.tr("Alejar")); key("plus.magnifyingglass", "zoomIn", model.tr("Acercar")) }
        }
    }
    private func key(_ symbol: String, _ command: String, _ label: String) -> some View {
        Button { action(command) } label: { Image(systemName: symbol).frame(width: 52, height: 44).background(Theme.surface, in: RoundedRectangle(cornerRadius: 10)) }
            .accessibilityLabel(label).tint(Theme.accent)
    }
}

/// Reads a stream with a delegate (the pieces arrive as the camera sends them) and applies the same certificate rules as the rest of the app.
final class MjpegLoader: NSObject, URLSessionDataDelegate {
    private var parser = MjpegFrameParser()
    private let trust: TrustDelegate
    private let onFrame: (Data) -> Void
    private let onEnd: () -> Void
    private var session: URLSession?

    init(trust: TrustDelegate, onFrame: @escaping (Data) -> Void, onEnd: @escaping () -> Void) {
        self.trust = trust; self.onFrame = onFrame; self.onEnd = onEnd
    }

    func open(_ url: URL) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 3600
        let made = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        session = made
        made.dataTask(with: url).resume()
    }

    func close() { session?.invalidateAndCancel(); session = nil }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) { for frame in parser.feed(data) { onFrame(frame) } }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) { onEnd() }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        trust.urlSession(session, didReceive: challenge, completionHandler: completionHandler)
    }
}

/// One live picture: opens the stream the server relays, cuts it into JPEGs and shows the newest. A dropped stream is asked for again after 1, 2, 4... seconds (30 at most).
@MainActor
final class MjpegStream: ObservableObject {
    @Published var image: UIImage?
    private var task: Task<Void, Never>?
    private var loader: MjpegLoader?
    private var runningFor: String?

    func start(api: ArmorApi, trust: TrustDelegate, origin: String, cameraId: String, quality: String = "auto") {
        if runningFor == cameraId, task != nil { return }
        stop()
        runningFor = cameraId
        task = Task { [weak self] in
            var backoff = Backoff()
            while !Task.isCancelled {
                if let address = try? await api.streamTicket(origin, cameraId: cameraId, quality: quality), let url = URL(string: address) {
                    await self?.run(url: url, trust: trust, backoff: &backoff)
                }
                if Task.isCancelled { break }
                backoff.failed()
                try? await Task.sleep(nanoseconds: UInt64(backoff.delaySeconds * 1_000_000_000))
            }
        }
    }

    /// Returns when the stream ends or fails.
    private func run(url: URL, trust: TrustDelegate, backoff: inout Backoff) async {
        var gotPicture = false
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            let once = Once(done)
            let made = MjpegLoader(trust: trust, onFrame: { [weak self] data in
                // one picture decoded at a time, the newest wins: a slow phone drops pictures instead of piling them up
                if let picture = UIImage(data: data) { Task { @MainActor in self?.image = picture } }
                gotPicture = true
            }, onEnd: { once.finish() })
            loader = made
            made.open(url)
        }
        loader?.close(); loader = nil
        if gotPicture { backoff.succeeded() }
    }

    func stop() { task?.cancel(); task = nil; loader?.close(); loader = nil; runningFor = nil }
}

/// Resumes a continuation once, whatever the number of times the stream says it ended.
final class Once: @unchecked Sendable {
    private var continuation: CheckedContinuation<Void, Never>?
    private let lock = NSLock()
    init(_ continuation: CheckedContinuation<Void, Never>) { self.continuation = continuation }
    func finish() { lock.lock(); let c = continuation; continuation = nil; lock.unlock(); c?.resume() }
}
