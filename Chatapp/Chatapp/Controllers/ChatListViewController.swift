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
        tableView.dataSource = self
        tableView.delegate = self
        startListening()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
    }

    // MARK: - Firestore
    private func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        listener = Firestore.firestore()
            .collection("conversations")
            .whereField("participants", arrayContains: uid)
            .order(by: "lastUpdated", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                self?.conversations = docs.compactMap { doc -> Conversation? in
                    let data = doc.data()
                    guard let names = data["participantNames"] as? [String: String],
                          let last = data["lastMessage"] as? String,
                          let ts = (data["lastUpdated"] as? Timestamp)?.dateValue() else { return nil }
                    let otherName = names.first(where: { $0.key != uid })?.value ?? NSLocalizedString("chatlist.unknownUser", comment: "")
                    return Conversation(id: doc.documentID, otherUserName: otherName, lastMessage: last, timestamp: ts)
                }
                DispatchQueue.main.async { self?.tableView.reloadData() }
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
