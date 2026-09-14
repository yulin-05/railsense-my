import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RailAssistantService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String _model = 'gemini-3.6-flash';

  Future<String> getResponse(String message) async {
    final text = message.trim();

    if (text.isEmpty) {
      return 'Please enter a railway-related question.';
    }

    if (_apiKey.isEmpty) {
      debugPrint('Gemini API key is missing.');
      return _fallbackResponse(text);
    }

    try {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/interactions',
      );

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'model': _model,
              'input':
                  '''
You are RailSense Assistant, a railway travel assistant for Malaysia.

Answer the user's question clearly and briefly.

Rules:
- Only answer questions related to Malaysian railway travel, RailSense MY, public transport, railway crowd estimates, ridership, stations, routes, and travel planning.
- RailSense MY uses Malaysia Government Open Data.
- Do not claim that crowd information is real-time.
- Crowd levels are estimates based on available historical or latest government ridership data.
- Do not invent passenger numbers.
- Do not invent train schedules, fares, station facilities, or route information if you are unsure.
- If information is unavailable, clearly say that it is unavailable.
- Keep the answer commuter-friendly and concise.
- If the question is unrelated to railway travel, politely say that you can only assist with railway-related questions.

User question:
$text
''',
            }),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint('Gemini status: ${response.statusCode}');
      debugPrint('Gemini response: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);

        final steps = data['steps'];

        if (steps is List) {
          for (final step in steps.reversed) {
            if (step is Map<String, dynamic> &&
                step['type'] == 'model_output') {
              final content = step['content'];

              if (content is List) {
                for (final item in content) {
                  if (item is Map<String, dynamic> && item['type'] == 'text') {
                    final outputText = item['text'];

                    if (outputText is String && outputText.trim().isNotEmpty) {
                      return outputText.trim();
                    }
                  }
                }
              }
            }
          }
        }

        debugPrint('Gemini returned no readable text.');
        return _fallbackResponse(text);
      }

      debugPrint('Gemini API error ${response.statusCode}: ${response.body}');

      return _fallbackResponse(text);
    } catch (error) {
      debugPrint('Gemini exception: $error');
      return _fallbackResponse(text);
    }
  }

  String _fallbackResponse(String message) {
    final text = message.toLowerCase();

    if (text.contains('best time') ||
        text.contains('when should') ||
        text.contains('off peak') ||
        text.contains('off-peak')) {
      return 'You can check the Smart Commute Dashboard for the recommended off-peak travel period based on available ridership data.';
    }

    if (text.contains('crowd') ||
        text.contains('crowded') ||
        text.contains('busy')) {
      return 'RailSense MY estimates crowd levels using Malaysia Government Open Data ridership records. These are estimates and not real-time train occupancy data.';
    }

    if (text.contains('popular') || text.contains('highest usage')) {
      return 'You can check the Insights module to compare railway usage and identify higher-usage railway services.';
    }

    if (text.contains('route') || text.contains('station')) {
      return 'You can use the Railway Explorer to search railway routes and view available station information.';
    }

    if (text.contains('data source') ||
        text.contains('government data') ||
        text.contains('open data') ||
        text.contains('where does the data')) {
      return 'RailSense MY uses Malaysia Government Open Data for railway ridership analysis and travel insights.';
    }

    return 'I can help with Malaysian railway crowd estimates, travel times, railway usage, routes and RailSense MY features.';
  }
}
