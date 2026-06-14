//
//  FriendRequest.swift
//  Chatapp
//

import Foundation
import FirebaseFirestore

struct FriendRequest: Codable {
    @DocumentID var id: String?
    let fromUID: String
    let toUID: String
    let fromName: String
    var status: String
    let createdAt: Date
}
