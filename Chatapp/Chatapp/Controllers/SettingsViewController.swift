//
//  SettingsViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SettingsViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("settings.nav.title", comment: "")
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
            .getDocument { [weak cell, weak self] snap, _ in
                let profile = try? snap?.data(as: UserProfile.self)
                DispatchQueue.main.async {
                    cell?.configure(
                        name: profile?.username ?? user.displayName ?? "",
                        detail: user.email
                    )
                    cell?.onUsernameConfirmed = { [weak self] newName in
                        self?.saveUsername(newName)
                    }
                }
            }
    }

    private func saveUsername(_ name: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid)
            .updateData(["displayName": name]) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.showAlert(String(format: NSLocalizedString("settings.error.signOutFailed", comment: ""), error.localizedDescription))
                    }
                }
            }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return NSLocalizedString("settings.section.profile", comment: "")
        case 1: return NSLocalizedString("settings.section.logout", comment: "")
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = self.tableView(tableView, titleForHeaderInSection: section) else { return nil }

        let label = UILabel()
        label.text = title
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor = .secondaryLabel

        let container = UIView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])
        return container
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.section == 1, indexPath.row == 0 {
            cell.contentView.subviews.compactMap { $0 as? UILabel }.first?.text =
                NSLocalizedString("settings.cell.logout", comment: "")
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
