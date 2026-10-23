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
