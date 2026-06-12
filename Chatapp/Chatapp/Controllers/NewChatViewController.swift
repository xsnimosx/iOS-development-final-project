//
//  NewChatViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class NewChatViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

    private var allUsers: [UserProfile] = []
    private var filteredUsers: [UserProfile] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        fetchUsers()
    }

    // MARK: - IBAction
    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true)
    }

    private func fetchUsers() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").getDocuments { [weak self] snapshot, _ in
            self?.allUsers = snapshot?.documents.compactMap { doc -> UserProfile? in
                guard doc.documentID != currentUID else { return nil }
                return try? doc.data(as: UserProfile.self)
            } ?? []
            self?.filteredUsers = self?.allUsers ?? []
            DispatchQueue.main.async { self?.tableView.reloadData() }
        }
    }

    private func startConversation(with user: UserProfile) {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let userID = user.id else { return }
        let db = Firestore.firestore()
        let participants = [currentUID, userID].sorted()
        let convId = participants.joined(separator: "_")
        let ref = db.collection("conversations").document(convId)
        ref.getDocument { [weak self] (snapshot: DocumentSnapshot?, _: Error?) in
            if snapshot?.exists == false {
                ref.setData([
                    "participants": participants,
                    "participantNames": [currentUID: Auth.auth().currentUser?.email ?? "", userID: user.displayName],
                    "lastMessage": "",
                    "lastUpdated": Timestamp(date: Date())
                ])
            }
            DispatchQueue.main.async {
                self?.dismiss(animated: true)
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension NewChatViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredUsers = searchText.isEmpty ? allUsers : allUsers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension NewChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { filteredUsers.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserCell", for: indexPath)
        let user = filteredUsers[indexPath.row]
        if let label = cell.contentView.subviews.compactMap({ $0 as? UILabel }).first {
            label.text = user.displayName
        }
        return cell
    }
}

// MARK: - UITableViewDelegate
extension NewChatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        startConversation(with: filteredUsers[indexPath.row])
    }
}
