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
    var otherUID: String = ""
    private var messages: [Message] = []
    private var listener: ListenerRegistration?
    private var currentUserName: String = ""
    private var visibleTimestampRow: Int? = nil

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        tableView.separatorStyle = .none
        messageTextField.placeholder = NSLocalizedString("chat.message.placeholder", comment: "")
        fetchCurrentUserName()
        startListening()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        setupKeyboardDismissOnTap()
        messageTextField.autocapitalizationType = .sentences
        messageTextField.returnKeyType = .send
        messageTextField.textContentType = .none
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let uid = Auth.auth().currentUser?.uid, !conversationId.isEmpty else { return }
        db.collection("conversations").document(conversationId)
            .updateData(["unreadCounts.\(uid)": 0])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Now that the thread is actually on screen, flag the messages we received
        // as read so the sender sees "已讀". Guarded by view.window inside the method.
        markIncomingAsReadIfVisible()
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
                    // New message arrived while we're looking: flag any received ones read.
                    self.markIncomingAsReadIfVisible()
                }
            }
    }

    private func scrollToBottom() {
        guard !messages.isEmpty else { return }
        tableView.scrollToRow(at: IndexPath(row: messages.count - 1, section: 0), at: .bottom, animated: true)
    }

    /// Marks the messages we received from the other party as read, in one batch.
    /// Only fires while the thread is actually on screen (view.window != nil), so we
    /// never flag messages the user hasn't seen. Self-terminating: the resulting write
    /// re-triggers the listener, but the second pass finds no unread and bails.
    private func markIncomingAsReadIfVisible() {
        guard isViewLoaded, view.window != nil, !otherUID.isEmpty else { return }
        let unread = messages.filter { $0.senderId == otherUID && !$0.isRead }
        guard !unread.isEmpty else { return }
        let batch = db.batch()
        let base = db.collection("conversations").document(conversationId).collection("messages")
        for m in unread {
            if let id = m.id { batch.updateData(["isRead": true], forDocument: base.document(id)) }
        }
        batch.commit()
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
        let isOwn = message.senderId == Auth.auth().currentUser?.uid
        // Messenger-style grouping: head a run with the sender's name, then hide it on the
        // following messages from the same sender. Comparing senderName too means a nickname
        // change mid-run starts a fresh group (and re-shows the new name).
        let prev = indexPath.row > 0 ? messages[indexPath.row - 1] : nil
        let showSenderName = prev == nil
            || prev!.senderId != message.senderId
            || prev!.senderName != message.senderName
        cell.configure(with: message, isOwn: isOwn, showSenderName: showSenderName, showTimestamp: indexPath.row == visibleTimestampRow)
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

            // Spring the timestamp reveal: keep the live cells, change their target
            // state, then let performBatchUpdates(nil) re-measure the self-sizing rows.
            // Wrapping it in a spring UIView.animate makes the row-height delta (and the
            // label alpha) interpolate with the bounce. Off-screen rows have no cell to
            // animate; visibleTimestampRow + cellForRowAt set them right when scrolled back.
            UIView.animate(withDuration: 0.45, delay: 0,
                           usingSpringWithDamping: 0.75, initialSpringVelocity: 0.6,
                           options: [.curveEaseOut, .allowUserInteraction]) {
                if let cell = tableView.cellForRow(at: indexPath) as? MessageCell {
                    cell.setTimestampVisible(self.visibleTimestampRow == indexPath.row)
                }
                if let p = prev, p != indexPath.row,
                   let prevCell = tableView.cellForRow(at: IndexPath(row: p, section: 0)) as? MessageCell {
                    prevCell.setTimestampVisible(false)
                }
                tableView.performBatchUpdates(nil)
            }
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
