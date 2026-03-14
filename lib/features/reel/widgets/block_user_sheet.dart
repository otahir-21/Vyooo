import 'package:flutter/material.dart';

/// "Block User" confirmation sheet.
/// Matches Figma: magenta gradient, user info card, consequence list, pink Block button.
void showBlockUserSheet(BuildContext context, {required String username, required String avatarUrl}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _BlockUserSheet(username: username, avatarUrl: avatarUrl),
  );
}

class _BlockUserSheet extends StatelessWidget {
  const _BlockUserSheet({required this.username, required this.avatarUrl});

  final String username;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF49113B), // Deep Magenta
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
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                   IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  const Text(
                    'Block User',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5), size: 24),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // User Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    backgroundColor: Colors.grey[800],
                    child: avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Block $username ?',
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
                            color: Colors.white.withOpacity(0.6),
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
            
            // Consequence List
            _ConsequenceItem(
              icon: Icons.block_flipped,
              text: 'They won\'t be able to message you, find your profile, or your content on VyooO',
            ),
            _ConsequenceItem(
              icon: Icons.notifications_off_outlined,
              text: 'They won\'t be notified that you blocked them.',
            ),
            _ConsequenceItem(
              icon: Icons.settings_outlined,
              text: 'You can unblock them at anytime from settings.',
            ),
            
            const SizedBox(height: 32),
            
            // Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    // TODO: Implement block logic
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Block',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
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
          Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
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
