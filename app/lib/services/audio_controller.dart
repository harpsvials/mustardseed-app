import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// 曲目（GitHub raw 直链 + jsDelivr 备源）
class Track {
  final String title;
  final String sub;
  final List<String> urls;

  const Track({required this.title, required this.sub, required this.urls});
}

class MusicTracks {
  static const list = [
    Track(
      title: 'Alleluia',
      sub: '芥菜种教会',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/Alleluia.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/Alleluia.mp3',
      ],
    ),
    Track(
      title: 'Healing In Your Presence',
      sub: '芥菜种教会',
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
    _player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      notifyListeners();
    });
  }

  Future<void> play(int index) async {
    if (index != _index) {
      _index = index;
      await _player.stop();
      var ok = false;
      for (final url in current.urls) {
        try {
          await _player.play(UrlSource(url));
          ok = true;
          break;
        } catch (_) {}
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
