import 'package:idz_flutter/idz_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted runtime config for the demo app.
///
/// In production you would never store an API key client-side — fetch a
/// short-lived scoped key from your own backend instead. The example app
/// stores it in SharedPreferences purely so you can paste a test key
/// and exercise the SDK end to end.
class AppConfig {
  static const _baseUrlKey = 'api_base_url';
  static const _apiKeyKey = 'api_key';
  static const _docTypeKey = 'document_type';
  static const String _defaultBaseUrl = 'https://api.idz.holool.dev';

  static String baseUrl = _defaultBaseUrl;
  static String apiKey = '';
  static DocumentType documentType = DocumentType.algerianNationalId;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
    apiKey = prefs.getString(_apiKeyKey) ?? '';
    final dtRaw = prefs.getString(_docTypeKey);
    documentType =
        DocumentType.fromWire(dtRaw) ?? DocumentType.algerianNationalId;
  }

  static Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
    baseUrl = url;
  }

  static Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
    apiKey = key;
  }

  static Future<void> saveDocumentType(DocumentType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_docTypeKey, type.wireValue);
    documentType = type;
  }

  static bool get isReady => apiKey.isNotEmpty;
}
