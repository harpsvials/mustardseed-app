import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../i18n.dart';
import '../services/audio_controller.dart';

/// 迷你音乐播放条：悬浮在底部导航上方，跨 Tab 显示
class MusicPlayerBar extends StatelessWidget {
  final AudioController audio;

  const MusicPlayerBar({super.key, required this.audio});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: audio,
      builder: (context, _) {
        if (!audio.ready && !audio.playing) {
          // 常驻入口：未播放时显示音乐播放器条，点击打开曲目列表
          return Material(
            color: AppColors.bgRaised,
            child: InkWell(
              onTap: () => _showTrackList(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.lineStrong),
                    bottom: BorderSide(color: AppColors.lineStrong),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.music_note,
                        color: AppColors.mustard, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocale.value == 'en'
                            ? 'Music Player'
                            : '音乐播放器',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cream,
                        ),
                      ),
                    ),
                    const Icon(Icons.play_circle,
                        color: AppColors.mustard, size: 26),
                  ],
                ),
              ),
            ),
          );
        }
        final track = audio.current;
        return Material(
          color: AppColors.bgRaised,
          child: InkWell(
            onTap: () => _showTrackList(context),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.lineStrong),
                  bottom: BorderSide(color: AppColors.lineStrong),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: AppColors.mustard, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.cream,
                          ),
                        ),
                        Text(
                          track.sub,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.creamFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // 播放按钮外围的转动光圈：轨道 + 随播放时间向前转动的光弧
                      CustomPaint(
                        size: const Size(42, 42),
                        painter: _ProgressRingPainter(
                          progress: audio.progress,
                          playing: audio.playing,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          audio.playing
                              ? Icons.pause_circle
                              : Icons.play_circle,
                          color: AppColors.mustard,
                          size: 30,
                        ),
                        onPressed: audio.toggle,
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next,
                        color: AppColors.creamDim, size: 22),
                    onPressed: audio.next,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.creamFaint, size: 18),
                    onPressed: audio.stop,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTrackList(BuildContext context) {
    final scrollCtrl = ScrollController();
    const itemH = 72.0; // ListTile 两行固定高度
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // 打开时自动滚动到当前播放的曲目
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (audio.ready && scrollCtrl.hasClients) {
            final pos = (audio.index * itemH) - 100;
            scrollCtrl.animateTo(
              pos.clamp(0, scrollCtrl.position.maxScrollExtent),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        });
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  AppLocale.value == 'en' ? 'Music Player' : '音乐播放器',
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Flexible(
                child: ListenableBuilder(
                  listenable: audio,
                  builder: (context, _) => ListView.builder(
                    controller: scrollCtrl,
                    itemExtent: itemH,
                    shrinkWrap: true,
                    itemCount: MusicTracks.list.length,
                    itemBuilder: (context, i) {
                      final active = audio.index == i;
                      return ListTile(
                        leading: Icon(
                          active ? Icons.equalizer : Icons.music_note,
                          color:
                              active ? AppColors.mustard : AppColors.creamDim,
                        ),
                        title: Text(
                          MusicTracks.list[i].title,
                          style: TextStyle(
                            color:
                                active ? AppColors.mustard : AppColors.cream,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                        subtitle: Text(
                          MusicTracks.list[i].sub,
                          style: const TextStyle(color: AppColors.creamFaint),
                        ),
                        trailing: active
                            ? IconButton(
                                icon: Icon(
                                  audio.playing
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: AppColors.mustard,
                                ),
                                onPressed: audio.toggle,
                              )
                            : null,
                        onTap: () {
                          audio.play(i);
                          // 点击后立刻滚动到该曲目，并即时高亮为正在播放
                          if (scrollCtrl.hasClients) {
                            final pos = (i * itemH) - 100;
                            scrollCtrl.animateTo(
                              pos.clamp(0, scrollCtrl.position.maxScrollExtent),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// 播放按钮外围的转动光圈：暗色轨道 + 随播放时间向前转动的光弧
class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final bool playing;

  _ProgressRingPainter({required this.progress, required this.playing});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    // 暗色轨道圆环
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.lineStrong.withValues(alpha: 0.85);
    canvas.drawCircle(center, radius, track);

    if (playing) {
      // 光圈主弧：从 12 点方向顺时针按播放进度扫过
      final sweep = progress.clamp(0.0, 1.0) * 2 * 3.1415926;
      final arc = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.mustard;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.1415926 / 2,
        sweep,
        false,
        arc,
      );

      // 弧头光点：跟随转动，强化"光圈在转"的感觉
      final angle = -3.1415926 / 2 + sweep;
      final head = Offset(
        center.dx + radius * 0.92 * cos(angle),
        center.dy + radius * 0.92 * sin(angle),
      );
      canvas.drawCircle(
        head,
        2.6,
        Paint()..color = AppColors.mustard.withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        head,
        5,
        Paint()..color = AppColors.mustard.withValues(alpha: 0.18),
      );
    }
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) =>
      old.progress != progress || old.playing != playing;
}
