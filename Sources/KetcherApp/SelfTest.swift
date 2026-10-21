import AppKit
import WebKit

/// `KetcherApp --selftest`: loads the bundled Ketcher in a window that is never shown and checks what the wrapper
/// is responsible for (bundle served, Indigo WASM runs, network cut, blob download reaches disk). Exit 0 = all pass.
final class SelfTest {
    private let host: WebHost
    private let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("ketcherapp-selftest-\(getpid())")
    private var script: [String: Any]?
    private var saved: URL??
    private var finished = false

    init(host: WebHost) { self.host = host }

    func run() {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        host.autoDownloadDir = dir
        host.onDownload = { [weak self] url in self?.saved = .some(url); self?.checkDone() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in self?.fail("timed out") }
        waitForKetcher()
    }

    private func fail(_ message: String) {
        guard !finished else { return }
        print("FAIL: \(message)")
        exit(1)
    }

    private func waitForKetcher() {
        host.webView.evaluateJavaScript("typeof window.ketcher") { [weak self] result, _ in
            guard let self else { return }
            if (result as? String) == "object" { return self.exercise() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.waitForKetcher() }
        }
    }

    private func exercise() {
        print("ok: Ketcher loaded from the bundle")
        let body = """
            await window.ketcher.setMolecule('CCO');
            const smiles = await window.ketcher.getSmiles();
            let external = 'reached';
            try { await fetch('https://example.com/', { mode: 'no-cors' }); } catch (e) { external = 'blocked'; }
            const a = document.createElement('a');
            a.href = URL.createObjectURL(new Blob(['hello ketcher'], { type: 'text/plain' }));
            a.download = 'selftest.txt';
            document.body.appendChild(a);
            a.click();
            return { smiles, external };
            """
        host.webView.callAsyncJavaScript(body, arguments: [:], in: nil, in: .page) { [weak self] result in
            switch result {
            case .failure(let error): self?.fail("script: \(error)")
            case .success(let value):
                self?.script = value as? [String: Any]
                self?.checkDone()
            }
        }
    }

    private func checkDone() {
        guard let script, let saved else { return }
        finished = true
        var failed = false
        func check(_ ok: Bool, _ pass: String, _ fail: String) {
            print(ok ? "ok: \(pass)" : "FAIL: \(fail)")
            if !ok { failed = true }
        }
        let smiles = script["smiles"] as? String
        check(smiles == "CCO", "Indigo WASM round-trips ethanol (CCO)", "getSmiles returned \(smiles ?? "nil")")
        let external = script["external"] as? String
        check(external == "blocked", "external fetch is blocked", "external fetch was \(external ?? "nil")")
        let text = saved.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        check(text == "hello ketcher", "blob download saved selftest.txt", "blob download gave \(text ?? "no file")")
        let web = host.webView
        check(!web.allowsBackForwardNavigationGestures && !web.allowsMagnification,
              "swipe-back and pinch-zoom are off", "a browser gesture is on")
        try? FileManager.default.removeItem(at: dir)
        exit(failed ? 1 : 0)
    }
}
