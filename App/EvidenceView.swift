// ARMOR-IOS-CONTROL - the recordings: the photos and videos the cameras made, with the camera and the day of each, to look at and (for an operator) to delete. The same list as the Android app.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import AVKit
import UIKit
import ArmorCore

/// A file of the library taken to the phone for viewing: a picture or a video in a temporary file that is removed when it is closed.
struct ViewedMedia: Identifiable {
    let item: MediaItemView
    let file: URL
    var id: String { item.id }
}

@MainActor
final class EvidenceState: ObservableObject {
    @Published var catalogue = MediaCatalogueView()
    @Published var cameras: [CameraView] = []
    @Published var loaded = false
    @Published var failed = false
    @Published var viewing: ViewedMedia?
    @Published var opening: String?
    @Published var refusal: String?
    /// The temporary copy being shown: removed when the sheet closes, however it closes (the button or a swipe).
    private var temporary: URL?

    func name(of item: MediaItemView) -> String { cameras.first { $0.id == item.cameraId }?.name ?? item.cameraId }

    func load(model: AppModel) async {
        guard let origin = model.activeOrigin else { return }
        do {
            catalogue = try await model.controller.api.media(origin)
            cameras = (try? await model.controller.api.cameraViews(origin)) ?? cameras
            failed = false
        } catch { failed = true }
        loaded = true
    }

    func open(model: AppModel, item: MediaItemView) async {
        guard let origin = model.activeOrigin else { return }
        opening = item.id; refusal = nil
        defer { opening = nil }
        do { let file = try await model.controller.api.mediaFile(origin, item: item); temporary = file; viewing = ViewedMedia(item: item, file: file) }
        catch { refusal = model.tr("No se pudo abrir la grabación.") }
    }

    func close() {
        if let file = temporary { try? FileManager.default.removeItem(at: file) }
        temporary = nil; viewing = nil
    }

    func delete(model: AppModel, item: MediaItemView) async {
        guard let origin = model.activeOrigin else { return }
        refusal = nil
        do { try await model.controller.api.deleteMedia(origin, item: item); await load(model: model) }
        catch { refusal = model.tr("No se pudo borrar la grabación.") }
    }
}

struct EvidenceView: View {
    @EnvironmentObject var model: AppModel
    @StateObject private var evidence = EvidenceState()
    @State private var doomed: MediaItemView?

    var body: some View {
        List {
            if let refusal = evidence.refusal { Section { Text(refusal).foregroundColor(Theme.danger) }.listRowBackground(Theme.surface) }
            if evidence.failed { Section { Text(model.tr("No se pudo leer la lista de grabaciones.")).foregroundColor(Theme.danger) }.listRowBackground(Theme.surface) }
            else if evidence.loaded && evidence.catalogue.items.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash").font(.largeTitle).foregroundColor(Theme.muted)
                        Text(model.tr("No hay grabaciones")).font(.headline)
                        Text(model.tr("Las fotos y vídeos que hagas con las cámaras aparecerán aquí.")).font(.footnote).foregroundColor(Theme.muted).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 12)
                }.listRowBackground(Theme.surface)
            } else {
                Section {
                    ForEach(evidence.catalogue.items) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.isPhoto ? "camera" : "film").foregroundColor(Theme.accent).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(evidence.name(of: item)).fontWeight(.semibold)
                                Text((item.isPhoto ? model.tr("Foto") : model.tr("Vídeo")) + " · " + EvidenceParser.when(item.createdAt) + " · " + EvidenceParser.size(item.bytes)).font(.caption).foregroundColor(Theme.muted)
                            }
                            Spacer()
                            if evidence.opening == item.id { ProgressView() }
                            else { Button(model.tr("Ver")) { Task { await evidence.open(model: model, item: item) } }.buttonStyle(.borderless) }
                            // somebody who may only look is not offered the button (the server would refuse it anyway)
                            if model.state.facts.canChange { Button(role: .destructive) { doomed = item } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
                        }
                    }
                }.listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden).background(Theme.background)
        .navigationTitle(model.tr("Grabaciones"))
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button { Task { await evidence.load(model: model) } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel(model.tr("Actualizar")) } }
        .task { await evidence.load(model: model) }
        .refreshable { await evidence.load(model: model) }
        .alert(model.tr("¿Borrar la grabación?"), isPresented: Binding(get: { doomed != nil }, set: { if !$0 { doomed = nil } })) {
            Button(model.tr("Borrar"), role: .destructive) { if let item = doomed { Task { await evidence.delete(model: model, item: item) } }; doomed = nil }
            Button(model.tr("Cancelar"), role: .cancel) { doomed = nil }
        } message: { Text(model.tr("Se borra del servidor y no se puede deshacer.")) }
        .sheet(item: $evidence.viewing, onDismiss: { evidence.close() }) { shown in MediaViewer(shown: shown) { evidence.close() } }
    }
}

/// One picture or video, full screen. The file is the phone's own temporary copy; closing removes it.
struct MediaViewer: View {
    @EnvironmentObject var model: AppModel
    let shown: ViewedMedia
    let close: () -> Void
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            Group {
                if shown.item.isPhoto, let image = UIImage(contentsOfFile: shown.file.path) { Image(uiImage: image).resizable().scaledToFit() }
                else if let player { VideoPlayer(player: player) }
                else { Text(model.tr("No se pudo abrir la grabación.")).foregroundColor(Theme.muted) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.black.ignoresSafeArea())
            .navigationTitle(EvidenceParser.when(shown.item.createdAt)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(model.tr("Cerrar")) { close() } } }
        }
        .onAppear { if !shown.item.isPhoto { let made = AVPlayer(url: shown.file); player = made; made.play() } }
        .onDisappear { player?.pause(); player = nil }
    }
}
