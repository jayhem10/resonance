import SwiftUI
import AuthenticationServices

struct WebAuthView: UIViewControllerRepresentable {
    let url: URL
    let callbackURLScheme: String
    let completionHandler: (String) -> Void
    
    func makeUIViewController(context: Context) -> WebAuthViewController {
        let viewController = WebAuthViewController(
            url: url,
            callbackURLScheme: callbackURLScheme,
            completionHandler: completionHandler
        )
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: WebAuthViewController, context: Context) {}
}

class WebAuthViewController: UIViewController {
    private let url: URL
    private let callbackURLScheme: String
    private let completionHandler: (String) -> Void
    private var webAuthSession: ASWebAuthenticationSession?
    
    init(url: URL, callbackURLScheme: String, completionHandler: @escaping (String) -> Void) {
        self.url = url
        self.callbackURLScheme = callbackURLScheme
        self.completionHandler = completionHandler
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startAuthentication()
    }
    
    private func startAuthentication() {
        webAuthSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: callbackURLScheme
        ) { [weak self] callbackURL, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Authentication error: \(error.localizedDescription)")
                self.dismiss(animated: true)
                return
            }
            
            guard let callbackURL = callbackURL,
                  let code = URLComponents(string: callbackURL.absoluteString)?
                .queryItems?
                .first(where: { $0.name == "code" })?
                .value
            else {
                print("No code found in callback URL")
                self.dismiss(animated: true)
                return
            }
            
            self.completionHandler(code)
            self.dismiss(animated: true)
        }
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = true
        
        if !webAuthSession!.start() {
            print("Failed to start authentication session")
            dismiss(animated: true)
        }
    }
}

extension WebAuthViewController: ASWebAuthenticationPresentationContextProviding {
    @objc func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window ?? ASPresentationAnchor()
    }
}
