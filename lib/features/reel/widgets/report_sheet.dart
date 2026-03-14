import 'package:flutter/material.dart';
import 'block_user_sheet.dart';

/// Shows the Report flow: starts with reasons, then thank you screen with block/unfollow options.
void showReportSheet(BuildContext context, {required String username, required String avatarUrl}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ReportSheetFlow(username: username, avatarUrl: avatarUrl),
  );
}

class _ReportSheetFlow extends StatefulWidget {
  const _ReportSheetFlow({required this.username, required this.avatarUrl});

  final String username;
  final String avatarUrl;

  @override
  State<_ReportSheetFlow> createState() => _ReportSheetFlowState();
}

class _ReportSheetFlowState extends State<_ReportSheetFlow> {
  bool _showThanks = false;
  bool _isOtherActionsExpanded = false;

  final List<String> _reasons = [
    "I just don't like it",
    "Content isn't factual",
    "Content contains hate or discrimination",
    "Inappropriate or offensive visuals",
    "Promotes harm or misinformation",
  ];

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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5), size: 24),
                    ),
                  ),
                ],
              ),
            ),
            
            if (!_showThanks) _buildReasonsList() else _buildThanksView(),
            
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
        const SizedBox(height: 16),
        ..._reasons.map((reason) => _ReasonTile(
              label: reason,
              onTap: () => setState(() => _showThanks = true),
            )),
      ],
    );
  }

  Widget _buildThanksView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        const Text(
          'Thanks for your feedback',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'We use these reports to show less of this kind of content in the future.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // Other Actions Dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              InkWell(
                onTap: () => setState(() => _isOtherActionsExpanded = !_isOtherActionsExpanded),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Text(
                        'Other Actions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        _isOtherActionsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isOtherActionsExpanded) ...[
                _ActionItem(
                  icon: Icons.block_flipped,
                  label: 'Block User',
                  labelColor: const Color(0xFFEF4444),
                  onTap: () {
                    Navigator.of(context).pop();
                    showBlockUserSheet(
                      context,
                      username: widget.username,
                      avatarUrl: widget.avatarUrl,
                    );
                  },
                ),
                _ActionItem(
                  icon: Icons.person_remove_outlined,
                  label: 'Unfollow User',
                  onTap: () {
                    // TODO: Implement unfollow
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
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
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 20),
          ],
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    this.labelColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: labelColor ?? Colors.white.withOpacity(0.7), size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: labelColor ?? Colors.white.withOpacity(0.7),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
