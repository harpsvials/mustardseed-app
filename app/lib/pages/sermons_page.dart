import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';
import '../widgets/shared.dart';
import 'sermon_detail_page.dart';

class SermonsPage extends StatelessWidget {
  final AppData data;

  const SermonsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hero = data.sermonsMeta['heroTitle'] ?? {'zh': '讲道', 'en': 'Sermons'};
    final sub = data.sermonsMeta['heroSub'];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroHeader(
          title: AppLocale.t(hero),
          sub: AppLocale.t(sub),
        ),
        for (final s in data.sermons) _SermonTile(sermon: s),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _SermonTile extends StatelessWidget {
  final Sermon sermon;

  const _SermonTile({required this.sermon});

  @override
  Widget build(BuildContext context) {
    final title = AppLocale.t(sermon.title);
    final verse = AppLocale.t(sermon.verse);
    final summary = AppLocale.t(sermon.summary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SermonDetailPage(sermon: sermon))),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.mustard.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.mustard.withValues(alpha: .35)),
                      ),
                      child: Text(
                        '${sermon.no}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.mustard,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.cream,
                              height: 1.3,
                            ),
                          ),
                          if (summary.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.creamDim,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.creamFaint, size: 20),
                  ],
                ),
                if (verse.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: AppColors.line, width: .8),
                    ),
                    child: Text(
                      verse,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mustardSoft,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
