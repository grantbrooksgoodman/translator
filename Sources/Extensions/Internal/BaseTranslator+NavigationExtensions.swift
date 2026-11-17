//
//  BaseTranslator+NavigationExtensions.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
@preconcurrency import WebKit

extension BaseTranslator: WKNavigationDelegate {
    // MARK: - Constants Accessors

    private typealias Strings = Constants.Strings.Core

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
        decisionHandler(mimeType.contains("text/html") || mimeType.contains("application/xhtml+xml") ? .allow : .cancel)
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
        Translator.config.loggerDelegate?.log(
            "Web view finished navigation.",
            sender: self,
            fileName: #fileID,
            function: #function,
            line: #line
        )

        // Click to agree to cookie settings.
        guard !webView
            .url!
            .absoluteString
            .hasPrefix(Strings.googleConsentURLString) else {
            return webView
                .evaluateJavaScript(Strings.googleConsentJavaScriptString)
        }

        beginEvaluatingTranslationResult()
    }

    // MARK: - Did Receive Challenge

    func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @MainActor (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            return completionHandler(
                .useCredential,
                nil
            )
        }

        completionHandler(
            .useCredential,
            URLCredential(trust: serverTrust)
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
