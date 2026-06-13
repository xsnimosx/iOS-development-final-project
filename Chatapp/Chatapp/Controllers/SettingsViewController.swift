//
//  SettingsViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SettingsViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateProfileCell()
    }

    private func updateProfileCell() {
        guard let user = Auth.auth().currentUser else { return }
        let indexPath = IndexPath(row: 0, section: 0)
        guard let cell = tableView.cellForRow(at: indexPath) as? UserAvatarCell else { return }

        Firestore.firestore().collection("users").document(user.uid)
            .getDocument { [weak cell] snap, _ in
                let profile = try? snap?.data(as: UserProfile.self)
                DispatchQueue.main.async {
                    cell?.configure(
                        name: profile?.displayName ?? user.displayName ?? "",
                        detail: user.email
                    )
                }
            }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "toLogin" {
            do {
                try Auth.auth().signOut()
            } catch {
                showAlert(String(format: NSLocalizedString("settings.error.signOutFailed", comment: ""), error.localizedDescription))
                return false
            }
        }
        return true
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("settings.alert.ok", comment: ""), style: .default))
        present(alert, animated: true)
    }
}
