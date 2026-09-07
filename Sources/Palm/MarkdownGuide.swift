import SwiftUI

struct MarkdownGuide: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSource = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("A little structure, a clearer idea.").font(.system(size: 23, weight: .semibold)); Spacer(); Button("Done") { dismiss() } }
            Text("Write Markdown in Edit. Read renders formulas and diagrams locally. Select text in the editor to use the formatting toolbar; highlighting is saved as ==text==.").font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(4)
            WorkspaceTabs(title: "Example mode", selection: $showSource, options: [.init(false, "Preview"), .init(true, "Markdown source")])
            ScrollView { if showSource { Text(Self.example).font(.system(size: 13, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) } else { MarkdownReading(text: Self.example) } }.padding(18).background(Palette.surface, in: .rect(cornerRadius: 12))
        }.padding(26).frame(width: 700, height: 660).background(Palette.background)
    }
    static let example = #"""
    ## Start with something concrete

    Imagine looking for a name in a sorted list. Binary search checks the middle and keeps only the half that can contain the name. ==Each comparison halves the remaining search space.==

    > A useful reminder: binary search needs a sorted list.

    ### Follow the decision

    ```mermaid
    flowchart TD
      A["Check the middle item"] --> B{"Is it the target?"}
      B -->|Yes| C["Return its position"]
      B -->|No| D["Keep the relevant half"]
      D --> A
    ```

    ### Put a number on it

    After $k$ halvings, roughly $n / 2^k$ items remain. Starting with eight items, three halvings leave one:

    $$
    \frac{8}{2^3} = 1
    $$

    The variables are $n$, the starting number of items, and $k$, the number of halvings.

    | Start | After one halving | After two |
    | --- | --- | --- |
    | 8 items | 4 items | 2 items |

    A plain text flow works too:

    ```text
    8 candidates → 4 → 2 → 1
    ```

    **Try it:** How many halvings reduce sixteen candidates to one?
    """#
}
