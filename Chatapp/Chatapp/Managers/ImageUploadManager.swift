//
//  ImageUploadManager.swift
//  Chatapp
//
//  Created by cbe112048 on 2026/6/10.
//

import UIKit
import FirebaseStorage

class ImageUploadManager {
    static let shared = ImageUploadManager()
    private init() {}

    func uploadImage(_ image: UIImage, completion: @escaping (String?) -> Void) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }

        let filename = "\(UUID().uuidString).jpg"
        let ref = Storage.storage().reference().child("images/\(filename)")

        ref.putData(data, metadata: nil) { _, error in
            if let error = error {
                print("圖片上傳失敗：\(error)")
                completion(nil)
                return
            }
            ref.downloadURL { url, error in
                if let error = error {
                    print("取得 URL 失敗：\(error)")
                    completion(nil)
                    return
                }
                completion(url?.absoluteString)
            }
        }
    }
}
