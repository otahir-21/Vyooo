import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Result of preparing or starting voice search.
enum SearchVoiceInputFailure {
  unsupportedPlatform,
  permissionDenied,
  pluginNotLinked,
  notAvailable,
  listenFailed,
  noSpeechHeard,
}

/// On-device speech recognition for the search bar (tap mic to start/stop).
class SearchVoiceInput {
  SearchVoiceInput();

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  String? _localeId;
  SearchVoiceInputFailure? lastFailure;

  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  bool get isListening => _speech.isListening;
  bool get isAvailable => _speech.isAvailable;

  String messageForFailure(SearchVoiceInputFailure failure) {
    switch (failure) {
      case SearchVoiceInputFailure.unsupportedPlatform:
        return 'Voice search is only available on the iOS and Android app.';
      case SearchVoiceInputFailure.permissionDenied:
        return 'Microphone access is needed for voice search.';
      case SearchVoiceInputFailure.pluginNotLinked:
        return 'Voice search is not loaded. Fully quit Vyooo, then run again '
            'from Xcode or flutter run (not hot reload).';
      case SearchVoiceInputFailure.notAvailable:
        return 'Voice search is not available. On Android, install the Google '
            'app and enable voice typing in system settings.';
      case SearchVoiceInputFailure.listenFailed:
        return 'Could not start voice search. Try again.';
      case SearchVoiceInputFailure.noSpeechHeard:
        return 'Didn\'t catch that. Speak clearly, then tap the mic again.';
    }
  }

  static void _handleSpeechError(
    String message, {
    void Function(String message)? onError,
  }) {
    final lower = message.toLowerCase();
    if (lower.contains('error_no_match') ||
        lower.contains('no_match') ||
        lower.contains('speech_timeout')) {
      onError?.call('error_no_match');
      return;
    }
    onError?.call(message);
  }

  Future<bool> ensureReady({
    void Function(String status)? onStatus,
    void Function(String message)? onError,
  }) async {
    lastFailure = null;

    if (!isPlatformSupported) {
      lastFailure = SearchVoiceInputFailure.unsupportedPlatform;
      return false;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      lastFailure = SearchVoiceInputFailure.permissionDenied;
      return false;
    }

    if (_initialized) {
      return _speech.isAvailable;
    }

    try {
      final ok = await _speech.initialize(
        onStatus: onStatus,
        onError: (error) => _handleSpeechError(error.errorMsg, onError: onError),
        debugLogging: kDebugMode,
        options: [
          SpeechToText.androidIntentLookup,
          SpeechToText.androidNoBluetooth,
        ],
      );
      _initialized = true;
      if (!ok || !_speech.isAvailable) {
        lastFailure = SearchVoiceInputFailure.notAvailable;
        return false;
      }
      final locale = await _speech.systemLocale();
      _localeId = locale?.localeId;
      return true;
    } on MissingPluginException {
      lastFailure = SearchVoiceInputFailure.pluginNotLinked;
      return false;
    } on PlatformException {
      lastFailure = SearchVoiceInputFailure.notAvailable;
      return false;
    }
  }

  Future<bool> startListening({
    required void Function(String words) onTranscript,
    void Function(String message)? onError,
  }) async {
    lastFailure = null;
    if (!_speech.isAvailable) {
      lastFailure = SearchVoiceInputFailure.notAvailable;
      return false;
    }
    try {
      await _speech.listen(
        onResult: (result) => onTranscript(result.recognizedWords),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.confirmation,
          localeId: _localeId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          cancelOnError: false,
        ),
      );
      return _speech.isListening;
    } on MissingPluginException {
      lastFailure = SearchVoiceInputFailure.pluginNotLinked;
      return false;
    } on PlatformException {
      lastFailure = SearchVoiceInputFailure.listenFailed;
      return false;
    }
  }

  Future<void> stopListening() async {
    if (!_speech.isListening) return;
    try {
      await _speech.stop();
    } on MissingPluginException {
      // Native plugin not linked; nothing to stop.
    }
  }

  void noteNoSpeechHeard() {
    lastFailure = SearchVoiceInputFailure.noSpeechHeard;
  }

  Future<void> dispose() => stopListening();
}
