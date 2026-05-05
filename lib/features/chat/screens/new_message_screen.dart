import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_user_model.dart';
import '../../../core/services/user_service.dart';
import '../services/chat_service.dart';
import 'chat_thread_screen.dart';
import 'group_create_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  final UserService _userService = UserService();
  final ChatService _chatService = ChatService();

  List<UserDiscoveryItem> _results = [];
  bool _loading = false;
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

  Future<void> _selectUser(UserDiscoveryItem item) async {
    if (_currentUser == null) return;
    if (item.uid == _currentUid) return;

    try {
      final otherUser = await _userService.getUser(item.uid);
      if (!mounted || otherUser == null) return;

      final chatId = await _chatService.getOrCreateDirectChat(
        currentUser: _currentUser!,
        otherUser: otherUser,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            chatId: chatId,
            currentUser: _currentUser!,
            otherUser: otherUser,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open chat')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          'New Message',
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
                _buildSearchField(),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                _buildGroupChatRow(),
                Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                Expanded(child: _buildList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'To:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: AppColors.brandDeepMagenta,
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupChatRow() {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const GroupCreateScreen()),
        );
      },
      splashColor: AppColors.brandDeepMagenta.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1A0A2E),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0x33FFFFFF), width: 0.5),
              ),
              child: const Icon(Icons.group_add_outlined, color: Colors.white70, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Start group chat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
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
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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
        return InkWell(
          onTap: () => _selectUser(item),
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
              ],
            ),
          ),
        );
      },
    );
  }
}
