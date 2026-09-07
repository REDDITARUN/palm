import SwiftUI
import WebKit
import PalmCore

struct BlockNoteEditor: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    var note: StudyNote
    var links: [String: String] = [:]
    var openNote: (String) -> Void = { _ in }
    var changed: (UUID, String, String, String) -> Void
    var selected: (String) -> Void
    var askSelection: (String) -> Void = { _ in }
    var failed: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "palm")
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        context.coordinator.webView = view
        if let url = WorkspaceResources.editorURL { view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
        else { failed("The bundled note editor is missing.") }
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) { context.coordinator.parent = self; context.coordinator.load() }
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.evaluateJavaScript("window.palm?.flush()")
        view.configuration.userContentController.removeScriptMessageHandler(forName: "palm")
    }
    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: BlockNoteEditor
        weak var webView: WKWebView?
        var ready = false
        var lastLoad = ""
        var loadedRevisions: [String: String] = [:]
        init(_ parent: BlockNoteEditor) { self.parent = parent }
        func load() {
            guard ready else { return }
            let identity = (parent.note.documentRevision?.uuidString ?? parent.note.id.uuidString) + String(parent.colorScheme == .dark) + parent.links.sorted { $0.key < $1.key }.map { $0.key + $0.value }.joined()
            guard lastLoad != identity else { return }; lastLoad = identity
            var payload: [String: Any] = ["links": parent.links, "id": parent.note.id.uuidString, "markdown": parent.note.body, "dark": parent.colorScheme == .dark, "revision": parent.note.documentRevision?.uuidString ?? parent.note.id.uuidString]
            loadedRevisions[parent.note.id.uuidString] = parent.note.documentRevision?.uuidString ?? parent.note.id.uuidString
            if let blocks = parent.note.blocksJSON { payload["blocks"] = blocks }
            webView?.callAsyncJavaScript("window.palm.load(payload)", arguments: ["payload": payload], in: nil, in: .page, completionHandler: { _ in })
        }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let payload = message.body as? [String: Any], let type = payload["type"] as? String else { return }
            switch type {
            case "ready": ready = true; load()
            case "change":
                guard let identity = payload["id"] as? String, let id = UUID(uuidString: identity), let revision = payload["revision"] as? String, loadedRevisions[identity] == revision, let blocks = payload["blocks"] as? String, let markdown = payload["markdown"] as? String else { return }
                // A final edit may arrive after selection moved to another note. Route it by its document identity.
                parent.changed(id, revision, markdown, blocks)
            case "openNote": if let target = payload["target"] as? String { parent.openNote(target) }
            case "askSelection": if let text = payload["text"] as? String { parent.askSelection(text) }
            case "selection": if let text = payload["text"] as? String, !text.isEmpty { parent.selected(text) }
            case "error": parent.failed(payload["message"] as? String ?? "The note editor could not open this document.")
            default: break
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                if ["http", "https"].contains(url.scheme) { NSWorkspace.shared.open(url) }
                decisionHandler(.cancel)
            } else { decisionHandler(action.request.url?.isFileURL == true ? .allow : .cancel) }
        }
    }
}
