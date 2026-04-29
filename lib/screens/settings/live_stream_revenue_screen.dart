import 'package:flutter/material.dart';
import 'package:vyooo/core/widgets/app_gradient_background.dart';

class LiveStreamRevenueScreen extends StatelessWidget {
  const LiveStreamRevenueScreen({super.key});

  static const List<Map<String, String>> _streams = [
    {
      'date': 'April 22 2026',
      'views': '1M',
      'time': '6574',
      'rate': '7',
      'earnings': '€ 46032',
    },
    {
      'date': 'April 22 2026',
      'views': '1M',
      'time': '6574',
      'rate': '7',
      'earnings': '€ 46032',
    },
    {
      'date': 'April 22 2026',
      'views': '1M',
      'time': '6574',
      'rate': '7',
      'earnings': '€ 46032',
    },
    {
      'date': 'April 22 2026',
      'views': '1M',
      'time': '6574',
      'rate': '7',
      'earnings': '€ 46032',
    },
    {
      'date': 'April 22 2026',
      'views': '1M',
      'time': '6574',
      'rate': '7',
      'earnings': '€ 46032',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        type: GradientType.premiumDark,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAppBar(context),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _streams.length,
                  itemBuilder: (context, index) {
                    final item = _streams[index];
                    return _StreamCard(
                      date: item['date']!,
                      views: item['views']!,
                      timeMinutes: item['time']!,
                      rate: item['rate']!,
                      earnings: item['earnings']!,
                    );
                  },
                ),
              ),
            ],
          ),
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
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 16),
                Text(
                  'Live stream revenue',
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
}

class _StreamCard extends StatelessWidget {
  const _StreamCard({
    required this.date,
    required this.views,
    required this.timeMinutes,
    required this.rate,
    required this.earnings,
  });

  final String date;
  final String views;
  final String timeMinutes;
  final String rate;
  final String earnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 110,
              height: double.infinity,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: const DecorationImage(
                  image: NetworkImage(
                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=240&q=80',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 16, 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _DetailRow(
                      label: 'View Count',
                      value: views,
                      isValueBold: true,
                    ),
                    _ShortDetailRow(
                      label: 'Total view time\n(Minutes)',
                      value: '$timeMinutes min * ',
                      highlight: '(€$rate)',
                    ),
                    _DetailRow(
                      label: 'Earnings',
                      value: earnings,
                      isValueBold: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isValueBold = false,
  });

  final String label;
  final String value;
  final bool isValueBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isValueBold ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ShortDetailRow extends StatelessWidget {
  const _ShortDetailRow({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
        RichText(
          textAlign: TextAlign.right,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: highlight,
                style: const TextStyle(
                  color: Color(0xFFF43F5E),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
