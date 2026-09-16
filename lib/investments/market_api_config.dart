import 'package:flutter_dotenv/flutter_dotenv.dart';

class MarketApiConfig {
  static String get apiKey => dotenv.env['TWELVE_DATA_API_KEY'] ??
      String.fromEnvironment('TWELVE_DATA_API_KEY');
  static const baseUrl = String.fromEnvironment(
    'TWELVE_DATA_BASE_URL',
    defaultValue: 'https://api.twelvedata.com',
  );
}