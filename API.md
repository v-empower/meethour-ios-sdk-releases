---
id: dev-guide-ios-sdk
title: Meet Hour iOS SDK API
---

## API

MeetHour is an iOS framework which embodies the whole Meet Hour experience and
makes it reusable by third-party apps.

To get started:

1. Add a `MeetHourView` to your app using a Storyboard or Interface Builder,
   for example.

2. Then, once the view has loaded, set the delegate in your controller and load
   the desired URL:

```objc
- (void)viewDidLoad {
  [super viewDidLoad];

  MeetHourView *MH = (MeetHourView *) self.view;
  MH.delegate = self;

  MeetHourConferenceOptions *options = [MeetHourConferenceOptions fromBuilder:^(MeetHourConferenceOptionsBuilder *builder) {
      builder.serverURL = [NSURL URLWithString:@"https://meethour.io"];
      builder.room = @"test123";
      builder.audioOnly = YES;
  }];

  [MH join:options];
}
```

```Swift
// create and configure Meet Hour view
    let MHView = MeetHourView()
    MHView.delegate = self
    self.MHView = MHView
    let options = MeetHourConferenceOptions.fromBuilder { (builder) in
      builder.welcomePageEnabled = false
      builder.setPrejoinPageEnabled = true //  Set it to false to Disable prejoin dynamically.
      builder.setDisableInviteFunctions = true //  To disable Invite options in SDK. 
      builder.serverURL = URL(string: "https://meethour.io")
      builder.room = “MeetHourSDKiOS”
      builder.setFeatureFlag("ios.recording.enabled", withBoolean: true)
    }
    MHView.join(options)
```

```Swift (Picture-In-Picture)
// create and configure Meet Hour view
    let MHView = MeetHourView()
    MHView.delegate = self
    self.MHView = MHView
    let options = MeetHourConferenceOptions.fromBuilder { (builder) in
      builder.welcomePageEnabled = false
      builder.setPrejoinPageEnabled = true //  Set it to false to Disable prejoin dynamically.
      builder.setDisableInviteFunctions = true //  To disable Invite options in SDK. 
      builder.serverURL = URL(string: "https://meethour.io")
      builder.room = “MeetHourSDKiOS”
      builder.setFeatureFlag("ios.recording.enabled", withBoolean: true)
    }
    MHView.join(options)

// Enable meet hour view to be a view that can be displayed
// on top of all the things, and let the coordinator to manage
// the view state and interactions
    pipViewCoordinator = PiPViewCoordinator(withView: MHView)
    pipViewCoordinator?.configureAsStickyView(withParentView: view)

    // animate in
    MHView.alpha = 0
    pipViewCoordinator?.show()
```

### MeetHourView class

The `MeetHourView` class is the entry point to the SDK. It a subclass of
`UIView` which renders a full conference in the designated area.

#### delegate

Property to get/set the `MeetHourViewDelegate` on `MeetHourView`.

#### join:MeetHourConferenceOptions

Joins the conference specified by the given options.

```objc
  MeetHourConferenceOptions *options = [MeetHourConferenceOptions fromBuilder:^(MeetHourConferenceOptionsBuilder *builder) {
      builder.serverURL = [NSURL URLWithString:@"https://meethour.io"];
      builder.room = @"test123";
      builder.audioOnly = NO;
      builder.audioMuted = NO;
      builder.videoMuted = NO;
      builder.welcomePageEnabled = NO;
      builder.setPrejoinPageEnabled = YES //  Set it to NO to Disable prejoin dynamically.
      builder.setDisableInviteFunctions = YES //  To disable Invite options in SDK. 
  }];

  [MH join:options];
```

#### leave

Leaves the currently active conference.

#### hangUp

The localParticipant leaves the current conference.

#### setAudioMuted

Sets the state of the localParticipant audio muted according to the `muted` parameter.

#### sendEndpointTextMessage

Sends a message via the data channel to one particular participant or to all of them.
If the `to` param is empty, the message will be sent to all the participants in the conference.

In order to get the participantId, the `PARTICIPANT_JOINED` event should be listened for,
which `data` includes the id and this should be stored somehow.

#### Universal / deep linking

In order to support Universal / deep linking, `MeetHour` offers 2 class
methods that you app's delegate should call in order for the app to follow those
links.

If these functions return NO it means the URL wasn't handled by the SDK. This
is useful when the host application uses other SDKs which also use linking.

```objc
-  (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
  restorationHandler:(void (^)(NSArray *restorableObjects))restorationHandler
{
  return [[MeetHour sharedInstance] application:application
               continueUserActivity:userActivity
                 restorationHandler:restorationHandler];
}
```

