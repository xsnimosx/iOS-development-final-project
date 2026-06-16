import UIKit

/// 無狀態的 tap-gesture delegate:只讓「點背景」的 tap 觸發收鍵盤。落在 UIControl
/// (輸入框、按鈕、分段控制、開關…)或 UITableViewCell(可操作的列)內的點擊一律
/// 放行,不收鍵盤;其餘視為背景。
///
/// 因為完全無狀態(只看 `touch.view`,不依賴任何 controller),全 App 共用單一
/// 實例即可:UITapGestureRecognizer 對 delegate 是 weak reference,而此單例由
/// static 屬性持有、生命週期等同 App,所以不會被釋放,也不需 associated object。
final class BackgroundTapKeyboardDismissDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = BackgroundTapKeyboardDismissDelegate()

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        // 沿 superview chain 往上找:命中的常是控制元件的內部子 view,而非元件本身。
        // 凡落在 UIControl 或 UITableViewCell 內就放行(不收鍵盤),其餘視為背景。
        var node: UIView? = touch.view
        while let current = node {
            if current is UIControl || current is UITableViewCell { return false }
            node = current.superview
        }
        return true
    }
}

extension UIViewController {
    /// 點背景收鍵盤,點互動元件(含表格列)不收。對應登入頁已驗證的行為,可全 App 復用。
    func setupKeyboardDismissOnBackgroundTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = BackgroundTapKeyboardDismissDelegate.shared
        view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() { view.endEditing(true) }
}
