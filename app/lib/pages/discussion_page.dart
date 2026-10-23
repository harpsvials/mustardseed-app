import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';
import '../widgets/shared.dart';

class DiscussionPage extends StatelessWidget {
  final AppData data;

  const DiscussionPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hero = data.discussionMeta['heroTitle'] ?? {'zh': '讨论', 'en': 'Discussion'};
    final sub = data.discussionMeta['heroSub'];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroHeader(
          title: AppLocale.t(hero),
          sub: AppLocale.t(sub),
        ),
        const SizedBox(height: 16),
        for (final t in data.topics) _TopicCard(topic: t),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _TopicCard extends StatelessWidget {
  final Topic topic;

  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    final label = AppLocale.t(topic.label);
    final q = AppLocale.t(topic.q);
    final prompt = AppLocale.t(topic.prompt);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppColors.mustard,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q,
            style: const TextStyle(
              fontSize: 15,
              height: 1.65,
              color: AppColors.cream,
            ),
          ),
          if (prompt.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.sprout.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.sprout.withValues(alpha: .3)),
              ),
              child: Text(
                prompt,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.sprout,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
