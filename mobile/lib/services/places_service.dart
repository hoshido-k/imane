import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_keys.dart';

/// Model for place autocomplete prediction
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  /// Factory for Places API (New) format
  factory PlacePrediction.fromJsonNew(Map<String, dynamic> json) {
    final placePrediction = json['placePrediction'] ?? {};
    final structuredFormat = placePrediction['structuredFormat'] ?? {};

    return PlacePrediction(
      placeId: placePrediction['placeId'] as String? ?? '',
      description: placePrediction['text']?['text'] as String? ?? '',
      mainText: structuredFormat['mainText']?['text'] as String? ?? '',
      secondaryText: structuredFormat['secondaryText']?['text'] as String? ?? '',
    );
  }
}

/// Model for place details with coordinates
class PlaceDetails {
  final String placeId;
  final String name;
  final String formattedAddress;
  final double latitude;
  final double longitude;

  PlaceDetails({
    required this.placeId,
    required this.name,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  /// Factory for Places API (New) format
  factory PlaceDetails.fromJsonNew(Map<String, dynamic> json, String placeId) {
    final location = json['location'] ?? {};
    final displayName = json['displayName'] ?? {};
    final formattedAddress = json['formattedAddress'] as String? ?? '';

    return PlaceDetails(
      placeId: placeId,
      name: displayName['text'] as String? ?? formattedAddress,
      formattedAddress: formattedAddress,
      latitude: (location['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (location['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Legacy format (kept for Geocoding API compatibility)
  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    final location = json['geometry']['location'];
    return PlaceDetails(
      placeId: json['place_id'] as String,
      name: json['name'] as String? ?? json['formatted_address'] as String,
      formattedAddress: json['formatted_address'] as String,
      latitude: (location['lat'] as num).toDouble(),
      longitude: (location['lng'] as num).toDouble(),
    );
  }
}

/// Service for Google Places API (New)
class PlacesService {
  // Places API (New) endpoints
  static const String _placesBaseUrl = 'https://places.googleapis.com/v1';

  // Geocoding API (still uses legacy endpoint)
  static const String _geocodingBaseUrl = 'https://maps.googleapis.com/maps/api';

  static const String _apiKey = ApiKeys.googleMapsApiKey;

  /// Get autocomplete predictions for a search query using Places API (New)
  ///
  /// [input] - The user's search query
  /// [language] - Language code (default: 'ja' for Japanese)
  /// [region] - Region code (default: 'jp' for Japan)
  Future<List<PlacePrediction>> getAutocompletePredictions(
    String input, {
    String language = 'ja',
    String region = 'jp',
  }) async {
    if (input.trim().isEmpty) {
      return [];
    }

    try {
      final url = Uri.parse('$_placesBaseUrl/places:autocomplete');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat',
        },
        body: json.encode({
          'input': input,
          'languageCode': language,
          'regionCode': region,
          'includedPrimaryTypes': [], // Empty to include all types
          'includedRegionCodes': [region.toUpperCase()],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['suggestions'] != null && (data['suggestions'] as List).isNotEmpty) {
          final predictions = (data['suggestions'] as List)
              .where((s) => s['placePrediction'] != null)
              .map((s) => PlacePrediction.fromJsonNew(s))
              .toList();
          return predictions;
        } else {
          return [];
        }
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Unknown error';
        print('Places API error: ${response.statusCode} - $errorMessage');
        throw Exception('Places API error: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      print('Error fetching autocomplete predictions: $e');
      return [];
    }
  }

  /// Get detailed information about a place by place ID
  /// Uses Geocoding API with place_id for better Japanese language support
  ///
  /// [placeId] - The place ID from autocomplete prediction
  /// [language] - Language code (default: 'ja' for Japanese)
  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    String language = 'ja',
  }) async {
    try {
      // Use Geocoding API with place_id parameter for better Japanese language support
      final url = Uri.parse(
        '$_geocodingBaseUrl/geocode/json'
        '?place_id=$placeId'
        '&language=$language'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[PlaceDetails Geocoding] Response status: ${data['status']}');

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final formattedAddress = result['formatted_address'] as String;

          print('[PlaceDetails Geocoding] Formatted address: $formattedAddress');

          // Try to find a more specific name
          String name = formattedAddress;
          if (result['address_components'] != null && (result['address_components'] as List).isNotEmpty) {
            // Look for establishment, point_of_interest, or locality name
            for (var component in result['address_components']) {
              if (component['types'] != null) {
                final types = component['types'] as List;
                if (types.contains('establishment') ||
                    types.contains('point_of_interest') ||
                    types.contains('locality')) {
                  name = component['long_name'] as String;
                  print('[PlaceDetails Geocoding] Found name: $name');
                  break;
                }
              }
            }
          }

          return PlaceDetails(
            placeId: placeId,
            name: name,
            formattedAddress: formattedAddress,
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
          );
        } else {
          print('[PlaceDetails Geocoding] No results or error status: ${data['status']}');
          throw Exception('Geocoding API error: ${data['status']}');
        }
      } else {
        print('[PlaceDetails Geocoding] HTTP error: ${response.statusCode}');
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('[PlaceDetails Geocoding] Error fetching place details: $e');
      return null;
    }
  }

  /// Search address by postal code (郵便番号→住所)
  /// Uses Geocoding API with components parameter for better results
  ///
  /// [postalCode] - Japanese postal code (e.g., "1000001")
  /// [language] - Language code (default: 'ja' for Japanese)
  Future<PlaceDetails?> searchByPostalCode(
    String postalCode, {
    String language = 'ja',
  }) async {
    try {
      // Format postal code with hyphen for better results (XXX-XXXX)
      String formattedPostalCode = postalCode;
      if (postalCode.length == 7 && !postalCode.contains('-')) {
        formattedPostalCode = '${postalCode.substring(0, 3)}-${postalCode.substring(3)}';
      }

      // Use components parameter for more detailed address results
      final url = Uri.parse(
        '$_geocodingBaseUrl/geocode/json'
        '?components=postal_code:$formattedPostalCode|country:JP'
        '&language=$language'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('[PostalCode API] Response status: ${data['status']}');
        print('[PostalCode API] Results count: ${data['results']?.length ?? 0}');

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          // Get the most detailed result (usually results[0])
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final formattedAddress = result['formatted_address'] as String;

          print('[PostalCode API] Formatted address: $formattedAddress');
          print('[PostalCode API] Address components: ${result['address_components']}');

          return PlaceDetails(
            placeId: result['place_id'] as String,
            name: formattedAddress,
            formattedAddress: formattedAddress,
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
          );
        } else {
          print('[PostalCode API] No results or error status: ${data['status']}');
          throw Exception('Geocoding API error: ${data['status']}');
        }
      } else {
        print('[PostalCode API] HTTP error: ${response.statusCode}');
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('[PostalCode API] Error searching by postal code: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to get address (緯度経度→住所)
  /// Uses Geocoding API (legacy endpoint)
  ///
  /// [latitude] - Latitude
  /// [longitude] - Longitude
  /// [language] - Language code (default: 'ja' for Japanese)
  Future<PlaceDetails?> reverseGeocode(
    double latitude,
    double longitude, {
    String language = 'ja',
  }) async {
    try {
      final url = Uri.parse(
        '$_geocodingBaseUrl/geocode/json'
        '?latlng=$latitude,$longitude'
        '&language=$language'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        print('[ReverseGeocode API] Response status: ${data['status']}');

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          final formattedAddress = result['formatted_address'] as String;

          print('[ReverseGeocode API] Formatted address: $formattedAddress');

          // Try to find a more specific name (e.g., building, landmark)
          String name = formattedAddress;
          if (result['address_components'] != null && (result['address_components'] as List).isNotEmpty) {
            // Check for establishment or point_of_interest
            for (var component in result['address_components']) {
              if (component['types'] != null &&
                  (component['types'] as List).contains('establishment')) {
                name = component['long_name'] as String;
                print('[ReverseGeocode API] Found establishment name: $name');
                break;
              }
            }
          }

          return PlaceDetails(
            placeId: result['place_id'] as String,
            name: name,
            formattedAddress: formattedAddress,
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
          );
        } else {
          print('[ReverseGeocode API] No results or error status: ${data['status']}');
          throw Exception('Reverse Geocoding API error: ${data['status']}');
        }
      } else {
        print('[ReverseGeocode API] HTTP error: ${response.statusCode}');
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('[ReverseGeocode API] Error reverse geocoding: $e');
      return null;
    }
  }
}
