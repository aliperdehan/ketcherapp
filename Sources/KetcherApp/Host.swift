import AppKit
import WebKit

/// Owns the WKWebView and answers the questions a browser would normally answer: where a download goes, what the
/// file picker shows, whether a link may leave the app.
final class WebHost: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, WKScriptMessageHandlerWithReply {
    let webView: WKWebView
    weak var window: NSWindow?

    /// Set by --selftest: downloads land here without a save panel. `onDownload` gets the saved file (nil on failure).
    var autoDownloadDir: URL?
    var onDownload: ((URL?) -> Void)?
    private var downloadTargets: [ObjectIdentifier: URL] = [:]

    // Rubber-banding and swipe-back are what the app exists to avoid.
    private static let noOverscroll = """
        const s = document.createElement('style');
        s.textContent = 'html, body { overscroll-behavior: none; }';
        document.documentElement.appendChild(s);
        """

    // Ketcher copies and pastes through navigator.clipboard, and WebKit refuses it (NotAllowedError) once the user
    // gesture is gone: a menu ⌘C reaches Ketcher's copy handler, which awaits Indigo before writing, so nothing lands
    // on the pasteboard and ⌘V has nothing to read. This replaces it with a bridge to NSPasteboard. Ketcher only
    // uses text/plain (MOL or KET text) and image/png (Copy Image).
    private static let clipboardShim = """
        (() => {
          const post = (message) => window.webkit.messageHandlers.clipboard.postMessage(message);
          const base64 = (blob) => new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(String(reader.result).split(',')[1]);
            reader.onerror = reject;
            reader.readAsDataURL(blob);
          });
          const readText = async () => (await post({ read: true })).text;
          const clipboard = {
            writeText: async (text) => { await post({ text: String(text) }); },
            write: async (items) => {
              const message = {};
              for (const type of items[0].types) {
                const blob = await items[0].getType(type);
                if (type === 'text/plain') message.text = await blob.text();
                else if (type === 'image/png') message.png = await base64(blob);
              }
              await post(message);
            },
            readText,
            read: async () => [new ClipboardItem({ 'text/plain': new Blob([await readText()], { type: 'text/plain' }) })],
          };
          Object.defineProperty(navigator, 'clipboard', { value: clipboard, configurable: true });
        })();
        """

    init(resources: URL) {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(root: resources.appendingPathComponent("web")),
                                   forURLScheme: BundleSchemeHandler.scheme)
        config.userContentController.addUserScript(WKUserScript(
            source: Self.noOverscroll, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        config.userContentController.addUserScript(WKUserScript(
            source: Self.clipboardShim, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = false
        if #available(macOS 13.3, *) {
            webView.isInspectable = ProcessInfo.processInfo.environment["KETCHER_DEBUG"] != nil
        }
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.configuration.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "clipboard")
    }

    func load() { webView.load(URLRequest(url: BundleSchemeHandler.entry)) }

    // MARK: navigation

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.shouldPerformDownload { return decisionHandler(.download) }
        guard let url = action.request.url else { return decisionHandler(.cancel) }
        switch url.scheme {
        case BundleSchemeHandler.scheme, "blob", "data", "about":
            decisionHandler(.allow)
        case "http", "https", "mailto":
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        default:
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(response.canShowMIMEType ? .allow : .download)
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }

    // target=_blank and window.open: links go to the default browser, nothing opens inside the app.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url, ["http", "https", "mailto"].contains(url.scheme) {
            NSWorkspace.shared.open(url)
        }
        return nil
    }

    // MARK: downloads (Ketcher's "Save as" is a blob download)

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
                  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let key = ObjectIdentifier(download)
        if let dir = autoDownloadDir {
            let target = dir.appendingPathComponent(suggestedFilename)
            try? FileManager.default.removeItem(at: target)
            downloadTargets[key] = target
            return completionHandler(target)
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedFilename
        panel.canCreateDirectories = true
        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] result in
            guard result == .OK, let url = panel.url else { return completionHandler(nil) }
            try? FileManager.default.removeItem(at: url)   // the panel already confirmed the overwrite
            self?.downloadTargets[key] = url
            completionHandler(url)
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: finish) } else { finish(panel.runModal()) }
    }

    func downloadDidFinish(_ download: WKDownload) {
        onDownload?(downloadTargets.removeValue(forKey: ObjectIdentifier(download)))
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadTargets[ObjectIdentifier(download)] = nil
        if let onDownload { return onDownload(nil) }
        let alert = NSAlert(error: error)
        alert.messageText = "Could not save the file"
        alert.runModal()
    }

    // MARK: clipboard bridge

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard message.frameInfo.securityOrigin.protocol == BundleSchemeHandler.scheme,
              let body = message.body as? [String: Any] else { return replyHandler(nil, "not allowed") }
        let pasteboard = NSPasteboard.general
        if body["read"] != nil { return replyHandler(["text": pasteboard.string(forType: .string) ?? ""], nil) }
        pasteboard.clearContents()
        if let text = body["text"] as? String { pasteboard.setString(text, forType: .string) }
        if let png = (body["png"] as? String).flatMap({ Data(base64Encoded: $0) }) { pasteboard.setData(png, forType: .png) }
        replyHandler(nil, nil)
    }

    // MARK: file picker and JavaScript dialogs

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        let finish: (NSApplication.ModalResponse) -> Void = { result in
            completionHandler(result == .OK ? panel.urls : nil)
        }
        if let window { panel.beginSheetModal(for: window, completionHandler: finish) } else { finish(panel.runModal()) }
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        completionHandler(alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil)
    }
}
