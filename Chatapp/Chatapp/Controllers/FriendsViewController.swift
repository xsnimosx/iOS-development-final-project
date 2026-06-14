//
//  FriendsViewController.swift
//  Chatapp
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - FriendCell

class FriendCell: UserRowCell {
    static let reuseId = "FriendCell"

    func configure(user: UserProfile) {
        configure(name: user.username, detail: user.email)
    }
}

// MARK: - RequestCell

class RequestCell: UITableViewCell {
    static let reuseId = "RequestCell"

    private let card = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let acceptButton = UIButton(type: .system)
    private let declineButton = UIButton(type: .system)
    var onAccept: (() -> Void)?
    var onDecline: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.tintColor = AppCell.avatarTint
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        acceptButton.setTitle(NSLocalizedString("friends.request.accept", comment: ""), for: .normal)
        acceptButton.setTitleColor(.white, for: .normal)
        acceptButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        acceptButton.backgroundColor = .systemGreen
        acceptButton.layer.cornerRadius = 14
        acceptButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)

        declineButton.setTitle(NSLocalizedString("friends.request.ignore", comment: ""), for: .normal)
        declineButton.setTitleColor(.secondaryLabel, for: .normal)
        declineButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        declineButton.backgroundColor = .systemGray5
        declineButton.layer.cornerRadius = 14
        declineButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        declineButton.translatesAutoresizingMaskIntoConstraints = false
        declineButton.addTarget(self, action: #selector(declineTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [declineButton, acceptButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 8
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(avatarImageView)
        card.addSubview(nameLabel)
        card.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppCell.horizontalPadding),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppCell.horizontalPadding),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            avatarImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: AppCell.avatarLabelSpacing),
            avatarImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: AppCell.verticalPadding),
            avatarImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -AppCell.verticalPadding),
            avatarImageView.widthAnchor.constraint(equalToConstant: AppCell.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: AppCell.avatarSize),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: AppCell.avatarLabelSpacing),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            buttonStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -AppCell.avatarLabelSpacing),
            buttonStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
    }

    @objc private func acceptTapped() { onAccept?() }
    @objc private func declineTapped() { onDecline?() }

    func configure(name: String, onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        nameLabel.text = name
        self.onAccept = onAccept
        self.onDecline = onDecline
    }
}

// MARK: - FriendsViewController

class FriendsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var friends: [UserProfile] = []
    private var pendingRequests: [FriendRequest] = []
    private var requestSenderNames: [String: String] = [:]
    private var requestsListener: ListenerRegistration?

    private enum Section { case pendingRequests, friends }
    private var sections: [Section] {
        var result: [Section] = []
        if !pendingRequests.isEmpty { result.append(.pendingRequests) }
        result.append(.friends)
        return result
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("friends.nav.title", comment: "")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.badge.plus"),
            style: .plain,
            target: self,
            action: #selector(addFriendTapped))
        startRequestsListener()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchFriends()
    }

    deinit {
        requestsListener?.remove()
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
                self?.friends = profiles.sorted { $0.username < $1.username }
                self?.tableView.reloadData()
            }
        }
    }

    private func startRequestsListener() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let db = Firestore.firestore()
        requestsListener = db
            .collection("friendRequests")
            .whereField("toUID", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                let requests = snapshot?.documents.compactMap {
                    try? $0.data(as: FriendRequest.self)
                } ?? []
                self.pendingRequests = requests

                let group = DispatchGroup()
                var names: [String: String] = [:]
                let lock = NSLock()
                for request in requests {
                    group.enter()
                    db.collection("users").document(request.fromUID).getDocument { snap, _ in
                        defer { group.leave() }
                        if let profile = try? snap?.data(as: UserProfile.self) {
                            lock.lock()
                            names[request.fromUID] = profile.username
                            lock.unlock()
                        }
                    }
                }
                group.notify(queue: .main) { [weak self] in
                    self?.requestSenderNames = names
                    self?.tableView.reloadData()
                    let count = self?.pendingRequests.count ?? 0
                    self?.tabBarItem.badgeValue = count > 0 ? "\(count)" : nil
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

        db.collection("users").document(currentUID).getDocument { [weak self] profileSnap, _ in
            let currentUsername = (try? profileSnap?.data(as: UserProfile.self))?.username
                ?? Auth.auth().currentUser?.email ?? ""
            let names: [String: String] = [currentUID: currentUsername, userID: user.username]
            let navigate = {
                DispatchQueue.main.async {
                    let sb = UIStoryboard(name: "Main", bundle: nil)
                    guard let chatVC = sb.instantiateViewController(withIdentifier: "ChatViewController")
                            as? ChatViewController else { return }
                    chatVC.conversationId = convId
                    chatVC.otherUID = userID
                    self?.navigationController?.pushViewController(chatVC, animated: true)
                }
            }
            ref.getDocument { snapshot, _ in
                if snapshot?.exists == false {
                    ref.setData([
                        "participants": participants,
                        "participantNames": names,
                        "lastMessage": "",
                        "lastUpdated": Timestamp(date: Date())
                    ]) { _ in navigate() }
                } else {
                    ref.updateData(["participantNames": names]) { _ in navigate() }
                }
            }
        }
    }

    // MARK: - Friend Request Actions

    private func acceptRequest(_ request: FriendRequest) {
        guard let requestId = request.id else { return }

        Firestore.firestore().collection("friendRequests").document(requestId)
            .updateData(["status": "accepted"]) { [weak self] error in
                guard error == nil, let self = self else { return }
                Firestore.firestore().collection("users").document(request.fromUID)
                    .getDocument(completion: { [weak self] snap, _ in
                        guard let self = self else { return }
                        let newFriend = try? snap?.data(as: UserProfile.self)
                        DispatchQueue.main.async {
                            let friendInsertIdx: Int? = newFriend.map { friend in
                                self.friends.firstIndex(where: { $0.username > friend.username }) ?? self.friends.count
                            }

                            let currentIdx = self.pendingRequests.firstIndex(where: { $0.id == requestId })

                            if currentIdx == nil {
                                // Path A: snapshot listener already cleared pendingRequests and called
                                // reloadData(). Table's pending state is correct — just insert the friend.
                                guard let friend = newFriend, let insertIdx = friendInsertIdx else { return }
                                self.friends.insert(friend, at: insertIdx)
                                let friendsSectionIdx = self.sections.firstIndex(of: .friends)!
                                self.tableView.performBatchUpdates({
                                    self.tableView.insertRows(at: [IndexPath(row: insertIdx, section: friendsSectionIdx)], with: .automatic)
                                }, completion: { _ in
                                    self.tableView.reloadSections(IndexSet(integer: friendsSectionIdx), with: .none)
                                })
                            } else {
                                // Path B: handle both pending removal and friend insertion atomically.
                                guard let currentIdx = currentIdx,
                                      let pendingSectionIdx = self.sections.firstIndex(of: .pendingRequests) else { return }

                                let willRemovePendingSection = self.pendingRequests.count == 1

                                self.pendingRequests.remove(at: currentIdx)
                                if let friend = newFriend, let idx = friendInsertIdx {
                                    self.friends.insert(friend, at: idx)
                                }

                                let friendsSectionIdxNew = self.sections.firstIndex(of: .friends)!

                                self.tableView.performBatchUpdates({
                                    if willRemovePendingSection {
                                        self.tableView.deleteSections(IndexSet(integer: pendingSectionIdx), with: .automatic)
                                    } else {
                                        self.tableView.deleteRows(at: [IndexPath(row: currentIdx, section: pendingSectionIdx)], with: .automatic)
                                    }
                                    if let idx = friendInsertIdx {
                                        self.tableView.insertRows(at: [IndexPath(row: idx, section: friendsSectionIdxNew)], with: .automatic)
                                    }
                                }, completion: { _ in
                                    var toReload = IndexSet(integer: friendsSectionIdxNew)
                                    if !willRemovePendingSection { toReload.insert(pendingSectionIdx) }
                                    self.tableView.reloadSections(toReload, with: .none)
                                })
                            }
                        }
                    })
            }
    }

    private func declineRequest(_ request: FriendRequest) {
        guard let requestId = request.id else { return }
        Firestore.firestore().collection("friendRequests").document(requestId)
            .updateData(["status": "declined"])
    }

    // MARK: - Remove Friend

    private func confirmAndRemoveFriend(at indexPath: IndexPath) {
        let friend = friends[indexPath.row]
        let alert = UIAlertController(
            title: NSLocalizedString("friends.remove.title", comment: ""),
            message: String(format: NSLocalizedString("friends.remove.message", comment: ""), friend.username),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("friends.remove.cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("friends.remove.confirm", comment: ""), style: .destructive) { [weak self] _ in
            self?.removeFriend(friend, at: indexPath)
        })
        present(alert, animated: true)
    }

    private func removeFriend(_ user: UserProfile, at indexPath: IndexPath) {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let friendUID = user.id else { return }
        let db = Firestore.firestore()
        let group = DispatchGroup()

        for (from, to) in [(currentUID, friendUID), (friendUID, currentUID)] {
            group.enter()
            db.collection("friendRequests")
                .whereField("fromUID", isEqualTo: from)
                .whereField("toUID", isEqualTo: to)
                .whereField("status", isEqualTo: "accepted")
                .getDocuments { snapshot, _ in
                    let batch = db.batch()
                    snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                    batch.commit { _ in group.leave() }
                }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.friends.remove(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
}

// MARK: - UITableViewDataSource

extension FriendsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .pendingRequests: return pendingRequests.count
        case .friends: return friends.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .pendingRequests:
            let cell = tableView.dequeueReusableCell(withIdentifier: RequestCell.reuseId, for: indexPath) as! RequestCell
            let request = pendingRequests[indexPath.row]
            let senderName = requestSenderNames[request.fromUID] ?? request.fromName
            cell.configure(
                name: senderName,
                onAccept: { [weak self] in self?.acceptRequest(request) },
                onDecline: { [weak self] in self?.declineRequest(request) })
            return cell
        case .friends:
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendCell.reuseId, for: indexPath) as! FriendCell
            cell.configure(user: friends[indexPath.row])
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension FriendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .pendingRequests:
            return String(format: NSLocalizedString("friends.section.pending", comment: ""), pendingRequests.count)
        case .friends:
            return String(format: NSLocalizedString("friends.section.friends", comment: ""), friends.count)
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = self.tableView(tableView, titleForHeaderInSection: section) else { return nil }

        let label = UILabel()
        label.text = title
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor = .secondaryLabel

        let container = UIView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        return container
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard sections[indexPath.section] == .friends else { return }
        openChat(with: friends[indexPath.row])
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard sections[indexPath.section] == .friends else { return nil }
        let remove = UIContextualAction(style: .destructive, title: NSLocalizedString("friends.swipe.remove", comment: "")) { [weak self] _, _, done in
            self?.confirmAndRemoveFriend(at: indexPath)
            done(true)
        }
        remove.image = UIImage(systemName: "person.fill.xmark")
        return UISwipeActionsConfiguration(actions: [remove])
    }
}
