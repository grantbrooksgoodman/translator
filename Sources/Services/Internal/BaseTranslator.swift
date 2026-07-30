//
//  BaseTranslator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

@preconcurrency import WebKit

@MainActor
class BaseTranslator: NSObject {
    // MARK: - Properties

    private(set) var translationInput: TranslationInput?
    private(set) var translationLanguagePair: LanguagePair?
    private(set) var webView: StaticWebView?

    /// Memory-backed and shared across translations, so provider cookies
    /// (e.g. Google's consent acceptance) persist for the app run without
    /// ever touching the host app's default data store.
    private static let websiteDataStore: WKWebsiteDataStore = .nonPersistent()

    private let platform: TranslationPlatform

    private var completion: (@Sendable (Result<Translation, TranslationError>) -> Void)?
    private var didStartEvaluation = false
    private var navigationFinishedDate: Date?
    private var timeout: Timeout?
    private var translationResult: Result<Translation, TranslationError>? {
        didSet {
            if translationResult != nil { didSetTranslationResult() }
        }
    }

    // MARK: - Computed Properties

    private var didReachEvaluationThreshold: Bool {
        getDidReachEvaluationThreshold()
    }

    // MARK: - Init

    init(
        platform: TranslationPlatform
    ) {
        self.platform = platform
    }

    // MARK: - Prewarm

