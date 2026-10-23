import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';
import '../data/api_client.dart';

/// 我要做见证：提交到留言板（page=testimony）
class TestifyPage extends StatefulWidget {
  final AppData data;

  const TestifyPage({super.key, required this.data});

  @override
  State<TestifyPage> createState() => _TestifyPageState();
}

class _TestifyPageState extends State<TestifyPage> {
  final _nameCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hero = widget.data.testify['heroTitle'] ??
        {'zh': '我要做见证', 'en': 'Share Your Testimony'};
    final sub = widget.data.testify['heroSub'];
    final text = widget.data.testify['text'];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(AppLocale.t(hero)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.cream),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          if (sub != null)
            Text(
              AppLocale.t(sub),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.creamDim,
                height: 1.5,
              ),
            ),
          if (text != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lineStrong),
              ),
              child: Text(
                AppLocale.t(text),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.7,
                  color: AppColors.cream,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.cream),
            decoration: const InputDecoration(
              labelText: '名字',
              labelStyle: TextStyle(color: AppColors.creamDim),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.lineStrong)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.mustard)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contentCtrl,
            maxLines: 7,
            style: const TextStyle(color: AppColors.cream),
            decoration: const InputDecoration(
              labelText: '见证内容',
              labelStyle: TextStyle(color: AppColors.creamDim),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.lineStrong)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.mustard)),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mustard,
              foregroundColor: const Color(0xFF24301B),
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF24301B)))
                : const Text('提交见证'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (name.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写名字和见证内容')),
      );
      return;
    }
    setState(() => _submitting = true);
    final err =
        await ApiClient.postComment(name: name, content: content, page: 'testimony');
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err == null) {
      _nameCtrl.clear();
      _contentCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('见证已提交，感谢你的分享')),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    }
  }
}
