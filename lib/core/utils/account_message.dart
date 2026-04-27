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

  if (creatorVerified) {
    return 'Your creator profile has been verified successfully.';
  }

  return '';
}
