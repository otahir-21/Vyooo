#import <Foundation/Foundation.h>

@protocol FlutterPluginRegistry;

/// Registers AgoraRtcNg + IrisMethodChannel when Dart invokes `registerAgora` (not at cold start).
/// Registration is idempotent: if plugins were already registered (e.g. [GeneratedPluginRegistrant]
/// still contained them), this is a no-op.
@interface AgoraDeferredRegistration : NSObject
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry> *)registry;
@end
