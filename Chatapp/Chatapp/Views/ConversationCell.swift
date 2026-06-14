import UIKit

class ConversationCell: UITableViewCell {

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImageView.tintColor = AppCell.avatarTint
        avatarImageView.clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2
    }

    func configure(with conversation: Conversation) {
        nameLabel.text = conversation.otherUserName
        messageLabel.text = conversation.lastMessage
        timeLabel.text = timeString(from: conversation.timestamp)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "MM/dd"
        return formatter.string(from: date)
    }
}
