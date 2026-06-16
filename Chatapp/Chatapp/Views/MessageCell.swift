import UIKit

class MessageCell: UITableViewCell {
    static let reuseId = "MessageCell"
    private static let imageCache = NSCache<NSString, UIImage>()

    var onImageLoaded: (() -> Void)?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private let timestampLabel = UILabel()
    private var timestampHeightConstraint: NSLayoutConstraint!
    // Formatted once in configure() so the tap-driven toggle never rebuilds a DateFormatter.
    private var timestampText: String?

    private let bubbleView = UIView()
    private let nameLabel = UILabel()
    private let contentLabel = UILabel()
    private let msgImageView = UIImageView()

    private var imageHeightConstraint: NSLayoutConstraint?
    // Stored separately so it can be toggled off for image messages,
    // avoiding a Required-priority conflict with msgImageView.bottom = bubbleView.bottom.
    private var textBottomConstraint: NSLayoutConstraint?
    private var bubbleLeading: NSLayoutConstraint?
    private var bubbleTrailing: NSLayoutConstraint?
    // Collapses the bubble-external name row to zero height for grouped / own messages,
    // mirroring the timestampHeightConstraint toggle pattern.
    private var nameHeightConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        timestampLabel.font = .systemFont(ofSize: 11)
        timestampLabel.textColor = .tertiaryLabel
        timestampLabel.textAlignment = .center
        timestampLabel.clipsToBounds = true
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.layer.cornerRadius = 16
        bubbleView.clipsToBounds = true
        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .secondaryLabel
        nameLabel.clipsToBounds = true
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        contentLabel.numberOfLines = 0
        contentLabel.font = .systemFont(ofSize: 16)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        msgImageView.contentMode = .scaleAspectFill
        msgImageView.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.addSubview(contentLabel)
        bubbleView.addSubview(msgImageView)
        contentView.addSubview(timestampLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(bubbleView)

        bubbleLeading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        bubbleTrailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        textBottomConstraint = contentLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -6)
        timestampHeightConstraint = timestampLabel.heightAnchor.constraint(equalToConstant: 0)
        nameHeightConstraint = nameLabel.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            timestampLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            timestampLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            timestampLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            timestampHeightConstraint,
            // Name now sits *above* the bubble, left-aligned to it — a Messenger-style
            // group header. Its height collapses to 0 (nameHeightConstraint) for grouped
            // and own messages, pulling the next bubble up tight.
            nameLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            contentLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 6),
            contentLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            msgImageView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            msgImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            msgImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            msgImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            bubbleView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.72),
            bubbleLeading!
        ])
    }

    func configure(with message: Message, isOwn: Bool, showSenderName: Bool = false, showTimestamp: Bool = false) {
        let isImage = message.type == "image"

        // Name heads a group: shown only for the first received message of a same-sender
        // run (grouping decided in ChatViewController). Own and image messages never show it.
        let shouldShowName = showSenderName && !isOwn && !isImage
        nameLabel.isHidden = !shouldShowName
        nameLabel.text = shouldShowName ? message.senderName : nil
        nameHeightConstraint?.isActive = !shouldShowName
        contentLabel.isHidden = isImage
        contentLabel.text = isImage ? nil : message.content
        msgImageView.isHidden = !isImage
        msgImageView.image = nil

        textBottomConstraint?.isActive = !isImage
        imageHeightConstraint?.isActive = false

        if isImage {
            let maxWidth = max(contentView.bounds.width * 0.72 - 24, 160)
            imageHeightConstraint = msgImageView.heightAnchor.constraint(equalToConstant: 160)
            imageHeightConstraint?.isActive = true
            loadImage(urlString: message.imageURL, displayWidth: maxWidth)
            bubbleView.backgroundColor = .systemBackground
        } else {
            bubbleView.backgroundColor = isOwn ? .systemBlue : .secondarySystemFill
        }
        
        contentLabel.textColor = isOwn ? .white : .label
        bubbleLeading?.isActive = !isOwn
        bubbleTrailing?.isActive = isOwn

        let time = MessageCell.timeFormatter.string(from: message.timestamp)
        if isOwn {
            // Own messages reveal delivery state alongside the time: read once the
            // other party has seen them, "sent" until then. Received messages show
            // only the time — your own read state there is meaningless.
            let key = message.isRead ? "chat.receipt.read" : "chat.receipt.sent"
            timestampText = "\(NSLocalizedString(key, comment: "")) · \(time)"
        } else {
            timestampText = time
        }
        setTimestampVisible(showTimestamp)
    }

    /// Sets the timestamp row's *target* state only — no animation here.
    /// The spring lives in ChatViewController, which calls this inside a
    /// UIView.animate(usingSpringWithDamping:) block wrapping performBatchUpdates(nil),
    /// so the height (via the constraint) and the alpha both animate with the spring.
    func setTimestampVisible(_ visible: Bool) {
        timestampLabel.text = timestampText
        timestampHeightConstraint.constant = visible ? 18 : 0
        timestampLabel.alpha = visible ? 1 : 0
    }

    private func loadImage(urlString: String?, displayWidth: CGFloat) {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        let key = urlString as NSString

        if let cached = MessageCell.imageCache.object(forKey: key) {
            applyImage(cached, displayWidth: displayWidth)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            MessageCell.imageCache.setObject(img, forKey: key)
            DispatchQueue.main.async {
                self?.applyImage(img, displayWidth: displayWidth)
                self?.onImageLoaded?()
            }
        }.resume()
    }

    private func applyImage(_ image: UIImage, displayWidth: CGFloat) {
        msgImageView.image = image
        let ratio = image.size.height / image.size.width
        imageHeightConstraint?.constant = min(displayWidth * ratio, 280)
    }
}
