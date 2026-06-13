//
//  AddFriendViewController.swift
//  Chatapp
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class AddFriendViewController: UIViewController {

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

    private func sendFriendRequest(to user: UserProfile) {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let toUID = user.id else { return }
        let db = Firestore.firestore()
        let requestId = "\(currentUID)_\(toUID)"
        let ref = db.collection("friendRequests").document(requestId)
        ref.getDocument { [weak self] snapshot, _ in
            if let data = snapshot?.data(), let status = data["status"] as? String {
                let message = status == "accepted" ? "You are already friends." : "Friend request already sent."
                DispatchQueue.main.async {
                    self?.showAlert(message)
                }
                return
            }
            guard let displayName = Auth.auth().currentUser?.displayName
                                    ?? Auth.auth().currentUser?.email else { return }
            ref.setData([
                "fromUID": currentUID,
                "toUID": toUID,
                "fromName": displayName,
                "status": "pending",
                "createdAt": Timestamp(date: Date())
            ]) { [weak self] error in
                DispatchQueue.main.async {
                    if error == nil {
                        self?.showAlert("Friend request sent!")
                    }
                }
            }
        }
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension AddFriendViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filteredUsers = searchText.isEmpty ? allUsers : allUsers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText)
        }
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension AddFriendViewController: UITableViewDataSource {
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
extension AddFriendViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        sendFriendRequest(to: filteredUsers[indexPath.row])
    }
}
