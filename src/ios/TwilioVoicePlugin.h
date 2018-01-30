#import <Foundation/Foundation.h>
#import <Cordova/CDV.h>


@interface TwilioVoicePlugin : CDVPlugin <TVOCallDelegate, TVONotificationDelegate> { }

- (void) pluginInitialize;

# pragma mark javascript mapper methods
- (void) initializeWithAccessToken:(CDVInvokedUrlCommand*)command;
- (void) call:(CDVInvokedUrlCommand*)command;
- (void) sendDigits:(CDVInvokedUrlCommand*)command;
- (void) disconnect:(CDVInvokedUrlCommand*)command;
- (void) acceptCallInvite:(CDVInvokedUrlCommand*)command;
- (void) rejectCallInvite: (CDVInvokedUrlCommand*)command;
- (void) setSpeaker:(CDVInvokedUrlCommand*)command;
- (void) muteCall: (CDVInvokedUrlCommand*)command;
- (void) unmuteCall: (CDVInvokedUrlCommand*)command;
- (void) isCallMuted: (CDVInvokedUrlCommand*)command;

#pragma mark TVOCallDelegate
- (void) callDidConnect:(TVOCall *)call;
- (void) call:(TVOCall *)call didDisconnectWithError:(NSError *)error;
- (void) call:(TVOCall *)call didFailToConnectWithError:(NSError *)error;

#pragma mark TVONotificationDelegate
- (void)callInviteReceived:(TVOCallInvite *)callInvite;
- (void)notificationError:(NSError *)error;

#pragma mark Cordova Integration methods for the plugin Delegate 
- (void) javascriptCallback:(NSString *)event withArguments:(NSDictionary *)arguments;
- (void) javascriptCallback:(NSString *)event;
- (void) javascriptErrorback:(NSError *)error;


#pragma mark - CallKit Actions
- (void)performStartCallActionWithUUID:(NSUUID *)uuid handle:(NSString *)handle;
- (void)reportIncomingCallFrom:(NSString *) from withUUID:(NSUUID *)uuid;
- (void)performEndCallActionWithUUID:(NSUUID *)uuid;


@end