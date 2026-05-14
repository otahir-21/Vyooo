#import "AgoraDeferredRegistration.h"
#import <Flutter/Flutter.h>

#if __has_include(<agora_rtc_engine/AgoraRtcNgPlugin.h>)
#import <agora_rtc_engine/AgoraRtcNgPlugin.h>
#else
@import agora_rtc_engine;
#endif

#if __has_include(<iris_method_channel/IrisMethodChannelPlugin.h>)
#import <iris_method_channel/IrisMethodChannelPlugin.h>
#else
@import iris_method_channel;
#endif

@implementation AgoraDeferredRegistration

/// Idempotent: `GeneratedPluginRegistrant` may still register Agora/Iris at launch if the
/// strip script did not run for that build (ordering, `flutter run` edge cases, or a stale
/// registrant). Calling `registrarForPlugin:` when the key already exists throws
/// `NSInternalInconsistencyException` ("Duplicate plugin key"). Skip any plugin already
/// present via `hasPlugin:` (FlutterEngine sets the key when registration completes).
+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry> *)registry {
  static NSString *const kAgoraKey = @"AgoraRtcNgPlugin";
  static NSString *const kIrisKey = @"IrisMethodChannelPlugin";
  @synchronized([AgoraDeferredRegistration class]) {
    if (![registry hasPlugin:kAgoraKey]) {
      [AgoraRtcNgPlugin registerWithRegistrar:[registry registrarForPlugin:kAgoraKey]];
    }
    if (![registry hasPlugin:kIrisKey]) {
      [IrisMethodChannelPlugin registerWithRegistrar:[registry registrarForPlugin:kIrisKey]];
    }
  }
}

@end
