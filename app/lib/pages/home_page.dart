import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';
import '../widgets/shared.dart';
import 'about_page.dart';
import 'testify_page.dart';

class HomePage extends StatelessWidget {
  final AppData data;
  final ValueChanged<int>? onOpenTab;

  const HomePage({super.key, required this.data, this.onOpenTab});

  @override
  Widget build(BuildContext context) {
    final hero = data.home['heroTitle'] ?? {'zh': '主页', 'en': 'Home'};
    final heroSub = data.home['heroSub'] ?? {'zh': '', 'en': ''};
    final cards =
        (data.home['cards'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroHeader(
          title: AppLocale.t(hero),
          sub: AppLocale.t(heroSub),
          trailing: const _SeedLine(),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              for (final card in cards)
                _HomeCard(card: card, onTap: () => _open(context, card)),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _open(BuildContext context, Map<String, dynamic> card) {
    final href = (card['href'] ?? '').toString();
    switch (href) {
      case 'sermons.html':
        onOpenTab?.call(1);
      case 'testimonies.html':
        onOpenTab?.call(2);
      case 'discussion.html':
        onOpenTab?.call(3);
      case 'about.html':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AboutPage(data: data)));
      case 'testify.html':
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TestifyPage(data: data)));
      default:
        break;
    }
  }
}

class _SeedLine extends StatelessWidget {
  const _SeedLine();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'mustard · seed — 让每个分享都像种子，落进土壤',
      style: TextStyle(
        fontSize: 12,
        color: AppColors.sprout,
        letterSpacing: .3,
        height: 1.4,
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final Map<String, dynamic> card;
  final VoidCallback onTap;

  const _HomeCard({required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final no = (card['no'] ?? '').toString();
    final title = AppLocale.t(
        (card['title'] as Map?)?.cast<String, dynamic>() ?? {});
    final summary = AppLocale.t(
        (card['summary'] as Map?)?.cast<String, dynamic>() ?? {});
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.mustard.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.mustard.withValues(alpha: .35)),
                ),
                child: Text(
                  no,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mustard,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cream,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.creamFaint,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
