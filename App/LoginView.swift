// ARMOR-IOS-CONTROL - the sign-in: the two addresses of the house (at home and away), the user and the password, and the second factor when the account has it.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
import SwiftUI
import ArmorCore

struct LoginView: View {
    @EnvironmentObject var model: AppModel
    @State private var username = ""
    @State private var password = ""
    @State private var remember = false
    @State private var code = ""
    @State private var draft = SavedInstallation()
    @State private var showAddresses = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("A.R.M.O.R.").font(.system(size: 32, weight: .black)).foregroundColor(Theme.accent)
                Text(model.tr("Conecta con el servidor e inicia sesión para dar órdenes.")).foregroundColor(Theme.muted)

                Card {
                    Text(model.tr("Servidor")).font(.headline)
                    AddressFields(draft: $draft)
                }

                if let problem = model.problem {
                    Card { Text(problem.message(model.translator)).foregroundColor(Theme.amber) }
                }

                if let pending = model.needsCode {
                    Card {
                        Text(model.tr("Escribe el código de seis cifras de tu aplicación autenticadora, o uno de tus códigos de recuperación.")).font(.callout)
                        TextField(model.tr("Código de la aplicación (6 cifras)"), text: $code).textFieldStyle(.roundedBorder).keyboardType(.numbersAndPunctuation)
                        Button(model.tr("Verificar y entrar")) { Task { await model.submitCode(code) } }.buttonStyle(PrimaryButtonStyle()).disabled(code.isEmpty || model.busy)
                    }
                    .id(pending.challenge)
                } else {
                    Card {
                        TextField(model.tr("Usuario"), text: $username).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField(model.tr("Contraseña"), text: $password).textFieldStyle(.roundedBorder)
                        Toggle(model.tr("Recordarme en este móvil"), isOn: $remember).tint(Theme.accent)
                        Text(model.tr("Con «Recordarme» el usuario y la contraseña se guardan cifrados en este móvil, solo para este servidor. Quita la marca y se olvidan.")).font(.caption).foregroundColor(Theme.muted)
                        if let warning = secureWarning { Text(warning).font(.caption).foregroundColor(Theme.amber) }
                        Button(model.tr("Entrar")) {
                            model.saveInstallation(draft)
                            Task { await model.signIn(username: username, password: password, remember: remember) }
                        }
                        .buttonStyle(PrimaryButtonStyle()).disabled(model.busy || username.isEmpty || password.isEmpty)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            draft = model.installation
            if username.isEmpty { username = model.rememberedUser }
        }
    }

    /// What to tell the person when the address cannot be used: a public address without https never gets the password.
    private var secureWarning: String? {
        for host in [draft.homeHost, draft.awayHost] {
            if ServerEndpoint.needsSecureConnection(host) { return model.tr("Esa dirección está fuera de tu red: sin una conexión cifrada la app no envía tu contraseña. Escribe https:// delante del nombre.") }
            if ServerEndpoint.usesPublicIpAddress(host) { return model.tr("Esa es una IP pública: si tu operador la cambia, la app dejará de conectar. Usa un nombre de DNS dinámico (por ejemplo casa.duckdns.org).") }
        }
        return nil
    }
}

/// The two addresses: the private one at home and the one for away from home (a name that follows the house, or the address of the VPN).
struct AddressFields: View {
    @EnvironmentObject var model: AppModel
    @Binding var draft: SavedInstallation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.tr("En casa")).font(.subheadline.weight(.semibold))
            HStack {
                TextField("192.168.0.180", text: $draft.homeHost).textFieldStyle(.roundedBorder).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(model.tr("Puerto"), text: $draft.homePort).textFieldStyle(.roundedBorder).keyboardType(.numberPad).frame(width: 80)
            }
            Text(model.tr("Fuera de casa")).font(.subheadline.weight(.semibold))
            HStack {
                TextField("https://casa.duckdns.org", text: $draft.awayHost).textFieldStyle(.roundedBorder).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField(model.tr("Puerto"), text: $draft.awayPort).textFieldStyle(.roundedBorder).keyboardType(.numberPad).frame(width: 80)
            }
            Text(model.tr("La app usa la de casa en tu wifi y la de fuera con datos móviles; si una no responde, prueba la otra. La de fuera puede dejarse vacía.")).font(.caption).foregroundColor(Theme.muted)
        }
    }
}
