// ARMOR-IOS-CONTROL - the locked screen: shown while the phone has not recognised the person (when the lock to open the app is on). The way out is always there: signing in again with the password.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI

struct LockedView: View {
    @EnvironmentObject var model: AppModel
    @State private var asked = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "lock.shield").font(.system(size: 64)).foregroundColor(Theme.accent)
            Text("A.R.M.O.R.").font(.system(size: 28, weight: .black))
            Text(model.tr("Confirma que eres tú con el bloqueo del teléfono para abrirla.")).multilineTextAlignment(.center).foregroundColor(Theme.muted)
            Button(model.tr("Abre A.R.M.O.R. con el bloqueo del teléfono")) { Task { await model.unlockToOpen() } }.buttonStyle(PrimaryButtonStyle())
            Spacer()
            Button(model.tr("No puedo: entrar con la contraseña")) { model.forgetAndSignInAgain() }.foregroundColor(Theme.amber)
            Text(model.tr("Entrar con la contraseña olvida la sesión guardada en este teléfono; el servidor y sus alarmas no se tocan.")).font(.caption).foregroundColor(Theme.muted).multilineTextAlignment(.center)
        }
        .padding()
        .task { if !asked { asked = true; await model.unlockToOpen() } }
    }
}
