import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';

/// 留言 / 祷告墙的"写一条"按钮
class ComposeButton extends StatelessWidget {
  final VoidCallback onPressed;

  const ComposeButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(Icons.edit_outlined, size: 18),
        label: const Text('写一条'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mustard,
          foregroundColor: const Color(0xFF24301B),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

/// 页面英雄头部：芥菜黄标题 + 奶油副标题
class HeroHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? trailing;

  const HeroHeader({super.key, required this.title, this.sub, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        border: Border(bottom: BorderSide(color: AppColors.lineStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.mustard,
              letterSpacing: .5,
              height: 1.2,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 8),
            Text(
              sub!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.creamDim,
                height: 1.5,
              ),
            ),
          ],
          if (trailing != null) ...[const SizedBox(height: 14), trailing!],
        ],
      ),
    );
  }
}

/// 经文卡片
class VerseCard extends StatelessWidget {
  final String text;
  final String? ref;

  const VerseCard({super.key, required this.text, this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(fontSize: 15, height: 1.7, color: AppColors.cream),
          ),
          if (ref != null && ref!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ref!,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.mustard,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 章节标题（带序号）
class ChapterTitle extends StatelessWidget {
  final String no;
  final String title;

  const ChapterTitle({super.key, required this.no, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.mustard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              no,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF24301B),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.cream,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 讲道正文块渲染（p / verse / question）
class BlockView extends StatelessWidget {
  final Block block;

  const BlockView({super.key, required this.block});

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case 'verse':
        final label = AppLocale.t(block.label);
        final text = AppLocale.t(block.text);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: VerseCard(text: text, ref: label),
        );
      case 'question':
        // 讨论题统一由页面底部的 QuestionsView 卡片渲染，
        // 正文中重复的 question 块直接跳过，避免出现多余的问号条
        return const SizedBox.shrink();
      case 'sub':
        final text = AppLocale.t({'zh': block.zh, 'en': block.en});
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
              color: AppColors.mustard,
            ),
          ),
        );
      case 'quote':
        final text = AppLocale.t({'zh': block.zh, 'en': block.en});
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            border: Border(
              left: BorderSide(color: AppColors.mustard, width: 2),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.8,
              fontStyle: FontStyle.italic,
              color: AppColors.cream,
            ),
          ),
        );
      default:
        final text = AppLocale.t({'zh': block.zh, 'en': block.en});
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15.5,
              height: 1.75,
              color: AppColors.cream,
            ),
          ),
        );
    }
  }
}

/// 阅读页字号调节：关于 / 见证 / 讲稿详情共用同一设置（85%–140%）
class ReaderTextSize extends StatefulWidget {
  final Widget child;
  final String storageKey;

  const ReaderTextSize({
    super.key,
    required this.child,
    this.storageKey = 'ms_reader_text_scale',
  });

  @override
  State<ReaderTextSize> createState() => _ReaderTextSizeState();
}

class _ReaderTextSizeState extends State<ReaderTextSize> {
  static const double _min = .85;
  static const double _max = 1.4;
  static const double _step = .1;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getDouble(widget.storageKey) ?? 1;
    if (!mounted) return;
    setState(() => _scale = saved.clamp(_min, _max).toDouble());
  }

  void _change(double delta) {
    final next = (_scale + delta).clamp(_min, _max).toDouble();
    if (next == _scale) return;
    setState(() => _scale = next);
    SharedPreferences.getInstance().then(
      (sp) => sp.setDouble(widget.storageKey, next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = AppLocale.value == AppLocale.en;
    final baseScale = MediaQuery.textScalerOf(context).scale(1.0);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
          decoration: BoxDecoration(
            color: AppColors.bg,
            border: Border(bottom: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            children: [
              Text(
                isEn ? 'Text size' : '字号',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.2,
                  color: AppColors.creamDim,
                ),
              ),
              const Spacer(),
              _ReaderSizeButton(
                label: isEn ? 'Smaller' : '减小',
                enabled: _scale > _min + .001,
                onPressed: () => _change(-_step),
              ),
              const SizedBox(width: 8),
              _ReaderSizeButton(
                label: isEn ? 'Larger' : '加大',
                enabled: _scale < _max - .001,
                onPressed: () => _change(_step),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 42,
                child: Text(
                  '${(_scale * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.creamDim,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(baseScale * _scale)),
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _ReaderSizeButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  const _ReaderSizeButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: AppColors.cream,
        side: BorderSide(color: AppColors.lineStrong),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
      child: Text(label),
    );
  }
}
