import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_user_model.dart';
import '../models/chat_model.dart';
import '../models/chat_participant.dart';
import '../services/chat_service.dart';

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.currentUser,
    required this.chatModel,
  });

  final String chatId;
  final AppUserModel currentUser;
  final ChatModel chatModel;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final ChatService _chatService = ChatService();
  late ChatModel _chat;
  final TextEditingController _nameController = TextEditingController();

  bool get _isAdmin => _chat.admins.contains(widget.currentUser.uid);

  @override
  void initState() {
    super.initState();
    _chat = widget.chatModel;
    _nameController.text = _chat.groupName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _renameGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == _chat.groupName) return;
    await _chatService.updateGroupName(chatId: widget.chatId, groupName: name);
    if (!mounted) return;
    setState(() {
      _chat = _chat.copyWith(groupName: name);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Group name updated')));
  }

  Future<void> _leaveGroup() async {
    if (_isAdmin &&
        _chat.admins.length == 1 &&
        _chat.participantIds.length > 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign another admin before leaving this group.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1B2E),
        title: const Text('Leave group', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will no longer receive messages from this group.',
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
              'Leave',
              style: TextStyle(color: AppColors.deleteRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _chatService.leaveGroup(
        uid: widget.currentUser.uid,
        chatId: widget.chatId,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assign another admin before leaving this group.'),
        ),
      );
    }
  }

  Future<void> _removeMember(ChatParticipant member) async {
    if (member.uid == widget.currentUser.uid) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1B2E),
        title: const Text(
          'Remove member',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Remove ${member.displayName.isNotEmpty ? member.displayName : member.username} from this group?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.deleteRed),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _chatService.removeMember(
      chatId: widget.chatId,
      memberUid: member.uid,
    );
    if (!mounted) return;
    final updated = await _chatService.getChat(widget.chatId);
    if (!mounted || updated == null) return;
    setState(() => _chat = updated);
  }

  @override
  Widget build(BuildContext context) {
    final members = _chat.participantMap.values.toList();

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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Group Info',
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const SizedBox(height: 16),
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
                          backgroundImage: (_chat.groupImageUrl ?? '').isNotEmpty
                              ? CachedNetworkImageProvider(_chat.groupImageUrl!)
                              : null,
                          child: (_chat.groupImageUrl ?? '').isEmpty
                              ? const Icon(Icons.group, color: Colors.white54, size: 48)
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A0A2E).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x22DE106B), width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                style: const TextStyle(color: Colors.white, fontSize: 18),
                                decoration: InputDecoration(
                                  hintText: 'Group name',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.check, color: AppColors.brandMagenta),
                              onPressed: _renameGroup,
                            ),
                          ],
                        ),
                      )
                    else
                      Center(
                        child: Text(
                          _chat.groupName ?? 'Group',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '${members.length} members',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Members',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A0A2E).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0x22DE106B), width: 0.5),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < members.length; i++) ...[
                            _buildMemberTile(members[i]),
                            if (i < members.length - 1)
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
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton.icon(
                        onPressed: _leaveGroup,
                        icon: const Icon(Icons.exit_to_app, color: AppColors.deleteRed),
                        label: const Text(
                          'Leave Group',
                          style: TextStyle(color: AppColors.deleteRed),
                        ),
                      ),
                    ),
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

  Widget _buildMemberTile(ChatParticipant member) {
    final hasAvatar = member.avatarUrl.trim().isNotEmpty;
    final name = member.displayName.isNotEmpty
        ? member.displayName
        : member.username;
    final isAdm = _chat.admins.contains(member.uid);
    final isMe = member.uid == widget.currentUser.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF2A1540),
            backgroundImage: hasAvatar
                ? CachedNetworkImageProvider(member.avatarUrl)
                : null,
            child: hasAvatar
                ? null
                : const Icon(Icons.person, color: Colors.white54, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '$name (You)' : name,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                if (isAdm)
                  const Text(
                    'Admin',
                    style: TextStyle(
                      color: AppColors.brandMagenta,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (_isAdmin && !isMe && !isAdm)
            IconButton(
              icon: const Icon(
                Icons.shield_outlined,
                color: AppColors.brandMagenta,
                size: 20,
              ),
              tooltip: 'Make Admin',
              onPressed: () => _makeAdmin(member),
            ),
          if (_isAdmin && !isMe)
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: AppColors.deleteRed,
                size: 20,
              ),
              onPressed: () => _removeMember(member),
            ),
        ],
      ),
    );
  }

  Future<void> _makeAdmin(ChatParticipant member) async {
    final name = member.displayName.isNotEmpty ? member.displayName : member.username;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1B2E),
        title: const Text('Make admin', style: TextStyle(color: Colors.white)),
        content: Text(
          'Make $name an admin of this group?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: AppColors.brandMagenta)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _chatService.makeAdmin(chatId: widget.chatId, memberUid: member.uid);
    if (!mounted) return;
    final updated = await _chatService.getChat(widget.chatId);
    if (!mounted || updated == null) return;
    setState(() => _chat = updated);
  }
}
