import SwiftUI

struct WorkStatusView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 3) {
                Text(store.busy ?? "Working…").font(.system(size: 12, weight: .medium))
                Text(store.workActivity.isEmpty ? "You can keep browsing while this finishes." : store.workActivity)
                    .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            if let start = store.workStartedAt { Text(start, style: .timer).monospacedDigit().font(.system(size: 11)).foregroundStyle(.secondary).fixedSize() }
            Button("Cancel") { store.cancelWork() }.buttonStyle(TextActionStyle())
        }.padding(14).background(Palette.soft)
    }
}
