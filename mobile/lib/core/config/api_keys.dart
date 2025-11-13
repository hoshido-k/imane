/// Google Maps Platform API Keys
///
/// This file reads API keys from environment variables passed via --dart-define.
/// NEVER hardcode API keys in this file.
///
/// SETUP INSTRUCTIONS:
/// 1. Create a .env file in the mobile/ directory (see .env.example)
/// 2. Add your API keys:
///    GOOGLE_MAPS_API_KEY_DEV=your-dev-key-here
///    GOOGLE_MAPS_API_KEY_PROD=your-prod-key-here
/// 3. Build scripts will automatically load and inject these keys
///
/// For manual runs, use --dart-define flags:
/// flutter run --dart-define=GOOGLE_MAPS_API_KEY_DEV=xxx --dart-define=ENVIRONMENT=development
class ApiKeys {
  /// Current environment (development or production)
  static const String _environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  /// Development Google Maps API Key
  static const String _googleMapsApiKeyDev = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY_DEV',
    defaultValue: '',
  );

  /// Production Google Maps API Key
  static const String _googleMapsApiKeyProd = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY_PROD',
    defaultValue: '',
  );

  /// Get the appropriate Google Maps API key based on current environment
  /// Used for:
  /// - Maps SDK for iOS (map display)
  /// - Places API (autocomplete, place search)
  /// - Geocoding API (address to coordinates conversion)
  static String get googleMapsApiKey {
    final key = _environment == 'production'
        ? _googleMapsApiKeyProd
        : _googleMapsApiKeyDev;

    if (key.isEmpty) {
      throw Exception(
        'Google Maps API key not configured for environment: $_environment\n'
        'Please set GOOGLE_MAPS_API_KEY_${_environment.toUpperCase()} in your .env file\n'
        'or pass it via --dart-define=GOOGLE_MAPS_API_KEY_${_environment.toUpperCase()}=your-key'
      );
    }

    return key;
  }

  /// Get current environment name
  static String get environment => _environment;

  /// Check if running in production
  static bool get isProduction => _environment == 'production';

  /// Check if running in development
  static bool get isDevelopment => _environment == 'development';
}
