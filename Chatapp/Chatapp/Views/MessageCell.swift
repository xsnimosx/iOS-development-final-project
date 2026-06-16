import UIKit

// This file hosts the chat-row cell hierarchy:
//
//   MessageBubbleCell (base) ── shared chrome: tap-revealed timestamp/receipt row,
//   │                           bubble container, side alignment, bottom pin.
//   ├── TextMessageCell  ── name header + multi-line label; bubble height = text intrinsic.
//   └── ImageMessageCell ── image filling a fixed-72%-width bubble of constant height.
//
// Design rule that keeps self-sizing stable: there is NO runtime activate/deactivate of
// layout constraints anywhere below. Every per-message variation (timestamp shown, name
// shown, own-vs-other side, image height) is expressed as a *constant* or a *priority*
// change on an always-active constraint. A single cell that toggled a text-vs-image
// height constraint at configure() time had a measurement window where the bubble's top
// was pinned but its height was undetermined — self-sizing caught it there and the bubble
// floated to centre. Splitting into two cells, each owning one static height determinant,
// removes that window entirely.

// MARK: - Base

class MessageBubbleCell: UITableViewCell {

    let bubbleView = UIView()
    let timestampLabel = UILabel()

    private var timestampHeightConstraint: NSLayoutConstraint!
    // Both side pins stay active for the cell's whole life; configureChrome() flips their
    // priorities to choose the side. Re-prioritising an active, non-required constraint is
    // legal and — unlike toggling isActive — never leaves a measurement window where the
    // bubble's x-position is undetermined (the old "bubble jumps wide" flake).
    private var alignLeading: NSLayoutConstraint!
    private var alignTrailing: NSLayoutConstraint!

    private var timestampText: String?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupBase()
        setupContent()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Anchor a subclass hangs the bubble (or its name row) below.
    var headerBottomAnchor: NSLayoutYAxisAnchor { timestampLabel.bottomAnchor }

    /// Subclass hook: add views into `bubbleView`, pin `bubbleView.topAnchor` into the
    /// vertical chain, and install the ONE constraint that fixes the bubble's height.
    func setupContent() {}

    private func setupBase() {
        timestampLabel.font = .systemFont(ofSize: 11)
        timestampLabel.textColor = .tertiaryLabel
        timestampLabel.textAlignment = .center
        timestampLabel.clipsToBounds = true
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.layer.cornerRadius = 16
        bubbleView.clipsToBounds = true
        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(timestampLabel)
        contentView.addSubview(bubbleView)

        timestampHeightConstraint = timestampLabel.heightAnchor.constraint(equalToConstant: 0)

        // The bubble's bottom pin closes a vertical chain that must equal the cell height.
        // UITableView pixel-aligns its injected UIView-Encapsulated-Layout-Height (e.g.
        // 218.6 → 218.667 at @3x), so a fully *required* chain is always a hair off and
        // logs a conflict on every cell. At 999 the table's rounded height wins and this
        // one constraint yields the sub-pixel silently — the canonical self-sizing fix.
        let bubbleBottom = bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
        bubbleBottom.priority = UILayoutPriority(999)

        // Margins (required) + 72% width cap (required) bound the bubble; the equality on
        // the *chosen* side wins by priority, the other side's equality yields silently.
        alignLeading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        alignTrailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)

        NSLayoutConstraint.activate([
            timestampLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            timestampLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            timestampLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            timestampHeightConstraint,

            bubbleView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 12),
            bubbleView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.72),
            alignLeading,
            alignTrailing,
            bubbleBottom,
        ])
    }

    /// Sets the bubble's horizontal side and the timestamp/receipt text. Subclasses call
    /// this first from their own configure(...).
    func configureChrome(message: Message, isOwn: Bool, showTimestamp: Bool) {
        // Flip side by priority — both pins stay active. The winning equality glues the
        // bubble to its edge; the losing one (priority 250) yields against the 72% cap.
        alignLeading.priority = isOwn ? UILayoutPriority(250) : UILayoutPriority(999)
        alignTrailing.priority = isOwn ? UILayoutPriority(999) : UILayoutPriority(250)

        let time = MessageBubbleCell.timeFormatter.string(from: message.timestamp)
        if isOwn {
            // Own messages carry delivery state next to the time: read once the other
            // party has seen them, "unread" until then. Received messages show only time.
            let key = message.isRead ? "chat.receipt.read" : "chat.receipt.sent"
            timestampText = "\(NSLocalizedString(key, comment: "")) · \(time)"
        } else {
            timestampText = time
        }
        setTimestampVisible(showTimestamp)
    }

    /// Sets the timestamp row's target state only — no animation here. ChatViewController
    /// calls this inside a spring UIView.animate wrapping performBatchUpdates(nil), so the
    /// row-height delta (via the constant) and the alpha both animate with the bounce.
    func setTimestampVisible(_ visible: Bool) {
        timestampLabel.text = timestampText
        timestampHeightConstraint.constant = visible ? 18 : 0
        timestampLabel.alpha = visible ? 1 : 0
    }
}

