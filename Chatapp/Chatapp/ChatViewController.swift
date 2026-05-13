//
//  ChatViewController.swift
//  Chatapp
//
//  Created by snimos on 2026/5/13.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore

class ChatViewController: UIViewController {

    let messageField = UITextField()
    let sendButton = UIButton(type: .system)
    let db = Firestore.firestore()
    
    // 暫時寫死，之後由 ConversationListVC 傳進來
    let conversationId = "test-conversation"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
    }

    func setupUI() {
        messageField.placeholder = "輸入訊息"
        messageField.borderStyle = .roundedRect
        
        sendButton.setTitle("傳送", for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [messageField, sendButton])
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

    @objc func sendTapped() {
        guard let content = messageField.text, !content.isEmpty,
              let senderId = Auth.auth().currentUser?.uid else {
            print("訊息為空或未登入")
            return
        }

        let message: [String: Any] = [
            "conversationId": conversationId,
            "senderId": senderId,
            "content": content,
            "type": "text",
            "timestamp": Timestamp(date: Date())
        ]

        db.collection("conversations").document(conversationId)
          .collection("messages").addDocument(data: message) { error in
            if let error = error {
                print("傳送失敗：\(error)")
            } else {
                print("傳送成功")
                self.messageField.text = ""
            }
        }
    }
}
