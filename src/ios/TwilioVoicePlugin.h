#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>

@interface TwilioVoicePlugin : CDVPlugin <PKPushRegistryDelegate, TVOCallDelegate, TVONotificationDelegate, CXProviderDelegate> { }

- (void) pluginInitialize;

# pragma mark javascript mapper methods
- (void) initializeWithAccessToken:(CDVInvokedUrlCommand*)command;
- (void) call:(CDVInvokedUrlCommand*)command;
- (void) sendDigits:(CDVInvokedUrlCommand*)command;
- (void) disconnect:(CDVInvokedUrlCommand*)command;
- (void) acceptCallInvite:(CDVInvokedUrlCommand*)command;
- (void) rejectCallInvite: (CDVInvokedUrlCommand*)command;
- (void)setSpeaker:(CDVInvokedUrlCommand*)command;
- (void) muteCall: (CDVInvokedUrlCommand*)command;
- (void) unmuteCall: (CDVInvokedUrlCommand*)command;
- (void) isCallMuted: (CDVInvokedUrlCommand*)command;

#pragma mark PKPushRegistryDelegate methods
- (void)pushRegistry:(PKPushRegistry *)registry didUpdatePushCredentials:(PKPushCredentials *)credentials forType:(PKPushType)type;
- (void)pushRegistry:(PKPushRegistry *)registry didInvalidatePushTokenForType:(PKPushType)type;
- (void)pushRegistry:(PKPushRegistry *)registry didReceiveIncomingPushWithPayload:(PKPushPayload *)payload forType:(PKPushType)type;

#pragma mark TVONotificationDelegate
- (void)callInviteReceived:(TVOCallInvite *)callInvite;
- (void)callinvitecanceled:(TVOCallInvite *)callInvite;
- (void)notificationError:(NSError *)error;

#pragma mark TVOCallDelegate
- (void)callDidConnect:(TVOCall *)call
- (void)callDidDisconnect:(TVOCall *)call;
- (void)call:(TVOCall *)call didFailWithError:(NSError *)error;

#pragma mark Conversion methods for the plugin
- (NSString*) stringFromCallInviteState:(TVOCallInviteState)state;
- (NSString*) stringFromCallState:(TVOCallState)state;

#pragma mark Cordova Integration methods for the plugin Delegate 
- (void) javascriptCallback:(NSString *)event withArguments:(NSDictionary *)arguments;
- (void) javascriptCallback:(NSString *)event;
- (void) javascriptErrorback:(NSError *)error;

#pragma mark - CXProviderDelegate - based on Twilio Voice with CallKit Quickstart ObjC
- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action;
- (void)providerDidReset:(CXProvider *)provider;
- (void)providerDidBegin:(CXProvider *)provider;
- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession;
- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession;
- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action;
- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action;
- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action;
- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action;

#pragma mark - CallKit Actions
- (void)performStartCallActionWithUUID:(NSUUID *)uuid handle:(NSString *)handle;
- (void)reportIncomingCallFrom:(NSString *) from withUUID:(NSUUID *)uuid;
- (void)performEndCallActionWithUUID:(NSUUID *)uuid;


@end