//
//  LoginViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController {

    // MARK: - IBOutlets
    // 在 Xcode 中 ctrl-drag 從 Storyboard 元素連接到這裡
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - IBAction
    // 在 Xcode 中 ctrl-drag 從 LOGIN 按鈕連接到這裡
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showAlert("請填寫 Email 和密碼")
            return
        }

        if segmentedControl.selectedSegmentIndex == 0 {
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
                if let error = error {
                    self?.showAlert("登入失敗：\(error.localizedDescription)")
                    return
                }
                self?.navigateToMainApp()
            }
        } else {
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
                if let error = error {
                    self?.showAlert("註冊失敗：\(error.localizedDescription)")
                    return
                }
                guard let uid = result?.user.uid else { return }
                Firestore.firestore().collection("users").document(uid).setData([
                    "email": email,
                    "displayName": email
                ])
                self?.navigateToMainApp()
            }
        }
    }

    private func navigateToMainApp() {
        DispatchQueue.main.async {
            // 使用 storyboard 的 segue（名稱 "toMainApp"），
            // 需要在 Xcode 把 ViewController → TabBarController 的 segue 命名為 "toMainApp"
            self.performSegue(withIdentifier: "toMainApp", sender: nil)
        }
    }

    private func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "確定", style: .default))
            self.present(alert, animated: true)
        }
    }
}
