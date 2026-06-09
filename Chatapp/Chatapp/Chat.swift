//
//  Chat.swift
//  Chatapp
//
//  Created by  serene on 2026/6/10.
//

import Foundation
import SwiftUI
import Firebase

@main
struct ChatApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
