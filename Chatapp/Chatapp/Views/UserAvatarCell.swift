import UIKit

class UserAvatarCell: UITableViewCell {
    static let reuseId = "UserAvatarCell"

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!

    var onUsernameConfirmed: ((String) -> Void)?

    private var preEditUsername: String = ""
    private var savedDetailHidden: Bool = false

    private let usernameField: UITextField = {
        let tf = UITextField()
        tf.font = UIFont.boldSystemFont(ofSize: 17)
        tf.borderStyle = .none
        tf.returnKeyType = .done
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.isHidden = true
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        avatarImageView.tintColor = AppCell.avatarTint
        avatarImageView.clipsToBounds = true

        contentView.addSubview(usernameField)
        NSLayoutConstraint.activate([
            usernameField.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameField.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            usernameField.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        usernameField.delegate = self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2
    }

    func configure(name: String, detail: String? = nil) {
        nameLabel.attributedText = makeNameText(name)
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil || detail!.isEmpty
    }

    func startEditing() {
        preEditUsername = nameLabel.attributedText?.string
            .components(separatedBy: "  ").first ?? nameLabel.text ?? ""
        savedDetailHidden = detailLabel.isHidden
        usernameField.placeholder = preEditUsername
        usernameField.text = ""
        nameLabel.isHidden = true
        detailLabel.isHidden = true
        usernameField.isHidden = false
        usernameField.becomeFirstResponder()
    }

    private func confirmEdit() {
        let trimmed = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let isValid = isValidUsername(trimmed)
        let finalName = isValid ? trimmed : preEditUsername
        nameLabel.attributedText = makeNameText(finalName)
        nameLabel.isHidden = false
        detailLabel.isHidden = savedDetailHidden
        usernameField.isHidden = true
        usernameField.resignFirstResponder()
        if isValid && finalName != preEditUsername {
            onUsernameConfirmed?(finalName)
        }
    }

    private func isValidUsername(_ name: String) -> Bool {
        guard !name.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        return name.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    private func makeNameText(_ name: String) -> NSAttributedString {
        let font = nameLabel.font ?? UIFont.boldSystemFont(ofSize: 17)
        let iconSize = font.pointSize * 0.65
        let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .regular)
        let icon = UIImage(systemName: "pencil", withConfiguration: config)?
            .withTintColor(.tertiaryLabel, renderingMode: .alwaysOriginal)
        let attachment = NSTextAttachment()
        attachment.image = icon

        let result = NSMutableAttributedString(
            string: name + "  ", attributes: [.font: font])
        result.append(NSAttributedString(attachment: attachment))
        return result
    }
}

extension UserAvatarCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        confirmEdit()
        return false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard !usernameField.isHidden else { return }
        confirmEdit()
    }
}
