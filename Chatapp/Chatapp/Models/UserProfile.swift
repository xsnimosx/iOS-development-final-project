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
    let displayName: String
}
