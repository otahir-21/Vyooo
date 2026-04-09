import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if ok, let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "vyooo/deferred_native_plugins",
        binaryMessenger: controller.engine.binaryMessenger
      )
      channel.setMethodCallHandler { [weak controller] call, result in
        if call.method == "registerAgora" {
          guard let engine = controller?.engine else {
            result(FlutterError(code: "no_engine", message: nil, details: nil))
            return
          }
          AgoraDeferredRegistration.register(with: engine)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return ok
  }
}
