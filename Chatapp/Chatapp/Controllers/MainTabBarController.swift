//
//  MainTabBarController.swift
//  Chatapp

import UIKit

class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let titles = [
            NSLocalizedString("tab.chats", comment: ""),
            NSLocalizedString("tab.friends", comment: ""),
            NSLocalizedString("tab.settings", comment: ""),
        ]
        zip(viewControllers ?? [], titles).forEach { vc, title in
            vc.tabBarItem.title = title
        }

        // Tab bar 的子 VC 預設是「懶載入」:沒被選取過的 tab,其 view 不會載入,
        // viewDidLoad 不執行 → 該畫面註冊的 Firestore listener 不會啟動。
        // 這正是「Friends 紅點要先點過該 tab 才更新」的根因(Chats 是第 0 個 tab,
        // 啟動即載入所以正常)。啟動時主動載入每個 tab 的 root view,
        // 讓各畫面的 badge listener 一律即時上線,不必等使用者造訪。
        viewControllers?.forEach {
            ($0 as? UINavigationController)?.viewControllers.first?.loadViewIfNeeded()
        }
    }
}
