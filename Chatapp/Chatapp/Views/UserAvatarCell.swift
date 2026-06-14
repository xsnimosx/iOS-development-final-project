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
        tf.font = UIFont.preferredFont(forTextStyle: .headline)
        tf.borderStyle = .none
        tf.returnKeyType = .done
        tf.autocorrectionType = .no
        tf.isHidden = true
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImageView.tintColor = AppCell.avatarTint
        avatarImageView.clipsToBounds = true

        contentView.addSubview(usernameField)
        NSLayoutConstraint.activate([
            usernameField.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            usernameField.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            usernameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
        ])
        usernameField.delegate = self

        let tap = UITapGestureRecognizer(target: self, action: #selector(nameLabelTapped))
        nameLabel.isUserInteractionEnabled = true
        nameLabel.addGestureRecognizer(tap)
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

    @objc private func nameLabelTapped() {
        preEditUsername = nameLabel.text ?? ""
        usernameField.text = preEditUsername
        nameLabel.isHidden = true
        usernameField.isHidden = false
        usernameField.becomeFirstResponder()
    }

    private func confirmEdit() {
        let input = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let finalName = input.isEmpty ? preEditUsername : input
        nameLabel.text = finalName
        nameLabel.isHidden = false
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
