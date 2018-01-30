/********* TwilioVoicePlugin.m Cordova Plugin Implementation *******/

#import "TwilioVoicePlugin.h"

@import AVFoundation;
@import CallKit;
@import PushKit;
@import TwilioVoice;

@interface TwilioVoicePlugin () <PKPushRegistryDelegate, TVOCallDelegate, TVONotificationDelegate, CXProviderDelegate>

// Callback for the Javascript plugin delegate, used for events
@property(nonatomic, strong) NSString *callback;

// Push registry for APNS VOIP
@property (nonatomic, strong) PKPushRegistry *voipPushRegistry;

// Current call (can be nil)
@property (nonatomic, strong) TVOCall *call;

// Current call invite (can be nil)
@property (nonatomic, strong) TVOCallInvite *callInvite;

// Device Token from Apple Push Notification Service for VOIP
@property (nonatomic, strong) NSString *pushDeviceToken;

// Access Token from Twilio
@property (nonatomic, strong) NSString *accessToken;

// Configure whether or not to use CallKit via the plist
// This is a variable from plugin installation (ENABLE_CALLKIT)
@property (nonatomic, assign) BOOL enableCallKit;

// Call Kit member variables
@property (nonatomic, strong) CXProvider *callKitProvider;
@property (nonatomic, strong) CXCallController *callKitCallController;

// Ringing Audio Player
@property (nonatomic, strong) AVAudioPlayer *ringtonePlayer;


@end

@implementation TwilioVoicePlugin

- (void) pluginInitialize {
    [super pluginInitialize];
    
    NSLog(@"Initializing plugin");

    // set log level for development
    [TwilioVoice setLogLevel:TVOLogLevelVerbose];

    // read in Enable CallKit preference
    NSString *enableCallKitPreference = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"TVPEnableCallKit"] uppercaseString];
    if ([enableCallKitPreference isEqualToString:@"YES"] || [enableCallKitPreference isEqualToString:@"TRUE"]) {
        self.enableCallKit = YES;
    } else {
        self.enableCallKit = NO;
    }
    
    if (!self.enableCallKit) {
    	/*
        //ask for notification support
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
		[center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert + UNAuthorizationOptionSound)
   				completionHandler:^(BOOL granted, NSError * _Nullable error) {
      // Enable or disable features based on authorization.
   	 							if (!granted) {
                                      NSLog(@"Notifications not granted");
                                  }
}];
*/
        // initialize ringtone player
        NSURL *ringtoneURL = [[NSBundle mainBundle] URLForResource:@"ringing.wav" withExtension:nil];
        if (ringtoneURL) {
            NSError *error = nil;
            self.ringtonePlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:ringtoneURL error:&error];
            if (error) {
                NSLog(@"Error initializing ring tone player: %@",[error localizedDescription]);
            } else {
                //looping ring
                self.ringtonePlayer.numberOfLoops = -1;
                [self.ringtonePlayer prepareToPlay];
            }
        }
    }
    
}

- (void) initializeWithAccessToken:(CDVInvokedUrlCommand*)command  {
    NSLog(@"Initializing with an access token");
    
    // retain this command as the callback to use for raising Twilio events
    self.callback = command.callbackId;
    
    self.accessToken = [command.arguments objectAtIndex:0];
    if (self.accessToken) {
        
        // initialize VOIP Push Registry
        self.voipPushRegistry = [[PKPushRegistry alloc] initWithQueue:dispatch_get_main_queue()];
        self.voipPushRegistry.delegate = self;
        self.voipPushRegistry.desiredPushTypes = [NSSet setWithObject:PKPushTypeVoIP];
     

        if (self.enableCallKit) {
            // initialize CallKit (based on Twilio ObjCVoiceCallKitQuickstart)
            NSString *incomingCallAppName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"TVPIncomingCallAppName"];
            CXProviderConfiguration *configuration = [[CXProviderConfiguration alloc] initWithLocalizedName:incomingCallAppName];
            configuration.maximumCallGroups = 1;
            configuration.maximumCallsPerCallGroup = 1;
        //    UIImage *callkitIcon = [UIImage imageNamed:@"logo.png"];
         //   configuration.iconTemplateImageData = UIImagePNGRepresentation(callkitIcon);
         //   configuration.ringtoneSound = @"ringing.wav";
            
            self.callKitProvider = [[CXProvider alloc] initWithConfiguration:configuration];
            [self.callKitProvider setDelegate:self queue:nil];
            
            self.callKitCallController = [[CXCallController alloc] init];
        }

        [self javascriptCallback:@"onclientinitialized"];
    }
    
}

