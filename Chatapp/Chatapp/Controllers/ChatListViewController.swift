//
//  ChatListViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

struct Conversation {
    let id: String
    let otherUserName: String
    let lastMessage: String
    let timestamp: Date
}

class ChatListViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var tableView: UITableView!

    private var conversations: [Conversation] = []
    private var listener: ListenerRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("chats.nav.title", comment: "")
        tableView.dataSource = self
        tableView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startListening()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
    }

    // MARK: - Firestore
    private func startListening() {
        listener?.remove()
        conversations = []
        tableView.reloadData()

        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()

        listener = db
            .collection("conversations")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastUpdated", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self,
                      let docs = snapshot?.documents, !docs.isEmpty else {
                    DispatchQueue.main.async {
                        self?.conversations = []
                        self?.tableView.reloadData()
                    }
                    return
                }

                let group = DispatchGroup()
                var indexed: [(Int, Conversation)] = []
                let lock = NSLock()

                for (i, doc) in docs.enumerated() {
                    let data = doc.data()
                    guard let participants = data["participants"] as? [String],
                          let last = data["lastMessage"] as? String,
                          let ts = (data["lastUpdated"] as? Timestamp)?.dateValue() else { continue }
                    let otherUID = participants.first(where: { $0 != uid }) ?? ""

                    group.enter()
                    db.collection("users").document(otherUID).getDocument { snap, _ in
                        defer { group.leave() }
                        let name: String
                        if let profile = try? snap?.data(as: UserProfile.self) {
                            name = profile.username
                        } else {
                            name = NSLocalizedString("chatlist.unknownUser", comment: "")
                        }
                        lock.lock()
                        indexed.append((i, Conversation(id: doc.documentID, otherUserName: name, lastMessage: last, timestamp: ts)))
                        lock.unlock()
                    }
                }

                group.notify(queue: .main) { [weak self] in
                    self?.conversations = indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
                    self?.tableView.reloadData()
                }
            }
    }

    // MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "showChat",
              let chatVC = segue.destination as? ChatViewController else { return }
        if let conversation = sender as? Conversation {
            // triggered programmatically (e.g. addButtonTapped)
            chatVC.conversationId = conversation.id
        } else if let cell = sender as? UITableViewCell,
                  let indexPath = tableView.indexPath(for: cell) {
            // triggered by cell tap via storyboard segue
            chatVC.conversationId = conversations[indexPath.row].id
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
