import WebKit
import UIKit

/// WKWebView-based fetcher that extracts the `arytbl` vessel data array
/// from the Yokohama port website.
///
/// KEY FINDING: The server returns arytbl=null when cbo_cberth=MTK0C is
/// specified in the URL. Fetching without a berth filter returns ALL vessels
/// with arytbl populated. Client-side filtering by PBerth is done in
/// BerthMonitorService after fetching.
///
/// arytbl field indices (named JS constants on the page):
///  [0]=CallSign  [1]=VesselName  [2]=GT     [3]=LOA
///  [4]=Status    [7]=Country     [8]=Route  [12]=PBerth
///  [13]=PEta     [14]=PStart     [15]=PAta(着岸予定)  [16]=PAtd(離岸予定)
///  [19]=EAta(着岸実績)            [21]=EAtd(離岸実績)
@MainActor
final class BerthWebFetcher: NSObject {

    private var webView: WKWebView?
    private var continuation: CheckedContinuation<[[String]], Error>?
    private var timeoutTask: Task<Void, Never>?

    /// Loads the berth schedule page and returns the raw `arytbl` rows
    /// once `SetTblContent()` is called by the page's JavaScript.
    func fetchArytbl() async throws -> [[String]] {
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.setupWebView()
        }
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(self, name: "arytblCapture")

        // Intercept SetTblContent() and also poll arytbl in case it was
        // already set before our script ran.
        let captureScript = WKUserScript(source: """
            (function() {
                var _sent = false;
                function trySend() {
                    if (_sent) return false;
                    if (typeof arytbl !== 'undefined' && arytbl !== null && arytbl.length > 0) {
                        _sent = true;
                        window.webkit.messageHandlers.arytblCapture.postMessage(JSON.stringify(arytbl));
                        return true;
                    }
                    return false;
                }
                // Wrap SetTblContent so we capture the moment data is injected
                var _orig = window.SetTblContent;
                window.SetTblContent = function() {
                    if (typeof _orig === 'function') _orig.apply(this, arguments);
                    trySend();
                };
                // Fallback: poll every 500 ms for up to 20 s
                var _attempts = 0;
                var _poll = setInterval(function() {
                    if (trySend() || ++_attempts > 40) clearInterval(_poll);
                }, 500);
            })();
        """, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        controller.addUserScript(captureScript)
        config.userContentController = controller

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        self.webView = wv

        // WKWebView requires a window attachment for JS to execute
        // Use keyWindow for iOS 15+ compatibility
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.keyWindow
        if let window = keyWindow {
            wv.frame = CGRect(x: -1, y: -1, width: 1, height: 1)
            wv.alpha = 0
            window.addSubview(wv)
        }

        // NOTE: cbo_cberth must be EMPTY — specifying MTK0C causes the server
        // to return arytbl=null. All vessels are fetched and filtered client-side.
        let url = URL(string: """
            https://www.port.city.yokohama.lg.jp/APP/Pves0040InPlanC\
            ?hid_sessionid=&hid_gamenid=Jyoho04&hid_userid=\
            &cbo_cberth=&txt_cetay=&txt_cetam=&txt_cetad=\
            &cbo_status=&txt_callsign=
            """.replacingOccurrences(of: "\n", with: ""))!
        var request = URLRequest(url: url, timeoutInterval: 90)
        wv.load(request)

        // Hard timeout — give the page 90 s to load and respond
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 90_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.finish(throwing: URLError(.timedOut))
        }
    }

    private func finish(with rows: [[String]]) {
        timeoutTask?.cancel()
        webView?.removeFromSuperview()
        webView = nil
        continuation?.resume(returning: rows)
        continuation = nil
    }

    private func finish(throwing error: Error) {
        timeoutTask?.cancel()
        webView?.removeFromSuperview()
        webView = nil
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - WKScriptMessageHandler

extension BerthWebFetcher: WKScriptMessageHandler {
    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "arytblCapture",
              let jsonString = message.body as? String,
              let data = jsonString.data(using: .utf8),
              let rawArray = try? JSONSerialization.jsonObject(with: data) as? [[Any]]
        else { return }

        // Normalise every element to String so callers have a uniform type
        let stringRows = rawArray.map { row in
            row.map { element -> String in
                if let s = element as? String { return s }
                return "\(element)"
            }
        }
        finish(with: stringRows)
    }
}

// MARK: - WKNavigationDelegate

extension BerthWebFetcher: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        let nsErr = error as NSError
        print("[BerthFetcher] didFail: domain=\(nsErr.domain) code=\(nsErr.code) url=\(webView.url?.absoluteString ?? "nil")")
        finish(throwing: error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        let nsErr = error as NSError
        print("[BerthFetcher] didFailProvisional: domain=\(nsErr.domain) code=\(nsErr.code) url=\(webView.url?.absoluteString ?? "nil")")
        finish(throwing: error)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("[BerthFetcher] didStartProvisional: url=\(webView.url?.absoluteString ?? "nil")")
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[BerthFetcher] didFinish: url=\(webView.url?.absoluteString ?? "nil")")
    }
}
