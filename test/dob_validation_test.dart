import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/utils/dob_validation.dart';

void main() {
  group('DobValidation', () {
    test('requiresParentalConsent for 15-year-old', () {
      final on = DateTime(2026, 6, 1);
      final birth = DateTime(2011, 3, 1);
      expect(DobValidation.ageInCompletedYears(birth, on: on), 15);
      expect(DobValidation.requiresParentalConsent(birth, asOf: on), isTrue);
    });

    test('does not require consent at 16', () {
      final on = DateTime(2026, 6, 1);
      final birth = DateTime(2010, 1, 1);
      expect(DobValidation.ageInCompletedYears(birth, on: on), 16);
      expect(DobValidation.requiresParentalConsent(birth, asOf: on), isFalse);
    });

    test('isValidDobString accepts ISO date', () {
      expect(DobValidation.isValidDobString('2010-01-15'), isTrue);
      expect(DobValidation.tryParseIsoDob('2010-01-15'), DateTime(2010, 1, 15));
    });

    test('requiresParentalConsent false below min age', () {
      final on = DateTime(2026, 6, 1);
      final birth = DateTime(2017, 1, 1);
      expect(DobValidation.isValidBirthDate(birth, referenceDate: on), isFalse);
      expect(DobValidation.requiresParentalConsent(birth, asOf: on), isFalse);
    });
  });
}
