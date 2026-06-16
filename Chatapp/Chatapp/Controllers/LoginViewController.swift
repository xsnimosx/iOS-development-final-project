//
//  LoginViewController.swift
//  Chatapp

import UIKit
import FirebaseAuth
import FirebaseFirestore

/// A text field that always presents a Latin/English keyboard, overriding iOS's
/// global "last-used keyboard language" stickiness (which otherwise brings up a
/// CJK keyboard for email entry once the user has typed in that language
/// elsewhere). `textInputMode` is re-queried each time the field is focused.
private final class LatinTextField: UITextField {
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { ($0.primaryLanguage ?? "").hasPrefix("en") }
            ?? super.textInputMode
    }
}

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
    private let signInEmailField = LatinTextField()
    private let signUpEmailField = LatinTextField()
    // Secure fields already force a Latin keyboard, but LatinTextField makes that
    // guaranteed and consistent with the email fields across iOS versions.
    private let signInPasswordField = LatinTextField()
    private let signUpPasswordField = LatinTextField()
    private let signUpConfirmPasswordField = LatinTextField()

    private let loginButton = UIButton(type: .system)
    // Inline error feedback (replaces UIAlertController popups): red text that the
    // stack auto-collapses while hidden and springs up just above the offending field.
    private let errorLabel = UILabel()
    private var autoLoginTimer: Timer?

    // Last seen lengths of the sign-in credential fields, used to tell an AutoFill
    // (whole value inserted in one event → large jump) from manual typing (+1 per
    // keystroke). Only AutoFill should auto-submit.
    private var lastSignInEmailLength = 0
    private var lastSignInPasswordLength = 0

    // Most recent keyboard height (0 when hidden); used to re-rest the button
    // above the keyboard after a mode switch changes the form height.
    private var lastKeyboardHeight: CGFloat = 0

    // True only during a deliberate segment switch, so the keyboard-frame
    // observers don't fire their own competing scroll animation — the single
    // mode-switch spring owns the scroll adjustment instead.
    private var isSwitchingMode = false

    // The mode-switch spring, deferred until the incoming field's keyboard height
    // is known. Run by keyboardWillShow (accurate height) or a next-runloop fallback.
    private var pendingModeSwitchSpring: ((CGFloat) -> Void)?

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
        // Tapping the status bar / notch would otherwise scroll to top and drop the
        // login button behind the keyboard while the keyboard stays up.
        scrollView.scrollsToTop = false
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
        // Hidden (and collapsed) until an error shows; showInlineError repositions it
        // just above the offending field, or above the button for form-level errors.
        formStack.addArrangedSubview(errorLabel)
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

        errorLabel.textColor = .systemRed
        errorLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        errorLabel.numberOfLines = 0
        // Leading-aligned so it reads as attached to the field it sits above.
        errorLabel.textAlignment = .natural
        errorLabel.isHidden = true
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
            // Setting .text programmatically doesn't fire textDidChange; keep the
            // tracked length in sync so the next manual edit isn't misread as a bulk
            // AutoFill insertion.
            lastSignInEmailLength = signInEmailField.text?.count ?? 0
        } else {
            signUpEmailField.text = signInEmailField.text
        }

        let shownFields: [UITextField] = isSignIn
            ? [signInEmailField, signInPasswordField]
            : [signUpUsernameField, signUpEmailField, signUpPasswordField, signUpConfirmPasswordField]

        let applyVisibility = {
            self.signInEmailField.isHidden = !isSignIn
            self.signInPasswordField.isHidden = !isSignIn
            self.signUpUsernameField.isHidden = isSignIn
            self.signUpEmailField.isHidden = isSignIn
            self.signUpPasswordField.isHidden = isSignIn
            self.signUpConfirmPasswordField.isHidden = isSignIn
        }

        guard animated else {
            applyVisibility()
            formStack.layoutIfNeeded()
            updateButtonTitle()
            return
        }

        // Incoming fields rise into place AND the login button scrolls above the
        // keyboard in one coordinated spring. The scroll needs the *new* field's
        // keyboard height (AutoFill accessory bars differ in height), which is only
        // known from keyboardWillShow — so the spring is deferred until that height
        // is available rather than computed from the stale pre-switch height.
        isSwitchingMode = true
        applyVisibility()
        for field in shownFields {
            field.alpha = 0
            field.transform = CGAffineTransform(translationX: 0, y: 28)
        }

        pendingModeSwitchSpring = { [weak self] keyboardHeight in
            guard let self = self else { return }
            self.isSwitchingMode = false
            UIView.animate(withDuration: 0.5, delay: 0,
                           usingSpringWithDamping: 0.9, initialSpringVelocity: 0.75,
                           options: [.curveEaseOut, .allowUserInteraction]) {
                for field in shownFields {
                    field.alpha = 1
                    field.transform = .identity
                }
                self.applyScrollInset(for: keyboardHeight)
            }
        }

        // Keep the keyboard up; this fires keyboardWillShow with the new height,
        // which runs the deferred spring in sync with the field entrance.
        focusTarget?.becomeFirstResponder()

        // Fallback: if the keyboard height doesn't change (same keyboard → no
        // notification) or it's already closed, run next runloop with the current height.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let spring = self.pendingModeSwitchSpring else { return }
            self.pendingModeSwitchSpring = nil
            spring(self.lastKeyboardHeight)
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
        hideInlineError()
        updateModeUI(animated: true, keepKeyboard: true)
    }

    @objc private func loginButtonTapped() {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0

        if isSignIn {
            let email = signInEmailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let password = signInPasswordField.text ?? ""
            guard !email.isEmpty, !password.isEmpty else {
                showInlineError(NSLocalizedString("login.error.emptyFields", comment: ""),
                                on: email.isEmpty ? signInEmailField : signInPasswordField)
                return
            }
            signIn(email: email, password: password)
        } else {
            let email = signUpEmailField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let password = signUpPasswordField.text ?? ""
            let username = signUpUsernameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let confirm = signUpConfirmPasswordField.text ?? ""

            guard !email.isEmpty, !password.isEmpty, !confirm.isEmpty else {
                // Point at the first empty required field (username is optional).
                let target = email.isEmpty ? signUpEmailField
                    : (password.isEmpty ? signUpPasswordField : signUpConfirmPasswordField)
                showInlineError(NSLocalizedString("login.error.emptyFields", comment: ""), on: target)
                return
            }
            guard password == confirm else {
                showInlineError(NSLocalizedString("login.error.passwordMismatch", comment: ""),
                                on: signUpConfirmPasswordField)
                return
            }
            let displayName = username.isEmpty ? email : username
            register(email: email, password: password, displayName: displayName)
        }
    }

    // MARK: - Auth

    private func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                let mapped = self.authError(error)
                self.showInlineError(mapped.message, on: mapped.field)
                return
            }
            self.navigateToMainApp()
        }
    }

    private func register(email: String, password: String, displayName: String) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                let mapped = self.authError(error)
                self.showInlineError(mapped.message, on: mapped.field)
                return
            }
            guard let uid = result?.user.uid else { return }
            Firestore.firestore().collection("users").document(uid).setData([
                "email": email,
                "displayName": displayName
            ]) { _ in
                // Navigate only after Firestore confirms the write to avoid empty profile on first load
                self.navigateToMainApp()
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
                selector: #selector(credentialFieldChanged(_:)),
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

        // A mode switch deferred its coordinated spring until the new keyboard
        // height was known — run it now, with this accurate height, so the button
        // scroll and the field entrance move together.
        if let spring = pendingModeSwitchSpring {
            pendingModeSwitchSpring = nil
            spring(keyboardFrame.height)
            return
        }

        UIView.animate(withDuration: duration, delay: 0,
                       options: UIView.AnimationOptions(rawValue: curveRaw << 16)) {
            self.applyScrollInset(for: keyboardFrame.height)
        }
    }

    /// Set the scroll insets/offset so the login button rests just above a keyboard
    /// of `keyboardHeight` (0 = keyboard hidden). Lifts only enough to clear the
    /// button — not the whole keyboard. Call inside an animation block to animate it.
    private func applyScrollInset(for keyboardHeight: CGFloat) {
        // Make sure frames are current before measuring the button position
        view.layoutIfNeeded()

        guard keyboardHeight > 0 else {
            scrollView.contentInset.bottom = 0
            scrollView.scrollIndicatorInsets.bottom = 0
            scrollView.contentOffset = .zero
            return
        }

        let buttonMaxY = loginButton.convert(loginButton.bounds, to: contentView).maxY
        let spaceBelowButton = contentView.bounds.height - buttonMaxY
        let bottomInset = max(keyboardHeight - spaceBelowButton + buttonKeyboardGap, 0)
        scrollView.contentInset.bottom = bottomInset
        scrollView.scrollIndicatorInsets.bottom = keyboardHeight
        // Rest at the bottom of the scroll range: button sits just above the keyboard.
        let restingOffsetY = max(scrollView.contentSize.height + bottomInset - scrollView.bounds.height, 0)
        scrollView.contentOffset = CGPoint(x: 0, y: restingOffsetY)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        // During a switch the old field briefly resigns before the new one focuses;
        // ignore that transient hide so the cached height (used by the deferred
        // spring's fallback) isn't zeroed out.
        guard !isSwitchingMode else { return }

        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0

        // Switching focus between two fields whose keyboards differ in height (the
        // sign-in email field carries an AutoFill suggestion bar, the secure password
        // field doesn't) fires a transient hide→show. Don't act on the hide until the
        // next runloop: by then either the new field is first responder (focus moved,
        // not a real dismissal — skip) or it isn't (genuine dismissal — collapse).
        // A synchronous check isn't enough because the password field's AutoFill makes
        // it first responder a beat late, so the hide would otherwise zero the scroll
        // and bounce the form down before keyboardWillShow lifts it back.
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.currentFirstResponderField() == nil else { return }
            self.lastKeyboardHeight = 0
            UIView.animate(withDuration: duration, delay: 0,
                           options: UIView.AnimationOptions(rawValue: curveRaw << 16)) {
                self.applyScrollInset(for: 0)
            }
        }
    }

    @objc private func credentialFieldChanged(_ note: Notification) {
        let changedField = note.object as? UITextField

        let emailLength = signInEmailField.text?.count ?? 0
        let passwordLength = signInPasswordField.text?.count ?? 0
        // How many characters this single change added to the field that fired it.
        // AutoFill inserts the whole value at once (jump > 1); manual typing is +1.
        let jump: Int = changedField == signInEmailField
            ? emailLength - lastSignInEmailLength
            : passwordLength - lastSignInPasswordLength
        lastSignInEmailLength = emailLength
        lastSignInPasswordLength = passwordLength

        // Only auto-submit on AutoFill, and only once both fields are populated.
        // Manual typing must NEVER auto-submit: otherwise each keystroke fires a
        // failed sign-in, spamming alerts and tripping Firebase's rate limiter
        // (auth/too-many-requests → "blocked request").
        //
        // Invalidate only AFTER this guard, not before: picking a saved credential
        // fills both username and password, so a non-qualifying trailing event (the
        // username re-fill) must not cancel the submit the password event scheduled.
        guard segmentedControl.selectedSegmentIndex == 0,
              jump > 1,
              emailLength > 0, passwordLength > 0 else { return }

        // Debounce: iCloud Password fills email then password as two separate change
        // events, so wait briefly for both to settle before submitting.
        autoLoginTimer?.invalidate()
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

    // MARK: - Error Presentation

    /// Show an error inline instead of a modal alert. The red label springs up just
    /// above the offending `field`; pass `field == nil` for errors not tied to one
    /// field (network, too-many-requests, "email or password incorrect") — those
    /// appear above the login button.
    ///
    /// The keyboard is dismissed first: the form re-centers so the label and field
    /// are fully visible, and it sidesteps recomputing the scroll inset while the
    /// keyboard is up after the stack grows by the label's height (the fragile path
    /// behind the keyboard-jump debt).
    private func showInlineError(_ message: String, on field: UITextField?) {
        DispatchQueue.main.async {
            self.view.endEditing(true)

            // Reposition the single label: remove it first so the index math reflects
            // the stack without it, then insert it just above the target (or the button).
            self.formStack.removeArrangedSubview(self.errorLabel)
            self.errorLabel.removeFromSuperview()
            let anchor = field ?? self.loginButton
            let insertIndex = self.formStack.arrangedSubviews.firstIndex(of: anchor)
                ?? self.formStack.arrangedSubviews.count
            self.formStack.insertArrangedSubview(self.errorLabel, at: insertIndex)
            // Hug the field below it (tight 4pt) instead of the stack's default 16pt,
            // so the message reads as attached to that field. Keyed to errorLabel, so
            // it follows wherever the label is re-inserted.
            self.formStack.setCustomSpacing(4, after: self.errorLabel)

            // Start just below its slot and transparent, then spring up into place.
            self.errorLabel.text = message
            self.errorLabel.alpha = 0
            self.errorLabel.transform = CGAffineTransform(translationX: 0, y: 10)
            UIView.animate(withDuration: 0.4, delay: 0,
                           usingSpringWithDamping: 0.7, initialSpringVelocity: 0.8,
                           options: [.curveEaseOut]) {
                self.errorLabel.isHidden = false
                self.errorLabel.alpha = 1
                self.errorLabel.transform = .identity
                self.formStack.layoutIfNeeded()
            }
        }
    }

    private func hideInlineError() {
        errorLabel.isHidden = true
        errorLabel.text = nil
    }

    /// Map a Firebase Auth error to one of the app's own localized messages (rather
    /// than Firebase's raw English `localizedDescription`) plus the field it should
    /// point at. wrongPassword / userNotFound / invalidCredential are merged into one
    /// "incorrect" message with no field, so the screen never reveals whether an
    /// account exists (anti-enumeration); network/too-many/disabled are likewise
    /// form-level (nil field).
    private func authError(_ error: Error) -> (message: String, field: UITextField?) {
        let isSignIn = segmentedControl.selectedSegmentIndex == 0
        let ns = error as NSError
        guard ns.domain == AuthErrorDomain,
              let code = AuthErrorCode.Code(rawValue: ns.code) else {
            return (NSLocalizedString("login.error.auth.generic", comment: ""), nil)
        }
        switch code {
        case .wrongPassword, .userNotFound, .invalidCredential:
            return (NSLocalizedString("login.error.auth.invalidCredential", comment: ""), nil)
        case .invalidEmail:
            return (NSLocalizedString("login.error.auth.invalidEmail", comment: ""),
                    isSignIn ? signInEmailField : signUpEmailField)
        case .emailAlreadyInUse:
            return (NSLocalizedString("login.error.auth.emailInUse", comment: ""), signUpEmailField)
        case .weakPassword:
            return (NSLocalizedString("login.error.auth.weakPassword", comment: ""), signUpPasswordField)
        case .userDisabled:
            return (NSLocalizedString("login.error.auth.userDisabled", comment: ""), nil)
        case .networkError:
            return (NSLocalizedString("login.error.auth.network", comment: ""), nil)
        case .tooManyRequests:
            return (NSLocalizedString("login.error.auth.tooManyRequests", comment: ""), nil)
        default:
            return (NSLocalizedString("login.error.auth.generic", comment: ""), nil)
        }
    }
}

// MARK: - UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Focusing any field to correct the input clears the standing error.
        hideInlineError()
    }

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
        // Only dismiss the keyboard on a genuine background tap. Taps on any
        // interactive control must NOT run endEditing: the segment switches mode
        // (keeps the keyboard), a text field hands first-responder to itself, and
        // the button submits. A spurious endEditing fires a transient keyboard
        // hide that bounces the scroll down — and the keyboardWillHide guard can't
        // always catch it, because sign-in's password AutoFill delays the tapped
        // field from becoming first responder. Cutting the tap off here avoids the
        // hide entirely, regardless of that timing.
        guard let touched = touch.view else { return true }
        return !isInteractiveTouch(touched)
    }

    /// True if `view` is, or lives inside, any UIControl (text field, segment,
    /// button). Walks up the superview chain because the hit view is often an
    /// internal subview of the control rather than the control itself.
    private func isInteractiveTouch(_ view: UIView) -> Bool {
        var node: UIView? = view
        while let current = node {
            if current is UIControl { return true }
            node = current.superview
        }
        return false
    }
}
