import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../models/ktmb_ridership.dart';
import '../models/rail_ridership.dart';
import '../models/route_ridership.dart';
import '../models/station_facilities.dart';

class GovernmentDataService {
  const GovernmentDataService();

  static const Duration _requestTimeout = Duration(seconds: 5);

  static const String _headlineAsset =
      'assets/data/ridership_headline_sample.json';

  static const String _ktmbAsset = 'assets/data/ridership_ktmb_sample.json';

  static const String _rapidrailOdAsset =
      'assets/data/rapidrail_od_sample.json';

  static const String _stationFacilitiesAsset =
      'assets/data/station_facilities_reference.json';

  static final Uri _headlineApiUri = Uri.https(
    'api.data.gov.my',
    '/data-catalogue',
    {'id': 'ridership_headline', 'sort': '-date', 'limit': '100'},
  );

  static final Uri _ktmbApiUri =
      Uri.https('api.data.gov.my', '/data-catalogue', {
        'id': 'ridership_ktmb_daily',
        'filter': 'komuter@service',
        'sort': '-date',
        'limit': '100',
      });

  Future<List<RailRidership>> loadHeadlineRidership() async {
    try {
      final response = await http.get(_headlineApiUri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw HttpException('Headline API returned ${response.statusCode}.');
      }

      final records = _decodeJsonList(
        response.body,
        sourceName: 'ridership_headline API',
      );

      if (records.isEmpty) {
        throw const FormatException(
          'ridership_headline API returned no records.',
        );
      }

      return records.map(RailRidership.fromJson).toList();
    } catch (_) {
      return _loadHeadlineFromAsset();
    }
  }

  Future<List<KtmbRidership>> loadKtmbRidership() async {
    try {
      final response = await http.get(_ktmbApiUri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        throw HttpException('KTMB API returned ${response.statusCode}.');
      }

      final records = _decodeJsonList(
        response.body,
        sourceName: 'ridership_ktmb_daily API',
      );

      if (records.isEmpty) {
        throw const FormatException(
          'ridership_ktmb_daily API returned no records.',
        );
      }

      return records.map(KtmbRidership.fromJson).toList();
    } catch (_) {
      return _loadKtmbFromAsset();
    }
  }

  Future<List<RouteRidership>> loadRapidRailOdRidership() async {
    final jsonString = await rootBundle.loadString(_rapidrailOdAsset);

    final records = _decodeJsonList(
      jsonString,
      sourceName: 'rapidrail_od_sample.json',
    );

    return records.map(RouteRidership.fromJson).toList();
  }

  Future<List<StationReference>> loadStationFacilities() async {
    final jsonString = await rootBundle.loadString(_stationFacilitiesAsset);

    final decodedData = jsonDecode(jsonString);

    if (decodedData is! Map<String, dynamic> ||
        decodedData['stations'] is! List) {
      throw const FormatException(
        'station_facilities_reference.json must contain a stations array.',
      );
    }

    return (decodedData['stations'] as List)
        .whereType<Map<String, dynamic>>()
        .map(StationReference.fromJson)
        .toList();
  }

  Future<List<RailRidership>> _loadHeadlineFromAsset() async {
    final jsonString = await rootBundle.loadString(_headlineAsset);

    final records = _decodeJsonList(
      jsonString,
      sourceName: 'ridership_headline_sample.json',
    );

    return records.map(RailRidership.fromJson).toList();
  }

  Future<List<KtmbRidership>> _loadKtmbFromAsset() async {
    final jsonString = await rootBundle.loadString(_ktmbAsset);

    if (jsonString.trim().isEmpty) {
      return const [];
    }

    final records = _decodeJsonList(
      jsonString,
      sourceName: 'ridership_ktmb_sample.json',
    );

    return records.map(KtmbRidership.fromJson).toList();
  }

  List<Map<String, dynamic>> _decodeJsonList(
    String jsonString, {
    required String sourceName,
  }) {
    final decodedData = jsonDecode(jsonString);

    if (decodedData is! List) {
      throw FormatException('$sourceName must contain a JSON array.');
    }

    return decodedData.whereType<Map<String, dynamic>>().toList();
  }
}

class HttpException implements Exception {
  const HttpException(this.message);

  final String message;

  @override
  String toString() => message;
}
