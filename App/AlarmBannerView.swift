// ARMOR-IOS-CONTROL - the alarm window of the open app: a banner that pulses over every screen but the alarms while an alarm waits for a person. The app works under it; it goes to the alarms,
// confirms from the banner and can be closed until another alarm comes. A person who asked the phone for less motion gets it still.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct AlarmBannerView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let banner: AlarmBannerModel
    let onClose: (String) -> Void
    @State private var dim = false

    var body: some View {
        let colour = AlarmBannerPolicy.isCritical(banner.severity) ? Theme.danger : Theme.amber
        VStack(alignment: .leading, spacing: 4) {
            Text(banner.title).font(.subheadline.weight(.bold)).foregroundColor(colour).opacity(dim ? 0.45 : 1)
            Text(banner.detail).font(.caption).foregroundColor(.white)
            HStack {
                Spacer()
                Button(model.tr("Cerrar")) { onClose(banner.key) }
                Button(model.tr("Ver alarmas")) { model.selectedTab = .alarms }
                if model.state.facts.can(CapabilityAction.acknowledge) {
                    Button(model.tr("Confirmar")) { Task { await model.order { _ in try await model.controller.acknowledge(banner.alarm.id) } } }.buttonStyle(.borderedProminent)
                }
            }.buttonStyle(.bordered).tint(colour).font(.caption)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(colour.opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(colour.opacity(dim ? 0.45 : 1), lineWidth: 2))
        .padding(.horizontal, 12).padding(.top, 8)
        .accessibilityElement(children: .contain)
        .onAppear { pulse() }
        .onChange(of: banner.severity) { _ in pulse() }
    }

    private func pulse() {
        dim = false
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: AlarmBannerPolicy.pulseSeconds(banner.severity)).repeatForever(autoreverses: true)) { dim = true }
    }
}
