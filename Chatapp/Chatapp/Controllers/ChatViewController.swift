//
//  ChatViewController.swift
//  Chatapp
//
//  Created by snimos on 2026/5/13.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ChatViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private let tableView = UITableView()
    private let inputContainer = UIView()
    private let messageField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let imageButton = UIButton(type: .system)

    private let db = Firestore.firestore()
    var conversationId = "test-conversation"

    private var messages: [Message] = []
    private var listener: ListenerRegistration?
    private var currentUserName: String = ""
    private var inputBottomConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "聊天室"
        setupUI()
        fetchCurrentUserName()
        startListening()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func setupUI() {
        setupTableView()
        setupInputBar()
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }

    private func setupInputBar() {
        inputContainer.backgroundColor = .secondarySystemBackground
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainer)

        messageField.placeholder = "輸入訊息..."
        messageField.borderStyle = .roundedRect
        messageField.translatesAutoresizingMaskIntoConstraints = false

        sendButton.setTitle("傳送", for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        imageButton.setImage(UIImage(systemName: "photo"), for: .normal)
        imageButton.addTarget(self, action: #selector(pickImageTapped), for: .touchUpInside)
        imageButton.translatesAutoresizingMaskIntoConstraints = false

        inputContainer.addSubview(imageButton)
        inputContainer.addSubview(messageField)
        inputContainer.addSubview(sendButton)

        let bottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        inputBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            inputContainer.heightAnchor.constraint(equalToConstant: 56),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),

            imageButton.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 8),
            imageButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            imageButton.widthAnchor.constraint(equalToConstant: 36),

            messageField.leadingAnchor.constraint(equalTo: imageButton.trailingAnchor, constant: 4),
            messageField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            messageField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 56)
        ])
    }

    // MARK: - Data

    private func fetchCurrentUserName() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).getDocument { [weak self] snapshot, _ in
            if let data = snapshot?.data(), let name = data["displayName"] as? String {
                self?.currentUserName = name
            }
        }
    }

    private func startListening() {
        listener = db.collection("conversations").document(conversationId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, error == nil, let docs = snapshot?.documents else { return }
                self.messages = docs.compactMap { try? $0.data(as: Message.self) }
                LocalCacheManager.shared.saveMessages(self.messages, forConversation: self.conversationId)
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.scrollToBottom()
                }
            }
    }

    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    // MARK: - Image

    @objc private func pickImageTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let uid = Auth.auth().currentUser?.uid else { return }
        imageButton.isEnabled = false
        ImageUploadManager.shared.uploadImage(image) { [weak self] urlString in
            guard let self = self else { return }
            DispatchQueue.main.async { self.imageButton.isEnabled = true }
            guard let urlString = urlString else { return }
            let data: [String: Any] = [
                "senderId": uid,
                "senderName": self.currentUserName,
                "content": "",
                "type": "image",
                "imageURL": urlString,
                "timestamp": Timestamp(date: Date()),
                "isRead": false
            ]
            self.db.collection("conversations").document(self.conversationId)
                .collection("messages").addDocument(data: data)
        }
    }

    // MARK: - Keyboard

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        let safeBottom = view.safeAreaInsets.bottom
        inputBottomConstraint?.constant = -(keyboardFrame.height - safeBottom)
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
        scrollToBottom()
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        inputBottomConstraint?.constant = 0
        UIView.animate(withDuration: duration) { self.view.layoutIfNeeded() }
    }

    // MARK: - Actions

    @objc private func sendTapped() {
        guard let content = messageField.text, !content.isEmpty,
              let uid = Auth.auth().currentUser?.uid else { return }

        let data: [String: Any] = [
            "senderId": uid,
            "senderName": currentUserName,
            "content": content,
            "type": "text",
            "timestamp": Timestamp(date: Date()),
            "isRead": false
        ]

        db.collection("conversations").document(conversationId)
            .collection("messages").addDocument(data: data) { [weak self] error in
                if error == nil {
                    DispatchQueue.main.async { self?.messageField.text = "" }
                }
            }
    }

    private func deleteMessage(_ message: Message) {
        guard let id = message.id else { return }
        db.collection("conversations").document(conversationId)
            .collection("messages").document(id).delete()
    }
}

// MARK: - UITableViewDataSource

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseId, for: indexPath) as! MessageCell
        let message = messages[indexPath.row]
        let isOwn = message.senderId == Auth.auth().currentUser?.uid
        cell.configure(with: message, isOwn: isOwn)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ChatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let message = messages[indexPath.row]
        guard message.type == "image", message.imageURL != nil else { return }
        let preview = MediaPreviewViewController()
        preview.imageURL = message.imageURL
        preview.modalPresentationStyle = .fullScreen
        present(preview, animated: true)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let message = messages[indexPath.row]
        guard message.senderId == Auth.auth().currentUser?.uid else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let delete = UIAction(title: "刪除", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteMessage(message)
            }
            return UIMenu(title: "", children: [delete])
        }
    }
}

// MARK: - MessageCell

class MessageCell: UITableViewCell {
    static let reuseId = "MessageCell"

    private let bubbleView = UIView()
    private let nameLabel = UILabel()
    private let contentLabel = UILabel()
    private let msgImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        bubbleView.layer.cornerRadius = 12
        bubbleView.clipsToBounds = true
        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .secondaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        contentLabel.numberOfLines = 0
        contentLabel.font = .systemFont(ofSize: 15)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        msgImageView.contentMode = .scaleAspectFill
        msgImageView.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.addSubview(nameLabel)
        bubbleView.addSubview(contentLabel)
        bubbleView.addSubview(msgImageView)
        contentView.addSubview(bubbleView)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),

            contentLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            contentLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            contentLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -6),

            msgImageView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            msgImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            msgImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            msgImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            msgImageView.heightAnchor.constraint(equalToConstant: 180),

            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.72)
        ])
    }

    private var bubbleLeading: NSLayoutConstraint?
    private var bubbleTrailing: NSLayoutConstraint?

    func configure(with message: Message, isOwn: Bool) {
        let isImage = message.type == "image"

        nameLabel.isHidden = isOwn || isImage
        nameLabel.text = isOwn ? nil : message.senderName

        contentLabel.isHidden = isImage
        contentLabel.text = isImage ? nil : message.content

        msgImageView.isHidden = !isImage
        msgImageView.image = nil

        if isImage, let urlString = message.imageURL, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { self?.msgImageView.image = img }
            }.resume()
        }

        bubbleView.backgroundColor = isOwn ? .systemBlue : .secondarySystemFill
        contentLabel.textColor = isOwn ? .white : .label
        nameLabel.textColor = isOwn ? .white : .secondaryLabel

        bubbleLeading?.isActive = false
        bubbleTrailing?.isActive = false

        if isOwn {
            bubbleTrailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
            bubbleTrailing?.isActive = true
        } else {
            bubbleLeading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
            bubbleLeading?.isActive = true
        }
    }
}
