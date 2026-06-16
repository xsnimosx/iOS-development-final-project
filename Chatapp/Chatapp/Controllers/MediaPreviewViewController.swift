//
//  MediaPreviewViewController.swift
//  Chatapp
//
//  Created by cbe112048 on 2026/6/10.
//

import UIKit

class MediaPreviewViewController: UIViewController, UIScrollViewDelegate {

    var imageURL: String?

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)

    // 下滑關閉：拖動超過此距離(或甩動速度夠快)就關閉，否則彈回。
    private let dismissDistanceThreshold: CGFloat = 120
    private let dismissVelocityThreshold: CGFloat = 800

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        loadImage()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        tap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(tap)

        // 下滑關閉手勢。加在最外層 view 上(而非 scrollView)，才不會跟 scrollView
        // 內建用來平移縮放內容的 pan 手勢爭奪同一條 pan。實際是否啟動由
        // gestureRecognizerShouldBegin 把關：只在未縮放且向下垂直拖動時生效。
        let dismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        view.addGestureRecognizer(dismissPan)
    }

    private func setupUI() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])

        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    private func loadImage() {
        guard let urlString = imageURL, let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.imageView.image = image }
        }.resume()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    // MARK: - 下滑關閉

    @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .changed:
            // 圖片跟著手指走，水平只跟一半增加拖曳的順手感；背景與關閉鈕隨下拉淡出。
            let dy = max(0, translation.y)
            scrollView.transform = CGAffineTransform(translationX: translation.x * 0.5, y: dy)
            let progress = min(dy / 300, 1)
            view.backgroundColor = UIColor.black.withAlphaComponent(1 - progress * 0.6)
            closeButton.alpha = 1 - progress

        case .ended, .cancelled:
            let dy = max(0, translation.y)
            let velocity = gesture.velocity(in: view)
            if dy > dismissDistanceThreshold || velocity.y > dismissVelocityThreshold {
                // 把圖片往下推出畫面、背景淡到全透明，再不帶系統動畫地關閉，避免位置跳動。
                UIView.animate(withDuration: 0.2, animations: {
                    self.scrollView.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
                    self.view.backgroundColor = UIColor.black.withAlphaComponent(0)
                    self.closeButton.alpha = 0
                }, completion: { _ in
                    self.dismiss(animated: false)
                })
            } else {
                // 沒過門檻：彈回原位，帶點回彈手感。
                UIView.animate(withDuration: 0.3, delay: 0,
                               usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5,
                               options: [.allowUserInteraction], animations: {
                    self.scrollView.transform = .identity
                    self.view.backgroundColor = .black
                    self.closeButton.alpha = 1
                })
            }

        default:
            break
        }
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MediaPreviewViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        // 縮放狀態下，pan 交給 scrollView 平移圖片，不觸發關閉。
        guard scrollView.zoomScale <= scrollView.minimumZoomScale + 0.01 else { return false }
        // 只認向下、且垂直分量大於水平的拖動，避免誤觸與水平滑動衝突。
        let velocity = pan.velocity(in: view)
        return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
    }
}
