#import <Foundation/Foundation.h>

@protocol FlutterPluginRegistry;

/// Registers AgoraRtcNg + IrisMethodChannel once, when the user opens live (not at cold start).
@interface AgoraDeferredRegistration : NSObject
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry> *)registry;
@end
