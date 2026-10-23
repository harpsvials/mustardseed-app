import 'package:flutter/material.dart';
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
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: const Text('写一条'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mustard,
          foregroundColor: const Color(0xFF24301B),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
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
        border: const Border(bottom: BorderSide(color: AppColors.lineStrong)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
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
              style: const TextStyle(
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
            style: const TextStyle(
              fontSize: 15,
              height: 1.7,
              color: AppColors.cream,
            ),
          ),
          if (ref != null && ref!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              ref!,
              style: const TextStyle(
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
              style: const TextStyle(
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
      default:
        final text = AppLocale.t({'zh': block.zh, 'en': block.en});
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15.5,
              height: 1.75,
              color: AppColors.cream,
            ),
          ),
        );
    }
  }
}
