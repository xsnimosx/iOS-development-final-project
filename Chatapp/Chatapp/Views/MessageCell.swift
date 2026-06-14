import UIKit

class MessageCell: UITableViewCell {
    static let reuseId = "MessageCell"

    private let bubbleView = UIView()
    private let nameLabel = UILabel()
    private let contentLabel = UILabel()
    private let msgImageView = UIImageView()

    private var imageHeightConstraint: NSLayoutConstraint?
    private var bubbleLeading: NSLayoutConstraint?
    private var bubbleTrailing: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        bubbleView.layer.cornerRadius = 12
        bubbleView.clipsToBounds = true
        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .secondaryLabel
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        contentLabel.numberOfLines = 0
        contentLabel.font = .systemFont(ofSize: 15)
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        msgImageView.contentMode = .scaleAspectFill
        msgImageView.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.addSubview(nameLabel)
        bubbleView.addSubview(contentLabel)
        bubbleView.addSubview(msgImageView)
        contentView.addSubview(bubbleView)

        bubbleLeading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        bubbleTrailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            contentLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            contentLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -10),
            contentLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -6),
            msgImageView.topAnchor.constraint(equalTo: bubbleView.topAnchor),
            msgImageView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor),
            msgImageView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor),
            msgImageView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor),
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.72),
            bubbleLeading!
        ])
    }

    func configure(with message: Message, isOwn: Bool) {
        let isImage = message.type == "image"
        nameLabel.isHidden = isOwn || isImage
        nameLabel.text = isOwn ? nil : message.senderName
        contentLabel.isHidden = isImage
        contentLabel.text = isImage ? nil : message.content
        msgImageView.isHidden = !isImage
        msgImageView.image = nil
        imageHeightConstraint?.isActive = false
        if isImage {
            imageHeightConstraint = msgImageView.heightAnchor.constraint(equalToConstant: 180)
            imageHeightConstraint?.isActive = true
        }
        if isImage, let urlString = message.imageURL, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { return }
                DispatchQueue.main.async { self?.msgImageView.image = img }
            }.resume()
        }
        bubbleView.backgroundColor = isOwn ? .systemBlue : .secondarySystemFill
        contentLabel.textColor = isOwn ? .white : .label
        nameLabel.textColor = isOwn ? .white : .secondaryLabel
        bubbleLeading?.isActive = !isOwn
        bubbleTrailing?.isActive = isOwn
    }
}
