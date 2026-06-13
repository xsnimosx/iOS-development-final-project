//
//  ChatViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ChatViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageTextField: UITextField!
    @IBOutlet weak var inputBottomConstraint: NSLayoutConstraint!

    // MARK: - IBActions
    @IBAction func sendButtonTapped(_ sender: UIButton) { sendTapped() }
    @IBAction func imageButtonTapped(_ sender: UIButton) { pickImageTapped() }

    // MARK: - Properties
    private let db = Firestore.firestore()
    var conversationId: String = ""
    private var messages: [Message] = []
    private var listener: ListenerRegistration?
    private var currentUserName: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        tableView.separatorStyle = .none
        fetchCurrentUserName()
        startListening()
        setupKeyboardLayoutGuide()
        setupKeyboardDismissOnTap()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
    }

    // MARK: - Keyboard
    // Uses keyboardLayoutGuide (iOS 15+) instead of notification observers.
    // The guide's topAnchor equals safeArea.bottom when no keyboard is visible,
    // and tracks the keyboard top (with matching animation) when it appears.
    private func setupKeyboardLayoutGuide() {
        guard let inputContainer = inputBottomConstraint.firstItem as? UIView else { return }
        inputBottomConstraint.isActive = false
        inputContainer.bottomAnchor.constraint(
            equalTo: view.keyboardLayoutGuide.topAnchor
        ).isActive = true
    }

    private func setupKeyboardDismissOnTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
        tableView.scrollToRow(at: IndexPath(row: messages.count - 1, section: 0), at: .bottom, animated: true)
    }

    // MARK: - Actions
    private func sendTapped() {
        guard let content = messageTextField.text, !content.isEmpty,
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
                guard let self = self, error == nil else { return }
                DispatchQueue.main.async { self.messageTextField.text = "" }
                self.updateConversationMeta(lastMessage: content)
            }
    }

    private func pickImageTapped() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        guard let image = info[.originalImage] as? UIImage,
              let uid = Auth.auth().currentUser?.uid else { return }
        ImageUploadManager.shared.uploadImage(image) { [weak self] urlString in
            guard let self = self, let urlString = urlString else { return }
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
                .collection("messages").addDocument(data: data) { [weak self] error in
                    guard let self = self, error == nil else { return }
                    self.updateConversationMeta(lastMessage: "[Image]")
                }
        }
    }

    private func updateConversationMeta(lastMessage: String) {
        db.collection("conversations").document(conversationId)
            .updateData(["lastMessage": lastMessage, "lastUpdated": Timestamp(date: Date())])
    }


    private func deleteMessage(_ message: Message) {
        guard let id = message.id else { return }
        db.collection("conversations").document(conversationId)
            .collection("messages").document(id).delete()
    }
}

// MARK: - UITableViewDataSource
extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { messages.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseId, for: indexPath) as! MessageCell
        let message = messages[indexPath.row]
        cell.configure(with: message, isOwn: message.senderId == Auth.auth().currentUser?.uid)
        cell.onImageLoaded = { [weak self] in
            self?.tableView.beginUpdates()
            self?.tableView.endUpdates()
        }
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
            let delete = UIAction(title: NSLocalizedString("chat.action.delete", comment: ""), image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteMessage(message)
            }
            return UIMenu(title: "", children: [delete])
        }
    }
}

// MARK: - MessageCell
class MessageCell: UITableViewCell {
    static let reuseId = "MessageCell"
    private static let imageCache = NSCache<NSString, UIImage>()

    var onImageLoaded: (() -> Void)?

    private let bubbleView = UIView()
    private let nameLabel = UILabel()
    private let contentLabel = UILabel()
    private let msgImageView = UIImageView()

    private var imageHeightConstraint: NSLayoutConstraint?
    // Stored separately so it can be toggled off for image messages,
    // avoiding a Required-priority conflict with msgImageView.bottom = bubbleView.bottom.
    private var textBottomConstraint: NSLayoutConstraint?
    private var bubbleLeading: NSLayoutConstraint?
    private var bubbleTrailing: NSLayoutConstraint?

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

        bubbleLeading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        bubbleTrailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        textBottomConstraint = contentLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -6)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            contentLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            contentLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            msgImageView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            msgImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            msgImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            msgImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.72),
            bubbleLeading!
        ])
    }

    func configure(with message: Message, isOwn: Bool) {
        let isImage = message.type == "image"

        nameLabel.isHidden = isOwn || isImage
        nameLabel.text = isOwn ? nil : message.senderName
        contentLabel.isHidden = isImage
        contentLabel.text = isImage ? nil : message.content
        msgImageView.isHidden = !isImage
        msgImageView.image = nil

        textBottomConstraint?.isActive = !isImage
        imageHeightConstraint?.isActive = false

        if isImage {
            let maxWidth = max(contentView.bounds.width * 0.72 - 24, 160)
            imageHeightConstraint = msgImageView.heightAnchor.constraint(equalToConstant: 160)
            imageHeightConstraint?.isActive = true
            loadImage(urlString: message.imageURL, displayWidth: maxWidth)
        }

        bubbleView.backgroundColor = isOwn ? .systemBlue : .secondarySystemFill
        contentLabel.textColor = isOwn ? .white : .label
        nameLabel.textColor = isOwn ? .white : .secondaryLabel
        bubbleLeading?.isActive = !isOwn
        bubbleTrailing?.isActive = isOwn
    }

    private func loadImage(urlString: String?, displayWidth: CGFloat) {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        let key = urlString as NSString

        if let cached = MessageCell.imageCache.object(forKey: key) {
            applyImage(cached, displayWidth: displayWidth)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            MessageCell.imageCache.setObject(img, forKey: key)
            DispatchQueue.main.async {
                self?.applyImage(img, displayWidth: displayWidth)
                self?.onImageLoaded?()
            }
        }.resume()
    }

    private func applyImage(_ image: UIImage, displayWidth: CGFloat) {
        msgImageView.image = image
        let ratio = image.size.height / image.size.width
        imageHeightConstraint?.constant = min(displayWidth * ratio, 280)
    }
}
