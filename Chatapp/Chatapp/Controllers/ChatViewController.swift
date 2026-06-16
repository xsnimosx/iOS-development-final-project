//
//  ChatViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class ChatViewController: UIViewController,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate,
    UITextViewDelegate {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var messageTextView: UITextView!
    @IBOutlet weak var inputBottomConstraint: NSLayoutConstraint!

    // MARK: - IBActions
    @IBAction func sendButtonTapped(_ sender: UIButton) { sendTapped() }
    @IBAction func imageButtonTapped(_ sender: UIButton) { pickImageTapped() }

    // MARK: - Properties
    private let db = Firestore.firestore()
    var conversationId: String = ""
    var otherUID: String = ""
    private var messages: [Message] = []
    private var listener: ListenerRegistration?
    private var currentUserName: String = ""
    private var visibleTimestampRow: Int? = nil
    private var textViewHeightConstraint: NSLayoutConstraint!
    private var isShowingPlaceholder = true
    private static let placeholderText = NSLocalizedString("chat.message.placeholder", comment: "")

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        tableView.separatorStyle = .none
        fetchCurrentUserName()
        startListening()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        setupKeyboardDismissOnTap()
        messageTextView.delegate = self
        messageTextView.textContentType = .none
        messageTextView.font = UIFont.systemFont(ofSize: 17)
        messageTextView.layer.cornerRadius = 10
        messageTextView.layer.borderColor = UIColor.separator.cgColor
        messageTextView.layer.borderWidth = 0.5
        messageTextView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        messageTextView.isScrollEnabled = false
        textViewHeightConstraint = messageTextView.constraints.first { $0.firstAttribute == .height }
        showPlaceholder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let uid = Auth.auth().currentUser?.uid, !conversationId.isEmpty else { return }
        db.collection("conversations").document(conversationId)
            .updateData(["unreadCounts.\(uid)": 0])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
        NotificationCenter.default.removeObserver(self)
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
        guard !isShowingPlaceholder,
              let raw = messageTextView.text,
              let uid = Auth.auth().currentUser?.uid else { return }
        let content = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
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
                DispatchQueue.main.async {
                    self.showPlaceholder()
                    self.resetTextViewHeight()
                }
                self.updateConversationMetadata(lastMessage: content)
            }
    }

    private func updateConversationMetadata(lastMessage: String) {
        guard !otherUID.isEmpty else { return }
        db.collection("conversations").document(conversationId)
            .updateData([
                "unreadCounts.\(otherUID)": FieldValue.increment(Int64(1)),
                "lastMessage": lastMessage,
                "lastUpdated": Timestamp(date: Date())
            ])
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
                    if error == nil { self?.updateConversationMetadata(lastMessage: "[圖片]") }
                }
        }
    }

    // MARK: - Placeholder
    private func showPlaceholder() {
        isShowingPlaceholder = true
        messageTextView.text = Self.placeholderText
        messageTextView.textColor = .placeholderText
    }

    private func clearPlaceholderIfNeeded() {
        guard isShowingPlaceholder else { return }
        isShowingPlaceholder = false
        messageTextView.text = ""
        messageTextView.textColor = .label
    }

    // MARK: - UITextViewDelegate
    func textViewDidBeginEditing(_ textView: UITextView) {
        clearPlaceholderIfNeeded()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showPlaceholder()
            resetTextViewHeight()
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isShowingPlaceholder else { return }
        let font = textView.font ?? UIFont.systemFont(ofSize: 17)
        let insets = textView.textContainerInset
        let maxH = font.lineHeight * 6 + insets.top + insets.bottom
        let fittingH = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .infinity)).height
        let newH = min(fittingH, maxH)
        textView.isScrollEnabled = fittingH > maxH
        guard abs(newH - textViewHeightConstraint.constant) > 0.5 else { return }
        textViewHeightConstraint.constant = newH
        UIView.animate(withDuration: 0.15) { self.view.layoutIfNeeded() }
    }

    private func resetTextViewHeight() {
        let font = messageTextView.font ?? UIFont.systemFont(ofSize: 17)
        let insets = messageTextView.textContainerInset
        textViewHeightConstraint.constant = font.lineHeight + insets.top + insets.bottom
        messageTextView.isScrollEnabled = false
        UIView.animate(withDuration: 0.15) { self.view.layoutIfNeeded() }
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
        cell.configure(with: message, isOwn: message.senderId == Auth.auth().currentUser?.uid, showTimestamp: indexPath.row == visibleTimestampRow)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ChatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let message = messages[indexPath.row]
        guard message.type == "image", message.imageURL != nil else {
            let prev = visibleTimestampRow
            visibleTimestampRow = (prev == indexPath.row) ? nil : indexPath.row
            var toReload = [indexPath]
            if let p = prev, p != indexPath.row {
                toReload.append(IndexPath(row: p, section: 0))
            }
            tableView.reloadRows(at: toReload, with: .automatic)
            return
        }
        let preview = MediaPreviewViewController()
        preview.imageURL = message.imageURL
        preview.modalPresentationStyle = .fullScreen
        present(preview, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let message = messages[indexPath.row]
        guard message.senderId == Auth.auth().currentUser?.uid else { return nil }
        let title = NSLocalizedString("chat.action.delete", comment: "")
        let action = UIContextualAction(style: .destructive, title: title) { [weak self] _, _, done in
            self?.deleteMessage(message)
            done(true)
        }
        action.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [action])
    }
}
