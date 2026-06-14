//
//  LoginViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController {

    // MARK: - UI Properties

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let formStack = UIStackView()
    private let logoImageView = UIImageView()
    private let segmentedControl = UISegmentedControl(items: ["", ""])
    private let usernameField = UITextField()
    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let confirmPasswordField = UITextField()
    private let loginButton = UIButton(type: .system)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        setupTextFieldAttributes()
        applyBrandStyling()
        localizeUI()
        updateModeUI(animated: false)
        setupKeyboardDismissOnTap()
        setupKeyboardObservers()
        if Auth.auth().currentUser != nil {
            navigateToMainApp()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Layout

    private func setupViews() {
        view.backgroundColor = UIColor(named: "AccentColor")

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        formStack.axis = .vertical
        formStack.spacing = 16
        formStack.alignment = .fill
        formStack.distribution = .fill
        formStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(formStack)

        logoImageView.image = UIImage(named: "Logo")
        logoImageView.contentMode = .scaleAspectFit

        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        loginButton.addTarget(self, action: #selector(loginButtonTapped), for: .touchUpInside)

        for field in [usernameField, emailField, passwordField, confirmPasswordField] {
            field.delegate = self
        }

        formStack.addArrangedSubview(logoImageView)
        formStack.addArrangedSubview(segmentedControl)
        formStack.addArrangedSubview(usernameField)
        formStack.addArrangedSubview(emailField)
        formStack.addArrangedSubview(passwordField)
        formStack.addArrangedSubview(confirmPasswordField)
        formStack.addArrangedSubview(loginButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // contentView matches the scrollView frame; keyboard inset creates the scroll range
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            // formStack centered vertically; guards prevent clipping on small devices
            formStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            formStack.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 40),
            formStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -40),
            formStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            formStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
        ])

        logoImageView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        segmentedControl.heightAnchor.constraint(equalToConstant: 32).isActive = true
        usernameField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        emailField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        passwordField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        confirmPasswordField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        loginButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func applyBrandStyling() {
        let brandBrown = UIColor(red: 0.635, green: 0.518, blue: 0.369, alpha: 1)

        for field in [usernameField, emailField, passwordField, confirmPasswordField] {
            field.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
            field.layer.cornerRadius = 10
            field.layer.masksToBounds = true
            field.borderStyle = .none
            field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
            field.leftViewMode = .always
            field.font = UIFont.systemFont(ofSize: 15)
        }

        segmentedControl.selectedSegmentTintColor = brandBrown
        segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)

        loginButton.backgroundColor = brandBrown
        loginButton.layer.cornerRadius = 10
        loginButton.layer.masksToBounds = true
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    }

    private func setupTextFieldAttributes() {
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.textContentType = .emailAddress
        emailField.returnKeyType = .next

        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        usernameField.textContentType = .username
        usernameField.returnKeyType = .next

        // passwordField: textContentType and returnKeyType are set dynamically by updateModeUI
        passwordField.isSecureTextEntry = true
        passwordField.autocapitalizationType = .none
        passwordField.autocorrectionType = .no

        confirmPasswordField.isSecureTextEntry = true
        confirmPasswordField.textContentType = .newPassword
        confirmPasswordField.passwordRules = UITextInputPasswordRules(descriptor: "minlength: 6;")
        confirmPasswordField.returnKeyType = .go
    }

    // MARK: - Mode

    private func updateModeUI(animated: Bool) {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0

        let applyHidden = {
            self.usernameField.isHidden = isSignIn
            self.confirmPasswordField.isHidden = isSignIn
            self.formStack.layoutIfNeeded()
        }

        if animated {
            // Clear toggled fields so stale text doesn't survive a mode switch
            usernameField.text = nil
            confirmPasswordField.text = nil
            if isSignIn { passwordField.text = nil }
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: applyHidden)
        } else {
            applyHidden()
        }

        updateButtonTitle()
        updatePasswordFieldContentType()
        updateReturnKeyTypes()
    }

    private func updateButtonTitle() {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0
        let key = isSignIn ? "login.button.signIn" : "login.button.signUp"
        loginButton.setTitle(NSLocalizedString(key, comment: ""), for: .normal)
        passwordField.textContentType = isSignIn ? .password : .newPassword
    }

    private func updatePasswordFieldContentType() {
        if segmentedControl.selectedSegmentIndex == 0 {
            // Sign-in: offer to fill from Keychain
            passwordField.textContentType = .password
            passwordField.passwordRules = nil
        } else {
            // Sign-up: trigger "Use Strong Password" suggestion
            passwordField.textContentType = .newPassword
            passwordField.passwordRules = UITextInputPasswordRules(descriptor: "minlength: 6;")
        }
    }

    private func updateReturnKeyTypes() {
        passwordField.returnKeyType = segmentedControl.selectedSegmentIndex == 0 ? .go : .next
    }

    private func localizeUI() {
        segmentedControl.setTitle(NSLocalizedString("login.segment.signIn", comment: ""), forSegmentAt: 0)
        segmentedControl.setTitle(NSLocalizedString("login.segment.signUp", comment: ""), forSegmentAt: 1)
        usernameField.placeholder = NSLocalizedString("login.field.username", comment: "")
        emailField.placeholder = NSLocalizedString("login.field.email", comment: "")
        passwordField.placeholder = NSLocalizedString("login.field.password", comment: "")
        confirmPasswordField.placeholder = NSLocalizedString("login.field.confirmPassword", comment: "")
        updateButtonTitle()
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        view.endEditing(true)
        updateModeUI(animated: true)
    }

    @objc private func loginButtonTapped() {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0
        let email = emailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let password = passwordField.text ?? ""

        if isSignIn {
            guard !email.isEmpty, !password.isEmpty else {
                showAlert(NSLocalizedString("login.error.emptyFields", comment: ""))
                return
            }
            signIn(email: email, password: password)
        } else {
            let username = usernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let confirm = confirmPasswordField.text ?? ""

            guard !email.isEmpty, !password.isEmpty, !confirm.isEmpty else {
                showAlert(NSLocalizedString("login.error.emptyFields", comment: ""))
                return
            }
            guard password == confirm else {
                showAlert(NSLocalizedString("login.error.passwordMismatch", comment: ""))
                return
            }
            let displayName = username.isEmpty ? email : username
            register(email: email, password: password, displayName: displayName)
        }
    }

    // MARK: - Auth

    private func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            if let error = error {
                self?.showAlert(String(format: NSLocalizedString("login.error.signInFailed", comment: ""), error.localizedDescription))
                return
            }
            self?.navigateToMainApp()
        }
    }

    private func register(email: String, password: String, displayName: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.showAlert(String(format: NSLocalizedString("login.error.registerFailed", comment: ""), error.localizedDescription))
                return
            }
            guard let uid = result?.user.uid else { return }
            Firestore.firestore().collection("users").document(uid).setData([
                "email": email,
                "displayName": displayName
            ]) { _ in
                // Navigate only after Firestore confirms the write to avoid empty profile on first load
                self?.navigateToMainApp()
            }
        }
    }

    // MARK: - Keyboard

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }

        let insets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
        // Mirror the system's own curve so the inset tracks the keyboard animation exactly
        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16)) {
            self.scrollView.contentInset = insets
            self.scrollView.scrollIndicatorInsets = insets
        }

        if let activeField = [usernameField, emailField, passwordField, confirmPasswordField]
            .first(where: { $0.isFirstResponder }) {
            let rect = activeField.convert(activeField.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -16), animated: true)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16)) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }

    // MARK: - Navigation

    private func navigateToMainApp() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "toMainApp", sender: nil)
        }
    }

    private func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("login.alert.ok", comment: ""), style: .default))
            self.present(alert, animated: true)
        }
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0
        switch textField {
        case usernameField:
            emailField.becomeFirstResponder()
        case emailField:
            passwordField.becomeFirstResponder()
        case passwordField:
            if isSignIn {
                textField.resignFirstResponder()
                loginButtonTapped()
            } else {
                confirmPasswordField.becomeFirstResponder()
            }
        case confirmPasswordField:
            textField.resignFirstResponder()
            loginButtonTapped()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}
