import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/models/app_user_model.dart';
import 'package:vyooo/core/models/parent_consent_constants.dart';
import 'package:vyooo/core/onboarding/onboarding_route_resolver.dart';

void main() {
  AppUserModel base({
    String username = 'kid',
    String dob = '2011-03-01',
    String parentConsentStatus = ParentConsentStatusValue.pendingContact,
    String parentConsentId = '',
    List<String> interests = const [],
    String profileImage = '',
  }) {
    return AppUserModel(
      uid: 'u1',
      email: 'kid@test.com',
      username: username,
      dob: dob,
      interests: interests,
      profileImage: profileImage,
      parentConsentStatus: parentConsentStatus,
      parentConsentId: parentConsentId,
      createdAt: Timestamp.now(),
    );
  }

  test('resolve minor pending with consent id -> parentalPending', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        parentConsentStatus: ParentConsentStatusValue.pending,
        parentConsentId: 'c1',
      ),
    );
    expect(r, OnboardingRouteId.parentalPending);
  });

  test('resolve minor pending_contact -> parentContact', () {
    final r = OnboardingRouteResolver.resolve(
      base(parentConsentStatus: ParentConsentStatusValue.pendingContact),
    );
    expect(r, OnboardingRouteId.parentContact);
  });

  test('resolve minor pending without consent id -> parentContact', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        parentConsentStatus: ParentConsentStatusValue.pending,
        parentConsentId: '',
      ),
    );
    expect(r, OnboardingRouteId.parentContact);
  });

  test('resolve adult -> addProfile', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        dob: '2000-01-01',
        parentConsentStatus: ParentConsentStatusValue.notRequired,
      ),
    );
    expect(r, OnboardingRouteId.addProfile);
  });

  test('resolve approved minor with photo -> selectInterests', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        parentConsentStatus: ParentConsentStatusValue.approved,
        profileImage: 'https://example.com/a.jpg',
      ),
    );
    expect(r, OnboardingRouteId.selectInterests);
  });

  test('resolve no username', () {
    final r = OnboardingRouteResolver.resolve(base(username: ''));
    expect(r, OnboardingRouteId.createUsername);
  });
}
