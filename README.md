# Chatapp

A real-time iOS messaging application built as a university final project. Supports one-on-one text and image messaging, a friend request system, and live unread-count badges — all backed by Firebase.

---

## Features

- **Authentication** — Email/password sign-up and sign-in via Firebase Auth, with persistent sessions
- **Real-time messaging** — One-on-one text and image messages with read receipts and live updates
- **Friend system** — Send, accept, decline, or remove friend requests; search by email or username
- **Unread badges** — Tab bar badges update in real time as messages arrive
- **Media preview** — Full-screen image viewer with swipe-to-dismiss
- **Local cache** — Conversations cached locally as JSON for faster loads
- **Localization** — English and Traditional Chinese (zh-Hant)

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 15.4+ |
| iOS Deployment Target | 14.2+ |
| Swift | 5.0 |

---

## Setup

1. **Clone the repository**

   ```bash
   git clone "https://github.com/xsnimosx/iOS-development-final-project"
   ```

2. **Resolve Swift Package dependencies**

   Open `Chatapp.xcodeproj` in Xcode. SPM resolves Firebase packages automatically on first open (File → Packages → Resolve Package Versions if needed).

4. **Select a simulator or device and run** (`Cmd+R`)

---

## Architecture

The app follows **MVC** with Firebase as the real-time backend.

```
Chatapp/
├── Controllers/        # UIViewController subclasses
│   ├── ChatViewController.swift
│   ├── ChatListViewController.swift
│   ├── FriendsViewController.swift
│   ├── AddFriendViewController.swift
│   ├── LoginViewController.swift
│   ├── SettingsViewController.swift
│   ├── MainTabBarController.swift
│   └── MediaPreviewViewController.swift
├── Models/             # Codable structs mapped to Firestore documents
│   ├── Message.swift
│   ├── UserProfile.swift
│   └── FriendRequest.swift
├── Views/              # UITableViewCell subclasses and custom views
│   ├── MessageCell.swift
│   ├── ConversationCell.swift
│   ├── UserRowCell.swift
│   └── UserAvatarCell.swift
├── Managers/           # Singleton utilities
│   ├── ImageUploadManager.swift
│   └── LocalCacheManager.swift
└── Resources/
    ├── GoogleService-Info.plist   # Firebase config
    ├── Assets.xcassets
    ├── en.lproj/
    └── zh-Hant.lproj/
```

### Key design decisions

- **Tab pre-loading** — `MainTabBarController` instantiates all child view controllers at launch so Firestore listeners activate immediately, keeping badge counts accurate even before the user switches tabs.
- **Lifecycle-tied listeners** — Firestore snapshot listeners are attached in `viewWillAppear` / `viewDidDisappear` where appropriate; the chat-list and friends listeners are kept alive across navigation pushes to avoid missing updates.
- **Self-sizing message cells** — `MessageCell` uses constraint priorities rather than explicit height calculations so mixed text/image rows resize without manual math.

---

## Firestore Schema

```
users/{uid}
  displayName: String
  email: String

conversations/{conversationId}
  participants: [String]               # UIDs
  participantNames: {uid: displayName}
  lastMessage: String
  lastUpdated: Timestamp
  unreadCounts: {uid: Number}

  messages/{messageId}
    senderId: String
    senderName: String
    content: String
    type: "text" | "image"
    imageURL: String?
    imageWidth: Number?
    imageHeight: Number?
    timestamp: Timestamp
    isRead: Bool

friendRequests/{requestId}
  fromUID: String
  toUID: String
  status: "pending" | "accepted" | "declined"
```

---

## Dependencies

Managed via Swift Package Manager.

| Package | Purpose |
|---------|---------|
| `FirebaseAuth` | Email/password authentication |
| `FirebaseFirestore` | Real-time cloud database |
| `FirebaseStorage` | Image file storage |
| `FirebaseAnalytics` | Usage analytics |

---

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file.
