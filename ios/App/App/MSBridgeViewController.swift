import UIKit
import Capacitor

/* 深绿主题 #16281C：根视图直接铺深绿，WKWebView 设为透明，
   页面导航间隙（旧页卸载、新页 CSS 未接管）及滚动弹跳区域都露出根视图的深绿，
   从根源消除切换导航白闪 */
class MSBridgeViewController: CAPBridgeViewController {

    private static let themeBackground = UIColor(
        red: 22.0 / 255.0, green: 40.0 / 255.0, blue: 28.0 / 255.0, alpha: 1.0
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        /* 根视图立即铺深绿（不依赖 webView 是否已创建） */
        self.view.backgroundColor = MSBridgeViewController.themeBackground

        DispatchQueue.main.async { [weak self] in
            guard let wv = self?.webView else { return }
            wv.isOpaque = false
            wv.backgroundColor = UIColor.clear
            wv.scrollView.backgroundColor = UIColor.clear
            if #available(iOS 15.0, *) {
                wv.underPageBackgroundColor = UIColor.clear
            }
        }
    }
}