And also one of the following:

```objc
// See https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623073-application?language=objc
- (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
  return [[MeetHour sharedInstance] application:app
                            openURL:url
                            options: options];
}
```

### MeetHourViewDelegate

This delegate is optional, and can be set on the `MeetHourView` instance using
the `delegate` property.

It provides information about the conference state: was it joined, left, did it
fail?

All methods in this delegate are optional.

#### conferenceJoined

Called when a conference was joined.

The `data` dictionary contains a "url" key with the conference URL.

#### conferenceTerminated

Called when a conference was terminated either by user choice or due to a
failure.

The `data` dictionary contains an "error" key with the error and a "url" key
with the conference URL. If the conference finished gracefully no `error`
key will be present.

#### conferenceWillJoin

Called before a conference is joined.

The `data` dictionary contains a "url" key with the conference URL.

#### enterPictureInPicture

Called when entering Picture-in-Picture is requested by the user. The app should
now activate its Picture-in-Picture implementation (and resize the associated
`MeetHourView`. The latter will automatically detect its new size and adjust
its user interface to a variant appropriate for the small size ordinarily
associated with Picture-in-Picture.)

The `data` dictionary is empty.

#### participantJoined

Called when a participant has joined the conference.

The `data` dictionary contains information of the participant that has joined.
Depending of whether the participant is the local one or not, some of them are 
present/missing.
    isLocal
    email
    name
    participantId

#### participantLeft

Called when a participant has left the conference.

The `data` dictionary contains information of the participant that has left.
Depending of whether the participant is the local one or not, some of them are 
present/missing.
    isLocal
    email
    name
    participantId

#### audioMutedChanged

Called when audioMuted state changed.

The `data` dictionary contains a `muted` key with state of the audioMuted for the localParticipant.

#### endpointTextMessageReceived

Called when an endpoint text message is received.

The `data` dictionary contains a `senderId` key with the participantId of the sender and a `message` key with the content.

### Picture-in-Picture

`MeetHourView` will automatically adjust its UI when presented in a
Picture-in-Picture style scenario, in a rectangle too small to accommodate its
"full" UI.

Meet Hour SDK does not currently implement native Picture-in-Picture on iOS. If
desired, apps need to implement non-native Picture-in-Picture themselves and
resize `MeetHourView`.

If `delegate` implements `enterPictureInPicture:`, the in-call toolbar will
render a button to afford the user to request entering Picture-in-Picture.

## Dropbox integration

To setup the Dropbox integration, follow these steps:

1. Add the following to the app's Info.plist and change `<APP_KEY>` to your
Dropbox app key:
```
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string></string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>db-<APP_KEY></string>
    </array>
  </dict>
</array>
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>dbapi-2</string>
  <string>dbapi-8-emm</string>
</array>
	<key>GADApplicationIdentifier</key>
	<string>ca-app-pub-3940256099942544~1458002511</string>
	<key>SKAdNetworkItems</key>
	<array>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>cstr6suwn9.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>4fzdc2evr5.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>2fnua5tdw4.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>ydx93a7ass.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>p78axxw29g.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>v72qych5uu.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>ludvb6z3bs.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>cp8zw746q7.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>3sh42y64q3.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>c6k4g5qg8m.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>s39g8k73mm.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>3qy4746246.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>f38h382jlk.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>hs6bdukanm.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>mlmmfzh3r3.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>v4nxqhlyqp.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>wzmmz9fp6w.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>su67r6k2v3.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>yclnxrl5pm.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>t38b2kh725.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>7ug5zh24hu.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>gta9lk7p23.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>vutu7akeur.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>y5ghdn5j9k.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>v9wttpbfk9.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>n38lu8286q.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>47vhws6wlr.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>kbd757ywx3.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>9t245vhmpl.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>a2p9lx4jpn.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>22mmun2rn5.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>44jx6755aq.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>k674qkevps.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>4468km3ulz.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>2u9pt9hc89.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>8s468mfl3y.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>klf5c3l5u5.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>ppxm28t8ap.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>kbmxgpxpgc.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>uw77j35x4d.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>578prtvx9j.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>4dzt52r2t5.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>tl55sbb4fm.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>c3frkrj4fj.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>e5fvkxwrpn.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>8c4e2ghe7u.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>3rd42ekr43.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>97r2b46745.skadnetwork</string>
	</dict>
	<dict>
		<key>SKAdNetworkIdentifier</key>
		<string>3qcr597p9d.skadnetwork</string>
	</dict>
	</array>
```

2. Make sure your app calls the Meet Hour SDK universal / deep linking delegate methods.