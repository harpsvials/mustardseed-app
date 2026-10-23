import 'package:flutter/material.dart';
import 'theme.dart';
import 'i18n.dart';
import 'data/app_data.dart';
import 'pages/home_page.dart';
import 'pages/sermons_page.dart';
import 'pages/testimonies_page.dart';
import 'pages/discussion_page.dart';
import 'pages/guestbook_page.dart';
import 'pages/prayer_page.dart';
import 'services/audio_controller.dart';
import 'services/notice_fetcher.dart';
import 'services/update_checker.dart';
import 'widgets/music_player_bar.dart';

/// 全局数据控制器：内置数据立即可用，GitHub 远程版本成功后热替换
class AppDataController extends ChangeNotifier {
  AppData? _data;
  bool _usingRemote = false;

  AppData? get data => _data;
  bool get usingRemote => _usingRemote;

  Future<void> init() async {
    try {
      _data = await AppData.loadBuiltIn();
    } catch (_) {
      // 兜底：内置数据异常时用空数据渲染，避免启动卡在加载页
      _data = AppData.fromJson({});
    }
    notifyListeners();
    final remote = await AppData.fetchRemote();
    if (remote != null) {
      _data = remote;
      _usingRemote = true;
      notifyListeners();
    }
  }
}

void main() {
  runApp(const MustardSeedApp());
}

class MustardSeedApp extends StatefulWidget {
  const MustardSeedApp({super.key});

  @override
  State<MustardSeedApp> createState() => _MustardSeedAppState();
}

class _MustardSeedAppState extends State<MustardSeedApp> {
  final AppDataController _controller = AppDataController();
  final AudioController _audio = AudioController();
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _controller.init().then((_) => _checkStartupDialogs());
    AppLocale.current.addListener(() => setState(() {}));
  }

  Future<void> _checkStartupDialogs() async {
    // 等首帧稳定后依次弹：通知 → 更新
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await NoticeFetcher.showIfAny(context);
    if (!mounted) return;
    await UpdateChecker.showIfAny(context);
  }

  @override
  void dispose() {
    AppLocale.current.removeListener(() => setState(() {}));
    _controller.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mustardseed',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final data = _controller.data;
          if (data == null) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.mustard),
              ),
            );
          }
          return _Shell(
            data: data,
            audio: _audio,
            usingRemote: _controller.usingRemote,
            tab: _tab,
            onTab: (i) => setState(() => _tab = i),
          );
        },
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  final AppData data;
  final AudioController audio;
  final bool usingRemote;
  final int tab;
  final ValueChanged<int> onTab;

  const _Shell({
    required this.data,
    required this.audio,
    required this.usingRemote,
    required this.tab,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(data: data),
      SermonsPage(data: data),
      TestimoniesPage(data: data),
      DiscussionPage(data: data),
      GuestbookPage(data: data),
      PrayerPage(data: data),
    ];
    final titles = [
      AppLocale.t(data.nav['home'] as Map? ?? {'zh': '主页', 'en': 'Home'}),
      AppLocale.t(data.nav['sermons'] as Map? ?? {'zh': '讲道', 'en': 'Sermons'}),
      AppLocale.t(data.nav['testimonies'] as Map? ?? {'zh': '见证', 'en': 'Testimonies'}),
      AppLocale.t(data.nav['discussion'] as Map? ?? {'zh': '讨论', 'en': 'Discussion'}),
      AppLocale.t(data.nav['guestbook'] as Map? ?? {'zh': '留言', 'en': 'Guestbook'}),
      AppLocale.t(data.nav['prayer'] as Map? ?? {'zh': '祷告墙', 'en': 'Prayer Wall'}),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab]),
        leading: const Padding(
          padding: EdgeInsets.only(left: 14),
          child: SeedlingLogo(size: 26),
        ),
        actions: [
          _LangButton(data: data),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: IndexedStack(index: tab, children: pages)),
          MusicPlayerBar(audio: audio),
        ],
      ),
      bottomNavigationBar: _BottomNav(tab: tab, onTab: onTab, data: data),
    );
  }
}

class _LangButton extends StatelessWidget {
  final AppData data;
  const _LangButton({required this.data});

  @override
  Widget build(BuildContext context) {
    final isZh = AppLocale.value == AppLocale.zh;
    return TextButton(
      onPressed: () {
        AppLocale.set(isZh ? AppLocale.en : AppLocale.zh);
      },
      child: Text(
        isZh ? 'EN' : '中文',
        style: const TextStyle(
          color: AppColors.mustard,
          fontWeight: FontWeight.w600,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onTab;
  final AppData data;

  const _BottomNav({required this.tab, required this.onTab, required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _navItem('home'),
      _navItem('sermons'),
      _navItem('testimonies'),
      _navItem('discussion'),
      _navItem('guestbook'),
      _navItem('prayer'),
    ];
    return BottomNavigationBar(
      currentIndex: tab,
      onTap: onTab,
      items: items,
    );
  }

  BottomNavigationBarItem _navItem(String key) {
    final map = data.nav[key] as Map? ?? {};
    var label = AppLocale.t(map);
    if (label.isEmpty) {
      label = {'zh': '主页', 'en': 'Home'}[AppLocale.value] ?? '';
    }
    final IconData icon = switch (key) {
      'home' => Icons.home_outlined,
      'sermons' => Icons.menu_book_outlined,
      'testimonies' => Icons.favorite_border,
      'discussion' => Icons.forum_outlined,
      'guestbook' => Icons.edit_outlined,
      'prayer' => Icons.front_hand_outlined,
      _ => Icons.circle,
    };
    final IconData activeIcon = switch (key) {
      'home' => Icons.home,
      'sermons' => Icons.menu_book,
      'testimonies' => Icons.favorite,
      'discussion' => Icons.forum,
      'guestbook' => Icons.edit,
      'prayer' => Icons.front_hand,
      _ => Icons.circle,
    };
    return BottomNavigationBarItem(
      icon: Icon(icon),
      activeIcon: Icon(activeIcon),
      label: label,
    );
  }
}

/// 小嫩苗 logo（与启动图标一致的幼苗样式，无底部弧线）
class SeedlingLogo extends StatelessWidget {
  final double size;
  const SeedlingLogo({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SeedlingPainter(AppColors.sprout),
    );
  }
}

class _SeedlingPainter extends CustomPainter {
  final Color color;
  const _SeedlingPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final stem = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round;

    // 茎：从底部向上到叶分叉点
    canvas.drawLine(Offset(w * .5, h * .86), Offset(w * .5, h * .46), stem);

    // 左叶：从茎部向左上方展开的嫩叶
    final left = Path()
      ..moveTo(w * .5, h * .62)
      ..quadraticBezierTo(w * .12, h * .64, w * .14, h * .30)
      ..quadraticBezierTo(w * .36, h * .38, w * .5, h * .46)
      ..close();
    canvas.drawPath(left, fill);

    // 右叶：从茎部向右上方展开的嫩叶
    final right = Path()
      ..moveTo(w * .5, h * .46)
      ..quadraticBezierTo(w * .66, h * .36, w * .86, h * .14)
      ..quadraticBezierTo(w * .92, h * .42, w * .5, h * .60)
      ..close();
    canvas.drawPath(right, fill);

    // 顶芽：小叶尖上的圆点
    canvas.drawCircle(Offset(w * .88, h * .13), w * .045, fill);
  }

  @override
  bool shouldRepaint(_SeedlingPainter oldDelegate) =>
      oldDelegate.color != color;
}
