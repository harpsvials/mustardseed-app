import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';

class AboutPage extends StatelessWidget {
  final AppData data;

  const AboutPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final sections = data.about;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(AppLocale.t(
            data.nav['about'] as Map? ?? {'zh': '关于', 'en': 'About Us'})),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.cream),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          for (final section in sections)
            _SectionCard(section: section),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Section section;

  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    // blocks: 标题块（key 以 t./h./about.t 开头），其余为段落
    Map<String, dynamic>? titleBlock;
    final List<Map<String, dynamic>> paras = [];
    for (final b in section.blocks) {
      final key = (b['key'] ?? '').toString();
      if (key.startsWith('t.') ||
          key.startsWith('h.') ||
          key.startsWith('about.t')) {
        titleBlock ??= b;
      } else {
        paras.add(b);
      }
    }
    final titleZh = (titleBlock?['zh'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleZh.isNotEmpty) ...[
            Text(
              AppLocale.t(titleBlock!.cast<String, dynamic>()),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.mustard,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final p in paras)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                AppLocale.t(p.cast<String, dynamic>()),
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
