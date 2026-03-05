import UIKit
import Social
import UniformTypeIdentifiers

/// Share Extension view controller for translating selected text from other apps
class ShareViewController: UIViewController {

    // MARK: - UI Elements

    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let sourceTextView = UITextView()
    private let translatedLabel = UILabel()
    private let translatedTextView = UITextView()
    private let languageButton = UIButton(type: .system)
    private let translateButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    // MARK: - State

    private var sharedText: String = ""
    private var targetLanguage: String = "es"
    private var translatedText: String = ""

    private let supportedLanguages: [(code: String, name: String)] = [
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("pt", "Portuguese"),
        ("zh", "Chinese"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ru", "Russian"),
        ("ar", "Arabic")
    ]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        extractSharedText()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        // Container
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // Title
        titleLabel.text = "SayIt AI Translate"
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // Close button
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(closeButton)

        // Source text
        sourceTextView.font = .systemFont(ofSize: 16)
        sourceTextView.isEditable = false
        sourceTextView.backgroundColor = .secondarySystemBackground
        sourceTextView.layer.cornerRadius = 8
        sourceTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        sourceTextView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(sourceTextView)

        // Language button
        updateLanguageButton()
        languageButton.addTarget(self, action: #selector(languageTapped), for: .touchUpInside)
        languageButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(languageButton)

        // Translate button
        translateButton.setTitle("Translate", for: .normal)
        translateButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        translateButton.backgroundColor = .systemBlue
        translateButton.setTitleColor(.white, for: .normal)
        translateButton.layer.cornerRadius = 8
        translateButton.addTarget(self, action: #selector(translateTapped), for: .touchUpInside)
        translateButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(translateButton)

        // Translated label
        translatedLabel.text = "Translation"
        translatedLabel.font = .systemFont(ofSize: 14, weight: .medium)
        translatedLabel.textColor = .secondaryLabel
        translatedLabel.isHidden = true
        translatedLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(translatedLabel)

        // Translated text
        translatedTextView.font = .systemFont(ofSize: 16)
        translatedTextView.isEditable = false
        translatedTextView.backgroundColor = .secondarySystemBackground
        translatedTextView.layer.cornerRadius = 8
        translatedTextView.textContainerInset = UIEdgeInsets(top: 12, left: 8, bottom: 12, right: 8)
        translatedTextView.isHidden = true
        translatedTextView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(translatedTextView)

        // Copy button
        copyButton.setTitle("Copy Translation", for: .normal)
        copyButton.titleLabel?.font = .boldSystemFont(ofSize: 16)
        copyButton.backgroundColor = .systemGreen
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.layer.cornerRadius = 8
        copyButton.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        copyButton.isHidden = true
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(copyButton)

        // Activity indicator
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(activityIndicator)

        // Constraints
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),

            sourceTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            sourceTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            sourceTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            sourceTextView.heightAnchor.constraint(equalToConstant: 80),

            languageButton.topAnchor.constraint(equalTo: sourceTextView.bottomAnchor, constant: 12),
            languageButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),

            translateButton.topAnchor.constraint(equalTo: sourceTextView.bottomAnchor, constant: 12),
            translateButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            translateButton.widthAnchor.constraint(equalToConstant: 100),
            translateButton.heightAnchor.constraint(equalToConstant: 40),

            activityIndicator.centerXAnchor.constraint(equalTo: translateButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: translateButton.centerYAnchor),

            translatedLabel.topAnchor.constraint(equalTo: translateButton.bottomAnchor, constant: 16),
            translatedLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),

            translatedTextView.topAnchor.constraint(equalTo: translatedLabel.bottomAnchor, constant: 8),
            translatedTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            translatedTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            translatedTextView.heightAnchor.constraint(equalToConstant: 80),

            copyButton.topAnchor.constraint(equalTo: translatedTextView.bottomAnchor, constant: 12),
            copyButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            copyButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            copyButton.heightAnchor.constraint(equalToConstant: 44),
            copyButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
    }

    private func updateLanguageButton() {
        let langName = supportedLanguages.first { $0.code == targetLanguage }?.name ?? "Spanish"
        languageButton.setTitle("To: \(langName) ▼", for: .normal)
    }

    // MARK: - Extract Shared Content

    private func extractSharedText() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            return
        }

        // Try to get plain text
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
                DispatchQueue.main.async {
                    if let text = item as? String {
                        self?.sharedText = text
                        self?.sourceTextView.text = text
                    }
                }
            }
        }
        // Try URL (for Safari selections)
        else if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        self?.sharedText = url.absoluteString
                        self?.sourceTextView.text = url.absoluteString
                    }
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @objc private func languageTapped() {
        let alert = UIAlertController(title: "Select Language", message: nil, preferredStyle: .actionSheet)

        for lang in supportedLanguages {
            alert.addAction(UIAlertAction(title: lang.name, style: .default) { [weak self] _ in
                self?.targetLanguage = lang.code
                self?.updateLanguageButton()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = languageButton
            popover.sourceRect = languageButton.bounds
        }

        present(alert, animated: true)
    }

    @objc private func translateTapped() {
        guard !sharedText.isEmpty else { return }

        translateButton.isHidden = true
        activityIndicator.startAnimating()

        // Call translation API
        translateText(sharedText, to: targetLanguage) { [weak self] result in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                self?.translateButton.isHidden = false

                switch result {
                case .success(let translation):
                    self?.translatedText = translation
                    self?.translatedTextView.text = translation
                    self?.translatedLabel.isHidden = false
                    self?.translatedTextView.isHidden = false
                    self?.copyButton.isHidden = false

                case .failure(let error):
                    self?.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = translatedText

        // Show feedback
        let originalTitle = copyButton.title(for: .normal)
        copyButton.setTitle("Copied!", for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.copyButton.setTitle(originalTitle, for: .normal)
        }
    }

    // MARK: - Translation API

    private func translateText(_ text: String, to targetLang: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Use the same API endpoint as the main app
        guard let url = URL(string: "https://api.sayitai.com/api/v1/translate") else {
            completion(.failure(NSError(domain: "ShareExtension", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "sourceLanguage": "auto",
            "targetLanguage": targetLang
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "ShareExtension", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any],
                   let translatedText = dataDict["translatedText"] as? String {
                    completion(.success(translatedText))
                } else {
                    completion(.failure(NSError(domain: "ShareExtension", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
