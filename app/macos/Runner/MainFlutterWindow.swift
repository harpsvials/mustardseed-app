import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // 桌面端默认给内容留出舒展空间，同时避免缩到手机尺寸后布局拥挤
    self.setContentSize(NSSize(width: 1200, height: 820))
    self.minSize = NSSize(width: 960, height: 640)
    self.center()
    self.title = "芥菜种教会"
    self.setFrame(self.frame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
