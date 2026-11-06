// ARMOR-IOS-CONTROL - a field node's own configuration panel, inside the app: every setting of the node, as if its web page were opened in a browser. The node (radar, solar, electrical) serves
// that page itself on the local network, or the server relays it to a signed-in session so a node can be configured from outside the house. Instead of rebuilding its pages one by one - which would
// always be a copy that lags behind the node - this shows the real page in a web view. The web view may only go where the node is, and the node must be an address of the local network.
// Written without a Mac: it is built by the CI but has not been run against a node or an iPhone.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import WebKit
import ArmorCore

private struct OpenedPanel: Identifiable {
    let address: String
    var id: String { address }
}

struct NodesView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var network = NetworkState()
    @StateObject private var health = NodeHealthState()
    @State private var typed = ""
    @State private var recent: [String] = []
    @State private var opened: OpenedPanel?
    @State private var toForget: String?

    private static let recentKey = "recent_nodes"

    private var origin: String { model.activeOrigin ?? "" }
    private var canForget: Bool { model.state.facts.isAdmin }
    private var serverNodes: [String] {
        let data = health.overview
        let ids = (data?.nodes.map { $0.nodeId } ?? []) + (data?.waiting.map { $0.nodeId } ?? [])
        return Array(Set(ids)).sorted()
    }

    private func open(_ address: String) {
        recent = NodeAddress.remember(address, among: recent)
        UserDefaults.standard.set(recent.joined(separator: ","), forKey: Self.recentKey)
        opened = OpenedPanel(address: address)
    }

    /// Forgets a node of the server, with the lock of the phone and the proof of identity the server may ask for.
    private func forget(_ id: String) async {
        guard let origin = model.activeOrigin else { return }
        let api = model.controller.api
        await model.order(model.tr("Nodo olvidado")) { asker in
            try await model.controller.guarded(reason: model.tr("Olvidar nodo"), needs: CapabilityAction.administer, asker: asker) { _ in try await api.forgetNode(origin, id: id) }
        }
        await health.load(model: model)
    }

    private func forgetRecent(_ address: String) {
        recent = recent.filter { $0 != address }
        UserDefaults.standard.set(recent.joined(separator: ","), forKey: Self.recentKey)
    }

    var body: some View {
        let found = NodeFinder.candidates(network.overview, knownIds: [])
        let hasWatcher = network.overview?.nodes.contains { !$0.stale } == true
        let typedAddress = NodeAddress.parse(typed)
        List {
            Section {
                Text(model.tr("Abre el configurador de un nodo (radar, solar, eléctrico) dentro de la app: es su propia página, con todos sus menús y parámetros. Tu móvil tiene que estar en la misma red que el nodo."))
                    .font(.footnote).foregroundColor(Theme.muted)
            }.listRowBackground(Theme.surface)
            Section(header: Text(model.tr("Dirección del nodo"))) {
                HStack {
                    TextField("192.168.0.235", text: $typed).keyboardType(.numbersAndPunctuation).autocorrectionDisabled().textInputAutocapitalization(.never)
                        .onChange(of: typed) { value in typed = String(value.prefix(24)) }
                    Button(model.tr("Abrir")) { if let typedAddress { open(typedAddress) } }.disabled(typedAddress == nil)
                }
                if !typed.isEmpty && typedAddress == nil { Text(model.tr("Escribe una dirección de tu red, como 192.168.0.235.")).font(.caption).foregroundColor(Theme.amber) }
                ForEach(recent, id: \.self) { address in
                    HStack {
                        Button(address.replacingOccurrences(of: "http://", with: "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))) { open(address) }
                        Spacer()
                        Button(role: .destructive) { forgetRecent(address) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                            .accessibilityLabel(model.tr("Borrar nodo guardado"))
                    }
                }
            }.listRowBackground(Theme.surface)
            if !serverNodes.isEmpty && !origin.isEmpty {
                Section(header: Text(model.tr("A través del servidor")), footer: Text(model.tr("El servidor abre el panel del nodo por ti, también desde fuera de casa y con datos móviles. Hace falta tener la sesión iniciada."))) {
                    ForEach(serverNodes, id: \.self) { id in
                        HStack {
                            Button(id) { if let address = NodeServerPanel.address(origin: origin, nodeId: id) { opened = OpenedPanel(address: address) } }
                            Spacer()
                            if canForget { Button(role: .destructive) { toForget = id } label: { Image(systemName: "trash") }.buttonStyle(.borderless).accessibilityLabel(model.tr("Olvidar nodo")) }
                        }
                    }
                }.listRowBackground(Theme.surface)
            }
            Section(header: Text(model.tr("Encontrados en la red"))) {
                Button(network.scanning ? model.tr("Buscando…") : model.tr("Buscar en la red")) { Task { await network.scan(model: model) } }.disabled(!hasWatcher || network.scanning)
                if !hasWatcher { Text(model.tr("El nodo de red no informa, así que no hay con qué buscar.")).font(.caption2).foregroundColor(Theme.muted) }
                else if found.isEmpty { Text(model.tr("El nodo de red no ha encontrado ninguno todavía. Escribe la dirección arriba.")).font(.caption2).foregroundColor(Theme.muted) }
                ForEach(found, id: \.ip) { node in
                    Button {
                        if let address = NodeAddress.parse(node.ip) { open(address) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(node.nodeId ?? node.hostname ?? node.ip).font(.subheadline.weight(.medium)).foregroundColor(.white)
                            Text([node.ip, node.mac, node.vendor, node.online ? nil : model.tr("no responde ahora")].compactMap { $0 }.joined(separator: " · ")).font(.caption2).foregroundColor(Theme.muted)
                        }
                    }
                }
            }.listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Configurar nodos"))
        .task { await network.watch(model: model) }
        .task { await health.watch(model: model) }
        .onAppear { recent = (UserDefaults.standard.string(forKey: Self.recentKey) ?? "").split(separator: ",").compactMap { NodeAddress.parse(String($0)) } }
        .sheet(item: $opened) { panel in NodePanelSheet(address: panel.address, origin: origin) }
        .confirmationDialog(model.tr("Olvidar nodo"), isPresented: Binding(get: { toForget != nil }, set: { if !$0 { toForget = nil } }), titleVisibility: .visible) {
            Button(model.tr("Olvidar nodo"), role: .destructive) {
                if let id = toForget { Task { await forget(id) } }
                toForget = nil
            }
            Button(model.tr("Cancelar"), role: .cancel) { toForget = nil }
        } message: { Text((toForget ?? "") + "\n\n" + model.tr("Se borran sus avisos de salud en el servidor. Si el nodo sigue encendido, volverá a aparecer.")) }
    }
}

/// The panel in full size, with a way out and a retry when the node does not answer.
private struct NodePanelSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let address: String
    let origin: String
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if failed {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(model.trf("No se pudo abrir el nodo en %s. Comprueba que el móvil está en la misma red y que el nodo está encendido.", URL(string: address)?.host ?? address)).font(.footnote).foregroundColor(Theme.amber)
                        Button(model.tr("Reintentar")) { failed = false; attempt += 1 }
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }
                NodePanelWeb(address: address, cookie: NodeServerPanel.isViaServer(address, origin: origin) ? model.controller.api.sessionCookie(origin) : nil, onFail: { failed = true })
                    .id(attempt)
            }
            .background(Theme.background)
            .navigationTitle(URL(string: address)?.host ?? "").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(model.tr("Cerrar")) { dismiss() } } }
        }
    }
}

