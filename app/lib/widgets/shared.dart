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

/// A- / A+ 字号按钮的统一字形，符号位于 A 的右上角。
class TextSizeGlyph extends StatelessWidget {
  final bool plus;

  const TextSizeGlyph({super.key, required this.plus});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: Text(
              'A',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: -2,
            child: Text(
              plus ? '+' : '-',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 关于 / 见证 / 讲稿 / 灵修共用的字号按钮。
class ReaderSizeButton extends StatelessWidget {
  final bool plus;
  final String label;
  final VoidCallback? onPressed;

  const ReaderSizeButton({
    super.key,
    required this.plus,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 36),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          foregroundColor: AppColors.cream,
          disabledForegroundColor: AppColors.creamFaint.withValues(alpha: .38),
          side: BorderSide(color: AppColors.lineStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
        child: TextSizeGlyph(plus: plus),
      ),
    );
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

  /// 会话内共享，避免新页面重建时被尚未落盘的旧值覆盖。
  static final Map<String, double> _sessionScales = {};
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _scale = _sessionScales[widget.storageKey] ?? 1;
    _load();
  }

  Future<void> _load() async {
    if (_sessionScales.containsKey(widget.storageKey)) return;
    final sp = await SharedPreferences.getInstance();
    final saved = (sp.getDouble(widget.storageKey) ?? 1)
        .clamp(_min, _max)
        .toDouble();
    _sessionScales[widget.storageKey] = saved;
    if (!mounted) return;
    setState(() => _scale = saved);
  }

  void _change(double delta) {
    final next = (_scale + delta).clamp(_min, _max).toDouble();
    if (next == _scale) return;
    _sessionScales[widget.storageKey] = next;
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
              ReaderSizeButton(
                plus: false,
                label: isEn ? 'Smaller' : '减小',
                onPressed: _scale > _min + .001 ? () => _change(-_step) : null,
              ),
              const SizedBox(width: 8),
              ReaderSizeButton(
                plus: true,
                label: isEn ? 'Larger' : '加大',
                onPressed: _scale < _max - .001 ? () => _change(_step) : null,
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 42,
                child: Text(
                  '${(_scale * 100).round()}%',
                  textAlign: TextAlign.left,
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
