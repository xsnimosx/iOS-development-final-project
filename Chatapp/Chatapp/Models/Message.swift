//
//  Message.swift
//  Chatapp
//
//  Created by snimos on 2026/5/13.
//

import Foundation
import FirebaseFirestore

struct Message: Codable {
    @DocumentID var id: String?
    let senderId: String
    let senderName: String
    let content: String
    let type: String
    var imageURL: String?
    let timestamp: Date
    var isRead: Bool
}
