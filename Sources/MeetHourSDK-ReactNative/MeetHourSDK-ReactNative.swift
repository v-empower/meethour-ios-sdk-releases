//
//  Placeholder for the `MeetHourSDK-ReactNative` SPM product.
//
//  Swift Package Manager binary targets cannot declare dependencies, so this
//  thin target exists only to bind the xcframeworks together and to pull in
//  GiphyUISDK. It intentionally contains no API.
//
//  Use the SDK the same way as under CocoaPods:
//
//      import MeetHourSDK
//
//  That module comes from MeetHourSDK.xcframework, not from this file.
//

public enum MeetHourSDK-ReactNativePackage {
    /// Version of the binary artifacts this package resolves to.
    public static let version = "5.0.20"

    /// Whether the resolved product bundles the React Native runtime.
    /// True for `MeetHourSDK`, false for `MeetHourSDK-ReactNative`.
    public static let bundlesReactRuntime = false
}
