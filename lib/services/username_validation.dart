/// Validation rules for username input.
/// Kept separate from UI and API.
class UsernameValidation {
  UsernameValidation._();

  /// Minimum length to trigger API check.
  static const int minLengthForCheck = 3;

  /// Allowed pattern: letters, numbers, underscore, dot (case-sensitive storage).
  static final RegExp _allowedPattern = RegExp(r'^[a-zA-Z0-9_.]*$');

  /// Canonical form for checks and Firestore: trim, remove whitespace, preserve case.
  static String normalize(String input) {
    return input.trim().replaceAll(RegExp(r'\s'), '');
  }

  /// Whether [input] is valid for display/API (length and pattern).
  static bool isValidFormat(String input) {
    final normalized = normalize(input);
    if (normalized.length < minLengthForCheck) return false;
    if (!_allowedPattern.hasMatch(normalized)) return false;
    // Instagram-style dot rules.
    if (normalized.startsWith('.') || normalized.endsWith('.')) return false;
    if (normalized.contains('..')) return false;
    return true;
  }

  /// Whether [input] has at least [minLengthForCheck] chars and valid pattern.
  static bool shouldCheckAvailability(String input) {
    return isValidFormat(input);
  }
}
