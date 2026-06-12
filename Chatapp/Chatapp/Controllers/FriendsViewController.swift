//
//  FriendsViewController.swift
//  Chatapp
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - FriendCell

class FriendCell: UITableViewCell {
    static let reuseId = "FriendCell"
    @IBOutlet weak var nameLabel: UILabel!
    var onMessage: (() -> Void)?

    @IBAction func messageTapped(_ sender: UIButton) { onMessage?() }
}

// MARK: - RequestCell

class RequestCell: UITableViewCell {
    static let reuseId = "RequestCell"
    @IBOutlet weak var nameLabel: UILabel!
    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?

    @IBAction func acceptTapped(_ sender: UIButton) { onAccept?() }
    @IBAction func declineTapped(_ sender: UIButton) { onDecline?() }
}

// MARK: - FriendsViewController

class FriendsViewController: UIViewController {

    @IBOutlet weak var segmentedControl: UISegmentedControl!
    @IBOutlet weak var tableView: UITableView!

    private var friends: [UserProfile] = []
    private var pendingRequests: [FriendRequest] = []
    private var requestsListener: ListenerRegistration?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Add Friend", style: .plain, target: self, action: #selector(addFriendTapped))
        startRequestsListener()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchFriends()
    }

    deinit {
        requestsListener?.remove()
    }

    // MARK: - IBActions

    @IBAction func segmentChanged(_ sender: UISegmentedControl) {
        tableView.reloadData()
    }

    @objc private func addFriendTapped() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let navVC = sb.instantiateViewController(withIdentifier: "AddFriendNav")
        present(navVC, animated: true)
    }

    // MARK: - Data

    private func fetchFriends() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        let group = DispatchGroup()
        var friendUIDs = Set<String>()

        group.enter()
        db.collection("friendRequests")
            .whereField("fromUID", isEqualTo: uid)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach {
                    if let toUID = $0["toUID"] as? String { friendUIDs.insert(toUID) }
                }
                group.leave()
            }

        group.enter()
        db.collection("friendRequests")
            .whereField("toUID", isEqualTo: uid)
            .whereField("status", isEqualTo: "accepted")
            .getDocuments { snapshot, _ in
                snapshot?.documents.forEach {
                    if let fromUID = $0["fromUID"] as? String { friendUIDs.insert(fromUID) }
                }
                group.leave()
            }

        group.notify(queue: .global()) { [weak self] in
            let profileGroup = DispatchGroup()
            var profiles = [UserProfile]()
            for friendUID in friendUIDs {
                profileGroup.enter()
                db.collection("users").document(friendUID).getDocument { snap, _ in
                    if let p = try? snap?.data(as: UserProfile.self) { profiles.append(p) }
                    profileGroup.leave()
                }
            }
            profileGroup.notify(queue: .main) { [weak self] in
                self?.friends = profiles
                if self?.segmentedControl.selectedSegmentIndex == 0 {
                    self?.tableView.reloadData()
                }
            }
        }
    }

    private func startRequestsListener() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        requestsListener = Firestore.firestore()
            .collection("friendRequests")
            .whereField("toUID", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, _ in
                self?.pendingRequests = snapshot?.documents.compactMap {
                    try? $0.data(as: FriendRequest.self)
                } ?? []
                DispatchQueue.main.async {
                    if self?.segmentedControl.selectedSegmentIndex == 1 {
                        self?.tableView.reloadData()
                    }
                }
            }
    }

    // MARK: - Chat

    private func openChat(with user: UserProfile) {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let userID = user.id else { return }
        let db = Firestore.firestore()
        let participants = [currentUID, userID].sorted()
        let convId = participants.joined(separator: "_")
        let ref = db.collection("conversations").document(convId)
        ref.getDocument { [weak self] snapshot, _ in
            if snapshot?.exists == false {
                ref.setData([
                    "participants": participants,
                    "participantNames": [currentUID: Auth.auth().currentUser?.email ?? "",
                                         userID: user.displayName],
                    "lastMessage": "",
                    "lastUpdated": Timestamp(date: Date())
                ])
            }
            DispatchQueue.main.async {
                let sb = UIStoryboard(name: "Main", bundle: nil)
                guard let chatVC = sb.instantiateViewController(withIdentifier: "ChatViewController")
                        as? ChatViewController else { return }
                chatVC.conversationId = convId
                self?.navigationController?.pushViewController(chatVC, animated: true)
            }
        }
    }

    // MARK: - Friend Request Actions

    private func acceptRequest(_ request: FriendRequest) {
        guard let requestId = request.id else { return }
        Firestore.firestore().collection("friendRequests").document(requestId)
            .updateData(["status": "accepted"]) { [weak self] _ in
                self?.fetchFriends()
            }
    }

    private func declineRequest(_ request: FriendRequest) {
        guard let requestId = request.id else { return }
        Firestore.firestore().collection("friendRequests").document(requestId)
            .updateData(["status": "declined"])
    }
}

// MARK: - UITableViewDataSource

extension FriendsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        segmentedControl.selectedSegmentIndex == 0 ? friends.count : pendingRequests.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if segmentedControl.selectedSegmentIndex == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendCell.reuseId, for: indexPath) as! FriendCell
            let user = friends[indexPath.row]
            cell.nameLabel.text = user.displayName
            cell.onMessage = { [weak self] in self?.openChat(with: user) }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: RequestCell.reuseId, for: indexPath) as! RequestCell
            let request = pendingRequests[indexPath.row]
            cell.nameLabel.text = request.fromName
            cell.onAccept  = { [weak self] in self?.acceptRequest(request) }
            cell.onDecline = { [weak self] in self?.declineRequest(request) }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension FriendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
