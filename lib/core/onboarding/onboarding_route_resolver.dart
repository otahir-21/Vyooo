import '../models/app_user_model.dart';
import '../models/parent_consent_constants.dart';
import '../utils/dob_validation.dart';

/// String route ids for [OnboardingGate] (and tests). No Flutter imports.
abstract class OnboardingRouteId {
  static const createUsername = 'createUsername';
  static const organization = 'organization';
  static const selectDob = 'selectDob';
  static const parentContact = 'parentContact';
  static const parentalPending = 'parentalPending';
  static const addProfile = 'addProfile';
  static const selectInterests = 'selectInterests';
  static const onboardingComplete = 'onboardingComplete';
}

class OnboardingRouteResolver {
  OnboardingRouteResolver._();

  static String resolve(AppUserModel user) {
    final hasUsername = (user.username ?? '').trim().isNotEmpty;
    if (!hasUsername) {
      return OnboardingRouteId.createUsername;
    }

    final accountType = user.accountType.trim().toLowerCase();
    if (accountType == 'business' || accountType == 'government') {
      if (!user.orgProfileCompleted) {
        return OnboardingRouteId.organization;
      }
    }

    final dobRaw = (user.dob ?? '').trim();
    if (dobRaw.isEmpty || !DobValidation.isValidDobString(dobRaw)) {
      return OnboardingRouteId.selectDob;
    }

    final birth = DobValidation.tryParseIsoDob(dobRaw)!;
    final isMinor = DobValidation.requiresParentalConsent(birth);
    if (!isMinor) {
      return _postDobRoute(user);
    }

    final status = user.parentConsentStatus.trim().toLowerCase();
    if (status == ParentConsentStatusValue.approved) {
      return _postDobRoute(user);
    }
    // Explicit: minor has not submitted parent contact yet.
    if (status == ParentConsentStatusValue.pendingContact) {
      return OnboardingRouteId.parentContact;
    }
    if (status == ParentConsentStatusValue.pending) {
      final id = user.parentConsentId.trim();
      if (id.isNotEmpty) {
        return OnboardingRouteId.parentalPending;
      }
      // Status says pending but no consent id (corrupt / partial write): stay on contact.
      return OnboardingRouteId.parentContact;
    }
    if (status == ParentConsentStatusValue.denied) {
      return OnboardingRouteId.parentContact;
    }
    return OnboardingRouteId.parentContact;
  }

  static String _postDobRoute(AppUserModel user) {
    if (user.interests.isEmpty) {
      final hasProfileImage = (user.profileImage ?? '').trim().isNotEmpty;
      if (!hasProfileImage) {
        return OnboardingRouteId.addProfile;
      }
      return OnboardingRouteId.selectInterests;
    }
    return OnboardingRouteId.onboardingComplete;
  }
}
