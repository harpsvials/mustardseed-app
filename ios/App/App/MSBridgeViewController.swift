import UIKit
import Capacitor

/* 深绿主题 #16281C 作为 WKWebView 原生背景：
   页面导航/加载瞬间（CSS 尚未接管）显示深绿而非白色，彻底消除切导航白闪 */
class MSBridgeViewController: CAPBridgeViewController {

    private static let themeBackground = UIColor(
        red: 22.0 / 255.0, green: 40.0 / 255.0, blue: 28.0 / 255.0, alpha: 1.0
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let wv = self?.webView else { return }
            wv.backgroundColor = MSBridgeViewController.themeBackground
            if #available(iOS 15.0, *) {
                wv.underPageBackgroundColor = MSBridgeViewController.themeBackground
            }
            /* 保持不透明：导航期间用原生背景色渲染，避免露出窗口白底 */
            wv.isOpaque = true
        }
    }
}
