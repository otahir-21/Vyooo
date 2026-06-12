import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/utils/dob_validation.dart';

void main() {
  group('DobValidation', () {
    // Parental consent flow is temporarily disabled and the minimum sign-up
    // age is 16. Restore the original expectations when the flow returns.
    test('15-year-old is not a valid birth date and needs no consent', () {
      final on = DateTime(2026, 6, 1);
      final birth = DateTime(2011, 3, 1);
      expect(DobValidation.ageInCompletedYears(birth, on: on), 15);
      expect(DobValidation.isValidBirthDate(birth, referenceDate: on), isFalse);
      expect(DobValidation.requiresParentalConsent(birth, asOf: on), isFalse);
    });

    test('16-year-old is valid and does not require consent', () {
      final on = DateTime(2026, 6, 1);
      final birth = DateTime(2010, 1, 1);
      expect(DobValidation.ageInCompletedYears(birth, on: on), 16);
      expect(DobValidation.isValidBirthDate(birth, referenceDate: on), isTrue);
      expect(DobValidation.requiresParentalConsent(birth, asOf: on), isFalse);
    });

    test('isValidDobString accepts ISO date for 16+', () {
      final on = DateTime(2026, 6, 1);
      expect(
        DobValidation.isValidDobString('2010-01-15', referenceDate: on),
        isTrue,
      );
      expect(DobValidation.tryParseIsoDob('2010-01-15'), DateTime(2010, 1, 15));
    });

    test('isValidDobString rejects under-16 DOB', () {
      final on = DateTime(2026, 6, 1);
      expect(
        DobValidation.isValidDobString('2011-03-01', referenceDate: on),
        isFalse,
      );
    });

    test('requiresParentalConsent false below min age', () {
      final on = DateTime(2026, 6, 1);
      final birth = DateTime(2017, 1, 1);
      expect(DobValidation.isValidBirthDate(birth, referenceDate: on), isFalse);
      expect(DobValidation.requiresParentalConsent(birth, asOf: on), isFalse);
    });
  });
}
