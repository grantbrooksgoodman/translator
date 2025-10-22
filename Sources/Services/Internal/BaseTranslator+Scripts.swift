//
//  BaseTranslator+Scripts.swift
//
//  Created by Grant Brooks Goodman.
//  Copyright © NEOTechnica Corporation. All rights reserved.
//

/* Native */
import Foundation
import WebKit

extension BaseTranslator {
    // MARK: - Scripts

    func addBlockContentFocusScript() {
        let blockContentFocus = """
        (function() {
          // Blur anything that somehow gets focused
          const block = (e) => {
            const t = e.target;
            if (!t) return;
            if (t.matches && (t.matches('input, textarea, select, [contenteditable]'))) {
              try { t.blur(); } catch (e) {}
              e.stopImmediatePropagation();
              e.preventDefault();
            }
          };
          document.addEventListener('focus', block, true);
          document.addEventListener('focusin', block, true);

          // Disable programmatic focus on focusable elements
          const proto = HTMLElement.prototype;
          const origFocus = proto.focus;
          proto.focus = function(...args) {
            if (this.matches && (this.matches('input, textarea, select, [contenteditable], [tabindex]'))) {
              return; // no-op
            }
            return origFocus.apply(this, args);
          };
        })();
        """

        addScript(
            blockContentFocus,
            forMainFrameOnly: false
        )
    }

    func addContentSecurityPolicyScript() {
        let contentSecurityPolicy = """
        (function () {
          var m = document.createElement('meta');
          m.httpEquiv = 'Content-Security-Policy';

          // block images and media; allow everything else to default-policy
          m.content = "img-src 'none'; media-src 'none'";
          document.head.appendChild(m);
        })();
        """

        addScript(
            contentSecurityPolicy,
            forMainFrameOnly: false
        )
    }

    func addDenyPermissionsScript() {
        let denyPermissions = """
        (function(){
          // Notifications
          try { Notification.requestPermission = () => Promise.resolve('denied'); } catch {}
          Object.defineProperty(Notification, 'permission', { get: ()=>'denied' });

          // Generic permissions queries
          if (navigator && navigator.permissions && navigator.permissions.query) {
            const orig = navigator.permissions.query.bind(navigator.permissions);
            navigator.permissions.query = (desc) => {
              if (!desc || !desc.name) return orig(desc);
              // common ones pages check; report denied so they don't enable extras
              if (['notifications','geolocation','camera','microphone','clipboard-read','background-sync'].includes(desc.name)) {
                return Promise.resolve({ state:'denied' });
              }
              return orig(desc);
            };
          }
        })();
        """

        addScript(denyPermissions)
    }

    func addDisableAnimationsScript() {
        let disableAnimations = """
        (function(){
          var s=document.createElement('style');
          s.textContent='*{animation:none!important;transition:none!important;scroll-behavior:auto!important}';
          document.documentElement.appendChild(s);
        })();
        """

        addScript(
            disableAnimations,
            injectionTime: .atDocumentEnd
        )
    }

    func addDisableServiceWorkerScript() {
        let disableServiceWorker = """
        try {
          const orig = navigator.serviceWorker && navigator.serviceWorker.register;
          if (orig) {
            navigator.serviceWorker.register = function() {
              return Promise.reject(new Error('ServiceWorker disabled'));
            };
          }
        } catch(e) {}
        """

        addScript(disableServiceWorker)
    }

    func addFauxVisibilityScript() {
        let fauxVisibility = """
        (function(){
          try {
            // Force visible state
            Object.defineProperty(document, 'hidden', { get: () => false });
            Object.defineProperty(document, 'visibilityState', { get: () => 'visible' });
            // Legacy webkitHidden alias (if present)
            if ('webkitHidden' in document) {
              Object.defineProperty(document, 'webkitHidden', { get: () => false });
            }
            // Fire a visibilitychange to update any listeners
            setTimeout(() => {
              document.dispatchEvent(new Event('visibilitychange'));
              window.dispatchEvent(new Event('pageshow'));
            }, 0);

            // Nudge “good network / no data saver”
            if (navigator && navigator.connection) {
              try {
                Object.defineProperty(navigator.connection, 'saveData', { get: () => false });
                Object.defineProperty(navigator.connection, 'effectiveType', { get: () => '4g' });
              } catch {}
            }
          } catch {}
        })();
        """

        addScript(fauxVisibility)
    }

