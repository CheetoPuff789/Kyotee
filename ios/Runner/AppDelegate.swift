import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "kyotee/app_icon",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "supportsAlternateIcons":
          if #available(iOS 10.3, *) {
            result(UIApplication.shared.supportsAlternateIcons)
          } else {
            result(false)
          }
        case "currentIconName":
          if #available(iOS 10.3, *) {
            if let name = UIApplication.shared.alternateIconName {
              result(name)
            } else {
              result("")
            }
          } else {
            result("")
          }
        case "setIcon":
          guard #available(iOS 10.3, *) else {
            result(
              FlutterError(
                code: "unavailable",
                message: "Alternate icons require iOS 10.3 or later.",
                details: nil
              )
            )
            return
          }
          guard let args = call.arguments as? [String: Any?] else {
            result(
              FlutterError(
                code: "bad_args",
                message: "Missing arguments.",
                details: nil
              )
            )
            return
          }
          let iconArg = args["iconName"] ?? nil
          let iconName = (iconArg as? String)?.isEmpty == false ? iconArg as? String : nil
          UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
              result(
                FlutterError(
                  code: "icon_error",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            } else {
              result(true)
            }
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
