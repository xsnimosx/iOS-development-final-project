import UIKit

// MARK: - Shared appearance constants

enum AppCell {
    static let avatarSize: CGFloat = 44
    static let avatarTint: UIColor = .systemBrown
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let avatarLabelSpacing: CGFloat = 12
}

// MARK: - UserRowCell

/// Programmatic base cell: avatar (44pt circle) + vertical label stack (name + optional detail).
/// Subclasses may call setupBase() via init, then add their own accessories and adjust
/// labelStackTrailingConstraint before activating additional constraints.
class UserRowCell: UITableViewCell {

    let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "person.crop.circle.fill")
        iv.tintColor = AppCell.avatarTint
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    let nameLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.boldSystemFont(ofSize: 17)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let detailLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    let labelStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 2
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    /// Subclasses deactivate this and replace it to accommodate trailing accessories.
    var labelStackTrailingConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupBase()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBase()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2
    }

    func setupBase() {
        labelStack.addArrangedSubview(nameLabel)
        labelStack.addArrangedSubview(detailLabel)
        contentView.addSubview(avatarImageView)
        contentView.addSubview(labelStack)

        labelStackTrailingConstraint = labelStack.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor, constant: -AppCell.horizontalPadding)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppCell.horizontalPadding),
            avatarImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppCell.verticalPadding),
            avatarImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppCell.verticalPadding),
            avatarImageView.widthAnchor.constraint(equalToConstant: AppCell.avatarSize),
            avatarImageView.heightAnchor.constraint(equalToConstant: AppCell.avatarSize),

            labelStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: AppCell.avatarLabelSpacing),
            labelStackTrailingConstraint,
            labelStack.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),
        ])
    }

    func configure(name: String, detail: String? = nil) {
        nameLabel.text = name
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil || detail!.isEmpty
    }
}

// MARK: - AddFriendUserCell

class AddFriendUserCell: UserRowCell {
    static let reuseId = "AddFriendUserCell"
}
