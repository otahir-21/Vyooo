import 'package:flutter/material.dart';
import '../../core/widgets/app_gradient_background.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  bool activity = true;
  bool post = true;
  bool live = true;
  bool subscriptions = false;
  bool recommended = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAppBar(context),
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  const Text(
                    'Push Notifications',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        _NotificationSwitch(
                          title: 'Activity',
                          subtitle:
                              'Notify me about likes, comments, and interactions on my content',
                          value: activity,
                          onChanged: (v) => setState(() => activity = v),
                        ),
                        _divider(),
                        _NotificationSwitch(
                          title: 'Post',
                          subtitle: 'Notifications from profiles I follow',
                          value: post,
                          onChanged: (v) => setState(() => post = v),
                        ),
                        _divider(),
                        _NotificationSwitch(
                          title: 'Live',
                          subtitle:
                              'Notify me when creators I follow start a live stream',
                          value: live,
                          onChanged: (v) => setState(() => live = v),
                        ),
                        _divider(),
                        _NotificationSwitch(
                          title: 'Subscriptions',
                          subtitle:
                              'Notify me about new subscriptions, renewals, & cancellations',
                          value: subscriptions,
                          onChanged: (v) => setState(() => subscriptions = v),
                        ),
                        _divider(),
                        _NotificationSwitch(
                          title: 'Recommended Content',
                          subtitle:
                              'Notify when a content is posted based on my interest',
                          value: recommended,
                          onChanged: (v) => setState(() => recommended = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                SizedBox(width: 16),
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            'VyooO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 24,
      thickness: 1,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _NotificationSwitch extends StatelessWidget {
  const _NotificationSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFFF81945),
          activeTrackColor: const Color(0xFFF81945).withValues(alpha: 0.3),
        ),
      ],
    );
  }
}
