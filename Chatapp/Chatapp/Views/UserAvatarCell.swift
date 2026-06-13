import UIKit

class UserAvatarCell: UITableViewCell {
    static let reuseId = "UserAvatarCell"

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImageView.tintColor = AppCell.avatarTint
        avatarImageView.clipsToBounds = true
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
}
