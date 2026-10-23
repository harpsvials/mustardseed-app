import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../data/app_data.dart';
import '../services/tts_service.dart';
import '../widgets/shared.dart';

class SermonDetailPage extends StatefulWidget {
  final Sermon sermon;

  const SermonDetailPage({super.key, required this.sermon});

  @override
  State<SermonDetailPage> createState() => _SermonDetailPageState();
}

class _SermonDetailPageState extends State<SermonDetailPage> {
  bool _reading = false;

  String get _fullText {
    final buf = StringBuffer();
    buf.writeln(AppLocale.t(widget.sermon.title));
    for (final ch in widget.sermon.body) {
      final t = AppLocale.t(ch.title);
      if (t.isNotEmpty) buf.writeln(t);
      for (final b in ch.blocks) {
        if (b.type == 'p') {
          buf.writeln(AppLocale.t({'zh': b.zh, 'en': b.en}));
        }
      }
    }
    final q = widget.sermon.questions;
    if (q != null) {
      final qText = AppLocale.t(q.text);
      if (qText.isNotEmpty) buf.writeln(qText);
    }
    return buf.toString();
  }

  Future<void> _toggleRead() async {
    if (_reading) {
      await TtsService.instance.stop();
      setState(() => _reading = false);
    } else {
      await TtsService.instance.speak(_fullText);
      setState(() => _reading = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = AppLocale.t(widget.sermon.title);
    final verseText = AppLocale.t(widget.sermon.verseText);
    final verseRef = AppLocale.t(widget.sermon.verseRef);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.cream),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _reading ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
              color: _reading ? AppColors.terra : AppColors.mustard,
            ),
            onPressed: _toggleRead,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.mustard,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          if (verseText.isNotEmpty)
            VerseCard(text: verseText, ref: verseRef),
          for (var i = 0; i < widget.sermon.body.length; i++)
            _ChapterView(index: i, chapter: widget.sermon.body[i]),
          if (widget.sermon.questions != null)
            _QuestionsView(q: widget.sermon.questions!),
        ],
      ),
    );
  }
}

class _ChapterView extends StatelessWidget {
  final int index;
  final Chapter chapter;

  const _ChapterView({required this.index, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final title = AppLocale.t(chapter.title);
    final hasTitle = title.isNotEmpty;
    final no = hasTitle ? '${index + 1}' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTitle) ChapterTitle(no: no, title: title),
        for (final b in chapter.blocks) BlockView(block: b),
      ],
    );
  }
}

class _QuestionsView extends StatelessWidget {
  final Questions q;

  const _QuestionsView({required this.q});

  @override
  Widget build(BuildContext context) {
    final tag = AppLocale.t(q.tag);
    final qTitle = AppLocale.t(q.title);
    final qText = AppLocale.t(q.text);
    if (qText.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 26),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lineStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tag.isNotEmpty)
            Text(
              tag,
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: AppColors.mustard,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (qTitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              qTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.cream,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            qText,
            style: const TextStyle(
              fontSize: 15,
              height: 1.8,
              color: AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }
}
