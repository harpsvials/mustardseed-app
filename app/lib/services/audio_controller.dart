import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 曲目（内置 assets 优先，GitHub raw + jsDelivr 在线兜底）
class Track {
  final String title;
  final String sub;
  final String? asset; // 内置文件（相对 assets/ 目录）
  final List<String> urls;

  const Track({
    required this.title,
    required this.sub,
    this.asset,
    required this.urls,
  });
}

class MusicTracks {
  static const list = [
    Track(
      title: 'Alleluia',
      sub: '芥菜种教会',
      asset: 'music/Alleluia.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/Alleluia.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/Alleluia.mp3',
      ],
    ),
    Track(
      title: 'Healing In Your Presence',
      sub: '芥菜种教会',
      asset: 'music/Healing In Your Presence.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/Healing%20In%20Your%20Presence.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/Healing%20In%20Your%20Presence.mp3',
      ],
    ),
  ];
}

/// App 级音乐播放器：跨 Tab 续播
class AudioController extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  int _index = 0;
  bool _playing = false;
  bool _ready = false;

  int get index => _index;
  bool get playing => _playing;
  bool get ready => _ready;
  Track get current => MusicTracks.list[_index];

  AudioController() {
    // stop 模式下资源不释放，切歌/暂停后 resume 立即有声
    _player.setReleaseMode(ReleaseMode.stop);
    // 后台/锁屏播放：iOS 用 playback 音频会话，Android 保持媒体焦点
    _player.setAudioContext(AudioContext(
      iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
      android: AudioContextAndroid(
        audioFocus: AndroidAudioFocus.gain,
        isSpeakerphoneOn: false,
      ),
    ));
    _player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      notifyListeners();
    });
  }

  Future<void> play(int index) async {
    // 初始 _index=0：用户第一次点第一首时 index 与 _index 相同，
    // 但播放器尚未加载任何源，必须走完整加载流程，不能直接 resume
    if (index != _index || !_ready) {
      _index = index;
      await _player.stop();
      var ok = false;
      // 优先播内置文件，避免在线流卡顿；
      // 先 setSource 等待加载完成再 resume，保证首次播放立即出声
      if (current.asset != null) {
        try {
          await _player.setSource(AssetSource(current.asset!));
          await _player.resume();
          ok = true;
        } catch (_) {
          ok = false;
        }
      }
      if (!ok) {
        for (final url in current.urls) {
          try {
            await _player.setSource(UrlSource(url));
            await _player.resume();
            ok = true;
            break;
          } catch (_) {}
        }
      }
      _ready = ok;
    } else {
      await _player.resume();
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.resume();
      if (!_ready) await play(_index);
    }
    notifyListeners();
  }

  Future<void> next() async {
    await play((_index + 1) % MusicTracks.list.length);
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
    _ready = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
