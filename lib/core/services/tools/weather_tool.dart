import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/pip_tool.dart';

/// Fetches current weather and temperature using Open-Meteo free geocoding and forecast API.
class WeatherTool extends PipTool {
  const WeatherTool()
      : super(
          name: 'get_weather',
          description: 'Get current weather condition and temperature for any city.',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: const [
            ToolParameterSpec(
              name: 'city',
              type: 'string',
              description: 'The name of the city, e.g. London, Tokyo, New York',
              isRequired: true,
            ),
          ],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> args) async {
    final city = (args['city'] as String?)?.trim() ?? '';
    if (city.isEmpty) {
      return {'error': 'City name is required'};
    }

    try {
      final geoUrl = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(city)}&count=1&language=en&format=json',
      );
      final geoRes = await http.get(geoUrl);
      if (geoRes.statusCode != 200) {
        return {'error': 'Failed to geocode location'};
      }
      final geoData = jsonDecode(geoRes.body);
      final results = geoData['results'] as List?;
      if (results == null || results.isEmpty) {
        return {'error': 'Location not found: $city'};
      }

      final lat = results[0]['latitude'];
      final lon = results[0]['longitude'];
      final name = results[0]['name'] ?? city;
      final country = results[0]['country'] ?? '';

      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
      );
      final weatherRes = await http.get(weatherUrl);
      if (weatherRes.statusCode != 200) {
        return {'error': 'Failed to retrieve weather data'};
      }

      final weatherData = jsonDecode(weatherRes.body);
      final current = weatherData['current'] as Map<String, dynamic>? ?? {};

      return {
        'location': '$name, $country',
        'temperature_celsius': current['temperature_2m'],
        'humidity_percent': current['relative_humidity_2m'],
        'wind_speed_kmh': current['wind_speed_10m'],
        'weather_code': current['weather_code'],
      };
    } catch (e) {
      return {'error': 'Weather query exception: $e'};
    }
  }
}
