/// DOB validation and constraints. Kept separate from UI.
class DobValidation {
  DobValidation._();

  static const int minAge = 13;
  static const int maxAgeYears = 100;

  /// Users below this age require parental consent before completing onboarding.
  static const int parentalConsentRequiredIfUnder = 16;

  /// Latest valid birth date (user must be at least [minAge] years old).
  static DateTime get latestValidBirthDate {
    final now = DateTime.now();
    return DateTime(now.year - minAge, now.month, now.day);
  }

  /// Earliest valid birth date ([maxAgeYears] years ago from today).
  static DateTime get earliestValidBirthDate {
    final now = DateTime.now();
    return DateTime(now.year - maxAgeYears, now.month, now.day);
  }

  /// Year range for picker: [currentYear - 100, currentYear - 13].
  static List<int> get allowedYears {
    final now = DateTime.now();
    final end = now.year - minAge;
    final start = now.year - maxAgeYears;
    return List.generate(end - start + 1, (i) => start + i);
  }

  /// Number of days in [month] for [year].
  static int daysInMonth(int year, int month) {
    if (month == 2) {
      final isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeap ? 29 : 28;
    }
    const days = [31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }

  /// Clamp [day] to valid range for [year] and [month].
  static int clampDay(int year, int month, int day) {
    final max = daysInMonth(year, month);
    if (day < 1) return 1;
    if (day > max) return max;
    return day;
  }

  /// True if [date] is a valid birth date (at least [minAge], not future).
  /// [referenceDate] defaults to today (use in tests for stable age gates).
  static bool isValidBirthDate(DateTime date, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(date.year, date.month, date.day);
    if (birth.isAfter(today)) return false;
    final at13 = DateTime(date.year + minAge, date.month, date.day);
    return !today.isBefore(at13);
  }

  /// Completed age in years (birthday not yet reached this year => subtract one).
  static int ageInCompletedYears(DateTime birthDate, {DateTime? on}) {
    final now = on ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final birth = DateTime(birthDate.year, birthDate.month, birthDate.day);
    var age = today.year - birth.year;
    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }
    return age;
  }

  /// True when [birthDate] is a valid minor age (13–15) requiring parent approval.
  static bool requiresParentalConsent(DateTime birthDate, {DateTime? asOf}) {
    final ref = asOf ?? DateTime.now();
    if (!isValidBirthDate(birthDate, referenceDate: ref)) return false;
    return ageInCompletedYears(birthDate, on: ref) < parentalConsentRequiredIfUnder;
  }

  /// Parses `YYYY-MM-DD` only; returns null if invalid.
  static DateTime? tryParseIsoDob(String raw) {
    final value = raw.trim();
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (m == null) return null;
    final y = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final d = int.tryParse(m.group(3)!);
    if (y == null || mo == null || d == null) return null;
    if (mo < 1 || mo > 12 || d < 1 || d > daysInMonth(y, mo)) return null;
    return DateTime(y, mo, d);
  }

  /// True if [raw] is a non-empty ISO DOB string that passes [isValidBirthDate].
  static bool isValidDobString(String raw, {DateTime? referenceDate}) {
    final parsed = tryParseIsoDob(raw);
    return parsed != null &&
        isValidBirthDate(parsed, referenceDate: referenceDate);
  }
}
