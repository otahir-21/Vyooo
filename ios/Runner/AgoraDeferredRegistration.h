#import <Foundation/Foundation.h>

@class FlutterEngine;

/// Registers AgoraRtcNg + IrisMethodChannel once, when the user opens live (not at cold start).
@interface AgoraDeferredRegistration : NSObject
+ (void)registerWithEngine:(FlutterEngine *)engine;
@end
