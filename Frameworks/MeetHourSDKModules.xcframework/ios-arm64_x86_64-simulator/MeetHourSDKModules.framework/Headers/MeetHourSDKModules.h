/*
 * MeetHourSDKModules.framework
 *
 * Carries the third-party React Native modules that MeetHourSDK.framework
 * deliberately does NOT link: safe-area-context, svg, webview, device-info and
 * the rest of the list in react-native.config.js.
 *
 * Why they live here instead of inside MeetHourSDK.framework:
 *
 *   A React Native host app already links all of them. A second copy inside
 *   MeetHourSDK.framework registers every one of their Objective-C classes
 *   twice in one process; the runtime keeps whichever image dyld loaded first
 *   (always the framework) and silently discards the host's, after which the
 *   host's Fabric renderer pairs a component descriptor built in one image
 *   with a provider built in the other and aborts:
 *
 *     componentDescriptor->getComponentHandle() == componentDescriptorProvider.handle
 *     ComponentDescriptorRegistry.cpp, line 41
 *
 *   dyld decides this at image-load time, before any of our code runs, so
 *   there is no runtime flag that can make a duplicate stand down. Exactly one
 *   image in the process has to own these classes.
 *
 * Who links this framework:
 *
 *   Objective-C, Swift and Flutter hosts -- via the `MeetHourSDK/Native`
 *   subspec (CocoaPods) or the `MeetHourSDK` product (SPM). Nothing else in
 *   those apps provides these modules.
 *
 *   React Native hosts do NOT link it. They already have their own copies, and
 *   react-native-meet-hour-sdk declares them as peerDependencies so npm
 *   installs them. MeetHourSDK resolves module classes by name at runtime
 *   (-[RCTBridgeWrapper getModuleClassFromName:] -> NSClassFromString), and
 *   the legacy module registry that RCT_EXPORT_MODULE populates at +load is
 *   process-global, so the SDK finds the host's copies without being linked
 *   against them. That is what makes one MeetHourSDK.xcframework serve both.
 *
 * This framework has no API of its own. It exists so the linker keeps the
 * modules' Objective-C classes, which register themselves at load time.
 */

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT double MeetHourSDKModulesVersionNumber;
FOUNDATION_EXPORT const unsigned char MeetHourSDKModulesVersionString[];

@interface MeetHourSDKModules : NSObject

/**
 * YES when this framework is loaded in the current process. MeetHourSDK does
 * not call this -- it resolves modules by name regardless -- but it gives
 * native and Flutter integrators a way to assert that the modules half of the
 * SDK actually got embedded, which is otherwise only visible as components
 * silently rendering as <UnimplementedView>.
 */
+ (BOOL)isAvailable;

@end
