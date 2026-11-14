// ARMOR-IOS-CONTROL - the shell: the locked screen, the sign-in, or the tabs, with the messages and the question of the proof of identity over them.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch model.screen {
            case .starting: ProgressView().tint(Theme.accent)
            case .locked: LockedView()
            case .login: LoginView()
            case .main: MainTabs()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = model.toast {
                Text(toast.text).font(.callout).padding(12).frame(maxWidth: .infinity)
                    .background((toast.isError ? Theme.danger : Theme.ok).opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundColor(.black).padding().transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut, value: model.toast)
        .sheet(item: $model.pendingElevation) { request in ElevationSheet(request: request) }
        .id(model.language)   // a change of language redraws everything
    }
}

/// The places of the tab bar, so a notice can ask for one.
enum MainTab: Hashable { case status, alarms, cameras, assistant, more }

struct MainTabs: View {
    @EnvironmentObject var model: AppModel
    /// The set of waiting alarms the person closed the banner for; a new alarm brings it back.
    @State private var closedBanner: String?

    var body: some View {
        TabView(selection: $model.selectedTab) {
            HomeView().tabItem { Label(model.tr("Estado"), systemImage: "shield.lefthalf.filled") }.tag(MainTab.status)
            AlarmsView().tabItem { Label(model.tr("Alarmas"), systemImage: "bell.badge") }
                .badge(model.state.unseenAlarms).tag(MainTab.alarms)
            CamerasView().tabItem { Label(model.tr("Cámaras"), systemImage: "video") }.tag(MainTab.cameras)
            AssistantView().tabItem { Label(model.tr("Asistente"), systemImage: "waveform") }.tag(MainTab.assistant)
            MoreView().tabItem { Label(model.tr("Más"), systemImage: "ellipsis.circle") }.tag(MainTab.more)
        }
        .tint(Theme.accent)
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.selectedTab != .alarms, let banner = AlarmBannerPolicy.from(model.state.active, closedKey: closedBanner, model.translator) {
                AlarmBannerView(banner: banner) { closedBanner = $0 }
            }
        }
    }
}

/// The password again (or a code of the app), asked when the server wants a new proof of identity for a critical action from outside the house.
struct ElevationSheet: View {
    @EnvironmentObject var model: AppModel
    let request: AppModel.ElevationRequest
    @State private var password = ""
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text(model.tr("Estás usando el servidor desde fuera de casa y esta acción es crítica. Escribe tu contraseña de nuevo (o un código de la aplicación) para continuar."))) {
                    SecureField(model.tr("Tu contraseña (para confirmar que eres tú)"), text: $password)
                    TextField(model.tr("o código de la aplicación"), text: $code).keyboardType(.numberPad)
                }
                Button(model.tr("Confirmar")) {
                    let answer = ElevationForm.answer(password: password, code: code)
                    model.answerElevation(request, password: answer.password, code: answer.code)
                }
                    .disabled(!ElevationForm.canConfirm(password: password, code: code))
                Button(model.tr("Cancelar"), role: .cancel) { model.declineElevation(request) }
            }
            .navigationTitle(model.tr("Confirma que eres tú"))
        }
        .interactiveDismissDisabled()
    }
}
