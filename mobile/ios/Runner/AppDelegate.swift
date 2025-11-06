import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Load Google Maps API key from GoogleService-Info.plist (not tracked in git)
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let config = NSDictionary(contentsOfFile: path),
       let apiKey = config["GOOGLE_MAPS_API_KEY"] as? String {
      GMSServices.provideAPIKey(apiKey)
    } else {
      print("Warning: GoogleService-Info.plist not found or GOOGLE_MAPS_API_KEY is missing")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
