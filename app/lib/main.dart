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
          child: _AppLogo(size: 22),
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
      'guestbook' => Icons.mail_outlined,
      'prayer' => Icons.add_box_outlined,
      _ => Icons.circle,
    };
    final IconData activeIcon = switch (key) {
      'home' => Icons.home,
      'sermons' => Icons.menu_book,
      'testimonies' => Icons.favorite,
      'discussion' => Icons.forum,
      'guestbook' => Icons.mail,
      'prayer' => Icons.add_box,
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
class _AppLogo extends StatelessWidget {
  final double size;
  const _AppLogo({this.size = 26});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
