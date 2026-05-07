import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Province {
  final int id;
  final String name;
  final List<District> districts;

  Province({required this.id, required this.name, required this.districts});

  factory Province.fromJson(Map<String, dynamic> json) {
    final districtsList = json['districts'] as List? ?? [];
    final parsedDistricts = districtsList.map((d) => District.fromJson(d)).toList();
    return Province(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      districts: parsedDistricts,
    );
  }
}

class District {
  final int id;
  final String name;

  District({required this.id, required this.name});

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class Neighborhood {
  final int id;
  final String name;

  Neighborhood({required this.id, required this.name});

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class LocationApiService {
  static const String _baseUrl = 'https://api.turkiyeapi.dev/v1';

  // Memory cache to prevent redundant API calls
  static List<Province>? _cachedProvinces;
  static final Map<int, List<Neighborhood>> _cachedNeighborhoods = {};

  /// Fetches all countries supported (primarily Turkey)
  static List<String> getCountries() {
    return ['Türkiye'];
  }

  /// Fetches all provinces (cities) and their districts from the API
  static Future<List<Province>> getProvinces() async {
    if (_cachedProvinces != null) {
      return _cachedProvinces!;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/provinces')).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'OK' && decoded['data'] != null) {
          final list = decoded['data'] as List;
          final provinces = list.map((item) => Province.fromJson(item)).toList();
          // Sort alphabetically
          provinces.sort((a, b) => a.name.compareTo(b.name));
          _cachedProvinces = provinces;
          return provinces;
        }
      }
    } catch (e) {
      // Graceful error fallback below
      debugPrint('LocationApiService Error: $e');
    }

    // Dynamic offline fallback if API fails or device is offline
    return _getFallbackProvinces();
  }

  /// Fetches neighborhoods of a specific district from the API
  static Future<List<Neighborhood>> getNeighborhoods(int districtId) async {
    if (_cachedNeighborhoods.containsKey(districtId)) {
      return _cachedNeighborhoods[districtId]!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/neighborhoods?districtId=$districtId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['status'] == 'OK' && decoded['data'] != null) {
          final list = decoded['data'] as List;
          final neighborhoods = list.map((item) => Neighborhood.fromJson(item)).toList();
          neighborhoods.sort((a, b) => a.name.compareTo(b.name));
          _cachedNeighborhoods[districtId] = neighborhoods;
          return neighborhoods;
        }
      }
    } catch (e) {
      debugPrint('LocationApiService Error: $e');
    }

    // Dynamic offline neighborhood fallback
    return [
      Neighborhood(id: 1, name: 'Merkez Mahallesi'),
      Neighborhood(id: 2, name: 'Atatürk Mahallesi'),
      Neighborhood(id: 3, name: 'Cumhuriyet Mahallesi'),
      Neighborhood(id: 4, name: 'Hürriyet Mahallesi'),
      Neighborhood(id: 5, name: 'Fatih Mahallesi'),
    ];
  }

  /// High quality offline mock data in case the server is unreachable
  static List<Province> _getFallbackProvinces() {
    return [
      Province(
        id: 34,
        name: 'İstanbul',
        districts: [
          District(id: 2048, name: 'Arnavutköy'),
          District(id: 1183, name: 'Beşiktaş'),
          District(id: 1421, name: 'Kadıköy'),
          District(id: 1604, name: 'Sarıyer'),
          District(id: 1708, name: 'Üsküdar'),
        ],
      ),
      Province(
        id: 6,
        name: 'Ankara',
        districts: [
          District(id: 1231, name: 'Çankaya'),
          District(id: 1745, name: 'Keçiören'),
          District(id: 1746, name: 'Mamak'),
          District(id: 1723, name: 'Yenimahalle'),
        ],
      ),
      Province(
        id: 35,
        name: 'İzmir',
        districts: [
          District(id: 1203, name: 'Bornova'),
          District(id: 1780, name: 'Buca'),
          District(id: 1819, name: 'Konak'),
          District(id: 1448, name: 'Karşıyaka'),
        ],
      ),
    ];
  }
}