- (void) call:(CDVInvokedUrlCommand*)command {
    if ([command.arguments count] > 0) {
        self.accessToken = command.arguments[0];
        if ([command.arguments count] > 1) {
            NSDictionary *params = command.arguments[1];
            NSLog(@"Making call to with params %@", params);
            self.call = [TwilioVoice call:self.accessToken
                                                params:params
                                              delegate:self];
        } else {
            NSLog(@"Making call with no params");
            self.call = [TwilioVoice call:self.accessToken
                                                    params:@{}
                                                  delegate:self];

        }
    }
}

- (void) sendDigits:(CDVInvokedUrlCommand*)command {
    if ([command.arguments count] > 0) {
        [self.call sendDigits:command.arguments[0]];
    }
}

- (void) disconnect:(CDVInvokedUrlCommand*)command {
    if (self.call && self.call.state == TVOCallStateConnected) {
        [self.call disconnect];
    }
}

- (void) acceptCallInvite:(CDVInvokedUrlCommand*)command {
    if (self.callInvite) {
        [self.callInvite acceptWithDelegate:self];
    }
    if ([self.ringtonePlayer isPlaying]) {
        //pause ringtone
        [self.ringtonePlayer pause];
    }
}

- (void) rejectCallInvite: (CDVInvokedUrlCommand*)command {
    if (self.callInvite) {
        [self.callInvite reject];
    }
    if ([self.ringtonePlayer isPlaying]) {
        //pause ringtone
        [self.ringtonePlayer pause];
    }
}

-(void)setSpeaker:(CDVInvokedUrlCommand*)command {
    NSString *mode = [command.arguments objectAtIndex:0];
    if([mode isEqual: @"on"]) {
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
        AudioSessionSetProperty (
            kAudioSessionProperty_OverrideAudioRoute,
            sizeof (audioRouteOverride),
            &audioRouteOverride
        );
    }
    else {
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;
        AudioSessionSetProperty (
            kAudioSessionProperty_OverrideAudioRoute,
            sizeof (audioRouteOverride),
            &audioRouteOverride
        );
    }
}

- (void) muteCall: (CDVInvokedUrlCommand*)command {
    if (self.call) {
        self.call.muted = YES;
    }
}

- (void) unmuteCall: (CDVInvokedUrlCommand*)command {
    if (self.call) {
        self.call.muted = NO;
    }
}

- (void) isCallMuted: (CDVInvokedUrlCommand*)command {
    if (self.call) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:self.call.muted];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:NO];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

#pragma mark PKPushRegistryDelegate methods
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type {
    if ([type isEqualToString:PKPushTypeVoIP]) {
        self.pushDeviceToken = [credentials.token description];
        NSLog(@"Updating push device token for VOIP: %@",self.pushDeviceToken);
        [TwilioVoice registerWithAccessToken:self.accessToken
                                                  deviceToken:self.pushDeviceToken completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"An error occurred while registering: %@", [error localizedDescription]);
            } else {
                NSLog(@"Successfully registered for VoIP push notifications.");
            }
        }];
    }
}

- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type {
    if ([type isEqualToString:PKPushTypeVoIP]) {
        NSLog(@"Invalidating push device token for VOIP: %@",self.pushDeviceToken);
        [TwilioVoice unregisterWithAccessToken:self.accessToken
                                                    deviceToken:self.pushDeviceToken completion:^(NSError * _Nullable error) {
            if (error) {
                NSLog(@"An error occurred while unregistering: %@", [error localizedDescription]);
            } else {
                NSLog(@"Successfully unregistered for VoIP push notifications.");
            }
        }];
        self.pushDeviceToken = nil;
    }
}


- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type {
    if ([type isEqualToString:PKPushTypeVoIP]) {
        NSLog(@"Received Incoming Push Payload for VOIP: %@",payload.dictionaryPayload);
        [TwilioVoice handleNotification:payload.dictionaryPayload delegate:self];
    }
}

#pragma mark TVONotificationDelegate
- (void)callInviteReceived:(TVOCallInvite *)callInvite {
    NSLog(@"Call Invite Received: %@", callInvite.uuid);
    self.callInvite = callInvite;
    NSDictionary *callInviteProperties = @{
                                           @"from":callInvite.from,
                                           @"to":callInvite.to,
                                           @"callSid":callInvite.callSid,
                                           @"state":[self stringFromCallInviteState:callInvite.state]
                                           };
    if (self.enableCallKit) {
        [self reportIncomingCallFrom:callInvite.from withUUID:callInvite.uuid];
    } else {
    /*
        [self showNotification:callInvite.from];
        //play ringtone
        [self.ringtonePlayer play];*/
    }

    [self javascriptCallback:@"oncallinvitereceived" withArguments:callInviteProperties];
}


/*- (void)callinvitecanceled:(TVOCallInvite *)callInvite {
    NSLog(@"Call Invite Cancelled: %@", callInvite.uuid);
    if (self.enableCallKit) {
        [self performEndCallActionWithUUID:callInvite.uuid];
    } else {
     //   [self cancelNotification];
        //pause ringtone
     //   [self.ringtonePlayer pause];
    }
    self.callInvite = nil;
    [self javascriptCallback:@"oncallinvitecanceled"];

}*/

- (void)notificationError:(NSError *)error {
    NSLog(@"Twilio Voice Notification Error: %@", [error localizedDescription]);
    [self javascriptErrorback:error];
}

#pragma mark TVOCallDelegate
- (void) callDidConnect:(TVOCall *)call {
    NSLog(@"callDidConnect:");
    self.call = call;

    if (!self.enableCallKit) {
      /*  [self cancelNotification];
        if ([self.ringtonePlayer isPlaying]) {
            //pause ringtone
            [self.ringtonePlayer pause];
        }*/
    }
    
    NSMutableDictionary *callProperties = [NSMutableDictionary new];
    if (call.from) {
        callProperties[@"from"] = call.from;
    }
    if (call.to) {
        callProperties[@"to"] = call.to;
    }
    if (call.sid) {
        callProperties[@"callSid"] = call.sid;
    }
    callProperties[@"isMuted"] = [NSNumber numberWithBool:call.muted];
    NSString *callState = [self stringFromCallState:call.state];
    if (callState) {
        callProperties[@"state"] = callState;
    }
    [self javascriptCallback:@"oncalldidconnect" withArguments:callProperties];
    
}
- (void) call:(TVOCall *)call didDisconnectWithError:(NSError *)error{
NSLog(@"Call disconnect with error: %@, %@", [call description], [error localizedDescription]);
    self.call = nil;
    [self javascriptErrorback:error];
}

/*- (void)callDidDisconnect:(TVOCall *)call {    
	    NSLog(@"callDidDisconnect:");

    // Call Kit Integration
    if (self.enableCallKit) {
        [self performEndCallActionWithUUID:call.uuid];
    }
    
    self.call = nil;
    [self javascriptCallback:@"oncalldiddisconnect"];
}*/

