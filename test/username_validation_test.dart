import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/services/username_validation.dart';

void main() {
  group('UsernameValidation', () {
    test('normalize preserves case and strips whitespace', () {
      expect(UsernameValidation.normalize('  My_Name  '), 'My_Name');
    });

    test('isValidFormat allows mixed case', () {
      expect(UsernameValidation.isValidFormat('AbC'), isTrue);
      expect(UsernameValidation.isValidFormat('User_One'), isTrue);
    });

    test('isValidFormat rejects too short', () {
      expect(UsernameValidation.isValidFormat('Ab'), isFalse);
    });
  });
}
