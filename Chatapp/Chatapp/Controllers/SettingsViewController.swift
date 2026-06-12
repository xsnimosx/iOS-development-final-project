//
//  SettingsViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth

class SettingsViewController: UITableViewController {

    // MARK: - IBOutlets（靜態 cell，直接用 tag 或在 Xcode Identity Inspector 中連接）
    // 個人資料區塊（section 0, row 0）
    // 用 tag 取得 label（或手動加 IBOutlet）：
    // - 用戶名稱 label（id: hWX-Tl-iGU）
    // - Email label（id: irl-s8-Ua7）

    override func viewDidLoad() {
        super.viewDidLoad()
        updateProfileCell()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateProfileCell()
    }

    private func updateProfileCell() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // 如果有連接 IBOutlet 的 label，在這裡更新
        // 範例：nameLabel.text = ...
        // 暫時用 section header 顯示
        _ = uid
    }

    // MARK: - Table view delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // section 3（登出按鈕區塊），row 0 → 登出
        // 登出 segue 已在 storyboard 中設定（segue id: jky-Uc-sic → LoginVC）
        // 若需要在登出前做清除，覆寫 shouldPerformSegue
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        // 當按下登出 cell 時，先執行登出再允許 segue
        if identifier == "toLogin" {
            do {
                try Auth.auth().signOut()
            } catch {
                showAlert("登出失敗：\(error.localizedDescription)")
                return false
            }
        }
        return true
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "確定", style: .default))
        present(alert, animated: true)
    }
}
