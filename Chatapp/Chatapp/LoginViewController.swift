//
//  LoginViewController.swift
//  Chatapp
//
//  Created by snimos on 2026/5/12.
//

import Foundation
import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {

    let emailField = UITextField()
    let passwordField = UITextField()
    let segmentedControl = UISegmentedControl(items: ["登入", "註冊"])
    let actionButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
    }

    func setupUI() {
        emailField.placeholder = "Email"
        emailField.borderStyle = .roundedRect
        emailField.autocapitalizationType = .none

        passwordField.placeholder = "密碼"
        passwordField.borderStyle = .roundedRect
        passwordField.isSecureTextEntry = true

        segmentedControl.selectedSegmentIndex = 0

        actionButton.setTitle("登入", for: .normal)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [segmentedControl, emailField, passwordField, actionButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 300)
        ])
    }

    @objc func actionTapped() {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            print("請填寫 Email 和密碼")
            return
        }

        if segmentedControl.selectedSegmentIndex == 0 {
            // 登入
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    print("登入失敗：\(error.localizedDescription)")
                    return
                }
                print("登入成功：\(result?.user.email ?? "")")
                guard let window = self.view.window else { return }
                window.rootViewController = ConversationListViewController()
            }
        } else {
            // 註冊
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    print("註冊失敗：\(error.localizedDescription)")
                    return
                }
                print("註冊成功：\(result?.user.email ?? "")")
                guard let window = self.view.window else { return }
                window.rootViewController = ConversationListViewController()
            }
        }
    }	
}
