import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/user_service.dart';
import '../services/chat_service.dart';
import '../../../screens/profile/user_profile_screen.dart';

class ChatInfoScreen extends StatefulWidget {
  const ChatInfoScreen({
    super.key,
    required this.chatId,
    required this.currentUser,
    required this.otherUser,
    required this.isMuted,
    required this.onMuteToggled,
    required this.onChatCleared,
  });

  final String chatId;
  final AppUserModel currentUser;
  final AppUserModel otherUser;
  final bool isMuted;
  final VoidCallback onMuteToggled;
  final VoidCallback onChatCleared;

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  late bool _isMuted;
  bool _isBlocked = false;
  bool _blockBusy = false;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _checkBlocked();
  }

  Future<void> _checkBlocked() async {
    try {
      final doc = await UserService().getUser(widget.currentUser.uid);
      if (!mounted) return;
      final blocked = doc?.blockedUsers ?? [];
      setState(() => _isBlocked = blocked.contains(widget.otherUser.uid));
    } catch (_) {}
  }

  void _viewProfile() {
    final u = widget.otherUser;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          payload: UserProfilePayload(
            targetUserId: u.uid,
            username: u.username ?? '',
            displayName: u.displayName ?? u.username ?? '',
            avatarUrl: u.profileImage ?? '',
            isVerified: u.isVerified,
            accountType: u.accountType,
            vipVerified: u.vipVerified,
            followerCount: 0,
            bio: u.bio ?? '',
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMute() async {
    try {
      if (_isMuted) {
        await ChatService().unmuteChat(
          uid: widget.currentUser.uid,
          chatId: widget.chatId,
        );
      } else {
        await ChatService().muteChat(
          uid: widget.currentUser.uid,
          chatId: widget.chatId,
        );
      }
      setState(() => _isMuted = !_isMuted);
      widget.onMuteToggled();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update mute setting')),
      );
    }
  }

  Future<void> _clearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1B2E),
        title: const Text('Clear chat', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will hide all messages for you. Other participants are not affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.deleteRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ChatService().clearChat(
        uid: widget.currentUser.uid,
        chatId: widget.chatId,
      );
      widget.onChatCleared();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not clear chat')));
    }
  }

  Future<void> _toggleBlock() async {
    if (_blockBusy) return;
    final action = _isBlocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1B2E),
        title: Text(
          '$action user',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          _isBlocked
              ? 'They will be able to message you again.'
              : 'They will no longer be able to message you.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: const TextStyle(color: AppColors.deleteRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _blockBusy = true);
    try {
      if (_isBlocked) {
        await UserService().unblockUser(
          currentUid: widget.currentUser.uid,
          targetUid: widget.otherUser.uid,
        );
      } else {
        await UserService().blockUser(
          currentUid: widget.currentUser.uid,
          targetUid: widget.otherUser.uid,
        );
      }
      setState(() {
        _isBlocked = !_isBlocked;
        _blockBusy = false;
      });
    } catch (e) {
      setState(() => _blockBusy = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not $action user')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.otherUser;
    final avatar = u.profileImage;
    final hasAvatar = avatar != null && avatar.trim().isNotEmpty;
    final displayName = (u.displayName ?? '').trim().isNotEmpty
        ? u.displayName!
        : u.username ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF07010F),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.2,
            colors: [Color(0xFF1A0A2E), Color(0xFF07010F)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Chat info',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFDE106B), Color(0xFF6B21A8)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFF1A0A2E),
                          backgroundImage: hasAvatar
                              ? CachedNetworkImageProvider(avatar)
                              : null,
                          child: hasAvatar
                              ? null
                              : const Icon(
                                  Icons.person,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if ((u.username ?? '').trim().isNotEmpty)
                      Center(
                        child: Text(
                          '@${u.username}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _buildSection([
                      _buildTile(
                        icon: Icons.person_outline,
                        label: 'View profile',
                        onTap: _viewProfile,
                      ),
                      _buildTile(
                        icon: _isMuted
                            ? Icons.notifications_off_outlined
                            : Icons.notifications_outlined,
                        label: _isMuted ? 'Unmute' : 'Mute',
                        onTap: _toggleMute,
                      ),
                      _buildTile(
                        icon: Icons.delete_outline,
                        label: 'Clear chat',
                        onTap: _clearChat,
                      ),
                      _buildTile(
                        icon: Icons.search,
                        label: 'Search in conversation',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                      _buildTile(
                        icon: Icons.photo_library_outlined,
                        label: 'Media, links and files',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Privacy',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSection([
                      _buildTile(
                        icon: Icons.block,
                        label: _isBlocked ? 'Unblock user' : 'Block user',
                        color: AppColors.deleteRed,
                        onTap: _toggleBlock,
                      ),
                      _buildTile(
                        icon: Icons.flag_outlined,
                        label: 'Report',
                        color: AppColors.deleteRed,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming soon')),
                          );
                        },
                      ),
                    ]),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A0A2E).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x22DE106B), width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < tiles.length; i++) ...[
            tiles[i],
            if (i < tiles.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 54),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 1,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
    Color? color,
  }) {
    final c = color ?? Colors.white;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: c, size: 22),
      title: Text(label, style: TextStyle(color: c, fontSize: 15)),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.white.withValues(alpha: 0.2),
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
