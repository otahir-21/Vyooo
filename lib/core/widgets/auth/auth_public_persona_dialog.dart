import 'package:flutter/material.dart';

import '../../services/user_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import 'auth_branded_dialog.dart';

/// Collects public-profile persona text during username onboarding.
class AuthPublicPersonaDialog extends StatefulWidget {
  const AuthPublicPersonaDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (dialogContext) => Theme(
        data: AppTheme.light,
        child: const AuthPublicPersonaDialog(),
      ),
    );
  }

  @override
  State<AuthPublicPersonaDialog> createState() => _AuthPublicPersonaDialogState();
}

class _AuthPublicPersonaDialogState extends State<AuthPublicPersonaDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    final normalized = UserService.normalizePublicPersona(_controller.text);
    if (normalized.length < 2) {
      setState(() => _errorText = 'Enter at least 2 characters.');
      return;
    }
    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return AuthBrandedDialog(
      title: 'Describe your public profile',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.lightScaffoldBackground,
                    borderRadius: AppRadius.pillRadius,
                    border: Border.all(color: AppTheme.lightUnfocusedUnderline),
                  ),
                  child: TextFormField(
                    controller: _controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: UserService.publicPersonaMaxLength,
                    style: AppTypography.usernameFieldValue.copyWith(
                      color: AppTheme.lightOnSurface,
                    ),
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                    decoration: InputDecoration(
                      hintText:
                          'e.g. Entrepreneur, Content creator, Celebrity',
                      hintStyle: AppTypography.inputHint.copyWith(
                        color: AppTheme.lightSecondaryText,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                if (_errorText != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorText!,
                    style: AppTypography.usernameAvailabilityError,
                  ),
                ],
              ],
            ),
        ),
        const SizedBox(height: AppSpacing.md),
        AuthBrandedDialogActionRow(
          actions: [
            AuthBrandedDialogAction(
              label: 'Back',
              style: AppTypography.authDialogCancel,
              onTap: () => Navigator.of(context).pop(),
            ),
            AuthBrandedDialogAction(
              label: 'Continue',
              onTap: _onContinue,
            ),
          ],
        ),
      ],
    );
  }
}
