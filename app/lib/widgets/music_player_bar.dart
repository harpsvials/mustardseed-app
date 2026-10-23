import 'package:flutter/material.dart';
import '../theme.dart';
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
          return const SizedBox.shrink();
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
                  IconButton(
                    icon: Icon(
                      audio.playing ? Icons.pause_circle : Icons.play_circle,
                      color: AppColors.mustard,
                      size: 30,
                    ),
                    onPressed: audio.toggle,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                '音乐播放器',
                style: TextStyle(
                  color: AppColors.cream,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            for (var i = 0; i < MusicTracks.list.length; i++)
              ListTile(
                leading: Icon(
                  audio.index == i ? Icons.equalizer : Icons.music_note,
                  color: audio.index == i
                      ? AppColors.mustard
                      : AppColors.creamDim,
                ),
                title: Text(
                  MusicTracks.list[i].title,
                  style: TextStyle(
                    color: audio.index == i
                        ? AppColors.mustard
                        : AppColors.cream,
                    fontWeight:
                        audio.index == i ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  MusicTracks.list[i].sub,
                  style: const TextStyle(color: AppColors.creamFaint),
                ),
                trailing: audio.index == i
                    ? IconButton(
                        icon: Icon(
                          audio.playing ? Icons.pause : Icons.play_arrow,
                          color: AppColors.mustard,
                        ),
                        onPressed: audio.toggle,
                      )
                    : null,
                onTap: () => audio.play(i),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
