import UIKit

class ConversationCell: UITableViewCell {

    @IBOutlet weak var avatarImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!

    // 每列未讀數字徽章(程式碼建立,storyboard 無對應元件)
    private let unreadBadgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.backgroundColor = .systemRed
        label.textAlignment = .center
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // 「messageLabel 不要壓到徽章」的約束 —— 只在有未讀時啟用,
    // 沒未讀時停用讓預覽文字延伸到貼邊。
    private var messageTrailingToBadge: NSLayoutConstraint!

    override func awakeFromNib() {
        super.awakeFromNib()
        avatarImageView.tintColor = AppCell.avatarTint
        avatarImageView.clipsToBounds = true
        setupUnreadBadge()
    }

    private func setupUnreadBadge() {
        contentView.addSubview(unreadBadgeLabel)

        // 停用 storyboard 裡 messageLabel 釘在 contentView 右緣的約束,
        // 改由我們的低優先權版本(留邊)+ 高優先權避讓徽章版本接手。
        if let storyboardTrailing = contentView.constraints.first(where: { c in
            (c.firstItem === messageLabel && c.firstAttribute == .trailing && c.secondItem === contentView)
                || (c.secondItem === messageLabel && c.secondAttribute == .trailing && c.firstItem === contentView)
        }) {
            storyboardTrailing.isActive = false
        }

        let messageTrailingToEdge = messageLabel.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor, constant: -16)
        messageTrailingToEdge.priority = .defaultHigh   // 750:無徽章時生效

        messageTrailingToBadge = messageLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: unreadBadgeLabel.leadingAnchor, constant: -8)
        messageTrailingToBadge.isActive = false          // 有未讀時才啟用(required 1000)

        NSLayoutConstraint.activate([
            messageTrailingToEdge,
            unreadBadgeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            unreadBadgeLabel.centerYAnchor.constraint(equalTo: messageLabel.centerYAnchor),
            unreadBadgeLabel.heightAnchor.constraint(equalToConstant: 20),
            unreadBadgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2
        unreadBadgeLabel.layer.cornerRadius = unreadBadgeLabel.bounds.height / 2
    }

    func configure(with conversation: Conversation) {
        nameLabel.text = conversation.otherUserName
        messageLabel.text = conversation.lastMessage
        timeLabel.text = timeString(from: conversation.timestamp)

        let unread = conversation.unreadCount
        if unread > 0 {
            unreadBadgeLabel.isHidden = false
            // 兩位數以上補空白維持膠囊外觀
            unreadBadgeLabel.text = unread > 9 ? " \(unread) " : "\(unread)"
            messageTrailingToBadge.isActive = true
            nameLabel.font = .boldSystemFont(ofSize: 17)
            // 未讀:預覽文字從灰(secondaryLabel)提亮為主要文字色並加重,
            // 模仿 iMessage/WhatsApp「亮起來」的視覺權重。
            messageLabel.textColor = .label
            messageLabel.font = .systemFont(ofSize: 14, weight: .medium)
        } else {
            unreadBadgeLabel.isHidden = true
            messageTrailingToBadge.isActive = false
            nameLabel.font = .boldSystemFont(ofSize: 17)
            // 已讀:還原 storyboard 原本的灰字、一般字重(cell 會被重用,務必還原)
            messageLabel.textColor = .secondaryLabel
            messageLabel.font = .systemFont(ofSize: 14, weight: .regular)
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "MM/dd"
        return formatter.string(from: date)
    }
}
