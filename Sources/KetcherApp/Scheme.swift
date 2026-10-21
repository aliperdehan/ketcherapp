import Foundation
import WebKit

/// Serves the built Ketcher bundle from the app's Resources under `ketcher://app/`.
/// A custom scheme (not `file://`) keeps WebAssembly, workers and fetch working, and lets the CSP below
/// cut every network request.
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "ketcher"
    static let entry = URL(string: "ketcher://app/index.html")!

    // Everything must come from the bundle; blob:/data: are needed by Ketcher's file export and canvas.
    static let csp = [
        "default-src ketcher:",
        "script-src ketcher: 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' blob:",
        "style-src ketcher: 'unsafe-inline'",
        "img-src ketcher: data: blob:",
        "font-src ketcher: data:",
        "worker-src ketcher: blob:",
        "connect-src ketcher: data: blob:",
    ].joined(separator: "; ")

    private static let mime: [String: String] = [
        "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8",
        "mjs": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
        "json": "application/json", "map": "application/json", "wasm": "application/wasm",
        "svg": "image/svg+xml", "png": "image/png", "jpg": "image/jpeg", "gif": "image/gif",
        "ico": "image/x-icon", "woff": "font/woff", "woff2": "font/woff2", "ttf": "font/ttf",
        "txt": "text/plain; charset=utf-8",
    ]

    private let root: URL

    init(root: URL) { self.root = root.standardizedFileURL }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return task.didFailWithError(URLError(.badURL)) }
        var path = url.path
        if path.isEmpty || path.hasSuffix("/") { path += "index.html" }
        let file = root.appendingPathComponent(path).standardizedFileURL
        let inside = file.path.hasPrefix(root.path + "/")
        let data = inside ? try? Data(contentsOf: file) : nil
        let type = Self.mime[file.pathExtension.lowercased()] ?? "application/octet-stream"
        var headers = ["Content-Type": type, "Cache-Control": "no-store",
                       "Content-Security-Policy": Self.csp]
        if let data { headers["Content-Length"] = String(data.count) }
        let response = HTTPURLResponse(url: url, statusCode: data == nil ? 404 : 200,
                                       httpVersion: "HTTP/1.1", headerFields: headers)!
        task.didReceive(response)
        if let data { task.didReceive(data) }
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
