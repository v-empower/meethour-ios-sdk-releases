/*
 * Copyright @ 2021-present Meet Hour, LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <ReplayKit/ReplayKit.h>

/**
 * Meet Hour screen sharing on iOS: the whole broadcast upload extension.
 *
 * An app adds an iOS "Broadcast Upload Extension" target (Apple requires one
 * for screen sharing) and, instead of writing any code in it, sets in that
 * extension's Info.plist:
 *
 *   NSExtension > NSExtensionPrincipalClass = MHBroadcastSampleHandler
 *   RTCAppGroupIdentifier                   = the same app group as the app
 *
 * It sends the screen to the meeting and, when the user ticks "Share your
 * device's audio", the sound other apps are playing (e.g. a YouTube video).
 * Updates arrive with the SDK; the extension itself never changes.
 */
@interface MHBroadcastSampleHandler : RPBroadcastSampleHandler

@end
