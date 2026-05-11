import 'package:flutter/material.dart';

import '../models/app_user_model.dart';
import '../models/parent_consent_constants.dart';
import 'onboarding_route_resolver.dart';
import 'parental_submit_handoff.dart';
import '../../screens/auth/create_username_screen.dart';
import '../../screens/onboarding/add_profile_screen.dart';
import '../../screens/onboarding/onboarding_complete_screen.dart';
import '../../screens/onboarding/organization_details_screen.dart';
import '../../screens/onboarding/parent_contact_screen.dart';
import '../../screens/onboarding/parental_pending_screen.dart';
import '../../screens/onboarding/select_dob_screen.dart';
import '../../screens/onboarding/select_interests_screen.dart';

/// Maps [AppUserModel] to the next onboarding screen (before [onboardingCompleted]).
class OnboardingGate {
  OnboardingGate._();

  /// Next full-screen widget for signed-in users who have not finished onboarding.
  static Widget nextScreen(AppUserModel user) {
    final routeId = OnboardingRouteResolver.resolve(user);
    final handoffId =
        ParentalSubmitHandoff.instance.activeConsentIdForMinor(user.uid);

    if (handoffId != null) {
      // Resolver can briefly read a stale user doc (e.g. missing DOB) after a
      // successful invite; never drop the handoff for those routes or we snap
      // back to the wrong onboarding step.
      const postParentMinor = <String>{
        OnboardingRouteId.addProfile,
        OnboardingRouteId.selectInterests,
        OnboardingRouteId.onboardingComplete,
      };
      if (postParentMinor.contains(routeId)) {
        ParentalSubmitHandoff.instance.disarm(minorUid: user.uid);
      } else if (routeId == OnboardingRouteId.parentalPending) {
        final cid = user.parentConsentId.trim();
        ParentalSubmitHandoff.instance.disarm(minorUid: user.uid);
        return ParentalPendingScreen(
          consentId: cid.isNotEmpty ? cid : handoffId,
        );
      } else {
        return ParentalPendingScreen(consentId: handoffId);
      }
    }

    switch (routeId) {
      case OnboardingRouteId.createUsername:
        return const CreateUsernameScreen();
      case OnboardingRouteId.organization:
        final accountType = user.accountType.trim().toLowerCase();
        return OrganizationDetailsScreen(accountType: accountType);
      case OnboardingRouteId.selectDob:
        return const SelectDobScreen();
      case OnboardingRouteId.parentContact:
        final denied =
            user.parentConsentStatus == ParentConsentStatusValue.denied;
        return ParentContactScreen(previousDenied: denied);
      case OnboardingRouteId.parentalPending:
        return ParentalPendingScreen(consentId: user.parentConsentId.trim());
      case OnboardingRouteId.addProfile:
        return const AddProfileScreen();
      case OnboardingRouteId.selectInterests:
        return const SelectInterestsScreen();
      case OnboardingRouteId.onboardingComplete:
      default:
        return const OnboardingCompleteScreen();
    }
  }
}
