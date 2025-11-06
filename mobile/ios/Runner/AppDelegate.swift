import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // CRITICAL: Initialize Google Maps BEFORE registering plugins
    // Load Google Maps API key from GoogleService-Info.plist (not tracked in git)
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let config = NSDictionary(contentsOfFile: path),
       let apiKey = config["GoogleMapsAPIKey"] as? String {
      GMSServices.provideAPIKey(apiKey)
      print("✓ Google Maps API key loaded successfully: \(String(apiKey.prefix(10)))...")
    } else {
      print("❌ CRITICAL: GoogleService-Info.plist not found or GoogleMapsAPIKey is missing")
      // This will cause the app to crash when trying to use maps
    }

    // Register plugins AFTER initializing Google Maps
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
