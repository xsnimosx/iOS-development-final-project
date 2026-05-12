//
//  ConversationListViewController.swift
//  Chatapp
//
//  Created by snimos on 2026/5/12.
//

import Foundation
import UIKit
import FirebaseAuth

class ConversationListViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
    }

    func setupUI() {
        let signOutButton = UIButton(type: .system)
        signOutButton.setTitle("登出", for: .normal)
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        signOutButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(signOutButton)
        NSLayoutConstraint.activate([
            signOutButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            signOutButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    @objc func signOutTapped() {
        do {
            try Auth.auth().signOut()
            // 登出成功，回到 LoginVC
            guard let window = view.window else { return }
            window.rootViewController = LoginViewController()
        } catch {
            print("登出失敗：\(error.localizedDescription)")
        }
    }
}
