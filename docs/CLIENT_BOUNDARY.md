# Client boundary

ARMOR-IOS-CONTROL is a client of ARMOR-SERVER. It reads and orders through the server and nothing else.

- **It never talks to a node, a camera or a battery.** Cameras are seen through the stream the server relays; the app has no camera password and no RTSP address. Nodes are ordered through the server, which checks the role, the PIN and the proof of identity on its own.
- **It never keeps a password unless asked.** The password goes to the server once. With "Remember me" the user and the password are kept in the Keychain of this phone (this device only, no backup, no iCloud); without it nothing is kept but the session cookie, which the server renews while it is used and ends when it is not.
- **The lock of the phone protects an unattended phone, not the server.** Face ID, Touch ID or the passcode is asked before the sensitive orders and, if wanted, to open the app. The server keeps checking everything; it can raise what the lock asks for (`client.device_lock`) and never lower it.
- **Plain HTTP only inside the house.** A private-network or loopback IPv4 address may use http; anything else needs https, and the app remembers the key of the certificate of the installation to refuse a different one.
- **The spoken turn changes what the phone fails closed on, and is off by default.** Until a switch in More (*Orden hablada al servidor*) is turned on, the app never opens the microphone, never asks for its permission and never sends a sound: the Assistant takes written commands and the keyboard's own dictation (which sends only text), and in the challenge mode of `voice.silence_confirmation` silencing by a written command still asks for the signed confirmation and never less. With the switch on, a second button of the Assistant records one phrase (up to ten seconds of 16 kHz mono sound; the system asks for the permission of the microphone the first time the button is tapped), sends it raw to `POST /api/v1/voice/turn` with the voice token and drops it; the sound is kept nowhere. The voice token is the shared secret of the voice route, not a session: the person types it once and it is kept in the Keychain of this phone (readable only while the phone is unlocked), and a person signed in as a viewer cannot start a turn. When the server answers a `challenge`, the app shows that number on the screen for nineteen seconds, as the wall panel does, and never says it aloud; it is gone when the screen is left. Anything that is not exactly what the contract says (an answer that is not a voice reply, a number that is not two to six digits 0-9) shows nothing and tells the person the answer was not valid. The app writes a short audit trail on the phone (the last fifty events: switch on and off, blocked while off, no token, permission refused, sent, answered, failed; no words and no sound), and the server writes its own `voice.turn` line. The server's own policy (`voice.silence_confirmation`, `voice.multipart_turn`, the rate limit) applies to it exactly as to a wall panel. It is the same rule set as the Android app's.
- **It does not watch in the background.** iOS does not let a closed app query the server. Alarms reach a closed app through push only, and only when the server has push on and the installation has its Firebase file in the app.

## Building

The rules of the app are the Swift package `ArmorCore` (`swift test` runs its tests on macOS or Linux). The app itself is described in `project.yml` for XcodeGen:

```sh
brew install xcodegen
xcodegen generate
open ARMOR-IOS-CONTROL.xcodeproj
```

Choose a signing team in Xcode, add the app icon to `App/Resources/Assets.xcassets/AppIcon.appiconset` and, for push, put the installation's `GoogleService-Info.plist` in the app target (it is never kept in the repository).

`python tools/ios_lint.py` needs no Mac: it checks the structure, the eight language tables against the phrases of the sources, that the app calls only paths the Android client calls (and that the OpenAPI of the common repository knows them), the permission texts and the absence of secrets.

## What the person may do: the capabilities of the session

`GET /api/v1/studio/session` carries, for a signed-in person, a `capabilities` field (version 1: `actions`, `features`, `security`). The app reads it once at sign-in and decides what to show or enable from it, not from the role alone; the server checks the role again on every route, so this only decides what the screens offer. ARMOR-STUDIO reads it the same way.

- **Not announced (an older server):** the role decides as it always did: administrator everything but `security_settings`, operator arm, disarm, acknowledge, operate and camera control, anyone else nothing that changes.
- **Announced:** it is believed. An action the server does not name is not allowed (a newer action never appears on its own). A field of another version or shape counts as not announced.

| Action | What the app does with it |
| --- | --- |
| `operate` | Without it the person only looks: every order is refused before the server is asked, with the message of the read-only role. Also decides Reports and the device switches. |
| `arm` / `disarm` | The arm buttons (and the arming modes and the panel arm commands) / the disarm button and the panel disarm command. |
| `acknowledge` | Confirming one alarm or all of them. |
| `camera_control` | Photo, recording and moving a camera. |
| `administer` | The administrator screens: alarm panels commands, batteries, node control, updating the programs of the machine, forgetting a node, remote access. |
| `manage_users`, `security_settings` | Read and kept in the model; the phone has no screen for them yet. |

An order the server does not allow to this person, though the person may operate, is refused with "The server does not allow your user to do this." (in the eight languages).

Difference by system: none; it is the port of the Android reading (`SessionCapabilities`). The pure rules are in `Capabilities.swift` and have tests in `CapabilitiesTests.swift`; the screens read them through `SessionFacts.can(_:)`.
