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

    // Register for remote notifications (required for FCM on iOS)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // Register plugins AFTER initializing Google Maps
    GeneratedPluginRegistrant.register(with: self)

    // Register for APNs (Apple Push Notification service)
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle APNs token registration
  override func application(_ application: UIApplication,
                           didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("✓ APNs token registered successfully")
    // Firebase Messaging will automatically receive this token
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Handle APNs token registration failure
  override func application(_ application: UIApplication,
                           didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
  }
}
