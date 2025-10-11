//
//  BaseTranslator.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation

@preconcurrency import WebKit

class BaseTranslator: NSObject {
    // MARK: - Properties

    private(set) var translationInput: TranslationInput?
    private(set) var translationLanguagePair: LanguagePair?
    private(set) var webView: WKWebView?

    private let platform: TranslationPlatform

    private var dispatchGroup: DispatchGroup?
    private var navigationFinishedDate: Date?
    private var timeout: Timeout?
    private var translationResult: Result<Translation, TranslationError>? {
        didSet { didSetTranslationResult() }
    }

    // MARK: - Computed Properties

    private var didReachEvaluationThreshold: Bool { getDidReachEvaluationThreshold() }

    // MARK: - Init

    init(platform: TranslationPlatform) {
        self.platform = platform
    }

    // MARK: - Translate

    @MainActor
    func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair
    ) async -> Result<Translation, TranslationError> {
        return await withCheckedContinuation { continuation in
            translate(
                input,
                languagePair: languagePair
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    @MainActor
    private func translate(
        _ input: TranslationInput,
        languagePair: LanguagePair,
        completion: @escaping (Result<Translation, TranslationError>) -> Void
    ) {
        guard let requestURL = platform.requestURL(
            input.value,
            languagePair: languagePair
        ) else { return completion(.failure(.failedToGenerateRequestURL)) }

        translationInput = input
        translationLanguagePair = languagePair

        clearCookies()
        initializeWebView()
        dispatchGroup = .init()

        timeout = Timeout(after: .seconds(10)) { self.setTranslationResult(.failure(.timedOut)) }

        dispatchGroup?.enter()
        webView?.load(.init(url: requestURL))
        dispatchGroup?.notify(queue: .main) { completion(self.translationResult ?? .failure(.unknown())) }
    }

    // MARK: - Evaluate JavaScript

    @MainActor
    open func evaluateJavaScript(useAlternateString: Bool = false) async {
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

    // MARK: - Auxiliary

    func failForMissingValues() {
        setTranslationResult(.failure(.evaluateJavaScriptFailed("Missing required parameters.")))
    }

    func retryOrFail(_ error: TranslationError, useAlternateString: Bool) async {
        guard didReachEvaluationThreshold else { return await evaluateJavaScript(useAlternateString: useAlternateString) }
        setTranslationResult(.failure(error))
    }

    func setTranslationResult(_ translationResult: Result<Translation, TranslationError>) {
        dispatchGroup?.leave()
        self.translationResult = translationResult
    }

    private func clearCookies() {
        let websiteDataStore = WKWebsiteDataStore.default()
        websiteDataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            for record in records {
                websiteDataStore.removeData(
                    ofTypes: record.dataTypes,
                    for: [record],
                    completionHandler: {}
                )
            }
        }

        DispatchQueue.global(qos: .utility).async {
            HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        }
    }

    private func didSetTranslationResult() {
        DispatchQueue.main.async {
            self.dispatchGroup = nil
            self.navigationFinishedDate = nil
            self.timeout = nil
            self.translationInput = nil
            self.translationLanguagePair = nil
            self.webView?.removeFromSuperview()
            self.webView = nil
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
        webView = .init(frame: .init(
            origin: .zero,
            size: .init(
                width: UIApplication.shared.mainScreen.bounds.width,
                height: UIApplication.shared.mainScreen.bounds.height
            )
        ))

        guard let webView else { return }
        webView.alpha = 0
        webView.navigationDelegate = self
        UIApplication.shared.keyWindow?.addSubview(webView)
    }
}

extension BaseTranslator: WKNavigationDelegate {
    // MARK: - Did Fail Navigation

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        Config.shared.loggerDelegate?.log(
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
        Config.shared.loggerDelegate?.log(
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

        Config.shared.loggerDelegate?.log(
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

        navigationFinishedDate = .now
        timeout?.cancel()
        Task { await evaluateJavaScript() }
    }

    // MARK: - Did Receive Challenge

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else { return completionHandler(.useCredential, nil) }

        let urlCredential: URLCredential = .init(trust: serverTrust)
        DispatchQueue.global(qos: .userInteractive).async { completionHandler(.useCredential, urlCredential) }
    }
}