    static func prewarm(
        _ platforms: [TranslationPlatform]
    ) {
        // Compile content rule lists ahead of time so the first translation
        // doesn't pay the compilation cost.
        precompileContentRuleLists()

        // Warm the DNS + TLS sessions for the translation API fast paths.
        var apiWarmupURLStrings = [String]()
        if platforms.contains(.google) { apiWarmupURLStrings.append(GoogleTranslator.apiWarmupURLString) }
        if platforms.contains(.reverso) { apiWarmupURLStrings.append(ReversoTranslator.apiWarmupURLString) }

        for apiWarmupURL in apiWarmupURLStrings.compactMap({ URL(string: $0) }) {
            URLSession.shared.dataTask(with: apiWarmupURL).resume()
        }

        for prewarmURL in platforms.compactMap(\.prewarmURL) {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = websiteDataStore

            let webView = WKWebView(
                frame: .zero,
                configuration: configuration
            )

            webView.load(.init(url: prewarmURL))

            // TODO: Audit this.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                webView.stopLoading()
                webView.removeFromSuperview()
            }
        }
    }

    // MARK: - Translate

    func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async throws -> Translation {
        try await withCheckedThrowingContinuation { continuation in
            translate(
                input,
                languagePair: languagePair
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair,
        completion: @escaping @Sendable (Result<Translation, TranslationError>) -> Void
    ) {
        guard let requestURL = platform.requestURL(
            input.value,
            languagePair: languagePair
        ) else { return completion(.failure(.failedToGenerateRequestURL)) }

        translationInput = input
        translationLanguagePair = languagePair

        initializeWebView()
        configureWebView()

        if platform != .deepL { addTrimLazyLoadersScript() }

        self.completion = completion
        timeout = Timeout(after: .seconds(10)) { self.setTranslationResult(.failure(.timedOut)) }
        webView?.load(.init(url: requestURL))
    }

    // MARK: - Configure Web View

    open func configureWebView() {}

    // MARK: - Evaluate JavaScript

    open func evaluateJavaScript(
        useAlternateString: Bool = false
    ) async {
        do {
            guard let translationInput,
                  let translationLanguagePair else { return failForMissingValues() }

            let javaScriptString = useAlternateString ? platform.alternateJavaScriptString : platform.javaScriptString

            guard let translationOutput = try await webView?.evaluateJavaScript(javaScriptString) as? String,
                  !translationOutput.lowercasedTrimmingWhitespaceAndNewlines.isEmpty else {
                return await retryOrFail(
                    .evaluateJavaScriptFailed(),
                    useAlternateString: !useAlternateString
                )
            }

            setTranslationResult(
                .success(.init(
                    input: translationInput,
                    output: translationOutput,
                    languagePair: translationLanguagePair
                ))
            )
        } catch {
            await retryOrFail(
                .javaScriptError(Translator.descriptor(error)),
                useAlternateString: !useAlternateString
            )
        }
    }

    // MARK: - Begin Evaluating Translation Result

    /// Kicks off result extraction exactly once, whether triggered by the
    /// result observer script (as soon as the result renders) or by the
    /// web view finishing navigation – whichever happens first.
    func beginEvaluatingTranslationResult() {
        guard !didStartEvaluation else { return }
        didStartEvaluation = true
        navigationFinishedDate = .now
        timeout?.cancel()
        Task { await evaluateJavaScript() }
    }

    // MARK: - Auxiliary

    func failForMissingValues() {
        setTranslationResult(.failure(.evaluateJavaScriptFailed("Missing required parameters.")))
    }

    func retryOrFail(
        _ error: TranslationError,
        useAlternateString: Bool
    ) async {
        // A terminal event (timeout, navigation failure) may already have
        // delivered the result; don't keep the evaluation loop alive after.
        guard completion != nil else { return }
        guard didReachEvaluationThreshold else {
            // Brief backoff between evaluation attempts; the result observer
            // script surfaces results as soon as they render, so tight polling
            // only wastes main thread time.
            try? await Task.sleep(for: .milliseconds(100))
            return await evaluateJavaScript(useAlternateString: useAlternateString)
        }

        setTranslationResult(.failure(error))
    }

    func setTranslationResult(
        _ translationResult: Result<Translation, TranslationError>
    ) {
        // Only the first terminal event per translation may complete; later
        // ones (a late delegate callback, a stale timeout) are no-ops.
        guard let completion else { return }
        self.completion = nil
        self.translationResult = translationResult
        completion(translationResult)
    }

    private func didSetTranslationResult() {
        Task {
            self.didStartEvaluation = false
            self.navigationFinishedDate = nil
            self.timeout = nil
            self.translationInput = nil
            self.translationLanguagePair = nil
            self.webView?.configuration.userContentController.removeScriptMessageHandler(
                forName: Constants.Strings.Core.resultObserverMessageHandlerName
            )

            self.webView?.removeFromSuperview()
            self.webView = nil
            self.translationResult = nil
        }
    }

    private func getDidReachEvaluationThreshold() -> Bool {
        guard let navigationFinishedDate,
              let elapsedSeconds = Calendar.current.dateComponents(
                  [.second],
                  from: navigationFinishedDate,
                  to: .now
              ).second else { return false }
        return elapsedSeconds >= 10
    }

    private func initializeWebView() {
        // Share only the data store; per-translation user scripts and message
        // handlers require a fresh configuration and content controller.
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = Self.websiteDataStore

        webView = .init(
            frame: .init(
                origin: .zero,
                size: .init(
                    width: UIApplication.shared.mainScreen.bounds.width,
                    height: UIApplication.shared.mainScreen.bounds.height
                )
            ),
            configuration: configuration
        )

        guard let webView else { return }
        webView.alpha = 0
        webView.isUserInteractionEnabled = false
        webView.navigationDelegate = self

        webView.configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        addBlockContentFocusScript()
        addContentSecurityPolicyScript()
        addDenyPermissionsScript()
        addDisableAnimationsScript()
        addDisableServiceWorkerScript()
        addFauxVisibilityScript()
        addPromoteIdleCallbackScript()

        if let resultObserverScript = platform.resultObserverScript {
            webView.configuration.userContentController.addUserScript(.init(
                source: resultObserverScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))

            webView.configuration.userContentController.add(
                WeakScriptMessageHandler(delegate: self),
                name: Constants.Strings.Core.resultObserverMessageHandlerName
            )
        }

        enableBlockThirdPartyCookiesRule()
        enableNoImagesRule()
        enableNoFontsRule()

        UIApplication.shared.keyWindow?.addSubview(webView)
    }
}

extension BaseTranslator: WKNavigationDelegate {
    // MARK: - Create Web View with Configuration

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        nil
    }

    // MARK: - Dedice Policy for Navigation Response

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void
    ) {
        // Only ever allow HTML/text; cancel images, gifs, pdfs, etc.
        let mimeType = navigationResponse.response.mimeType?.lowercased() ?? ""
        let allowedTypes = mimeType.contains("text/html") || mimeType.contains("application/xhtml+xml")
        decisionHandler(allowedTypes ? .allow : .cancel)
    }

    // MARK: - Did Fail Navigation

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        Translator.config.loggerDelegate?.log(
            "Web view failed navigation: \(Translator.descriptor(error))",
            sender: self,
            fileName: #fileID,
            function: #function,
            line: #line
        )

        setTranslationResult(.failure(
            .webViewNavigationFailed(Translator.descriptor(error))
        ))
    }

    // MARK: - Did Fail Provisional Navigation

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        Translator.config.loggerDelegate?.log(
            "Web view failed provisional navigation: \(Translator.descriptor(error))",
            sender: self,
            fileName: #fileID,
            function: #function,
            line: #line
        )

        setTranslationResult(.failure(
            .webViewNavigationFailed(Translator.descriptor(error))
        ))
    }

    // MARK: - Did Finish Navigation

    func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        typealias Strings = Constants.Strings.Core

        Translator.config.loggerDelegate?.log(
            "Web view finished navigation.",
            sender: self,
            fileName: #fileID,
            function: #function,
            line: #line
        )

        // Click to agree to cookie settings.
        guard !webView.url!.absoluteString.hasPrefix(Strings.googleConsentURLString) else {
            return webView.evaluateJavaScript(Strings.googleConsentJavaScriptString)
        }

        beginEvaluatingTranslationResult()
    }

    // MARK: - Did Receive Challenge

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @MainActor (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else { return completionHandler(.useCredential, nil) }

        let urlCredential: URLCredential = .init(trust: serverTrust)
        completionHandler(
            .useCredential,
            urlCredential
        )
    }

    // MARK: - Navigation Action Did Become Download

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.cancel()
    }

    // MARK: - Navigation Response Did Become Download

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        download.cancel()
    }
}

final class StaticWebView: WKWebView {
    override var canBecomeFirstResponder: Bool {
        false
    }

    override var inputAccessoryView: UIView? {
        UIView(frame: .zero)
    }

    override var inputView: UIView? {
        UIView(frame: .zero)
    }
}

/// Proxies script messages through a weak reference, preventing the retain
/// cycle `WKUserContentController` would otherwise create with its handler.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    // MARK: - Properties

    private weak var delegate: (any WKScriptMessageHandler)?

    // MARK: - Init

    init(delegate: any WKScriptMessageHandler) {
        self.delegate = delegate
    }

    // MARK: - Did Receive Script Message

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(
            userContentController,
            didReceive: message
        )
    }
}

extension BaseTranslator: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Constants.Strings.Core.resultObserverMessageHandlerName,
              translationResult == nil else { return }
        beginEvaluatingTranslationResult()
    }
}
