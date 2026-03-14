import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../models/share_action.dart';
import '../models/share_contact.dart';

List<ShareContact> getMockShareContacts() {
  return [
    const ShareContact(
      id: 'sc1',
      name: 'Sandy Wilder Cheng',
      avatarUrl: 'https://i.pravatar.cc/100?img=1',
      app: ShareApp.whatsapp,
    ),
    const ShareContact(
      id: 'sc2',
      name: 'Kevin Leong',
      avatarUrl: 'https://i.pravatar.cc/100?img=2',
      app: ShareApp.whatsapp,
    ),
    const ShareContact(
      id: 'sc3',
      name: 'Sandy and Kevin',
      avatarUrl: 'https://i.pravatar.cc/100?img=3',
      app: ShareApp.instagram,
    ),
    const ShareContact(
      id: 'sc4',
      name: 'Juliana Mejia',
      avatarUrl: 'https://i.pravatar.cc/100?img=4',
      app: ShareApp.sms,
    ),
    const ShareContact(
      id: 'sc5',
      name: 'Greg Apodaca',
      avatarUrl: 'https://i.pravatar.cc/100?img=5',
      app: ShareApp.whatsapp,
    ),
    const ShareContact(
      id: 'sc6',
      name: 'Alex Rivera',
      avatarUrl: 'https://i.pravatar.cc/100?img=6',
      app: ShareApp.instagram,
    ),
  ];
}

/// Traditional share targets (AirDrop, Messages, Mail, Notes, Reminders).
List<ShareActionItem> getMockNativeShareTargets() {
  return [
    ShareActionItem(
      id: 'airdrop',
      label: 'AirDrop',
      icon: Icons.wifi,
      backgroundColor: const Color(0xFF007AFF),
    ),
    ShareActionItem(
      id: 'messages',
      label: 'Messages',
      icon: Icons.chat_bubble_outline,
      backgroundColor: AppColors.whatsappGreen,
    ),
    ShareActionItem(
      id: 'mail',
      label: 'Mail',
      icon: Icons.mail_outline,
      backgroundColor: const Color(0xFF007AFF),
    ),
    ShareActionItem(
      id: 'notes',
      label: 'Notes',
      icon: Icons.note_outlined,
      backgroundColor: const Color(0xFFFFCC00),
    ),
    ShareActionItem(
      id: 'reminders',
      label: 'Reminders',
      icon: Icons.list_alt,
      backgroundColor: Colors.white,
    ),
  ];
}

/// System actions: Copy, Add to Reading List, etc. (label + trailing icon).
class ShareSystemAction {
  const ShareSystemAction({
    required this.id,
    required this.label,
    required this.icon,
  });
  final String id;
  final String label;
  final IconData icon;
}

List<ShareSystemAction> getMockShareSystemActions() {
  return const [
    ShareSystemAction(id: 'copy', label: 'Copy', icon: Icons.copy),
    ShareSystemAction(
      id: 'reading_list',
      label: 'Add to Reading List',
      icon: Icons.menu_book_outlined,
    ),
    ShareSystemAction(
      id: 'bookmark',
      label: 'Add Bookmark',
      icon: Icons.bookmark_border,
    ),
    ShareSystemAction(
      id: 'favorites',
      label: 'Add to Favorites',
      icon: Icons.star_border,
    ),
  ];
}

List<ShareActionItem> getMockShareActions() {
  return [
    ShareActionItem(
      id: 'whatsapp',
      label: 'WhatsApp',
      icon: Icons.chat,
      backgroundColor: AppColors.whatsappGreen,
    ),
    ShareActionItem(
      id: 'share_to',
      label: 'Share to',
      icon: Icons.ios_share,
      backgroundColor: AppColors.iconBackgroundDark,
    ),
    ShareActionItem(
      id: 'copy_link',
      label: 'Copy Link',
      icon: Icons.link,
      backgroundColor: AppColors.linkBlue,
    ),
    ShareActionItem(
      id: 'sms',
      label: 'SMS',
      icon: Icons.sms_outlined,
      backgroundColor: AppColors.whatsappGreen,
    ),
    ShareActionItem(
      id: 'instagram',
      label: 'Instagram',
      icon: Icons.camera_alt_outlined,
      backgroundColor: AppColors.instagramPink,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: AppColors.instagramGradient,
      ),
    ),
  ];
}
