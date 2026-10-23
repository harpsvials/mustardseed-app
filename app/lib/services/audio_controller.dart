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
    Track(
      title: '点燃 / Rest On Us · Holy Spirit',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl01_RestOnUs.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl01_RestOnUs.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl01_RestOnUs.mp3',
      ],
    ),
    Track(
      title: 'GO',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl02_GO.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl02_GO.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl02_GO.mp3',
      ],
    ),
    Track(
      title: '大山你算什么',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl03_Dashan.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl03_Dashan.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl03_Dashan.mp3',
      ],
    ),
    Track(
      title: 'Every Giant Will Fall',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl04_GiantWillFall.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl04_GiantWillFall.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl04_GiantWillFall.mp3',
      ],
    ),
    Track(
      title: 'Echoes',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl05_Echoes.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl05_Echoes.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl05_Echoes.mp3',
      ],
    ),
    Track(
      title: 'Last Battle',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl06_LastBattle.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl06_LastBattle.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl06_LastBattle.mp3',
      ],
    ),
    Track(
      title: '大声敬拜',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl07_Dasheng.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl07_Dasheng.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl07_Dasheng.mp3',
      ],
    ),
    Track(
      title: '我们是神军队 / Upside Down',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl08_GodsArmy.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl08_GodsArmy.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl08_GodsArmy.mp3',
      ],
    ),
    Track(
      title: '满有能力',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl09_FullPower.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl09_FullPower.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl09_FullPower.mp3',
      ],
    ),
    Track(
      title: '将天敞开',
      sub: '2026 吉隆坡烈火特会',
      asset: 'music/kl10_OpenHeaven.mp3',
      urls: [
        'https://raw.githubusercontent.com/harpsvials/mustardseed-app/main/mp3/kl10_OpenHeaven.mp3',
        'https://cdn.jsdelivr.net/gh/harpsvials/mustardseed-app@main/mp3/kl10_OpenHeaven.mp3',
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
