# Selection, notebook caret, and distribution review

Date: 2026-09-07
Status: Source fixes complete; public installation alert unresolved

## Code selection

The pinned editor had two integration limitations: SwiftUI cursor updates compared the state to itself, and read-only single clicks did not position the cursor. Palm now uses the public TextViewCoordinator API to select exact AST ranges and a non-delaying click recognizer to select the clicked AST element directly. Code remains non-editable. The selected element shows its type. Expand and Shrink move through its ancestor path; Ask opens the lesson tutor with the selected text. The old selection menu is removed. Whitespace clicks are ignored, and unsupported language hints require choosing a known language rather than guessing a grammar. Language aliases and an explicit language picker cover snippets with missing or abbreviated hints.

Native review with an isolated synthetic library confirmed one click → highlighted identifier → expand to attribute and call → shrink → exact tutor attachment. Unit tests cover Python nesting, Unicode offsets, aliases, invalid ranges, EOF, applying native ranges, stale code, and coordinator teardown. Question code indentation was left unchanged as requested.

## Notebook caret

Editable line boxes now use the text's natural line height. Code block pre/code share the same font metrics; block padding keeps paragraphs separated. This reduces WebKit's oversized caret behavior without replacing the native caret or changing editing/IME handling. Native notebook review covered body text, code blocks, editing and undo, with flow diagrams and highlights still rendered. This was checked on the development Mac; caret rasterization on other macOS versions is not verified.

Reference: [WebKit caret and line-height issue](https://bugs.webkit.org/show_bug.cgi?id=287429).

## Validation

- Swift suite: 72 passed, 6 opt-in live-provider tests skipped, zero failures.
- Editor typecheck, 3 tests, and production bundle passed.
- Native Release build and strict local signature integrity checks passed.
- Public packaging rejects the available ad-hoc build because Developer ID is missing.
- No live model calls were required. No personal library was used for fixture testing.

## Distribution remains blocked

The user reports “Palm will damage your computer.” Local Apple checks found ad-hoc signing and a missing notarization ticket but did not reproduce a malware-specific finding. The warning is not established to be a false positive. Both old installers remain in GitHub drafts; the live website states that downloads are paused. A free Apple developer account cannot provide Developer ID distribution signing. See [ADR 0008](adr/0008-distribution-security-gate.md) and [release steps](RELEASING.md).
