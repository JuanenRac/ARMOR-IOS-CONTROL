# Client boundary

ARMOR-IOS-CONTROL is a client of ARMOR-SERVER. It reads and orders through the server and nothing else.

- **It never talks to a node, a camera or a battery.** Cameras are seen through the stream the server relays; the app has no camera password and no RTSP address. Nodes are ordered through the server, which checks the role, the PIN and the proof of identity on its own.
- **It never keeps a password unless asked.** The password goes to the server once. With "Remember me" the user and the password are kept in the Keychain of this phone (this device only, no backup, no iCloud); without it nothing is kept but the session cookie, which the server renews while it is used and ends when it is not.
- **The lock of the phone protects an unattended phone, not the server.** Face ID, Touch ID or the passcode is asked before the sensitive orders and, if wanted, to open the app. The server keeps checking everything; it can raise what the lock asks for (`client.device_lock`) and never lower it.
- **Plain HTTP only inside the house.** A private-network or loopback IPv4 address may use http; anything else needs https, and the app remembers the key of the certificate of the installation to refuse a different one.
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
