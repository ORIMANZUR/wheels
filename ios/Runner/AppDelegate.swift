import Flutter
import UIKit
import GoogleMaps

GMSServices.provideAPIKey("AIzaSyDCaN5vjNn0_3iaSM46_biQlhlGx0EthSc")
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
