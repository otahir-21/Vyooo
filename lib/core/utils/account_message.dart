String accountMessage({
  required String? status,
  required bool restricted,
  required bool forceLogoutDetected,
  required bool creatorVerified,
}) {
  final normalizedStatus = status?.trim().toLowerCase();

  if (forceLogoutDetected) {
    return 'For your security, you were signed out. Please log in again.';
  }

  switch (normalizedStatus) {
    case 'banned':
      return 'Your account has been permanently disabled for violating community guidelines.';
    case 'suspended':
      return 'Your account is temporarily suspended. Please try again later or contact support.';
  }

  if (restricted) {
    return 'Some features are currently limited on your account due to policy review.';
  }

  // Do not show "creator verified" as a login-time toast.
  // Verification state can already be reflected in profile UI badges.
  if (creatorVerified) {
    return '';
  }

  return '';
}
