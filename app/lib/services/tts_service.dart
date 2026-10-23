import 'package:flutter_tts/flutter_tts.dart';
import '../i18n.dart';

/// 讲道朗读（TTS），按当前语言选语音
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  bool get speaking => _speaking;

  Future<void> _configure() async {
    final isZh = AppLocale.value == AppLocale.zh;
    await _tts.setLanguage(isZh ? 'zh-CN' : 'en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  /// 朗读一段文本（stop 前会覆盖上一条）
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _configure();
    await _tts.stop();
    await _tts.speak(text.trim());
    _speaking = true;
  }

  /// 停止朗读
  Future<void> stop() async {
    await _tts.stop();
    _speaking = false;
  }
}
