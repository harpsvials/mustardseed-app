import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';
import '../widgets/shared.dart';

class TestimoniesPage extends StatelessWidget {
  final AppData data;

  const TestimoniesPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hero = data.testimoniesMeta['heroTitle'] ?? {'zh': '见证', 'en': 'Testimonies'};
    final sub = data.testimoniesMeta['heroSub'];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroHeader(
          title: AppLocale.t(hero),
          sub: AppLocale.t(sub),
        ),
        for (final p in data.periods) _PeriodCard(period: p),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final Period period;

  const _PeriodCard({required this.period});

  @override
  Widget build(BuildContext context) {
    final periodText = AppLocale.t(period.period);
    final sub = AppLocale.t(period.sub);
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
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.terra.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.terra.withValues(alpha: .4)),
                ),
                child: Text(
                  periodText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.terraSoft,
                  ),
                ),
              ),
              if (sub.isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.creamFaint,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          for (final para in period.paras)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                AppLocale.t(para.cast<String, dynamic>()),
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.75,
                  color: AppColors.cream,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
