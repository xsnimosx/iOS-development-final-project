//
//  LoginViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var loginButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        applyBrandStyling()
        segmentedControl.setTitle(NSLocalizedString("login.segment.signIn", comment: ""), forSegmentAt: 0)
        segmentedControl.setTitle(NSLocalizedString("login.segment.signUp", comment: ""), forSegmentAt: 1)
        emailField.placeholder = NSLocalizedString("login.field.email", comment: "")
        passwordField.placeholder = NSLocalizedString("login.field.password", comment: "")
        loginButton.setTitle(NSLocalizedString("login.button.title", comment: ""), for: .normal)
        if Auth.auth().currentUser != nil {
            navigateToMainApp()
        }
        setupKeyboardDismissOnTap()
    }

    private func applyBrandStyling() {
        view.backgroundColor = UIColor(named: "AccentColor")
        for field in [emailField, passwordField] {
            guard let field else { continue }
            field.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
            field.layer.cornerRadius = 10
            field.layer.masksToBounds = true
            field.borderStyle = .none
            field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
            field.leftViewMode = .always
        }
    }

    // MARK: - IBAction
    // 在 Xcode 中 ctrl-drag 從 LOGIN 按鈕連接到這裡
    @IBAction func loginButtonTapped(_ sender: UIButton) {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showAlert(NSLocalizedString("login.error.emptyFields", comment: ""))
            return
        }

        if segmentedControl.selectedSegmentIndex == 0 {
            Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
                if let error = error {
                    self?.showAlert(String(format: NSLocalizedString("login.error.signInFailed", comment: ""), error.localizedDescription))
                    return
                }
                self?.navigateToMainApp()
            }
        } else {
            Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
                if let error = error {
                    self?.showAlert(String(format: NSLocalizedString("login.error.registerFailed", comment: ""), error.localizedDescription))
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
            alert.addAction(UIAlertAction(title: NSLocalizedString("login.alert.ok", comment: ""), style: .default))
            self.present(alert, animated: true)
        }
    }
}
