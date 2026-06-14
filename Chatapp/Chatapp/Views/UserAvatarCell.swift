import UIKit

class UserAvatarCell: UITableViewCell {
    static let reuseId = "UserAvatarCell"

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!

    var onUsernameConfirmed: ((String) -> Void)?

    private var preEditUsername: String = ""

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
        nameLabel.text = name
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil || detail!.isEmpty
    }

    func startEditing() {
        preEditUsername = nameLabel.text ?? ""
        usernameField.text = preEditUsername
        nameLabel.alpha = 0
        detailLabel.alpha = 0
        usernameField.isHidden = false
        usernameField.becomeFirstResponder()
    }

    private func confirmEdit() {
        let trimmed = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let finalName = trimmed.isEmpty ? preEditUsername : trimmed
        nameLabel.text = finalName
        nameLabel.alpha = 1
        detailLabel.alpha = 1
        usernameField.isHidden = true
        usernameField.resignFirstResponder()
        if finalName != preEditUsername {
            onUsernameConfirmed?(finalName)
        }
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
