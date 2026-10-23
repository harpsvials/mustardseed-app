import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';
import '../data/api_client.dart';
import '../widgets/shared.dart';

class PrayerPage extends StatefulWidget {
  final AppData data;

  const PrayerPage({super.key, required this.data});

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ApiClient.fetchPrayers();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.data.prayer['heroTitle'] ??
        {'zh': '祷告墙', 'en': 'Prayer Wall'};
    final sub = widget.data.prayer['heroSub'];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        HeroHeader(
          title: AppLocale.t(hero),
          sub: AppLocale.t(sub),
          trailing: ComposeButton(onPressed: _compose),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.mustard),
            ),
          )
        else if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text(
                '还没有祷告，把你的心愿放在这里',
                style: TextStyle(color: AppColors.creamFaint, fontSize: 14),
              ),
            ),
          )
        else
          for (final item in _items) _PrayerCard(item: item),
        const SizedBox(height: 20),
      ],
    );
  }

  Future<void> _compose() async {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final result = await showDialog<_ComposeResult>(
      context: context,
      builder: (ctx) => _ComposeDialog(
        nameCtrl: nameCtrl,
        contentCtrl: contentCtrl,
      ),
    );
    if (result == null) return;
    if (!mounted) return;
    final err = await ApiClient.postPrayer(
      name: result.name,
      content: result.content,
    );
    if (!mounted) return;
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发送，我们一起在耶稣里守望')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }
}

class _ComposeResult {
  final String name;
  final String content;
  const _ComposeResult(this.name, this.content);
}

class _ComposeDialog extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController contentCtrl;

  const _ComposeDialog({required this.nameCtrl, required this.contentCtrl});

  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgRaised,
      title: const Text('发送祷告',
          style: TextStyle(color: AppColors.cream, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.nameCtrl,
            style: const TextStyle(color: AppColors.cream),
            decoration: const InputDecoration(
              labelText: '名字',
              labelStyle: TextStyle(color: AppColors.creamDim),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.lineStrong)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.contentCtrl,
            maxLines: 4,
            style: const TextStyle(color: AppColors.cream),
            decoration: const InputDecoration(
              labelText: '祷告内容',
              labelStyle: TextStyle(color: AppColors.creamDim),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.lineStrong)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消', style: TextStyle(color: AppColors.creamFaint)),
        ),
        TextButton(
          onPressed: () {
            if (widget.nameCtrl.text.trim().isEmpty ||
                widget.contentCtrl.text.trim().isEmpty) {
              return;
            }
            Navigator.of(context).pop(_ComposeResult(
              widget.nameCtrl.text.trim(),
              widget.contentCtrl.text.trim(),
            ));
          },
          child: const Text('发送', style: TextStyle(color: AppColors.mustard)),
        ),
      ],
    );
  }
}

class _PrayerCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _PrayerCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final name = (item['name'] ?? '匿名').toString();
    final content = (item['content'] ?? '').toString();
    final created = (item['created_at'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.sprout.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                      color: AppColors.sprout.withValues(alpha: .35)),
                ),
                child: const Icon(Icons.front_hand,
                    color: AppColors.sprout, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.cream,
                  ),
                ),
              ),
              if (created.isNotEmpty)
                Text(
                  created,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.creamFaint),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.7,
              color: AppColors.cream,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '✝ 阿们',
            style: TextStyle(fontSize: 12, color: AppColors.sprout),
          ),
        ],
      ),
    );
  }
}
