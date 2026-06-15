//
//  SettingsViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SettingsViewController: UITableViewController {

    private var logoutConfirmed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("settings.nav.title", comment: "")

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapToDismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)
    }

    @objc private func handleTapToDismissKeyboard() {
        tableView.endEditing(true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateProfileCell()
    }

    private func updateProfileCell() {
        guard let user = Auth.auth().currentUser else { return }
        let indexPath = IndexPath(row: 0, section: 0)

        if let cell = tableView.cellForRow(at: indexPath) as? UserAvatarCell {
            cell.onUsernameConfirmed = { [weak self] newName in
                self?.saveUsername(newName)
            }
        }

        Firestore.firestore().collection("users").document(user.uid)
            .getDocument { [weak self] snap, _ in
                let profile = try? snap?.data(as: UserProfile.self)
                DispatchQueue.main.async {
                    guard let self = self,
                          let cell = self.tableView.cellForRow(at: indexPath) as? UserAvatarCell else { return }
                    cell.configure(
                        name: profile?.username ?? user.displayName ?? "",
                        detail: user.email
                    )
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
        if indexPath.section == 0, indexPath.row == 0,
           let cell = tableView.cellForRow(at: indexPath) as? UserAvatarCell {
            cell.startEditing()
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "toLogin" {
            if logoutConfirmed {
                logoutConfirmed = false
                return true
            }
            showLogoutConfirmation()
            return false
        }
        return true
    }

    private func showLogoutConfirmation() {
        let alert = UIAlertController(
            title: NSLocalizedString("settings.logout.confirmation.title", comment: ""),
            message: NSLocalizedString("settings.logout.confirmation.message", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("settings.logout.confirmation.cancel", comment: ""),
            style: .cancel
        ))
        alert.addAction(UIAlertAction(
            title: NSLocalizedString("settings.logout.confirmation.confirm", comment: ""),
            style: .destructive
        ) { [weak self] _ in
            guard let self = self else { return }
            do {
                try Auth.auth().signOut()
                self.logoutConfirmed = true
                self.performSegue(withIdentifier: "toLogin", sender: nil)
            } catch {
                self.showAlert(String(format: NSLocalizedString("settings.error.signOutFailed", comment: ""), error.localizedDescription))
            }
        })
        present(alert, animated: true)
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("settings.alert.ok", comment: ""), style: .default))
        present(alert, animated: true)
    }
}