/// The page of the node. It may only go where the node is (a link to anywhere else is not followed), and a panel through the server gets the session cookie of the app for the server only.
private struct NodePanelWeb: UIViewRepresentable {
    let address: String
    let cookie: SessionCookie?
    let onFail: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(address: address, onFail: onFail) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()   // nothing of the page (or of the session cookie) is kept on the phone after the panel is closed
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1)
        guard let url = URL(string: address) else { context.coordinator.onFail(); return view }
        if let cookie, let host = url.host {
            var properties: [HTTPCookiePropertyKey: Any] = [.name: cookie.name, .value: cookie.value, .path: "/", .domain: host, .originURL: url]
            if url.scheme == "https" { properties[.secure] = "TRUE" }
            if let made = HTTPCookie(properties: properties) {
                view.configuration.websiteDataStore.httpCookieStore.setCookie(made) { view.load(URLRequest(url: url)) }
                return view
            }
        }
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let address: String
        let onFail: () -> Void
        init(address: String, onFail: @escaping () -> Void) { self.address = address; self.onFail = onFail }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let target = navigationAction.request.url else { decisionHandler(.cancel); return }
            decisionHandler(target.absoluteString == "about:blank" || NodeServerPanel.sameHost(target.absoluteString, as: address) ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { onFail() }
    }
}
