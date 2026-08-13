import SwiftUI
import WebKit

/// WKWebView pour le rendu HTML des mails. Par défaut, tout chargement réseau
/// est bloqué (règles de contenu) pour neutraliser les pixels de tracking ;
/// `allowRemote` lève le blocage à la demande.
struct HTMLView: NSViewRepresentable {
    let html: String
    var allowRemote: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.render(html: html, allowRemote: allowRemote, in: webView)
    }

    @MainActor
    final class Coordinator {
        private var lastRenderKey: Int?

        func render(html: String, allowRemote: Bool, in webView: WKWebView) {
            var hasher = Hasher()
            hasher.combine(html)
            hasher.combine(allowRemote)
            let key = hasher.finalize()
            guard key != lastRenderKey else { return }
            lastRenderKey = key

            let document = Self.wrap(html)
            if allowRemote {
                webView.configuration.userContentController.removeAllContentRuleLists()
                webView.loadHTMLString(document, baseURL: nil)
            } else {
                Self.blockAllRules { [weak self, weak webView] rules in
                    // La compilation est asynchrone : n'appliquer le résultat que
                    // si aucun rendu plus récent n'a été demandé entre-temps.
                    guard let self, let webView, self.lastRenderKey == key else { return }
                    webView.configuration.userContentController.removeAllContentRuleLists()
                    if let rules {
                        webView.configuration.userContentController.add(rules)
                    }
                    webView.loadHTMLString(document, baseURL: nil)
                }
            }
        }

        private static func wrap(_ html: String) -> String {
            if html.range(of: "<html", options: .caseInsensitive) != nil {
                return html
            }
            return """
            <!doctype html>
            <html>
            <head>
            <meta charset="utf-8">
            <meta name="color-scheme" content="light dark">
            <style>
            body { font-family: -apple-system, sans-serif; font-size: 13px; margin: 12px; }
            img { max-width: 100%; height: auto; }
            </style>
            </head>
            <body>\(html)</body>
            </html>
            """
        }

        private static var cachedRules: WKContentRuleList?

        /// Bloque toute requête réseau ; les images inline `data:` restent autorisées.
        private static func blockAllRules(_ completion: @escaping (WKContentRuleList?) -> Void) {
            if let cachedRules {
                completion(cachedRules)
                return
            }
            let json = """
            [
              {"trigger": {"url-filter": ".*"}, "action": {"type": "block"}},
              {"trigger": {"url-filter": "^data:"}, "action": {"type": "ignore-previous-rules"}},
              {"trigger": {"url-filter": "^about:"}, "action": {"type": "ignore-previous-rules"}}
            ]
            """
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "block-remote-content",
                encodedContentRuleList: json
            ) { rules, _ in
                cachedRules = rules
                completion(rules)
            }
        }
    }
}
