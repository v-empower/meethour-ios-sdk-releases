// swift-tools-version:5.9
//
//  Meet Hour iOS SDK — Swift Package Manager manifest.
//
//  The xcframeworks are NOT referenced by path out of this repository. They are
//  downloaded from the GitHub Release whose tag matches `sdkVersion` below.
//  Every release adds ~1 GB of binaries, and Swift Package Manager always does a
//  full (never shallow) clone of a package repository, so path-based binary
//  targets would force every consumer to download the entire history before
//  resolution. Remote binary targets let SPM fetch only the artifacts for the
//  version actually being resolved.
//
//  `scripts/make-spm-release.sh` produces the zips and rewrites the checksums
//  below, in the same spirit as MeetHourSDK.podspec.tpl -> MeetHourSDK.podspec.
//

import PackageDescription

// Keep in sync with MeetHourSDK.podspec. Also the Git tag that carries the
// Release assets referenced below.
let sdkVersion = "5.0.27"

let downloadBase =
    "https://github.com/v-empower/meethour-ios-sdk-releases/releases/download/\(sdkVersion)"

// Replaced by scripts/make-spm-release.sh. Checksums are only verified when SPM
// downloads an artifact, so placeholders still parse and dump cleanly.
let checksums: [String: String] = [
    "MeetHourSDK": "6ce5197139491f17d0a700f5376c2e0e4e8b93577e1e68bdf2c498c62d650cbe",
    "MeetHourSDKModules": "dba541b99a2f5e6def0c7c1db8adc2669f2a9140ef2a0e76d83b81bf4862617d",
    "WebRTC": "250ae9820bda44707817150f7682034ec6a4be5fc3bd07cf7931f188f8f44ecc",
    "hermesvm": "54aab74c8d998cd37c15a3817fa131dada395b95b915b6613c89f25320ca8105",
    "React": "06b130628af57599f0f0ab2354594c32ea48e2ecfb2a1340285e19ca995a1548",
    "ReactNativeDependencies": "5f0f9967a9bfa57f95509b416e7ad2d9a9379b51142d5bd0da42b8ca7b87b8b4",
]

func remoteFramework(_ name: String) -> Target {
    .binaryTarget(
        name: name,
        url: "\(downloadBase)/\(name).xcframework.zip",
        checksum: checksums[name]!
    )
}

let package = Package(
    name: "MeetHourSDK",
    // MeetHourSDK.framework is built with a minimum deployment target of iOS
    // 15.1 (React.framework: 15.0). The CocoaPods spec still advertises 13.1,
    // which is stale — anything below 15 will fail to link or launch.
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Objective-C, Swift and Flutter hosts. Self-contained: ships the React
        // runtime, because these hosts have no React Native of their own.
        .library(
            name: "MeetHourSDK",
            targets: ["MeetHourSDK-Native"]
        ),
        // React Native hosts. Same MeetHourSDK binary as above, but without
        // MeetHourSDKModules and without the React runtime — the host already
        // has both, and a second copy in one process collides class-for-class
        // and crashes at startup.
        .library(
            name: "MeetHourSDK-ReactNative",
            targets: ["MeetHourSDK-ReactNative"]
        ),
        // iOS screen sharing: the whole Broadcast Upload Extension. Link it to
        // the extension target only and set, in that extension's Info.plist,
        // NSExtensionPrincipalClass = MHBroadcastSampleHandler and
        // RTCAppGroupIdentifier = the app's app group. No code is needed.
        // Dynamic, so the principal class is always loaded (a static library's
        // classes are dropped by the linker when nothing references them).
        .library(
            name: "MeetHourBroadcastExtension",
            type: .dynamic,
            targets: ["MeetHourBroadcastExtension"]
        ),
    ],
    dependencies: [
        // Giphy has supported SPM since 2.1.3; it vends a single "GiphyUISDK"
        // product. MeetHourSDK.framework links @rpath/GiphyUISDK.framework, so
        // every consumer needs it regardless of which product they pick.
        .package(url: "https://github.com/Giphy/giphy-ios-sdk", from: "2.2.12"),
    ],
    targets: [
        remoteFramework("MeetHourSDK"),
        // The third-party React Native modules MeetHourSDK deliberately does
        // not link. Native and Flutter hosts need them; React Native hosts
        // already have their own.
        remoteFramework("MeetHourSDKModules"),
        remoteFramework("WebRTC"),
        remoteFramework("hermesvm"),
        remoteFramework("React"),
        remoteFramework("ReactNativeDependencies"),

        // Binary targets cannot declare dependencies of their own, so these thin
        // Swift targets exist purely to group the frameworks and to pull in
        // Giphy. Consumers still `import MeetHourSDK` — the module comes from
        // the binary framework, not from these shims.
        .target(
            name: "MeetHourSDK-Native",
            dependencies: [
                "MeetHourSDK",
                "MeetHourSDKModules",
                "WebRTC",
                "hermesvm",
                "React",
                "ReactNativeDependencies",
                .product(name: "GiphyUISDK", package: "giphy-ios-sdk"),
            ],
            path: "Sources/MeetHourSDK-Native"
        ),
        .target(
            name: "MeetHourSDK-ReactNative",
            dependencies: [
                "MeetHourSDK",
                "WebRTC",
                .product(name: "GiphyUISDK", package: "giphy-ios-sdk"),
            ],
            path: "Sources/MeetHourSDK-ReactNative"
        ),
        .target(
            name: "MeetHourBroadcastExtension",
            path: "BroadcastExtension",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("ReplayKit"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("AudioToolbox"),
            ]
        ),
    ]
)
