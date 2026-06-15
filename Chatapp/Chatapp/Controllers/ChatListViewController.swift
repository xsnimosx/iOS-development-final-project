//
//  ChatListViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

struct Conversation {
    let id: String
    let otherUserID: String
    let otherUserName: String
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int
}

class ChatListViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!

    private var conversations: [Conversation] = []
    private var listener: ListenerRegistration?
    private var authHandle: AuthStateDidChangeListenerHandle?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("chats.nav.title", comment: "")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none

        // Listener 跟著登入狀態存活,而非 view 生命週期 —— 這樣切到其他 tab 時
        // 仍能收到新訊息並即時更新 tab bar 紅氣泡。
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if user != nil {
                self.startListening()
            } else {
                self.listener?.remove()
                self.conversations = []
                self.tableView.reloadData()
                self.navigationController?.tabBarItem.badgeValue = nil
            }
        }
    }

    deinit {
        listener?.remove()
        if let authHandle = authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    // MARK: - Firestore
    private func startListening() {
        listener?.remove()

        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        listener = db
            .collection("conversations")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastUpdated", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("conversation listener error: \(error)")
                    return
                }

                // 對方名稱直接讀 conversation 文件裡的 participantNames map,
                // 不再逐筆查 users collection —— handler 變同步,消除競態與多餘讀取。
                let docs = snapshot?.documents ?? []
                self.conversations = docs.compactMap { doc -> Conversation? in
                    let data = doc.data()
                    guard let participants = data["participants"] as? [String],
                          let last = data["lastMessage"] as? String,
                          let ts = (data["lastUpdated"] as? Timestamp)?.dateValue() else { return nil }
                    let otherUID = participants.first(where: { $0 != uid }) ?? ""
                    let names = data["participantNames"] as? [String: String] ?? [:]
                    let name = names[otherUID] ?? NSLocalizedString("chatlist.unknownUser", comment: "")
                    let unreadCounts = data["unreadCounts"] as? [String: Int] ?? [:]
                    return Conversation(id: doc.documentID,
                                        otherUserID: otherUID,
                                        otherUserName: name,
                                        lastMessage: last,
                                        timestamp: ts,
                                        unreadCount: unreadCounts[uid] ?? 0)
                }

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    // 紅氣泡必須設在 navigationController 的 tabBarItem 上 ——
                    // ChatListViewController 是 nav controller 的 root,tab bar 只認 nav controller 的 item。
                    let totalUnread = self.conversations.reduce(0) { $0 + $1.unreadCount }
                    self.navigationController?.tabBarItem.badgeValue = totalUnread > 0 ? "\(totalUnread)" : nil
                }
            }
    }

    // MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "showChat",
              let chatVC = segue.destination as? ChatViewController else { return }
        if let conversation = sender as? Conversation {
            chatVC.conversationId = conversation.id
            chatVC.otherUID = conversation.otherUserID
        } else if let cell = sender as? UITableViewCell,
                  let indexPath = tableView.indexPath(for: cell) {
            chatVC.conversationId = conversations[indexPath.row].id
            chatVC.otherUID = conversations[indexPath.row].otherUserID
        }
    }
}

// MARK: - UITableViewDataSource
extension ChatListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath) as! ConversationCell
        cell.configure(with: conversations[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ChatListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension ChatListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // TODO: 實作搜尋過濾
    }
}
