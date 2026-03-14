import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';

/// "Manage Content Preferences" bottom sheet with four toggles.
/// State is local to the sheet; persist via preferences/API as needed.
void showManageContentPreferencesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ManageContentPreferencesSheet(),
  );
}

abstract final class _Layout {
  static const double dragHandleWidth = 36;
  static const double dragHandleHeight = 4;
}

class _ManageContentPreferencesSheet extends StatefulWidget {
  const _ManageContentPreferencesSheet();

  @override
  State<_ManageContentPreferencesSheet> createState() =>
      _ManageContentPreferencesSheetState();
}

class _ManageContentPreferencesSheetState extends State<_ManageContentPreferencesSheet> {
  bool _limitSensitiveContent = true;
  bool _personaliseContent = true;
  bool _hideSensitiveWords = false;
  bool _showLessPolitical = false;

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
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.storyItem, bottom: AppSpacing.sm),
                  child: Center(
                    child: Container(
                      width: _Layout.dragHandleWidth,
                      height: _Layout.dragHandleHeight,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const Text(
                  'Manage Content Preferences',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                _PreferenceSwitch(
                  label: 'Limit sensitive content',
                  value: _limitSensitiveContent,
                  onChanged: (v) => setState(() => _limitSensitiveContent = v),
                ),
                _PreferenceSwitch(
                  label: 'Personalise content based on my activity',
                  value: _personaliseContent,
                  onChanged: (v) => setState(() => _personaliseContent = v),
                ),
                _PreferenceSwitch(
                  label: 'Hide content with sensitive words',
                  value: _hideSensitiveWords,
                  onChanged: (v) => setState(() => _hideSensitiveWords = v),
                ),
                _PreferenceSwitch(
                  label: 'Show less political content',
                  value: _showLessPolitical,
                  onChanged: (v) => setState(() => _showLessPolitical = v),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF22C55E), // Accurate WhatsApp Green
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white.withOpacity(0.1),
          ),
        ],
      ),
    );
  }
}
