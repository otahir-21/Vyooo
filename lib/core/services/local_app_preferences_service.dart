import 'package:shared_preferences/shared_preferences.dart';

/// Device-local settings (language, media quality) — not synced to Firestore.
class LocalAppPreferencesService {
  LocalAppPreferencesService._();
  static final LocalAppPreferencesService instance =
      LocalAppPreferencesService._();

  static const _keyLanguage = 'app_language_code';
  static const _keyCellularUpload = 'data_cellular_upload';
  static const _keyHighQualityUpload = 'data_high_quality_upload';
  static const _keyAutoplayOnCellular = 'data_autoplay_cellular';

  static const String defaultLanguage = 'en';

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'ar': 'Arabic',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
    'hi': 'Hindi',
    'ur': 'Urdu',
  };

  Future<String> getLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_keyLanguage) ?? defaultLanguage;
    return supportedLanguages.containsKey(code) ? code : defaultLanguage;
  }

  Future<void> setLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyLanguage,
      supportedLanguages.containsKey(code) ? code : defaultLanguage,
    );
  }

  Future<bool> getCellularUploadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCellularUpload) ?? false;
  }

  Future<void> setCellularUploadEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCellularUpload, value);
  }

  Future<bool> getHighQualityUploadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHighQualityUpload) ?? true;
  }

  Future<void> setHighQualityUploadEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHighQualityUpload, value);
  }

  Future<bool> getAutoplayOnCellular() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoplayOnCellular) ?? false;
  }

  Future<void> setAutoplayOnCellular(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoplayOnCellular, value);
  }
}
