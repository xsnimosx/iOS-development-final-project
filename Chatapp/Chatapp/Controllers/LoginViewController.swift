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
    private var autoLoginTimer: Timer?

    // Gap kept between the login button and the top of the keyboard
    private let buttonKeyboardGap: CGFloat = 12

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupConstraints()
        setupTextFieldAttributes()
        applyBrandStyling()
        localizeUI()
        segmentedControl.selectedSegmentIndex = 0
        updateModeUI(animated: false)
        setupKeyboardDismissOnTap()
        setupKeyboardObservers()
        if Auth.auth().currentUser != nil {
            navigateToMainApp()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autoLoginTimer?.invalidate()
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
        usernameField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        emailField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        passwordField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        confirmPasswordField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        loginButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
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
        emailField.textContentType = .username
        emailField.returnKeyType = .next

        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        usernameField.textContentType = .name
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
        updateEmailFieldContentType()
        updatePasswordFieldContentType()
        updateReturnKeyTypes()
    }

    private func updateButtonTitle() {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0
        let key = isSignIn ? "login.button.signIn" : "login.button.signUp"
        loginButton.setTitle(NSLocalizedString(key, comment: ""), for: .normal)
    }

    private func updateEmailFieldContentType() {
        emailField.textContentType = segmentedControl.selectedSegmentIndex == 0 ? .username : .emailAddress
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
        // The same passwordField instance is reused across Sign-in/Sign-up.
        // iOS caches a field's AutoFill context (notably the .newPassword
        // "Strong Password" session) when it first becomes first responder and
        // ignores a later textContentType change — so the Sign-up strong-password
        // context bleeds into Sign-in if Sign-up was last left from a credential
        // field. Toggling isSecureTextEntry tears down and rebuilds the secure
        // input session, forcing iOS to re-read textContentType on next focus.
        let preservedText = passwordField.text
        passwordField.isSecureTextEntry = false
        passwordField.isSecureTextEntry = true
        if passwordField.text != preservedText { passwordField.text = preservedText }
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
        for field in [emailField, passwordField] {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(credentialFieldChanged),
                name: UITextField.textDidChangeNotification,
                object: field
            )
        }
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let info = notification.userInfo,
              let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }

        // Make sure frames are current before measuring the button position
        view.layoutIfNeeded()

        // Distance from the button's bottom edge down to the bottom of the scrollable content.
        // The scroll range only needs to lift the button (plus a small gap) above the keyboard —
        // not the whole keyboard height — so the very bottom of the scroll lands on the button.
        let buttonMaxY = loginButton.convert(loginButton.bounds, to: contentView).maxY
        let spaceBelowButton = contentView.bounds.height - buttonMaxY
        let bottomInset = max(keyboardFrame.height - spaceBelowButton + buttonKeyboardGap, 0)

        // Mirror the system's own curve so the scroll tracks the keyboard animation exactly
        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16)) {
            self.scrollView.contentInset.bottom = bottomInset
            self.scrollView.scrollIndicatorInsets.bottom = keyboardFrame.height
            // Rest at the bottom of the scroll range: button sits just above the keyboard.
            // Over-scrolling past this bounces straight back here.
            let restingOffsetY = max(
                self.scrollView.contentSize.height + bottomInset - self.scrollView.bounds.height,
                0
            )
            self.scrollView.contentOffset = CGPoint(x: 0, y: restingOffsetY)
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else { return }
        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16)) {
            self.scrollView.contentInset.bottom = 0
            self.scrollView.scrollIndicatorInsets.bottom = 0
            self.scrollView.contentOffset = .zero
        }
    }

    @objc private func credentialFieldChanged() {
        guard segmentedControl.selectedSegmentIndex == 0,
              let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            autoLoginTimer?.invalidate()
            return
        }
        autoLoginTimer?.invalidate()
        // Debounce: iCloud Password fills email then password as two separate change events,
        // so wait briefly for both to settle before submitting.
        autoLoginTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.loginButtonTapped()
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
