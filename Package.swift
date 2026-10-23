// swift-tools-version:5.9
// ARMOR-IOS-CONTROL - the rules of the iPhone app (server link, models, languages, lock policy) in a package with no UIKit or SwiftUI, so they are tested without a phone.
import PackageDescription

let package = Package(
    name: "ArmorCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "ArmorCore", targets: ["ArmorCore"])],
    targets: [
        .target(name: "ArmorCore", resources: [.copy("Resources/i18n")]),
        .testTarget(name: "ArmorCoreTests", dependencies: ["ArmorCore"], resources: [.copy("Fixtures")]),
    ]
)
