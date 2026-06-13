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
        let db = Firestore.firestore()
        let group = DispatchGroup()
        var friendUIDs = Set<String>()

        group.enter()
        db.collection("friendRequests")
            .whereField("fromUID", isEqualTo: currentUID)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach {
                    if let uid = $0["toUID"] as? String { friendUIDs.insert(uid) }
                }
                group.leave()
            }

        group.enter()
        db.collection("friendRequests")
            .whereField("toUID", isEqualTo: currentUID)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach {
                    if let uid = $0["fromUID"] as? String { friendUIDs.insert(uid) }
                }
                group.leave()
            }

        group.notify(queue: .global()) { [weak self] in
            let profileGroup = DispatchGroup()
            var profiles = [UserProfile]()
            for uid in friendUIDs {
                profileGroup.enter()
                db.collection("users").document(uid).getDocument { snap, _ in
                    if let p = try? snap?.data(as: UserProfile.self) { profiles.append(p) }
                    profileGroup.leave()
                }
            }
            profileGroup.notify(queue: .main) { [weak self] in
                self?.allUsers = profiles
                self?.filteredUsers = profiles
                self?.tableView.reloadData()
            }
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
