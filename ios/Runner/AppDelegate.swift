import Flutter
import UIKit

#if DEBUG && !targetEnvironment(simulator)
#error("Physical iPhone Debug mode is blocked for Vyooo because Agora/Iris can crash with EXC_BAD_ACCESS. Use Profile/Release (flutter run --profile/--release).")
#endif

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    guard let registrar = self.registrar(forPlugin: "VyoooDeferredNativePlugins") else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    let channel = FlutterMethodChannel(
      name: "vyooo/deferred_native_plugins",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "registerAgora" {
        guard let self else {
          result(FlutterError(code: "no_registry", message: nil, details: nil))
          return
        }
        AgoraDeferredRegistration.register(with: self)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
