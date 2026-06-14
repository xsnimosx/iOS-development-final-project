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
    }
}
