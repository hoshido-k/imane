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

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: json['structured_formatting']['main_text'] as String,
      secondaryText: json['structured_formatting']['secondary_text'] as String? ?? '',
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

/// Service for Google Places API
class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const String _apiKey = ApiKeys.googleMapsApiKey;

  /// Get autocomplete predictions for a search query
  ///
  /// [input] - The user's search query
  /// [language] - Language code (default: 'ja' for Japanese)
  /// [components] - Country restriction (default: 'country:jp' for Japan)
  Future<List<PlacePrediction>> getAutocompletePredictions(
    String input, {
    String language = 'ja',
    String components = 'country:jp',
  }) async {
    if (input.trim().isEmpty) {
      return [];
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&language=$language'
        '&components=$components'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((json) => PlacePrediction.fromJson(json))
              .toList();
          return predictions;
        } else if (data['status'] == 'ZERO_RESULTS') {
          return [];
        } else {
          final errorMessage = data['error_message'] ?? data['status'];
          print('Places API error: ${data['status']} - $errorMessage');
          throw Exception('Places API error: ${data['status']} - $errorMessage');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching autocomplete predictions: $e');
      return [];
    }
  }

  /// Get detailed information about a place by place ID
  ///
  /// [placeId] - The place ID from autocomplete prediction
  /// [language] - Language code (default: 'ja' for Japanese)
  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    String language = 'ja',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json'
        '?place_id=${Uri.encodeComponent(placeId)}'
        '&fields=place_id,name,formatted_address,geometry'
        '&language=$language'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        } else {
          throw Exception('Places API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching place details: $e');
      return null;
    }
  }

  /// Search places near a location
  ///
  /// [query] - Search query (e.g., "カフェ", "駅")
  /// [latitude] - Latitude of center point
  /// [longitude] - Longitude of center point
  /// [radius] - Search radius in meters (default: 1000)
  /// [language] - Language code (default: 'ja' for Japanese)
  Future<List<PlaceDetails>> searchNearby(
    String query, {
    required double latitude,
    required double longitude,
    int radius = 1000,
    String language = 'ja',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/place/nearbysearch/json'
        '?location=$latitude,$longitude'
        '&radius=$radius'
        '&keyword=${Uri.encodeComponent(query)}'
        '&language=$language'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final places = (data['results'] as List)
              .map((json) => PlaceDetails.fromJson(json))
              .toList();
          return places;
        } else if (data['status'] == 'ZERO_RESULTS') {
          return [];
        } else {
          throw Exception('Places API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error searching nearby places: $e');
      return [];
    }
  }

  /// Geocode an address to get coordinates
  ///
  /// [address] - Full address string
  /// [language] - Language code (default: 'ja' for Japanese)
  Future<PlaceDetails?> geocodeAddress(
    String address, {
    String language = 'ja',
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&language=$language'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['results'][0];
          final location = result['geometry']['location'];
          return PlaceDetails(
            placeId: result['place_id'] as String,
            name: result['formatted_address'] as String,
            formattedAddress: result['formatted_address'] as String,
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
          );
        } else {
          throw Exception('Geocoding API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to get address (緯度経度→住所)
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
        '$_baseUrl/geocode/json'
        '?latlng=$latitude,$longitude'
        '&language=$language'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final location = result['geometry']['location'];

          // Try to find a more specific name (e.g., building, landmark)
          String name = result['formatted_address'] as String;
          if (result['address_components'] != null && (result['address_components'] as List).isNotEmpty) {
            // Check for establishment or point_of_interest
            for (var component in result['address_components']) {
              if (component['types'] != null &&
                  (component['types'] as List).contains('establishment')) {
                name = component['long_name'] as String;
                break;
              }
            }
          }

          return PlaceDetails(
            placeId: result['place_id'] as String,
            name: name,
            formattedAddress: result['formatted_address'] as String,
            latitude: (location['lat'] as num).toDouble(),
            longitude: (location['lng'] as num).toDouble(),
          );
        } else {
          throw Exception('Reverse Geocoding API error: ${data['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
      return null;
    }
  }
}
