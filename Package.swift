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
let sdkVersion = "5.0.15"

let downloadBase =
    "https://github.com/v-empower/meethour-ios-sdk-releases/releases/download/\(sdkVersion)"

// Replaced by scripts/make-spm-release.sh. Checksums are only verified when SPM
// downloads an artifact, so placeholders still parse and dump cleanly.
let checksums: [String: String] = [
    "MeetHourSDK": "4a9eddd2df386d5dc748579260ab189c19822e1590fd38b93e37b383dc655c04",
    "WebRTC": "57d86f029101e23b64a67db937ad1bf79b937b8d8b64beb8ef508adfdc46013e",
    "hermesvm": "dad4dd9cc215da72372b439b88d3cdac93551c75cd4c51919f685d7fb22b8b5d",
    "React": "f2b6f84b9f680d277fb54874f1674388fdf8b1f0db549b9ecb671e6f97b2e500",
    "ReactNativeDependencies": "c9b4d40f7a5d4103194da22a1d8f4cb1f717d3308e5af681d720c18c864490f2",
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
            targets: ["MeetHourSDKNative"]
        ),
        // React Native hosts. Deliberately omits React.xcframework and
        // ReactNativeDependencies.xcframework — the host app already has a
        // React Native runtime, and a second copy in one process collides
        // class-for-class and crashes at startup.
        .library(
            name: "MeetHourSDK-ReactNativeHost",
            targets: ["MeetHourSDKReactNativeHost"]
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
        remoteFramework("WebRTC"),
        remoteFramework("hermesvm"),
        remoteFramework("React"),
        remoteFramework("ReactNativeDependencies"),

        // Binary targets cannot declare dependencies of their own, so these thin
        // Swift targets exist purely to group the frameworks and to pull in
        // Giphy. Consumers still `import MeetHourSDK` — the module comes from
        // the binary framework, not from these shims.
        .target(
            name: "MeetHourSDKNative",
            dependencies: [
                "MeetHourSDK",
                "WebRTC",
                "hermesvm",
                "React",
                "ReactNativeDependencies",
                .product(name: "GiphyUISDK", package: "giphy-ios-sdk"),
            ],
            path: "Sources/MeetHourSDKNative"
        ),
        .target(
            name: "MeetHourSDKReactNativeHost",
            dependencies: [
                "MeetHourSDK",
                "WebRTC",
                "hermesvm",
                .product(name: "GiphyUISDK", package: "giphy-ios-sdk"),
            ],
            path: "Sources/MeetHourSDKReactNativeHost"
        ),
    ]
)