- (void) call:(TVOCall *)call didFailToConnectWithError:(NSError *)error {
    NSLog(@"Call Did Fail with Error: %@, %@", [call description], [error localizedDescription]);
    self.call = nil;
    [self javascriptErrorback:error];
}

#pragma mark Conversion methods for the plugin

- (NSString*) stringFromCallInviteState:(TVOCallInviteState)state {
    if (state == TVOCallInviteStatePending) {
        return @"pending";
    } else if (state == TVOCallInviteStateAccepted) {
        return @"accepted";
    } else if (state == TVOCallInviteStateRejected) {
        return @"rejected";
    } else if (state == TVOCallInviteStateCanceled) {
        return @"canceled";
    }
    
    return nil;
}

- (NSString*) stringFromCallState:(TVOCallState)state {
    if (state == TVOCallStateConnected) {
        return @"connected";
    } else if (state == TVOCallStateConnecting) {
        return @"connecting";
    } else if (state == TVOCallStateDisconnected) {
        return @"disconnected";
    }
    return nil;
}

#pragma mark Cordova Integration methods for the plugin Delegate - from TCPlugin.m/Stevie Graham

- (void) javascriptCallback:(NSString *)event withArguments:(NSDictionary *)arguments {
    NSDictionary *options   = [NSDictionary dictionaryWithObjectsAndKeys:event, @"callback", arguments, @"arguments", nil];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:options];
    [result setKeepCallbackAsBool:YES];
    
    [self.commandDelegate sendPluginResult:result callbackId:self.callback];
}

- (void) javascriptCallback:(NSString *)event {
    [self javascriptCallback:event withArguments:nil];
}

- (void) javascriptErrorback:(NSError *)error {
    NSDictionary *object    = [NSDictionary dictionaryWithObjectsAndKeys:[error localizedDescription], @"message", nil];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:object];
    [result setKeepCallbackAsBool:YES];
    
    [self.commandDelegate sendPluginResult:result callbackId:self.callback];
}
/*
#pragma mark - Local Notification methods used if CallKit isn't enabled

-(void) showNotification:(NSString*)alertBody {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];

    [center removeAllPendingNotificationRequests];

    
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
   // content.sound = [UNNotificationSound soundNamed:@"ringing.wav"];
    content.title = @"Answer";
    content.body = alertBody;
    

    UNNotificationRequest *request = [UNNotificationRequest
                                      requestWithIdentifier:@"IncomingCall" content:content trigger:nil];
    
    [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Error adding local notification for incoming call: %@", error.localizedDescription);
        }
    }];

}

-(void) cancelNotification {
    [[UNUserNotificationCenter currentNotificationCenter] removeAllDeliveredNotifications];
}

*/

#pragma mark - CXProviderDelegate - based on Twilio Voice with CallKit Quickstart ObjC

- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action {
    if (self.call) {
        NSLog(@"Sending Digits: %@", action.digits);
        [self.call sendDigits:action.digits];
    } else {
        NSLog(@"No current call");
    }
    
}

// All CallKit Integration Code comes from https://github.com/twilio/voice-callkit-quickstart-objc/blob/master/ObjCVoiceCallKitQuickstart/ViewController.m

- (void)providerDidReset:(CXProvider *)provider {
    TwilioVoice.audioEnabled = YES;
}

- (void)providerDidBegin:(CXProvider *)provider {
    // No implementation
}

- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession {
   TwilioVoice.audioEnabled = YES;
}

- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession {
   TwilioVoice.audioEnabled = NO;
}

- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action {
    // No implementation
}

- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action {
    
    [TwilioVoice configureAudioSession];
     TwilioVoice.audioEnabled = NO;
    self.call = [TwilioVoice call:self.accessToken
                                            params:@{}
                                          delegate:self];
    
    if (!self.call) {
        [action fail];
    } else {
      //  self.call.uuid = action.callUUID;
        [action fulfillWithDateStarted:[NSDate date]];
    }
}

- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action {

    // Below comment from: https://github.com/twilio/voice-callkit-quickstart-objc/blob/master/ObjCVoiceCallKitQuickstart/ViewController.m#L298
    
    // Comment below from
    // RCP: Workaround from https://forums.developer.apple.com/message/169511 suggests configuring audio in the
    //      completion block of the `reportNewIncomingCallWithUUID:update:completion:` method instead of in
    //      `provider:performAnswerCallAction:` per the WWDC examples.
    // [TwilioVoice configureAudioSession];
     TwilioVoice.audioEnabled = NO;
    self.call = [self.callInvite acceptWithDelegate:self];
    if (self.call) {
      //  self.call.uuid = [action callUUID];
    }
    
    self.callInvite = nil;
    
    [action fulfill];
}

- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action {
    
    TwilioVoice.audioEnabled = NO;
    
    if (self.callInvite && self.callInvite.state == TVOCallInviteStatePending) {
        [self.callInvite reject];
        self.callInvite = nil;
    } else if (self.call) {
        [self.call disconnect];
    }
    
    [action fulfill];
}

#pragma mark - CallKit Actions
- (void)performStartCallActionWithUUID:(NSUUID *)uuid handle:(NSString *)handle {
    if (uuid == nil || handle == nil) {
        return;
    }
    
    NSLog(@"performStartCallActionWithUUID: %@", [uuid UUIDString]);
    
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:handle];
    CXStartCallAction *startCallAction = [[CXStartCallAction alloc] initWithCallUUID:uuid handle:callHandle];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:startCallAction];
    
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"StartCallAction transaction request failed: %@", [error localizedDescription]);
        } else {
            NSLog(@"StartCallAction transaction request successful");
            
            CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
            callUpdate.remoteHandle = callHandle;
            callUpdate.supportsDTMF = YES;
            callUpdate.supportsHolding = NO;
            callUpdate.supportsGrouping = NO;
            callUpdate.supportsUngrouping = NO;
            callUpdate.hasVideo = NO;
            
            [self.callKitProvider reportCallWithUUID:uuid updated:callUpdate];
        }
    }];
}

- (void)reportIncomingCallFrom:(NSString *) from withUUID:(NSUUID *)uuid {
    
    NSLog(@"reportIncomingCallFrom: %@",[uuid UUIDString]);
    
    CXHandle *callHandle = [[CXHandle alloc] initWithType:CXHandleTypeGeneric value:from];
    
    CXCallUpdate *callUpdate = [[CXCallUpdate alloc] init];
    callUpdate.remoteHandle = callHandle;
    callUpdate.supportsDTMF = YES;
    callUpdate.supportsHolding = NO;
    callUpdate.supportsGrouping = NO;
    callUpdate.supportsUngrouping = NO;
    callUpdate.hasVideo = NO;
    
    [self.callKitProvider reportNewIncomingCallWithUUID:uuid update:callUpdate completion:^(NSError *error) {
        if (!error) {
            NSLog(@"Incoming call successfully reported.");
            
            // RCP: Workaround per https://forums.developer.apple.com/message/169511
            [TwilioVoice configureAudioSession];
        }
        else {
            NSLog(@"Failed to report incoming call successfully: %@.", [error localizedDescription]);
        }
    }];
}


- (void)performEndCallActionWithUUID:(NSUUID *)uuid {
    if (uuid == nil) {
        return;
    }
       
    CXEndCallAction *endCallAction = [[CXEndCallAction alloc] initWithCallUUID:uuid];
    CXTransaction *transaction = [[CXTransaction alloc] initWithAction:endCallAction];
    
    [self.callKitCallController requestTransaction:transaction completion:^(NSError *error) {
        if (error) {
            NSLog(@"EndCallAction transaction request failed: %@", [error localizedDescription]);
        }
        else {
            NSLog(@"EndCallAction transaction request successful");
        }
    }];
}

@end