// MARK: - Text

final class TextMessageCell: MessageBubbleCell {
    static let reuseId = "TextMessageCell"

    private let nameLabel = UILabel()
    private let contentLabel = UILabel()
    // Collapses the bubble-external name row via a constant toggle (0 ↔ 15) — the same
    // safe mechanism as the timestamp row, never isActive.
    private var nameHeightConstraint: NSLayoutConstraint!

    override func setupContent() {
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .secondaryLabel
        nameLabel.clipsToBounds = true
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        contentLabel.numberOfLines = 0
        contentLabel.font = .systemFont(ofSize: 16)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        // Hug horizontally so the bubble shrinks to the text. Must out-prioritise the
        // losing-side alignment equality (250), which otherwise stretches the bubble
        // toward the 72% cap. Stays below the required cap, so long text still wraps.
        contentLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        contentView.addSubview(nameLabel)
        bubbleView.addSubview(contentLabel)

        nameHeightConstraint = nameLabel.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // Name sits above the bubble, left-aligned to it — a Messenger-style group header.
            nameLabel.topAnchor.constraint(equalTo: headerBottomAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 4),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
            nameHeightConstraint,

            bubbleView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),

            // Bubble height = the label's intrinsic height (this static chain is the
            // bubble's single height determinant).
            contentLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 6),
            contentLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            contentLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -6),
        ])
    }

    func configure(with message: Message, isOwn: Bool, showSenderName: Bool = false, showTimestamp: Bool = false) {
        configureChrome(message: message, isOwn: isOwn, showTimestamp: showTimestamp)

        // Name heads a group: shown only for the first received message of a same-sender run.
        let shouldShowName = showSenderName && !isOwn
        nameLabel.isHidden = !shouldShowName
        nameLabel.text = shouldShowName ? message.senderName : nil
        nameHeightConstraint.constant = shouldShowName ? 15 : 0

        contentLabel.text = message.content
        contentLabel.textColor = isOwn ? .white : .label
        bubbleView.backgroundColor = isOwn ? .systemBlue : .secondarySystemFill
    }
}

// MARK: - Image

final class ImageMessageCell: MessageBubbleCell {
    static let reuseId = "ImageMessageCell"

    private static let imageCache = NSCache<NSString, UIImage>()
    private static let minImageRatio: CGFloat = 9.0 / 20.0   // widest: landscape 20:9
    private static let maxImageRatio: CGFloat = 20.0 / 9.0   // tallest: portrait 9:20

    var onImageLoaded: (() -> Void)?

    private let msgImageView = UIImageView()
    // The bubble's single, always-active height determinant: a NUMERIC constant computed
    // from the image's (clamped) aspect — never an aspect-multiplier constraint, so it
    // can't fight UIView-Encapsulated-Layout-Height the way the old design did.
    private var imageHeightConstraint: NSLayoutConstraint!

    override func setupContent() {
        msgImageView.contentMode = .scaleAspectFill
        msgImageView.clipsToBounds = true
        msgImageView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(msgImageView)

        imageHeightConstraint = bubbleView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: headerBottomAnchor, constant: 2),
            // Fixed 72% width (equality, overriding the base's ≤72% cap which it satisfies).
            bubbleView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.72),
            imageHeightConstraint,

            msgImageView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            msgImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            msgImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            msgImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
        ])
    }

    func configure(with message: Message, isOwn: Bool, showTimestamp: Bool = false) {
        configureChrome(message: message, isOwn: isOwn, showTimestamp: showTimestamp)

        bubbleView.backgroundColor = .systemBackground
        msgImageView.image = nil

        // Reserve the correct box up front from stored dimensions. Legacy messages (no
        // dims) use a 4:3 placeholder, settled in applyImage once the image lands.
        let aspect: CGFloat
        if let w = message.imageWidth, let h = message.imageHeight, w > 0 {
            aspect = CGFloat(h) / CGFloat(w)
        } else {
            aspect = 0.75
        }
        imageHeightConstraint.constant = ImageMessageCell.clampedImageHeight(aspect: aspect)
        loadImage(urlString: message.imageURL)
    }

    /// Height (points) of a 72%-width image bubble for a given aspect (height/width),
    /// clamped to the allowed range. A plain number, recomputed per configure.
    private static func clampedImageHeight(aspect: CGFloat) -> CGFloat {
        let maxW = UIScreen.main.bounds.width * 0.72
        return maxW * min(max(aspect, minImageRatio), maxImageRatio)
    }

    private func loadImage(urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        let key = urlString as NSString

        if let cached = ImageMessageCell.imageCache.object(forKey: key) {
            applyImage(cached)            // sync: cell is sized correctly before it returns
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            ImageMessageCell.imageCache.setObject(img, forKey: key)
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
        let newH = ImageMessageCell.clampedImageHeight(aspect: image.size.height / image.size.width)
        guard abs(imageHeightConstraint.constant - newH) > 0.5 else { return false }
        imageHeightConstraint.constant = newH
        return true
    }
}
