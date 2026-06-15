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

    // Firestore listeners are the single source of truth; everything below is a cache
    // derived from the raw request documents the two listeners deliver.
    private var incomingDocs: [FriendRequest] = []   // toUID == me, any status
    private var outgoingDocs: [FriendRequest] = []   // fromUID == me, any status
    private var profilesByUID: [String: UserProfile] = [:]
    private var fetchingUIDs: Set<String> = []
    private var currentSections: [Section] = []

    private var incomingListener: ListenerRegistration?
    private var outgoingListener: ListenerRegistration?

    private enum Section: Hashable { case pendingRequests, friends }

    private enum Item: Hashable {
        case request(id: String, name: String)
        case friend(uid: String, username: String)
    }

    private lazy var dataSource = makeDataSource()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("friends.nav.title", comment: "")
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.backgroundColor = .systemGroupedBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "person.badge.plus"),
            style: .plain,
            target: self,
            action: #selector(addFriendTapped))
        startListeners()
    }

    deinit {
        incomingListener?.remove()
        outgoingListener?.remove()
    }

    @objc private func addFriendTapped() {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let navVC = sb.instantiateViewController(withIdentifier: "AddFriendNav")
        present(navVC, animated: true)
    }

    // MARK: - Diffable data source

    private func makeDataSource() -> UITableViewDiffableDataSource<Section, Item> {
        UITableViewDiffableDataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
            switch item {
            case let .request(id, name):
                let cell = tableView.dequeueReusableCell(withIdentifier: RequestCell.reuseId, for: indexPath) as! RequestCell
                cell.configure(
                    name: name,
                    onAccept: { [weak self] in self?.acceptRequest(id: id) },
                    onDecline: { [weak self] in self?.declineRequest(id: id) })
                return cell
            case let .friend(uid, _):
                let cell = tableView.dequeueReusableCell(withIdentifier: FriendCell.reuseId, for: indexPath) as! FriendCell
                if let profile = self?.profilesByUID[uid] {
                    cell.configure(user: profile)
                }
                return cell
            }
        }
    }

    // MARK: - Data (single source of truth)

    /// Two live listeners cover every relationship the current user is part of,
    /// regardless of status. Accept / decline / remove anywhere — even from the
    /// Add Friends screen or another device — flows back through these listeners,
    /// so the table never has to be mutated by hand.
    private func startListeners() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let collection = Firestore.firestore().collection("friendRequests")

        incomingListener = collection
            .whereField("toUID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                self.incomingDocs = snapshot?.documents.compactMap {
                    try? $0.data(as: FriendRequest.self)
                } ?? []
                self.rebuild()
            }

        outgoingListener = collection
            .whereField("fromUID", isEqualTo: uid)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self = self else { return }
                self.outgoingDocs = snapshot?.documents.compactMap {
                    try? $0.data(as: FriendRequest.self)
                } ?? []
                self.rebuild()
            }
    }

    /// Recompute the lookups the cells need, fetch any user profiles we are
    /// missing, then re-apply the snapshot. Profile fetches are cached so a
    /// listener firing repeatedly does not re-hit Firestore or flicker.
    private func rebuild() {
        let pending = incomingDocs.filter { $0.status == "pending" }
        var neededUIDs = Set(pending.map { $0.fromUID })
        for doc in incomingDocs where doc.status == "accepted" { neededUIDs.insert(doc.fromUID) }
        for doc in outgoingDocs where doc.status == "accepted" { neededUIDs.insert(doc.toUID) }

        let db = Firestore.firestore()
        for uid in neededUIDs where profilesByUID[uid] == nil && !fetchingUIDs.contains(uid) {
            fetchingUIDs.insert(uid)
            db.collection("users").document(uid).getDocument { [weak self] snap, _ in
                guard let self = self else { return }
                self.fetchingUIDs.remove(uid)
                if let profile = try? snap?.data(as: UserProfile.self) {
                    self.profilesByUID[uid] = profile
                }
                self.applySnapshot()
            }
        }

        applySnapshot()
    }

    /// Build the table snapshot deterministically from the caches. The pending
    /// section only exists while there are pending requests, exactly mirroring
    /// the old computed `sections` — but now UIKit diffs the change for us.
    private func applySnapshot() {
        let pending = incomingDocs
            .filter { $0.status == "pending" }
            .sorted { $0.createdAt < $1.createdAt }

        var friendUIDs = Set<String>()
        for doc in incomingDocs where doc.status == "accepted" { friendUIDs.insert(doc.fromUID) }
        for doc in outgoingDocs where doc.status == "accepted" { friendUIDs.insert(doc.toUID) }
        let friends = friendUIDs
            .compactMap { profilesByUID[$0] }
            .sorted { $0.username < $1.username }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        var order: [Section] = []

        if !pending.isEmpty {
            snapshot.appendSections([.pendingRequests])
            order.append(.pendingRequests)
            let items = pending.map { req -> Item in
                let name = profilesByUID[req.fromUID]?.username ?? req.fromName
                return .request(id: req.id ?? req.fromUID, name: name)
            }
            snapshot.appendItems(items, toSection: .pendingRequests)
        }

        snapshot.appendSections([.friends])
        order.append(.friends)
        let friendItems = friends.compactMap { profile -> Item? in
            profile.id.map { .friend(uid: $0, username: profile.username) }
        }
        snapshot.appendItems(friendItems, toSection: .friends)

        currentSections = order
        dataSource.apply(snapshot, animatingDifferences: viewIfLoaded?.window != nil)
        // FriendsViewController 同樣是 nav controller 的 root,badge 要設在 nav controller 的 item 上。
        navigationController?.tabBarItem.badgeValue = pending.isEmpty ? nil : "\(pending.count)"
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

    private func acceptRequest(id: String) {
        // Just record the acceptance; the listeners reflect it in the UI.
        Firestore.firestore().collection("friendRequests").document(id)
            .updateData(["status": "accepted"])
    }

    private func declineRequest(id: String) {
        Firestore.firestore().collection("friendRequests").document(id)
            .updateData(["status": "declined"])
    }

    // MARK: - Remove Friend

    private func confirmAndRemoveFriend(_ friend: UserProfile) {
        let alert = UIAlertController(
            title: NSLocalizedString("friends.remove.title", comment: ""),
            message: String(format: NSLocalizedString("friends.remove.message", comment: ""), friend.username),
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("friends.remove.cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("friends.remove.confirm", comment: ""), style: .destructive) { [weak self] _ in
            self?.removeFriend(friend)
        })
        present(alert, animated: true)
    }

    private func removeFriend(_ user: UserProfile) {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let friendUID = user.id else { return }
        let db = Firestore.firestore()

        // Delete both directions of the accepted friendship; the listeners
        // observe these deletions and drop the row.
        for (from, to) in [(currentUID, friendUID), (friendUID, currentUID)] {
            db.collection("friendRequests")
                .whereField("fromUID", isEqualTo: from)
                .whereField("toUID", isEqualTo: to)
                .whereField("status", isEqualTo: "accepted")
                .getDocuments { snapshot, _ in
                    guard let docs = snapshot?.documents, !docs.isEmpty else { return }
                    let batch = db.batch()
                    docs.forEach { batch.deleteDocument($0.reference) }
                    batch.commit()
                }
        }
    }
}

// MARK: - UITableViewDelegate

extension FriendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard section < currentSections.count else { return nil }
        let snapshot = dataSource.snapshot()
        switch currentSections[section] {
        case .pendingRequests:
            return String(format: NSLocalizedString("friends.section.pending", comment: ""),
                          snapshot.numberOfItems(inSection: .pendingRequests))
        case .friends:
            return String(format: NSLocalizedString("friends.section.friends", comment: ""),
                          snapshot.numberOfItems(inSection: .friends))
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
        guard case let .friend(uid, _)? = dataSource.itemIdentifier(for: indexPath),
              let profile = profilesByUID[uid] else { return }
        openChat(with: profile)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        guard case let .friend(uid, _)? = dataSource.itemIdentifier(for: indexPath),
              let profile = profilesByUID[uid] else { return nil }
        let remove = UIContextualAction(style: .destructive, title: NSLocalizedString("friends.swipe.remove", comment: "")) { [weak self] _, _, done in
            self?.confirmAndRemoveFriend(profile)
            done(true)
        }
        remove.image = UIImage(systemName: "person.fill.xmark")
        return UISwipeActionsConfiguration(actions: [remove])
    }
}
