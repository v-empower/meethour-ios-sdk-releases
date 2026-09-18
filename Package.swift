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
let sdkVersion = "5.0.24"

let downloadBase =
    "https://github.com/v-empower/meethour-ios-sdk-releases/releases/download/\(sdkVersion)"

// Replaced by scripts/make-spm-release.sh. Checksums are only verified when SPM
// downloads an artifact, so placeholders still parse and dump cleanly.
let checksums: [String: String] = [
    "MeetHourSDK": "8f4602415890af4f0c7486fa85edd0ddc48f842ad0f7a1c4b0d704a128a66016",
    "MeetHourSDKModules": "76e9e30e4b5d8132fda0850bb2289360eb39014aad942f6debbe67a6e252b2d5",
    "WebRTC": "06c0bc6924a07dbe3a85c55eb3f0f23029ca1f3d98a98e170c460d8f3ffa599f",
    "hermesvm": "8cc22988398b46e69a7909faaf04a0a5592a0e2358096b229c417750c8e333e2",
    "React": "11df9639ac4c5476c21d2fd0e6fe72ea2ae7a048041f9133e16e423eea52e794",
    "ReactNativeDependencies": "37cdd0f83f528c8e777c66388f4e85d020b3ac1177af64c7cacd3cdc0577065b",
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
    ]
)
