//
//  ConversationListViewController.swift
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

class ConversationListViewController: UIViewController {

    // MARK: - IBOutlets
    // 在 Xcode 中 ctrl-drag 從 Storyboard 的 TableView 連接到這裡
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
                    let otherName = names.first(where: { $0.key != uid })?.value ?? "未知"
                    return Conversation(id: doc.documentID, otherUserName: otherName, lastMessage: last, timestamp: ts)
                }
                DispatchQueue.main.async { self?.tableView.reloadData() }
            }
    }

    // MARK: - IBActions
    @IBAction func addButtonTapped(_ sender: UIBarButtonItem) {
        performSegue(withIdentifier: "showChat", sender: nil)
    }

    // MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "showChat",
              let chatVC = segue.destination as? ChatViewController else { return }
        if let indexPath = tableView.indexPathForSelectedRow {
            chatVC.conversationId = conversations[indexPath.row].id
        }
        // sender == nil 代表從 + 按鈕進來，保留 default "test-conversation"
    }
}

// MARK: - UITableViewDataSource
extension ConversationListViewController: UITableViewDataSource {
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
extension ConversationListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        performSegue(withIdentifier: "showChat", sender: nil)
    }
}

// MARK: - UISearchBarDelegate
extension ConversationListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // TODO: 實作搜尋過濾
    }
}
