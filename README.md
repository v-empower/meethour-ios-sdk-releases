# Meet Hour iOS SDK releases

---
id: dev-guide-ios-sdk
title: Meet Hour iOS SDK
---

This repository contains the binaries for the **[Meet Hour]() iOS SDK**. Each
release is tagged in this repository and is composed of 6 frameworks:

- `MeetHourSDK.xcframework` — the SDK itself
- `MeetHourSDKModules.xcframework` — the third-party React Native modules the
  SDK needs but deliberately does not link
- `WebRTC.xcframework`
- `React.xcframework`, `hermesvm.xcframework`,
  `ReactNativeDependencies.xcframework` — the React Native runtime

**Which of those you embed depends on what kind of app you have.** Getting this
wrong is the most common integration failure:

| Your app | Use | Embeds |
| --- | --- | --- |
| Objective-C, Swift, Flutter | `MeetHourSDK/Native` (the default) | all 6 |
| React Native | `MeetHourSDK/ReactNative` | MeetHourSDK + WebRTC only |

A React Native app already ships React Native and its own copies of
async-storage, svg, webview, screens, reanimated and the rest. Embedding the
`Native` subspec there puts a second copy of every one of those Objective-C
classes in one process, which the runtime reports as

```
objc: Class <X> is implemented in both ... and ...
      One of the duplicates must be removed or renamed.
```

and which crashes once instances start crossing between the two copies. The
`ReactNative` subspec exists to prevent exactly that: it ships the SDK alone and
lets your app provide everything else.

It is **strongly advised** to use the provided WebRTC framework and not
replace it with any other build, since the provided one is known to work
with the SDK.

## Using the SDK via Swift Package Manager (SPM)

Consumers then use File → Add Package Dependencies with https://github.com/v-empower/meethour-ios-sdk-releases, Pick 
1. MeetHourSDK-Native (For ObjC/Swift/Flutter projects)
2. MeetHourSDK-ReactNative.(For React Native project.)

## Using the SDK via Cocoapods

The recommended way for using the SDK is by using [CocoaPods](https://cocoapods.org/pods/MeetHourSDK). In order to
do so, add the `MeetHourSDK` dependency to your existing `Podfile` or create
a new one following this example:

For an Objective-C, Swift or Flutter app:

```ruby
platform :ios, '15.1'

target 'MeetHourSDKTest' do
    pod 'MeetHourSDK', '~> 5.0.20'

    post_install do |installer|
        installer.pods_project.targets.each do |target|
            target.build_configurations.each do |config|
                config.build_settings['ENABLE_BITCODE'] = 'NO'
            end
        end
    end
end
```

For a React Native app, ask for the `ReactNative` subspec explicitly — plain
`pod 'MeetHourSDK'` resolves to `Native`, which is the wrong half (see the table
above):

```ruby
pod 'MeetHourSDK/ReactNative', '~> 5.0.20'
```

Most React Native apps get this transitively instead, by depending on
[`react-native-meet-hour-sdk`](https://www.npmjs.com/package/react-native-meet-hour-sdk),
whose podspec already pins `MeetHourSDK/ReactNative`. That package also declares
the modules the SDK expects the host to provide as `peerDependencies`, so
`npm install` puts them in place; if any are missing, the components they back
render as `<UnimplementedView>`.

Replace `MeetHourSDKTest` with your project and target names.

`MeetHourSDK.framework` is built with a deployment target of iOS 15.1
(`React.framework` needs 15.0). The podspec still advertises 13.1 for historical
reasons, but anything below 15 will fail to link or launch.

Bitcode is not supported, so turn it off for your project.

The SDK uses Swift code, so make sure you select `Always Embed Swift Standard Libraries`
in your project.

Since the SDK requests camera and microphone access, make sure to include the
required entries for `NSCameraUsageDescription` and `NSMicrophoneUsageDescription`
in your `Info.plist` file.

In order for app to properly work in the background, select the "audio" and "voip"
background modes.

Last, since the SDK shows and hides the status bar based on the conference state,
you may want to set `UIViewControllerBasedStatusBarAppearance` to `NO` in your
`Info.plist` file.


# POD INSTALL
```
pod install
```

## API

The API is documented [here](API.md).

## Issues

Please report all issues related to this SDK to the [Meet Hour]() repository.

[CocoaPods]: https://cocoapods.org/pods/MeetHourSDK
[DownloadSDK]: https://github.com/v-empower/MeetHour-MobileSDKs
