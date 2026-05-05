import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/user_service.dart';
import '../services/chat_service.dart';
import '../utils/chat_constants.dart';
import 'chat_thread_screen.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  List<UserDiscoveryItem> _results = [];
  final List<AppUserModel> _selectedUsers = [];
  bool _loading = false;
  bool _creating = false;
  String? _currentUid;
  AppUserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _loadCurrentUser();
    _loadSuggested();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadCurrentUser() async {
    if (_currentUid == null) return;
    _currentUser = await _userService.getUser(_currentUid!);
  }

  Future<void> _loadSuggested() async {
    if (_currentUid == null) return;
    setState(() => _loading = true);
    final items = await _userService.discoverUserItems(
      currentUid: _currentUid!,
      limit: 30,
    );
    if (!mounted) return;
    setState(() {
      _results = items.where((i) => i.uid != _currentUid).toList();
      _loading = false;
    });
  }

  void _onSearchChanged() {
    _performSearch(_searchController.text);
  }

  Future<void> _performSearch(String query) async {
    if (_currentUid == null) return;
    setState(() => _loading = true);
    final items = await _userService.discoverUserItems(
      currentUid: _currentUid!,
      query: query.trim(),
      limit: 30,
    );
    if (!mounted) return;
    setState(() {
      _results = items.where((i) => i.uid != _currentUid).toList();
      _loading = false;
    });
  }

  Future<void> _toggleUser(UserDiscoveryItem item) async {
    final existing = _selectedUsers.indexWhere((u) => u.uid == item.uid);
    if (existing >= 0) {
      setState(() => _selectedUsers.removeAt(existing));
      return;
    }

    if (_selectedUsers.length >= ChatLimits.maxGroupSize - 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum group size reached')),
      );
      return;
    }

    final user = await _userService.getUser(item.uid);
    if (!mounted || user == null) return;
    setState(() => _selectedUsers.add(user));
  }

  bool _isSelected(String uid) {
    return _selectedUsers.any((u) => u.uid == uid);
  }

  Future<void> _createGroup() async {
    if (_currentUser == null) return;
    if (_selectedUsers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 2 members')),
      );
      return;
    }
    final name = _groupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a group name')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final chatId = await _chatService.createGroupChat(
        creator: _currentUser!,
        members: _selectedUsers,
        groupName: name,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            chatId: chatId,
            currentUser: _currentUser!,
            chatType: ChatTypes.group,
            groupName: name,
            participantIds: [
              _currentUser!.uid,
              ..._selectedUsers.map((u) => u.uid),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create group')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _selectedUsers.length >= 2 && !_creating;
    return Scaffold(
      backgroundColor: AppColors.brandNearBlack,
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: -60,
            right: -60,
            child: Container(
              height: 280,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x44DE106B), Color(0x00000000)],
                  radius: 0.9,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'New group',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildGroupNameField(),
                _buildSearchField(),
                if (_selectedUsers.isNotEmpty) _buildSelectedChips(),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                Expanded(child: _buildUserList()),
              ],
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: GestureDetector(
              onTap: canCreate ? _createGroup : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  color: canCreate ? Colors.white : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.brandNearBlack,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Create group',
                        style: TextStyle(
                          color: canCreate ? AppColors.brandNearBlack : Colors.white30,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupNameField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C0B2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x22FFFFFF), width: 0.5),
        ),
        child: TextField(
          controller: _groupNameController,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: AppColors.brandDeepMagenta,
          decoration: InputDecoration(
            hintText: 'Group Name (optional)',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedChips() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        itemCount: _selectedUsers.length,
        itemBuilder: (context, index) {
          final user = _selectedUsers[index];
          final name = (user.displayName ?? '').trim().isNotEmpty
              ? user.displayName!
              : user.username ?? '';
          final avatar = user.profileImage;
          final hasAvatar = avatar != null && avatar.trim().isNotEmpty;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF1A0A2E),
                      backgroundImage: hasAvatar ? CachedNetworkImageProvider(avatar) : null,
                      child: hasAvatar ? null : const Icon(Icons.person, color: Colors.white54, size: 16),
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedUsers.removeAt(index)),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 44,
                  child: Text(
                    name.split(' ').first,
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C0B2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x22FFFFFF), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: Colors.white.withValues(alpha: 0.35), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: AppColors.brandDeepMagenta,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandMagenta),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No users found',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text(
              'Suggested',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final item = _results[index - 1];
        final hasAvatar = item.avatarUrl.trim().isNotEmpty;
        final selected = _isSelected(item.uid);
        return InkWell(
          onTap: () => _toggleUser(item),
          splashColor: AppColors.brandDeepMagenta.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1A0A2E),
                  backgroundImage: hasAvatar
                      ? CachedNetworkImageProvider(item.avatarUrl)
                      : null,
                  child: hasAvatar
                      ? null
                      : const Icon(Icons.person, color: Colors.white54, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '@${item.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? AppColors.brandDeepMagenta : Colors.transparent,
                    border: Border.all(
                      color: selected ? AppColors.brandDeepMagenta : Colors.white.withValues(alpha: 0.25),
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
