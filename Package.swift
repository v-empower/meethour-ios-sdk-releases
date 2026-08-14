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
let sdkVersion = "5.0.21"

let downloadBase =
    "https://github.com/v-empower/meethour-ios-sdk-releases/releases/download/\(sdkVersion)"

// Replaced by scripts/make-spm-release.sh. Checksums are only verified when SPM
// downloads an artifact, so placeholders still parse and dump cleanly.
let checksums: [String: String] = [
    "MeetHourSDK": "95e5711e04abd5be51d000afd53592bd24c32a3b8467e3a0e68be3396325a99f",
    "MeetHourSDKModules": "39550ad9d98b0623b4d0e086fc13e055880af9fac8fda71e325c2aeed7a51277",
    "WebRTC": "ae88505d61ffb9b4ee4729da22e48275ed6e3a6591fe60d4f408e478b1407a4b",
    "hermesvm": "b52eb142336812d498d12c1f0b999851252b3ced268336763cf417e18d3f78a2",
    "React": "0f72827fe93b1b4b4ad492be7ae5ef394c7b31a5180255be2d2022ad0a76d5c7",
    "ReactNativeDependencies": "21a8388f7844c16d77be89294b5c831d3cdc7928388e9a0a9d02367924bc1192",
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
