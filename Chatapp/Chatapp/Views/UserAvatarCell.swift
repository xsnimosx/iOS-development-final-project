import UIKit

class UserAvatarCell: UITableViewCell {
    static let reuseId = "UserAvatarCell"

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImageView.layer.cornerRadius = 24
        avatarImageView.clipsToBounds = true
    }

    func configure(name: String, detail: String? = nil) {
        nameLabel.text = name
        detailLabel.text = detail
        detailLabel.isHidden = detail == nil || detail!.isEmpty
    }
}
