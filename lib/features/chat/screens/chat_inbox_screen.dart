import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/user_service.dart';
import '../controllers/chat_controller.dart';
import '../models/chat_summary_model.dart';
import '../utils/chat_constants.dart';
import '../widgets/chat_tile.dart';
import 'chat_thread_screen.dart';
import 'message_requests_screen.dart';
import 'new_message_screen.dart';

class ChatInboxScreen extends StatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final ChatController _controller;
  final UserService _userService = UserService();
  String? _currentUid;
  String _filter = 'Primary';

  @override
  void initState() {
    super.initState();
    _currentUid = FirebaseAuth.instance.currentUser?.uid;
    _controller = ChatController(uid: _currentUid ?? '');
    _controller.addListener(_onControllerChange);
  }

  void _onControllerChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChange);
    _controller.dispose();
    super.dispose();
  }

  List<ChatSummaryModel> get _primarySummaries {
    return _controller.summaries.where((s) {
      final rs = s.requestStatus;
      return rs == null ||
          rs == RequestStatus.none ||
          rs == RequestStatus.accepted;
    }).toList();
  }

  List<ChatSummaryModel> get _requestSummaries {
    return _controller.summaries.where((s) {
      return s.requestStatus == RequestStatus.pending;
    }).toList();
  }

  List<ChatSummaryModel> get _filteredSummaries {
    switch (_filter) {
      case 'Requests':
        return _requestSummaries;
      case 'General':
        return _primarySummaries.where((s) => s.unreadCount == 0).toList();
      default:
        return _primarySummaries;
    }
  }

  Future<void> _openThread(ChatSummaryModel summary) async {
    if (_currentUid == null) return;

    final currentUser = await _userService.getUser(_currentUid!);
    if (!mounted || currentUser == null) return;

    if (summary.type == ChatTypes.group) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatThreadScreen(
            chatId: summary.chatId,
            currentUser: currentUser,
            chatType: ChatTypes.group,
            groupName: summary.title,
            groupImageUrl: summary.avatarUrl,
            participantIds: summary.participantIds,
          ),
        ),
      );
      return;
    }

    final otherUid = summary.participantIds.firstWhere(
      (id) => id != _currentUid,
      orElse: () => '',
    );
    if (otherUid.isEmpty) return;

    final otherUser = await _userService.getUser(otherUid);
    if (!mounted || otherUser == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatThreadScreen(
          chatId: summary.chatId,
          currentUser: currentUser,
          otherUser: otherUser,
        ),
      ),
    );
  }

  void _openNewMessage() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NewMessageScreen()));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.brandNearBlack,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -60,
            right: -60,
            child: Container(
              height: 320,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0x55DE106B), Color(0x00000000)],
                  radius: 0.85,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildFilterChips(),
                _buildMessagesSectionHeader(),
                Expanded(child: _buildInboxList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.menu, color: Colors.white70, size: 22),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                FirebaseAuth.instance.currentUser?.displayName ?? 'Messages',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 18,
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: _openNewMessage,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1E0D33),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_square,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF1C0B2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x22FFFFFF), width: 0.5),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search,
              color: Colors.white.withValues(alpha: 0.35),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Search',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final requestCount = _requestSummaries.length;
    final chips = ['Primary', 'General', 'Requests'];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
        children: chips.map((c) {
          final isActive = _filter == c;
          final label = (c == 'Requests' && requestCount > 0)
              ? 'Requests ($requestCount)'
              : c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.brandDeepMagenta
                      : const Color(0xFF1C0B2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppColors.brandDeepMagenta
                        : const Color(0x33FFFFFF),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white60,
                    fontSize: 13,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMessagesSectionHeader() {
    final requestCount = _requestSummaries.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (requestCount > 0)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MessageRequestsScreen(requests: _requestSummaries),
                  ),
                );
              },
              child: Text(
                'Requests ($requestCount)',
                style: const TextStyle(
                  color: AppColors.brandDeepMagenta,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInboxList() {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.brandMagenta),
      );
    }

    if (_controller.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white.withValues(alpha: 0.3),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _controller.error!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final summaries = _filteredSummaries;
    if (summaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _filter == 'Requests'
                  ? Icons.mark_email_unread_outlined
                  : Icons.chat_bubble_outline,
              color: Colors.white.withValues(alpha: 0.2),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _filter == 'Requests'
                  ? 'No message requests'
                  : 'No conversations yet',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            if (_filter == 'Primary') ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openNewMessage,
                child: const Text(
                  'Start a conversation',
                  style: TextStyle(
                    color: AppColors.brandMagenta,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 80),
      itemCount: summaries.length,
      itemBuilder: (context, index) {
        final summary = summaries[index];
        return ChatTile(summary: summary, onTap: () => _openThread(summary));
      },
    );
  }
}
