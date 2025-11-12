import Flutter
import UIKit
import GoogleMaps
import UserNotifications

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

      // Register notification action categories
      registerNotificationActions()
    }

    // Register plugins AFTER initializing Google Maps
    GeneratedPluginRegistrant.register(with: self)

    // Register for APNs (Apple Push Notification service)
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Register notification actions for iOS
  @available(iOS 10.0, *)
  private func registerNotificationActions() {
    // Define "Open in Maps" action
    let openMapAction = UNNotificationAction(
      identifier: "OPEN_MAP_ACTION",
      title: "地図で開く",
      options: [.foreground]
    )

    // Define notification category with actions
    let mapCategory = UNNotificationCategory(
      identifier: "MAP_NOTIFICATION",
      actions: [openMapAction],
      intentIdentifiers: [],
      options: []
    )

    // Register the category
    UNUserNotificationCenter.current().setNotificationCategories([mapCategory])
    print("✓ Notification actions registered: MAP_NOTIFICATION")
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

  // Handle notification action button taps
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    // Check if "Open in Maps" action was tapped
    if response.actionIdentifier == "OPEN_MAP_ACTION" {
      print("✓ Open Map action tapped")

      // Get map link from notification data
      if let mapLink = userInfo["map_link"] as? String,
         let url = URL(string: mapLink) {
        print("Opening map URL: \(mapLink)")

        // Open map URL in external app (Maps app)
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:]) { success in
            if success {
              print("✓ Map URL opened successfully")
            } else {
              print("❌ Failed to open map URL")
            }
          }
        }
      } else {
        print("❌ No map link found in notification")
      }
    } else {
      // Default tap - open app
      print("✓ Notification tapped (default action)")
    }

    // Call Flutter's notification handler
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }
}
