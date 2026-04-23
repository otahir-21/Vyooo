import 'package:flutter/material.dart';

Color verificationBadgeColor({
  required bool isVerified,
  required String accountType,
  required bool vipVerified,
}) {
  if (!isVerified) return Colors.transparent;
  if (vipVerified) return const Color(0xFFFACC15); // Gold VIP tick
  final type = accountType.trim().toLowerCase();
  switch (type) {
    case 'personal':
      return const Color(0xFF22C55E); // Green
    case 'government':
      return const Color(0xFF111111); // Black
    case 'business':
    case 'private':
    default:
      return const Color(0xFFF81945); // Red
  }
}

