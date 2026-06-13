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

    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let messageButton = UIButton(type: .system)
    var onMessage: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .systemBackground

        avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.tintColor = .systemBrown
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = 22
        avatarImageView.clipsToBounds = true
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.tinted()
        config.image = UIImage(systemName: "message.fill")
        config.baseForegroundColor = .systemBlue
        config.baseBackgroundColor = .systemBlue
        config.cornerStyle = .capsule
        messageButton.configuration = config
        messageButton.translatesAutoresizingMaskIntoConstraints = false
        messageButton.addTarget(self, action: #selector(messageTapped), for: .touchUpInside)

        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(messageButton)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            avatarImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            avatarImageView.widthAnchor.constraint(equalToConstant: 44),
            avatarImageView.heightAnchor.constraint(equalToConstant: 44),

            messageButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            messageButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            messageButton.widthAnchor.constraint(equalToConstant: 36),
            messageButton.heightAnchor.constraint(equalToConstant: 36),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: messageButton.leadingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @objc private func messageTapped() { onMessage?() }

    func configure(user: UserProfile, onMessage: @escaping () -> Void) {
        nameLabel.text = user.displayName
        self.onMessage = onMessage
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

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear

        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(card)

        avatarImageView.image = UIImage(systemName: "person.crop.circle.fill")
        avatarImageView.tintColor = .systemBrown
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.cornerRadius = 22
        avatarImageView.clipsToBounds = true
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        var acceptCfg = UIButton.Configuration.filled()
        acceptCfg.title = "Accept"
        acceptCfg.baseBackgroundColor = .systemGreen
        acceptCfg.baseForegroundColor = .white
        acceptCfg.cornerStyle = .capsule
        acceptCfg.buttonSize = .small
        acceptButton.configuration = acceptCfg
        acceptButton.translatesAutoresizingMaskIntoConstraints = false
        acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)

        var declineCfg = UIButton.Configuration.gray()
        declineCfg.title = "Ignore"
        declineCfg.cornerStyle = .capsule
        declineCfg.buttonSize = .small
        declineButton.configuration = declineCfg
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
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            avatarImageView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            avatarImageView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            avatarImageView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            avatarImageView.widthAnchor.constraint(equalToConstant: 44),
            avatarImageView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            buttonStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            buttonStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
    }

    @objc private func acceptTapped() { onAccept?() }
    @objc private func declineTapped() { onDecline?() }

    func configure(request: FriendRequest, onAccept: @escaping () -> Void, onDecline: @escaping () -> Void) {
        nameLabel.text = request.fromName
        self.onAccept = onAccept
        self.onDecline = onDecline
    }
}

// MARK: - FriendsViewController

class FriendsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var friends: [UserProfile] = []
    private var pendingRequests: [FriendRequest] = []
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
        title = "Friends"
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
                self?.friends = profiles.sorted { $0.displayName < $1.displayName }
                self?.tableView.reloadData()
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
                    self?.tableView.reloadData()
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
            let navigate = {
                DispatchQueue.main.async {
                    let sb = UIStoryboard(name: "Main", bundle: nil)
                    guard let chatVC = sb.instantiateViewController(withIdentifier: "ChatViewController")
                            as? ChatViewController else { return }
                    chatVC.conversationId = convId
                    self?.navigationController?.pushViewController(chatVC, animated: true)
                }
            }
            if snapshot?.exists == false {
                ref.setData([
                    "participants": participants,
                    "participantNames": [currentUID: Auth.auth().currentUser?.email ?? "",
                                         userID: user.displayName],
                    "lastMessage": "",
                    "lastUpdated": Timestamp(date: Date())
                ]) { _ in navigate() }
            } else {
                navigate()
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
            cell.configure(
                request: request,
                onAccept: { [weak self] in self?.acceptRequest(request) },
                onDecline: { [weak self] in self?.declineRequest(request) })
            return cell
        case .friends:
            let cell = tableView.dequeueReusableCell(withIdentifier: FriendCell.reuseId, for: indexPath) as! FriendCell
            let user = friends[indexPath.row]
            cell.configure(user: user, onMessage: { [weak self] in self?.openChat(with: user) })
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension FriendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = .systemGroupedBackground

        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false

        switch sections[section] {
        case .pendingRequests:
            label.text = "PENDING REQUESTS — \(pendingRequests.count)"
        case .friends:
            label.text = "FRIENDS — \(friends.count)"
        }

        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 32 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
