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

/// 全局数据控制器：内置数据立即可用，GitHub 远程版本成功后热替换
class AppDataController extends ChangeNotifier {
  AppData? _data;
  bool _usingRemote = false;

  AppData? get data => _data;
  bool get usingRemote => _usingRemote;

  Future<void> init() async {
    _data = await AppData.loadBuiltIn();
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
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _controller.init();
    AppLocale.current.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    AppLocale.current.removeListener(() => setState(() {}));
    _controller.dispose();
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
  final bool usingRemote;
  final int tab;
  final ValueChanged<int> onTab;

  const _Shell({
    required this.data,
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
          child: Icon(Icons.spa, color: AppColors.mustard, size: 26),
        ),
        actions: [
          _LangButton(data: data),
          const SizedBox(width: 6),
        ],
      ),
      body: IndexedStack(index: tab, children: pages),
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
