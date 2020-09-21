import UIKit
import Flutter

import flutter_uploader

func registerPlugins(registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
}

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    SwiftFlutterUploaderPlugin.registerPlugins = registerPlugins

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
