//
//  LocalCacheManager.swift
//  Chatapp
//
//  Created by cbe112048 on 2026/6/10.
//

import Foundation

class LocalCacheManager {
    static let shared = LocalCacheManager()
    private init() {}

    private let fileManager = FileManager.default

    private func cacheURL(forConversation id: String) -> URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("cache_\(id).json")
    }

    func saveMessages(_ messages: [Message], forConversation id: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        guard let data = try? encoder.encode(messages) else { return }
        try? data.write(to: cacheURL(forConversation: id))
    }

    func loadMessages(forConversation id: String) -> [Message] {
        let url = cacheURL(forConversation: id)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return (try? decoder.decode([Message].self, from: data)) ?? []
    }
}
