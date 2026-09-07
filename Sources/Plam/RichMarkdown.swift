import SwiftUI
import Textual
import WebKit
import PlamCore

struct StudyMarkdownParser: MarkupParser {
    func attributedString(for input: String) throws -> AttributedString {
        let prepared = MathMarkdown.prepare(input)
        let parser = AttributedStringMarkdownParser(baseURL: nil, syntaxExtensions: [.math])
        var result = try parser.attributedString(for: prepared.text)
        for formula in prepared.formulas {
            guard let range = result.range(of: formula.token) else { continue }
            var rendered = try parser.attributedString(for: formula.markdown)
            rendered.presentationIntent = result[range].presentationIntent
            result.replaceSubrange(range, with: rendered)
        }
        let plain = String(result.characters)
        let regex = try NSRegularExpression(pattern: #"==([^=\n]+)=="#)
        for match in regex.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)).reversed() {
            guard let range = Range(match.range, in: plain), let inner = Range(match.range(at: 1), in: plain),
                  let start = AttributedString.Index(range.lowerBound, within: result), let end = AttributedString.Index(range.upperBound, within: result),
                  let innerStart = AttributedString.Index(inner.lowerBound, within: result), let innerEnd = AttributedString.Index(inner.upperBound, within: result) else { continue }
            let markerEnd = result.index(start, offsetByCharacters: 2)
            let isCode = result[start..<markerEnd].runs.contains { run in
                run.inlinePresentationIntent?.contains(.code) == true || run.presentationIntent?.components.contains { if case .codeBlock = $0.kind { return true }; return false } == true
            }
            guard !isCode else { continue }
            var marked = AttributedString(result[innerStart..<innerEnd]); marked.backgroundColor = .yellow.opacity(0.32)
            result.replaceSubrange(start..<end, with: marked)
        }
        return result
    }
}

struct MermaidDiagram: View {
    var source: String
    var showsControls = true
    @State private var height: CGFloat = 150
    @State private var expanded = false
    @State private var expandedHeight: CGFloat = 400
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DiagramWebView(source: source, height: $height).frame(height: height)
            if showsControls { HStack(alignment: .top) {
                DisclosureGroup("Diagram source") { Text(source).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10) }.font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                Button { expanded = true } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }.buttonStyle(IconButton()).help("Expand diagram").accessibilityLabel("Expand diagram")
            }.padding(.horizontal, 12).padding(.bottom, 8) }
        }.background(Palette.surface, in: .rect(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
            .sheet(isPresented: $expanded) {
                VStack(spacing: 12) {
                    HStack { Text("Diagram").font(.headline); Spacer(); Button("Done") { expanded = false }.buttonStyle(QuietButton()).keyboardShortcut(.cancelAction) }
                    ScrollView { DiagramWebView(source: source, height: $expandedHeight).frame(height: expandedHeight) }
                }.padding(24).frame(width: 850, height: 620)
            }
    }
}

private struct DiagramWebView: NSViewRepresentable {
    var source: String
    @Binding var height: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    func makeCoordinator() -> Coordinator { Coordinator(height: $height) }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "diagram")
        let view = WKWebView(frame: .zero, configuration: config)
        view.setValue(false, forKey: "drawsBackground")
        view.navigationDelegate = context.coordinator
        if let url = MarkdownBlocks.diagramPageURL { view.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent()) }
        return view
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.height = $height
        let dark = colorScheme == .dark
        guard coordinator.source != source || coordinator.dark != dark else { return }
        coordinator.source = source; coordinator.dark = dark
        if coordinator.ready { coordinator.draw(view) }
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading(); view.configuration.userContentController.removeScriptMessageHandler(forName: "diagram")
        view.navigationDelegate = nil
    }
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var source = "", dark = false, ready = false
        var height: Binding<CGFloat>
        init(height: Binding<CGFloat>) { self.height = height }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready = true; draw(webView) }
        func draw(_ view: WKWebView) {
            Task { _ = try? await view.callAsyncJavaScript("await window.draw(source, dark)", arguments: ["source": source, "dark": dark], in: nil, contentWorld: .page) }
        }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let payload = message.body as? [String: Any], let value = payload["height"] as? Double, value.isFinite else { return }
            let next = min(800, max(80, value))
            if abs(height.wrappedValue - next) > 1 { height.wrappedValue = next }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            decisionHandler(navigationAction.request.url == MarkdownBlocks.diagramPageURL ? .allow : .cancel)
        }
    }
}
