import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyooo/core/models/app_user_model.dart';
import 'package:vyooo/core/models/parent_consent_constants.dart';
import 'package:vyooo/core/onboarding/onboarding_route_resolver.dart';

void main() {
  // A DOB that is always under 16 at test time. The parental consent flow is
  // temporarily disabled and minimum sign-up age is 16, so such users are
  // routed back to selectDob (where no under-16 date can be chosen).
  final under16Dob =
      '${DateTime.now().year - 14}-01-01';

  AppUserModel base({
    String username = 'kid',
    String? dob,
    String accountType = 'private',
    bool orgProfileCompleted = false,
    Map<String, dynamic> organizationDetails = const {},
    String parentConsentStatus = ParentConsentStatusValue.pendingContact,
    String parentConsentId = '',
    List<String> interests = const [],
    String profileImage = '',
    bool locationSetupComplete = false,
    bool profileImageSetupComplete = false,
  }) {
    return AppUserModel(
      uid: 'u1',
      email: 'kid@test.com',
      username: username,
      dob: dob ?? under16Dob,
      accountType: accountType,
      orgProfileCompleted: orgProfileCompleted,
      organizationDetails: organizationDetails,
      interests: interests,
      profileImage: profileImage,
      parentConsentStatus: parentConsentStatus,
      parentConsentId: parentConsentId,
      locationSetupComplete: locationSetupComplete,
      profileImageSetupComplete: profileImageSetupComplete,
      createdAt: Timestamp.now(),
    );
  }

  // Parental consent flow temporarily disabled: under-16 DOBs are no longer
  // valid, so minors are routed to selectDob instead of the parental screens.
  // Restore the original expectations (parentalPending / parentContact) when
  // the flow is re-enabled.
  test('resolve minor pending with consent id -> selectDob (flow disabled)',
      () {
    final r = OnboardingRouteResolver.resolve(
      base(
        parentConsentStatus: ParentConsentStatusValue.pending,
        parentConsentId: 'c1',
      ),
    );
    expect(r, OnboardingRouteId.selectDob);
  });

  test('resolve minor pending_contact -> selectDob (flow disabled)', () {
    final r = OnboardingRouteResolver.resolve(
      base(parentConsentStatus: ParentConsentStatusValue.pendingContact),
    );
    expect(r, OnboardingRouteId.selectDob);
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

  test('resolve adult who skipped photo, no location -> selectLocation', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        dob: '2000-01-01',
        parentConsentStatus: ParentConsentStatusValue.notRequired,
        profileImageSetupComplete: true,
      ),
    );
    expect(r, OnboardingRouteId.selectLocation);
  });

  test('resolve adult who skipped photo, location done -> selectInterests', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        dob: '2000-01-01',
        parentConsentStatus: ParentConsentStatusValue.notRequired,
        profileImageSetupComplete: true,
        locationSetupComplete: true,
      ),
    );
    expect(r, OnboardingRouteId.selectInterests);
  });

  test('resolve adult with photo, no location -> selectLocation', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        dob: '2000-01-01',
        parentConsentStatus: ParentConsentStatusValue.notRequired,
        profileImage: 'https://example.com/a.jpg',
      ),
    );
    expect(r, OnboardingRouteId.selectLocation);
  });

  test('resolve adult with photo and location done -> selectInterests', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        dob: '2000-01-01',
        parentConsentStatus: ParentConsentStatusValue.notRequired,
        profileImage: 'https://example.com/a.jpg',
        locationSetupComplete: true,
      ),
    );
    expect(r, OnboardingRouteId.selectInterests);
  });

  test('resolve approved minor -> selectDob (flow disabled, under-16 blocked)',
      () {
    final r = OnboardingRouteResolver.resolve(
      base(
        parentConsentStatus: ParentConsentStatusValue.approved,
        profileImage: 'https://example.com/a.jpg',
        locationSetupComplete: true,
      ),
    );
    expect(r, OnboardingRouteId.selectDob);
  });

  test('resolve no username', () {
    final r = OnboardingRouteResolver.resolve(base(username: ''));
    expect(r, OnboardingRouteId.createUsername);
  });

  test('government without org details -> organization', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        accountType: 'government',
        orgProfileCompleted: false,
        dob: '',
      ),
    );
    expect(r, OnboardingRouteId.organization);
  });

  test('government without establishment date -> selectEstablishmentDate', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        accountType: 'government',
        orgProfileCompleted: true,
        organizationDetails: const {'orgName': 'Dept'},
        dob: '',
      ),
    );
    expect(r, OnboardingRouteId.selectEstablishmentDate);
  });

  test('government with establishment, no photo -> addProfile', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        accountType: 'government',
        orgProfileCompleted: true,
        organizationDetails: const {'establishmentDate': '1990-05-01'},
        dob: '',
      ),
    );
    expect(r, OnboardingRouteId.addProfile);
  });

  test('government never routes to selectDob or parentContact', () {
    final r = OnboardingRouteResolver.resolve(
      base(
        accountType: 'government',
        orgProfileCompleted: true,
        organizationDetails: const {'establishmentDate': '1990-05-01'},
        dob: '',
        parentConsentStatus: ParentConsentStatusValue.pendingContact,
      ),
    );
    expect(r, isNot(OnboardingRouteId.selectDob));
    expect(r, isNot(OnboardingRouteId.parentContact));
    expect(r, OnboardingRouteId.addProfile);
  });
}
