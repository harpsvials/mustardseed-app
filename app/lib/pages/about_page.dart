import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';
import '../services/update_checker.dart';

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
          icon: Icon(Icons.arrow_back, color: AppColors.cream),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          for (final section in sections)
            _SectionCard(section: section),
          const _UpdateCard(),
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.mustard,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final p in paras)
            if ((p['key'] ?? '').toString().endsWith('.label'))
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Text(
                  AppLocale.t(p.cast<String, dynamic>()),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: AppColors.mustard,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  AppLocale.t(p.cast<String, dynamic>()),
                  style: TextStyle(
                    fontSize: 17,
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


/// 版本与更新：显示本机版本 / 服务端最新版本，可手动检查并直接走应用内更新
class _UpdateCard extends StatefulWidget {
  const _UpdateCard();

  @override
  State<_UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<_UpdateCard> {
  bool _busy = true;
  UpdateCheckInfo? _info;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    setState(() => _busy = true);
    final info = await UpdateChecker.probe();
    if (!mounted) return;
    setState(() {
      _info = info;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
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
          Text(
            AppLocale.value == AppLocale.en ? 'Version' : '版本与更新',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.mustard,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          _row('当前版本', info?.current.isNotEmpty == true ? info!.current : '读取中…'),
          _row('最新版本', _busy ? '检查中…' : (info?.latest ?? '—')),
          _row('状态', _busy ? '正在检查…' : (info?.summary ?? '')),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _probe,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.cream,
                  side: BorderSide(color: AppColors.lineStrong),
                ),
                child: const Text('重新检查'),
              ),
              const SizedBox(width: 10),
              if (info?.hasUpdate == true)
                FilledButton(
                  onPressed: () => UpdateChecker.showUpdateDialog(context, info!),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.mustard,
                    foregroundColor: const Color(0xFF24301B),
                  ),
                  child: const Text('立即更新'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(fontSize: 14.5, color: AppColors.creamFaint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14.5, color: AppColors.cream, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
