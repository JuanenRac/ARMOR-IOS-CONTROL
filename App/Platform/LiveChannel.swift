// ARMOR-IOS-CONTROL - the open channel to one server (WebSocket /api/v1/events). It reconnects by itself (two seconds, doubling, a minute at most), carries the session cookie,
// hands every notice to `onNotice` and never sends anything: what the server says is read, never answered.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import Foundation
import ArmorCore

final class LiveChannel {
    private let origin: String
    private let cookie: () -> SessionCookie?
    private let onNotice: (LiveNotice) -> Void
    private let session: URLSession
    private var task: Task<Void, Never>?

    init(origin: String, trust: URLSessionDelegate, cookie: @escaping () -> SessionCookie?, onNotice: @escaping (LiveNotice) -> Void) {
        self.origin = origin; self.cookie = cookie; self.onNotice = onNotice
        self.session = URLSession(configuration: .ephemeral, delegate: trust, delegateQueue: nil)
    }

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            var failures = 0
            while !Task.isCancelled {
                guard let self, let url = LiveNotices.url(self.origin) else { return }
                var request = URLRequest(url: url)
                if let cookie = self.cookie() { request.setValue("\(cookie.name)=\(cookie.value)", forHTTPHeaderField: "Cookie") }
                let socket = self.session.webSocketTask(with: request)
                socket.resume()
                var opened = false
                while !Task.isCancelled {
                    do {
                        let message = try await socket.receive()
                        opened = true; failures = 0
                        if case .string(let text) = message, let notice = LiveNotices.parse(text) { self.onNotice(notice) }
                    } catch { break }
                }
                socket.cancel(with: .goingAway, reason: nil)
                if Task.isCancelled { return }
                failures = opened ? 1 : failures + 1
                try? await Task.sleep(nanoseconds: UInt64(LiveNotices.retryDelay(failures) * 1_000_000_000))
            }
        }
    }

    func stop() { task?.cancel(); task = nil; session.invalidateAndCancel() }
}
