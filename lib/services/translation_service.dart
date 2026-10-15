import 'dart:async';

/// Simple String Extension helper returning raw text directly (translation disabled).
extension StringTranslationX on String {
  /// Returns original text directly without translation.
  String get tr => this;

  /// Asynchronously returns original text directly.
  Future<String> trAsync({String? targetLangCode}) async => this;
}

/// Translation Engine Pass-Through Service (Translation Disabled).
class TranslationService {
  static void initSeedCache() {}

  /// Returns raw text directly.
  static String translateSync(String text, {String? targetLangCode}) => text;

  /// Warm up no-op.
  static Future<void> warmUpLanguage(String targetLangCode) async {}

  /// Async translate no-op returning raw text directly.
  static Future<String> translateText(
    String text, {
    String? targetLangCode,
  }) async =>
      text;
}
