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

    // MARK: - Segue
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showChat",
           let chatVC = segue.destination as? ChatViewController,
           let indexPath = tableView.indexPathForSelectedRow {
            chatVC.conversationId = conversations[indexPath.row].id
        }
    }
}

// MARK: - UITableViewDataSource
extension ConversationListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath)
        let conv = conversations[indexPath.row]
        // 找到 storyboard cell 裡的 label（用 tag 或 subview 結構）
        // nameLabel: stackView → label[0], messageLabel: stackView → label[1], timeLabel
        if let contentView = cell.contentView as? UIView {
            let labels = allLabels(in: contentView)
            if labels.count >= 3 {
                labels[0].text = conv.otherUserName
                labels[1].text = conv.lastMessage
                labels[2].text = timeString(from: conv.timestamp)
            }
        }
        return cell
    }

    private func allLabels(in view: UIView) -> [UILabel] {
        var result = [UILabel]()
        for sub in view.subviews {
            if let label = sub as? UILabel { result.append(label) }
            result += allLabels(in: sub)
        }
        return result
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "MM/dd"
        return formatter.string(from: date)
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
