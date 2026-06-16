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

    // Image bubble: fixed 72% width + a NUMERIC constant height computed from the image's
    // aspect (clamped). A constant — not a multiplier-aspect constraint — so self-sizing
    // never fights UIView-Encapsulated-Layout-Height (the cause of the earlier crash storm).
    private static let minImageRatio: CGFloat = 9.0 / 20.0   // widest: landscape 20:9
    private static let maxImageRatio: CGFloat = 20.0 / 9.0   // tallest: portrait 9:20
    private var bubbleImageWidth: NSLayoutConstraint?
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
        // configure() leaves exactly one side pin active, but a cell-reuse/self-sizing race
        // can momentarily catch both active, over-constraining width against the 72% cap
        // (the "bubble jumps wide" flake). Below required, the cap always wins silently.
        bubbleLeading?.priority = UILayoutPriority(999)
        bubbleTrailing?.priority = UILayoutPriority(999)
        bubbleImageWidth = bubbleView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.72)
        imageHeightConstraint = bubbleView.heightAnchor.constraint(equalToConstant: 0)
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
        bubbleImageWidth?.isActive = isImage
        imageHeightConstraint?.isActive = isImage

        if isImage {
            // Reserve the correct box up front from the stored dimensions. Legacy messages
            // (no dims) use a 4:3 placeholder, settled in applyImage once the image lands.
            let aspect: CGFloat
            if let w = message.imageWidth, let h = message.imageHeight, w > 0 {
                aspect = CGFloat(h) / CGFloat(w)
            } else {
                aspect = 0.75
            }
            imageHeightConstraint?.constant = MessageCell.clampedImageHeight(aspect: aspect)
            loadImage(urlString: message.imageURL)
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

    /// Height (points) of a 72%-width image bubble for a given aspect (height/width),
    /// clamped to the allowed range. A plain number — recomputed per configure, never a
    /// multiplier-aspect constraint, so it can't fight the table's self-sizing height.
    private static func clampedImageHeight(aspect: CGFloat) -> CGFloat {
        let maxW = UIScreen.main.bounds.width * 0.72
        return maxW * min(max(aspect, minImageRatio), maxImageRatio)
    }

    private func loadImage(urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        let key = urlString as NSString

        if let cached = MessageCell.imageCache.object(forKey: key) {
            applyImage(cached)            // sync: cell is sized correctly before it returns
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            MessageCell.imageCache.setObject(img, forKey: key)
            DispatchQueue.main.async {
                // Only refresh the row height if the real aspect differs from what we
                // reserved up front — i.e. legacy messages that had no stored dimensions.
                if self?.applyImage(img) == true { self?.onImageLoaded?() }
            }
        }.resume()
    }

    @discardableResult
    private func applyImage(_ image: UIImage) -> Bool {
        msgImageView.image = image
        let newH = MessageCell.clampedImageHeight(aspect: image.size.height / image.size.width)
        guard let c = imageHeightConstraint, abs(c.constant - newH) > 0.5 else { return false }
        c.constant = newH
        return true
    }
}
