import Foundation

struct Message: Codable {

    let id: String
    let conversationId: String
    let senderId: String
    let content: String
    let type: String
    let imageURL: String?
    let timestamp: Date
    let isRead: Bool
}