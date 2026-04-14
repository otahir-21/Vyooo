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

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry> *)registry {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [AgoraRtcNgPlugin registerWithRegistrar:[registry registrarForPlugin:@"AgoraRtcNgPlugin"]];
    [IrisMethodChannelPlugin registerWithRegistrar:[registry registrarForPlugin:@"IrisMethodChannelPlugin"]];
  });
}

@end
