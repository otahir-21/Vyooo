import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../../../core/utils/user_facing_errors.dart';

/// Instagram-style block flow: pick a reason, then confirm block.
void showBlockUserSheet(
  BuildContext context, {
  required String username,
  required String avatarUrl,
  String? targetUserId,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BlockUserSheet(
      username: username,
      avatarUrl: avatarUrl,
      targetUserId: targetUserId,
    ),
  );
}

class _BlockUserSheet extends StatefulWidget {
  const _BlockUserSheet({
    required this.username,
    required this.avatarUrl,
    this.targetUserId,
  });

  final String username;
  final String avatarUrl;
  final String? targetUserId;

  @override
  State<_BlockUserSheet> createState() => _BlockUserSheetState();
}

class _BlockUserSheetState extends State<_BlockUserSheet> {
  bool _busy = false;
  String? _selectedReason;

  static const List<String> _reasons = [
    'I don\'t want to see their content',
    'They\'re harassing or bullying me',
    'They\'re pretending to be someone else',
    'Spam or scam',
    'Something else',
  ];

  bool get _showConfirmation => _selectedReason != null;

  Future<void> _onBlock() async {
    final target = widget.targetUserId;
    final reason = _selectedReason;
    final me = AuthService().currentUser?.uid;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (me == null || me.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Sign in to block accounts.')),
      );
      return;
    }
    if (target == null || target.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Blocking isn’t available for this profile.')),
      );
      return;
    }
    if (reason == null || reason.isEmpty) return;
    if (me == target) return;
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await UserService().blockUser(
        currentUid: me,
        targetUid: target,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger?.showSnackBar(
        const SnackBar(content: Text('You blocked this account.')),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(messageForFirestore(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF49113B),
            Color(0xFF210D1D),
            Color(0xFF0F040C),
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  if (_showConfirmation)
                    IconButton(
                      onPressed: () => setState(() => _selectedReason = null),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  Text(
                    _showConfirmation
                        ? 'Block User'
                        : 'Block @${widget.username}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            if (!_showConfirmation) _buildReasonsList() else _buildConfirmation(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonsList() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Text(
            'Why are you blocking this account?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
        ..._reasons.map(
          (reason) => _ReasonTile(
            label: reason,
            onTap: () => setState(() => _selectedReason = reason),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmation() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundImage: widget.avatarUrl.isNotEmpty
                    ? NetworkImage(widget.avatarUrl)
                    : null,
                backgroundColor: Colors.grey[800],
                child: widget.avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Block ${widget.username}?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This will also block any other accounts that they may have or create in the future.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _ConsequenceItem(
          icon: Icons.block_flipped,
          text:
              'They won\'t be able to message you, find your profile, or your content on VyooO',
        ),
        const _ConsequenceItem(
          icon: Icons.notifications_off_outlined,
          text: 'They won\'t be notified that you blocked them.',
        ),
        const _ConsequenceItem(
          icon: Icons.settings_outlined,
          text: 'You can unblock them at anytime from settings.',
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy ? null : _onBlock,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                disabledBackgroundColor:
                    const Color(0xFFEF4444).withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                _busy ? 'Blocking…' : 'Block',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsequenceItem extends StatelessWidget {
  const _ConsequenceItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
