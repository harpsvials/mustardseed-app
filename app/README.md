# mustardseed_app

芥菜种教会 App（Flutter），支持 Android、iOS 与 macOS。

## macOS 构建

环境要求：Xcode、Flutter，插件依赖 CocoaPods。

```bash
export PATH="/Users/wangxiaodong/.gem/ruby/2.6.0/bin:$PATH"
export RUBYOPT="-rlogger"   # 系统 Ruby 2.6 下运行 CocoaPods 需要
flutter pub get
flutter build macos --release --build-name=v2026.11.24.0949 --build-number=202611240949
```

产物：`build/macos/Build/Products/Release/mustardseed_app.app`

打包 DMG 时，把 `.app` 与指向 `/Applications` 的快捷方式放入同一目录，再用 `hdiutil create` 生成压缩镜像。

## 桌面版说明

- 窗口默认 1200×820，最小 960×640，首页在宽屏下自动改为三列。
- 通知、音乐播放、讲道朗读均已接入 macOS 对应能力。
- 桌面版随安装包整体更新，不提供 Android 的 APK 应用内更新入口。
