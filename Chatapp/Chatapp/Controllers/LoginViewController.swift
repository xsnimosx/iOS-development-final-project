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

    // Sign-in and Sign-up use *separate* field instances so each keeps a fixed,
    // never-mutated textContentType. Reusing one field and flipping its
    // textContentType corrupts iOS's cached AutoFill context (the .newPassword
    // "Strong Password" session bled into Sign-in). Separate instances make that
    // class of bug structurally impossible.
    private let signUpUsernameField = UITextField()
    private let signInEmailField = UITextField()
    private let signUpEmailField = UITextField()
    private let signInPasswordField = UITextField()
    private let signUpPasswordField = UITextField()
    private let signUpConfirmPasswordField = UITextField()

    private let loginButton = UIButton(type: .system)
    private var autoLoginTimer: Timer?

    // Most recent keyboard height (0 when hidden); used to re-rest the button
    // above the keyboard after a mode switch changes the form height.
    private var lastKeyboardHeight: CGFloat = 0

    // Gap kept between the login button and the top of the keyboard
    private let buttonKeyboardGap: CGFloat = 12

    private var allFields: [UITextField] {
        [signUpUsernameField, signInEmailField, signUpEmailField,
         signInPasswordField, signUpPasswordField, signUpConfirmPasswordField]
    }

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
        setupKeyboardDismissOnTapExcludingSegment()
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

        for field in allFields {
            field.delegate = self
        }

        formStack.addArrangedSubview(logoImageView)
        formStack.addArrangedSubview(segmentedControl)
        // Two email/password instances sit adjacent; only one of each is visible
        // per mode, so the stack still reads as a single email/password row.
        formStack.addArrangedSubview(signUpUsernameField)
        formStack.addArrangedSubview(signInEmailField)
        formStack.addArrangedSubview(signUpEmailField)
        formStack.addArrangedSubview(signInPasswordField)
        formStack.addArrangedSubview(signUpPasswordField)
        formStack.addArrangedSubview(signUpConfirmPasswordField)
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
        for field in allFields {
            field.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }
        loginButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }

    private func applyBrandStyling() {
        let brandBrown = UIColor(red: 0.635, green: 0.518, blue: 0.369, alpha: 1)

        for field in allFields {
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

    /// Each field's AutoFill traits are fixed here and never change afterward.
    private func setupTextFieldAttributes() {
        // Sign-in email: .username triggers iCloud Keychain "fill existing password"
        signInEmailField.keyboardType = .emailAddress
        signInEmailField.autocapitalizationType = .none
        signInEmailField.autocorrectionType = .no
        signInEmailField.textContentType = .username
        signInEmailField.returnKeyType = .next

        signInPasswordField.isSecureTextEntry = true
        signInPasswordField.autocapitalizationType = .none
        signInPasswordField.autocorrectionType = .no
        signInPasswordField.textContentType = .password
        signInPasswordField.returnKeyType = .go

        // Sign-up username is a display name, not a credential
        signUpUsernameField.autocapitalizationType = .none
        signUpUsernameField.autocorrectionType = .no
        signUpUsernameField.textContentType = .name
        signUpUsernameField.returnKeyType = .next

        signUpEmailField.keyboardType = .emailAddress
        signUpEmailField.autocapitalizationType = .none
        signUpEmailField.autocorrectionType = .no
        // .username (not .emailAddress) to match the Sign-in email field: it keeps
        // the keyboard on a Latin/English layout and still lets iOS save the new
        // credential (account identifier + .newPassword) on sign-up.
        signUpEmailField.textContentType = .username
        signUpEmailField.returnKeyType = .next

        // Sign-up password: .newPassword triggers the "Use Strong Password" flow
        signUpPasswordField.isSecureTextEntry = true
        signUpPasswordField.autocapitalizationType = .none
        signUpPasswordField.autocorrectionType = .no
        signUpPasswordField.textContentType = .newPassword
        signUpPasswordField.passwordRules = UITextInputPasswordRules(descriptor: "minlength: 6;")
        signUpPasswordField.returnKeyType = .next

        signUpConfirmPasswordField.isSecureTextEntry = true
        signUpConfirmPasswordField.autocapitalizationType = .none
        signUpConfirmPasswordField.autocorrectionType = .no
        signUpConfirmPasswordField.textContentType = .newPassword
        signUpConfirmPasswordField.passwordRules = UITextInputPasswordRules(descriptor: "minlength: 6;")
        signUpConfirmPasswordField.returnKeyType = .go
    }

    // MARK: - Mode

    private func updateModeUI(animated: Bool, keepKeyboard: Bool = false) {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0

        // Capture the field to move focus to BEFORE hiding anything.
        let focusTarget = keepKeyboard ? counterpart(of: currentFirstResponderField(), isSignIn: isSignIn) : nil

        // Carry the email across the mode boundary so it doesn't vanish on switch.
        // Passwords stay independent per mode (avoids suppressing the Sign-up
        // Strong Password suggestion).
        if isSignIn {
            signInEmailField.text = signUpEmailField.text
        } else {
            signUpEmailField.text = signInEmailField.text
        }

        let applyVisibility = {
            self.signInEmailField.isHidden = !isSignIn
            self.signInPasswordField.isHidden = !isSignIn
            self.signUpUsernameField.isHidden = isSignIn
            self.signUpEmailField.isHidden = isSignIn
            self.signUpPasswordField.isHidden = isSignIn
            self.signUpConfirmPasswordField.isHidden = isSignIn
            self.formStack.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: applyVisibility)
        } else {
            applyVisibility()
        }

        // Re-take first responder on the counterpart (now visible) so the keyboard
        // stays up across the switch. iOS coalesces the resign+become in one runloop.
        focusTarget?.becomeFirstResponder()

        // The form height differs between modes; re-rest the button above the keyboard.
        if keepKeyboard, lastKeyboardHeight > 0 {
            adjustScrollForKeyboard(keyboardHeight: lastKeyboardHeight, duration: 0.25, options: .curveEaseInOut)
        }

        updateButtonTitle()
    }

    /// The field in the target mode that should inherit focus when switching.
    private func counterpart(of field: UITextField?, isSignIn: Bool) -> UITextField? {
        guard let field = field else { return nil }
        if isSignIn {
            switch field {
            case signUpEmailField, signUpUsernameField: return signInEmailField
            case signUpPasswordField, signUpConfirmPasswordField: return signInPasswordField
            default: return nil
            }
        } else {
            switch field {
            case signInEmailField: return signUpEmailField
            case signInPasswordField: return signUpPasswordField
            default: return nil
            }
        }
    }

    private func currentFirstResponderField() -> UITextField? {
        allFields.first { $0.isFirstResponder }
    }

    private func updateButtonTitle() {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0
        let key = isSignIn ? "login.button.signIn" : "login.button.signUp"
        loginButton.setTitle(NSLocalizedString(key, comment: ""), for: .normal)
    }

    private func localizeUI() {
        segmentedControl.setTitle(NSLocalizedString("login.segment.signIn", comment: ""), forSegmentAt: 0)
        segmentedControl.setTitle(NSLocalizedString("login.segment.signUp", comment: ""), forSegmentAt: 1)
        signUpUsernameField.placeholder = NSLocalizedString("login.field.username", comment: "")
        let emailPlaceholder = NSLocalizedString("login.field.email", comment: "")
        signInEmailField.placeholder = emailPlaceholder
        signUpEmailField.placeholder = emailPlaceholder
        let passwordPlaceholder = NSLocalizedString("login.field.password", comment: "")
        signInPasswordField.placeholder = passwordPlaceholder
        signUpPasswordField.placeholder = passwordPlaceholder
        signUpConfirmPasswordField.placeholder = NSLocalizedString("login.field.confirmPassword", comment: "")
        updateButtonTitle()
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        updateModeUI(animated: true, keepKeyboard: true)
    }

    @objc private func loginButtonTapped() {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0

        if isSignIn {
            let email = signInEmailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let password = signInPasswordField.text ?? ""
            guard !email.isEmpty, !password.isEmpty else {
                showAlert(NSLocalizedString("login.error.emptyFields", comment: ""))
                return
            }
            signIn(email: email, password: password)
        } else {
            let email = signUpEmailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let password = signUpPasswordField.text ?? ""
            let username = signUpUsernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let confirm = signUpConfirmPasswordField.text ?? ""

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

    private func setupKeyboardDismissOnTapExcludingSegment() {
        // A tap anywhere dismisses the keyboard — except on the segmented control,
        // so switching mode can keep the keyboard up. (Reuses dismissKeyboard from
        // the shared UIViewController+Keyboard extension.)
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

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
        // Auto-login on AutoFill only applies to Sign-in, so watch those fields.
        for field in [signInEmailField, signInPasswordField] {
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

        lastKeyboardHeight = keyboardFrame.height
        adjustScrollForKeyboard(keyboardHeight: keyboardFrame.height,
                                duration: duration,
                                options: UIView.AnimationOptions(rawValue: curveRaw << 16))
    }

    /// Lift the login button (plus a small gap) above the keyboard by extending the
    /// scroll range — not the full keyboard height — so the bottom of the scroll
    /// rests on the button.
    private func adjustScrollForKeyboard(keyboardHeight: CGFloat, duration: TimeInterval, options: UIView.AnimationOptions) {
        // Make sure frames are current before measuring the button position
        view.layoutIfNeeded()

        let buttonMaxY = loginButton.convert(loginButton.bounds, to: contentView).maxY
        let spaceBelowButton = contentView.bounds.height - buttonMaxY
        let bottomInset = max(keyboardHeight - spaceBelowButton + buttonKeyboardGap, 0)

        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.scrollView.contentInset.bottom = bottomInset
            self.scrollView.scrollIndicatorInsets.bottom = keyboardHeight
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
        lastKeyboardHeight = 0
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
              let email = signInEmailField.text, !email.isEmpty,
              let password = signInPasswordField.text, !password.isEmpty else {
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
        switch textField {
        case signInEmailField:
            signInPasswordField.becomeFirstResponder()
        case signInPasswordField:
            textField.resignFirstResponder()
            loginButtonTapped()
        case signUpUsernameField:
            signUpEmailField.becomeFirstResponder()
        case signUpEmailField:
            signUpPasswordField.becomeFirstResponder()
        case signUpPasswordField:
            signUpConfirmPasswordField.becomeFirstResponder()
        case signUpConfirmPasswordField:
            textField.resignFirstResponder()
            loginButtonTapped()
        default:
            textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: - UIGestureRecognizerDelegate

extension LoginViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't let the dismiss-on-tap gesture fire when tapping the segmented
        // control, otherwise switching mode would dismiss the keyboard.
        if let touched = touch.view, touched.isDescendant(of: segmentedControl) {
            return false
        }
        return true
    }
}
