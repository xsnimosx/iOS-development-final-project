//
//  UserProfile.swift
//  Chatapp
//
//  Created by snimos on 2026/5/13.
//

import Foundation
import FirebaseFirestore

struct UserProfile: Codable {
    @DocumentID var id: String?
    let email: String
    let username: String

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case username = "displayName"
    }
}