    func addPromoteIdleCallbackScript() {
        let promoteIdleCallback = """
        (function(){
          // Make requestIdleCallback run ASAP with a large budget
          window.requestIdleCallback = function(cb){
            return setTimeout(() => cb({
              didTimeout: false,
              timeRemaining: function(){ return 50; } // ~3 frames of work
            }), 0);
          };
          window.cancelIdleCallback = function(id){ clearTimeout(id); };
        })();
        """

        addScript(promoteIdleCallback)
    }

    func addTrimLazyLoadersScript() {
        let trimLazyLoaders = """
        (function(){
          // Replace IntersectionObserver with a no-op that always says "in view"
          const IO = window.IntersectionObserver;
          if (IO) {
            window.IntersectionObserver = function(cb){ this.observe = function(t){ cb([{isIntersecting:true, target:t}], this); }; this.unobserve = function(){}; this.disconnect=function(){}; };
          }
        })();
        """

        addScript(trimLazyLoaders)
    }

    // MARK: - Rules

    func enableBlockThirdPartyCookiesRule() {
        let blockThirdPartyCookiesRule = #"""
        [
          { "trigger": { "url-filter": "/gtm\\.js", "if-domain": ["googletagmanager.com","www.googletagmanager.com"], "resource-type": ["script"], "load-type": ["third-party"] }, "action": { "type": "block" } },

          { "trigger": { "url-filter": "/analytics\\.js", "if-domain": ["google-analytics.com","www.google-analytics.com"], "resource-type": ["script"], "load-type": ["third-party"] }, "action": { "type": "block" } },
          { "trigger": { "url-filter": "/gtag/js",        "if-domain": ["google-analytics.com","www.google-analytics.com"], "resource-type": ["script"], "load-type": ["third-party"] }, "action": { "type": "block" } },
          { "trigger": { "url-filter": "/collect\\?.*",   "if-domain": ["google-analytics.com","www.google-analytics.com","stats.g.doubleclick.net"], "load-type": ["third-party"] }, "action": { "type": "block" } },

          { "trigger": { "url-filter": "/", "if-domain": ["doubleclick.net","*.doubleclick.net"], "load-type": ["third-party"] }, "action": { "type": "block" } },

          { "trigger": { "url-filter": "/tr", "if-domain": ["facebook.com","www.facebook.com"], "load-type": ["third-party"] }, "action": { "type": "block" } },

          { "trigger": { "url-filter": "/", "if-domain": ["hotjar.com","*.hotjar.com"], "load-type": ["third-party"] }, "action": { "type": "block" } },

          { "trigger": { "url-filter": "/analytics\\.js", "if-domain": ["segment.com","cdn.segment.com"], "resource-type": ["script"], "load-type": ["third-party"] }, "action": { "type": "block" } }
        ]
        """#

        addRule(name: "no-trackers", blockThirdPartyCookiesRule)
    }

    func enableNoImagesRule() {
        let noImagesRule = """
        [{
          "trigger": { "url-filter": ".*", "resource-type": ["image","media"] },
          "action": { "type": "block" }
        }]
        """

        addRule(name: "no-images", noImagesRule)
    }

    func enableNoFontsRule() {
        let noFontsRule = """
        [{
          "trigger": { "url-filter": ".*", "resource-type": ["font"] },
          "action": { "type": "block" }
        }]
        """

        addRule(name: "no-fonts", noFontsRule)
    }

    // MARK: - Auxiliary

    private func addRule(
        name: String,
        _ rule: String
    ) {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: name,
            encodedContentRuleList: rule
        ) { ruleList, error in
            if let ruleList {
                self.webView?.configuration.userContentController.add(ruleList)
            } else {
                var descriptor = "An unknown error occurred."
                if let error { descriptor = Translator.descriptor(error) }
                Config.shared.loggerDelegate?.log(
                    descriptor,
                    sender: self,
                    fileName: #file,
                    function: #function,
                    line: #line
                )
            }
        }
    }

    private func addScript(
        _ script: String,
        injectionTime: WKUserScriptInjectionTime = .atDocumentStart,
        forMainFrameOnly: Bool = true
    ) {
        webView?
            .configuration
            .userContentController
            .addUserScript(.init(
                source: script,
                injectionTime: injectionTime,
                forMainFrameOnly: forMainFrameOnly
            ))
    }
}
