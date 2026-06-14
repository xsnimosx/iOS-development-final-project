//
//  AddFriendViewController.swift
//  Chatapp
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

private class PendingButton: UIButton {
    var tapAction: (() -> Void)?
    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func handleTap() { tapAction?() }
}

class AddFriendViewController: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!

    private enum RelationshipStatus {
        case none, sentPending, receivedPending, friends
    }

    private var allUsers: [UserProfile] = []
    private var filteredUsers: [UserProfile] = []
    private var statusMap: [String: RelationshipStatus] = [:]

    private var nonFriendUsers: [UserProfile] {
        allUsers.filter { statusMap[$0.id ?? ""] != .friends }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("addfriend.nav.title", comment: "")
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AddFriendUserCell.self, forCellReuseIdentifier: AddFriendUserCell.reuseId)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 68
        fetchUsers()
    }

    // MARK: - IBAction
    @IBAction func cancelTapped(_ sender: Any) {
        dismiss(animated: true)
    }

    // MARK: - Data

    private func fetchUsers() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").getDocuments { [weak self] snapshot, _ in
            guard let self = self else { return }
            self.allUsers = snapshot?.documents.compactMap { doc -> UserProfile? in
                guard doc.documentID != currentUID else { return nil }
                return try? doc.data(as: UserProfile.self)
            } ?? []
            self.loadRelationships {
                self.filteredUsers = self.nonFriendUsers
                self.tableView.reloadData()
            }
        }
    }

    private func loadRelationships(completion: @escaping () -> Void) {
        guard let currentUID = Auth.auth().currentUser?.uid else { completion(); return }
        let db = Firestore.firestore()
        let group = DispatchGroup()
        var map: [String: RelationshipStatus] = [:]

        group.enter()
        db.collection("friendRequests").whereField("fromUID", isEqualTo: currentUID)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { doc in
                    let data = doc.data()
                    guard let toUID = data["toUID"] as? String,
                          let status = data["status"] as? String else { return }
                    if status == "accepted" { map[toUID] = .friends }
                    else if status == "pending" { map[toUID] = .sentPending }
                }
                group.leave()
            }

        group.enter()
        db.collection("friendRequests").whereField("toUID", isEqualTo: currentUID)
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach { doc in
                    let data = doc.data()
                    guard let fromUID = data["fromUID"] as? String,
                          let status = data["status"] as? String else { return }
                    if status == "accepted" {
                        map[fromUID] = .friends
                    } else if status == "pending", map[fromUID] != .friends {
                        map[fromUID] = .receivedPending
                    }
                }
                group.leave()
            }

        group.notify(queue: .main) { [weak self] in
            self?.statusMap = map
            completion()
        }
    }

    // MARK: - Friend Request Logic

    private func handleTap(on user: UserProfile) {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let toUID = user.id else { return }

        switch statusMap[toUID] ?? .none {
        case .friends:
            showAlert(NSLocalizedString("addfriend.status.alreadyFriends", comment: ""))

        case .sentPending:
            break

        case .receivedPending:
            // Discord-style: they already sent us a request — just accept it
            let reverseId = "\(toUID)_\(currentUID)"
            Firestore.firestore().collection("friendRequests").document(reverseId)
                .updateData(["status": "accepted"]) { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if error == nil {
                            self.statusMap[toUID] = .friends
                            self.filteredUsers = self.nonFriendUsers
                            self.tableView.reloadData()
                            self.showAlert(NSLocalizedString("addfriend.status.nowFriends", comment: ""))
                        } else {
                            // Request may have been withdrawn; reload status
                            self.loadRelationships { self.tableView.reloadData() }
                        }
                    }
                }

        case .none:
            guard let displayName = Auth.auth().currentUser?.displayName
                                    ?? Auth.auth().currentUser?.email else { return }
            let requestId = "\(currentUID)_\(toUID)"
            Firestore.firestore().collection("friendRequests").document(requestId)
                .setData([
                    "fromUID": currentUID,
                    "toUID": toUID,
                    "fromName": displayName,
                    "status": "pending",
                    "createdAt": Timestamp(date: Date())
                ]) { [weak self] error in
                    DispatchQueue.main.async {
                        guard let self = self, error == nil else { return }
                        self.statusMap[toUID] = .sentPending
                        self.tableView.reloadData()
                        self.showAlert(NSLocalizedString("addfriend.status.requestSentSuccess", comment: ""))
                    }
                }
        }
    }

    private func cancelFriendRequest(to user: UserProfile) {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let toUID = user.id else { return }
        let requestId = "\(currentUID)_\(toUID)"
        Firestore.firestore().collection("friendRequests").document(requestId)
            .delete { [weak self] _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.statusMap[toUID] = .none
                    self.filteredUsers = self.nonFriendUsers
                    self.tableView.reloadData()
                }
            }
    }

    // MARK: - Helpers

    private func makeStatusBadge(for status: RelationshipStatus, onCancel: (() -> Void)? = nil) -> UIView? {
        switch status {
        case .none, .friends: return nil
        case .sentPending:
            let button = PendingButton()
            button.setTitle(NSLocalizedString("addfriend.badge.pending", comment: ""), for: .normal)
            button.setTitleColor(.systemOrange, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
            button.backgroundColor = .systemGray5
            button.layer.cornerRadius = 14
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            button.sizeToFit()
            button.tapAction = onCancel
            return button
        case .receivedPending:
            let label = UILabel()
            label.text = NSLocalizedString("addfriend.badge.accept", comment: "")
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.textColor = .systemGreen
            label.sizeToFit()
            return label
        }
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("addfriend.alert.ok", comment: ""), style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension AddFriendViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let base = nonFriendUsers
        filteredUsers = searchText.isEmpty ? base : base.filter {
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
        let cell = tableView.dequeueReusableCell(withIdentifier: AddFriendUserCell.reuseId, for: indexPath) as! AddFriendUserCell
        let user = filteredUsers[indexPath.row]
        cell.configure(name: user.displayName, detail: user.email)
        let status = statusMap[user.id ?? ""] ?? .none
        let cancelAction: (() -> Void)? = status == .sentPending ? { [weak self] in self?.cancelFriendRequest(to: user) } : nil
        cell.accessoryView = makeStatusBadge(for: status, onCancel: cancelAction)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension AddFriendViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        handleTap(on: filteredUsers[indexPath.row])
    }
}
