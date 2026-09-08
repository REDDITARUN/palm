import SwiftUI
import PalmCore

extension AppStore {
    var flashcards: [Flashcard] { data.flashcards ?? [] }
    var dueFlashcards: [Flashcard] { flashcards.filter { !$0.paused && $0.due <= clock }.sorted { $0.due < $1.due } }
    @discardableResult func commitCards(_ change: (inout [Flashcard]) throws -> Void) -> Bool {
        do { var next = data; var cards = flashcards; try change(&cards); next.flashcards = cards; let savedIDs = Set(cards.map(\.id)); next.flashcardDrafts?.removeAll { savedIDs.contains($0.id) }; try database.save(next); data = next; return true }
        catch { self.error = error.localizedDescription; return false }
    }
    func deleteNote(_ id: UUID) {
        do { var next = data; next.notes.removeAll { $0.id == id }; next.conversations?.removeAll { $0.id == "note:" + id.uuidString || $0.id.hasPrefix("note:" + id.uuidString + ":branch:") }; next.flashcards?.removeAll { $0.noteID == id }; next.flashcardDrafts?.removeAll { $0.noteID == id }; try database.save(next); data = next; selectedNoteID = nil }
        catch { self.error = error.localizedDescription }
    }
}

struct NoteFlashcardsView: View {
    @Environment(AppStore.self) private var store
    var noteID: UUID
    @State private var editingCard: Flashcard?
    @State private var review: CardReviewRequest?
    private var pendingDeck: [Flashcard] {
        get { store.data.flashcardDrafts?.filter { $0.noteID == noteID } ?? [] }
        nonmutating set {
            var next = store.data; var drafts = next.flashcardDrafts ?? []
            drafts.removeAll { $0.noteID == noteID }; drafts.append(contentsOf: newValue); next.flashcardDrafts = drafts
            do { try store.database.save(next); store.data = next } catch { store.error = error.localizedDescription }
        }
    }
    @State private var deleteCard: Flashcard?
    private var cards: [Flashcard] { store.flashcards.filter { $0.noteID == noteID } }
    private var due: [Flashcard] { cards.filter { !$0.paused && $0.due <= store.clock } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Flashcards").font(.system(size: 21, weight: .semibold))
                        Text("Recall the answer before revealing it.").font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { editingCard = Flashcard(noteID: noteID, front: "", back: "") } label: { Label("New card", systemImage: "plus") }.buttonStyle(QuietButton())
                }
                HStack(spacing: 12) {
                    Button("Generate from note") { generate() }.buttonStyle(QuietButton()).disabled(store.busy != nil || !store.hasModelAccess(for: "notes") || store.data.notes.first(where: { $0.id == noteID })?.body.isEmpty != false)
                    Spacer()
                    Text("\(cards.count) cards · \(due.count) due").font(.system(size: 12)).foregroundStyle(.secondary)
                    if !due.isEmpty { Button("Review due cards") { review = CardReviewRequest(ids: due.map(\.id)) }.buttonStyle(PrimaryButton()) }
                }
                if cards.isEmpty { EmptyState(icon: "rectangle.on.rectangle", title: "A question worth remembering", subtitle: "Write a card or generate a draft from this note. You can edit every question and answer before saving.", actionTitle: nil, action: nil) }
                ForEach(cards) { card in
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            MarkdownReading(text: card.front, fontSize: 15, selectable: false)
                            ActionPopover(title: "Flashcard actions", actions: [
                                WorkspaceAction(title: "Edit card", icon: "pencil") { editingCard = card },
                                WorkspaceAction(title: "Practice now", icon: "play", disabled: card.paused) { review = CardReviewRequest(ids: [card.id]) },
                                WorkspaceAction(title: card.paused ? "Resume reviews" : "Pause reviews", icon: "pause") { store.commitCards { cards in if let i = cards.firstIndex(where: { $0.id == card.id }) { cards[i].paused.toggle() } } },
                                WorkspaceAction(title: "Delete card", icon: "trash", destructive: true) { deleteCard = card }
                            ])
                        }
                        DisclosureGroup("Answer") { MarkdownReading(text: card.back, fontSize: 14).padding(.top, 10) }.font(.system(size: 12)).foregroundStyle(.secondary)
                        HStack { Text(card.paused ? "Paused" : (card.due <= store.clock ? "Ready to review" : "Due " + card.due.formatted(.relative(presentation: .named)))); Spacer(); Text("\(card.reviews.count) \(card.reviews.count == 1 ? "review" : "reviews")") }.font(.system(size: 11)).foregroundStyle(.secondary)
                    }.padding(20).background(Palette.surface, in: .rect(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.border))
                }
            }.frame(maxWidth: 680).padding(28).frame(maxWidth: .infinity)
        }
        .sheet(item: $editingCard) { card in FlashcardEditor(card: card) }
        .sheet(item: $review) { request in FlashcardReviewView(ids: request.ids) }
        .sheet(isPresented: Binding(get: { !pendingDeck.isEmpty }, set: { if !$0 { pendingDeck = [] } })) {
            FlashcardDraftReview(cards: Binding(get: { pendingDeck }, set: { pendingDeck = $0 }), noteID: noteID)
        }
        .confirmationDialog("Delete this flashcard and its review history?", isPresented: Binding(get: { deleteCard != nil }, set: { if !$0 { deleteCard = nil } })) {
            Button("Delete card", role: .destructive) { if let card = deleteCard { store.commitCards { $0.removeAll { $0.id == card.id } } }; deleteCard = nil }
        }
    }
    private func generate() {
        guard let note = store.data.notes.first(where: { $0.id == noteID }) else { return }
        store.run("Drafting flashcards from your note…", kind: "flashcards") {
            try await store.ensureLearningAgent()
            let deck = try await store.ai.flashcards(note: note, config: store.modelConfiguration(for: "notes"))
            try Task.checkCancellation()
            guard store.data.notes.contains(where: { $0.id == noteID }) else { return }
            let existing = Set(cards.map { LearningEngine.normalize($0.front) })
            pendingDeck = deck.cards.filter { !existing.contains(LearningEngine.normalize($0.front)) }.map { Flashcard(noteID: noteID, front: $0.front, back: $0.back) }
            if pendingDeck.isEmpty { store.notice = "These questions are already in this note’s deck." }
        }
    }
}

struct CardReviewRequest: Identifiable { let id = UUID(); let ids: [UUID] }
struct FlashcardEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let card: Flashcard
    @State private var front = ""
    @State private var back = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Flashcard").font(.title2); Spacer(); Button("Cancel") { dismiss() }.buttonStyle(QuietButton()) }
            Text("One idea per card. Markdown, code, and formulas are supported.").font(.system(size: 12)).foregroundStyle(.secondary)
            Text("Question").font(.system(size: 13, weight: .medium))
            TextEditor(text: $front).proseNavigation().font(.system(size: 14)).frame(height: 100).accessibilityLabel("Flashcard question")
            Text("Answer & explanation").font(.system(size: 13, weight: .medium))
            TextEditor(text: $back).proseNavigation().font(.system(size: 14)).frame(height: 170).accessibilityLabel("Flashcard answer")
            HStack { Text("Saved with this note").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Save card") {
                guard store.data.notes.contains(where: { $0.id == card.noteID }) else { store.error = "The source note no longer exists."; return }
                if store.commitCards({ cards in
                    try FlashcardEngine.validate(front: front, back: back)
                    var updated = card; updated.front = front; updated.back = back; updated.updatedAt = Date()
                    if card.front != front || card.back != back { updated.cardJSON = nil; updated.due = Date() }
                    if let i = cards.firstIndex(where: { $0.id == card.id }) { cards[i] = updated } else { cards.append(updated) }
                }) { dismiss() }
            }.buttonStyle(PrimaryButton()).disabled(front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || back.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(28).frame(width: 620).onAppear { front = card.front; back = card.back }
    }
}

struct FlashcardDraftReview: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var cards: [Flashcard]
    var noteID: UUID
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Review your draft cards").font(.title2)
            Text("Edit or remove anything before adding it to your notebook.").font(.system(size: 13)).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 18) { ForEach($cards) { $card in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text("Question").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Remove") { cards.removeAll { $0.id == card.id } }.buttonStyle(TextActionStyle()) }
                        TextField("Question", text: $card.front, axis: .vertical).lineLimit(1...8).fieldStyle()
                        TextField("Answer", text: $card.back, axis: .vertical).lineLimit(2...10).fieldStyle()
                    }.padding(14).overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.border))
                } }
            }
            HStack { Button("Discard") { cards = []; dismiss() }.buttonStyle(QuietButton()); Spacer(); Button("Add \(cards.count) cards") {
                guard store.data.notes.contains(where: { $0.id == noteID }) else { return }
                if store.commitCards({ saved in
                    for card in cards { try FlashcardEngine.validate(front: card.front, back: card.back) }
                    var fronts = Set(saved.filter { $0.noteID == noteID }.map { LearningEngine.normalize($0.front) })
                    for card in cards where fronts.insert(LearningEngine.normalize(card.front)).inserted { saved.append(card) }
                }) { cards = []; dismiss() }
            }.buttonStyle(PrimaryButton()).disabled(cards.isEmpty) }
        }.padding(26).frame(width: 650, height: 640)
    }
}

struct FlashcardReviewView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let ids: [UUID]
    @State private var index = 0
    @State private var revealed = false
    @State private var encounter = UUID()
    @FocusState private var reviewFocused: Bool
    private var card: Flashcard? { ids.indices.contains(index) ? store.flashcards.first { $0.id == ids[index] } : nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack { Label("Flashcards", systemImage: "rectangle.on.rectangle").font(.system(size: 14, weight: .semibold)); Spacer(); Text("\(min(index + 1, ids.count)) / \(ids.count)").font(.caption).monospacedDigit().foregroundStyle(.secondary); Button("Done") { dismiss() }.buttonStyle(QuietButton()) }
            ProgressView(value: Double(index), total: Double(max(1, ids.count))).tint(Palette.accent)
            if let card {
                if let note = store.data.notes.first(where: { $0.id == card.noteID }) { Text(note.title).font(.system(size: 12)).foregroundStyle(.secondary) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        MarkdownReading(text: card.front, fontSize: 18)
                        if revealed { Divider(); Text("Answer").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.accent); MarkdownReading(text: card.back) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.id(card.id)
                if revealed {
                    Text("How well did you recall it before revealing?").font(.system(size: 12)).foregroundStyle(.secondary)
                    HStack(spacing: 10) { ForEach(RecallRating.allCases) { rating in
                        Button { rate(rating, cardID: card.id) } label: {
                            VStack(spacing: 5) { Text(rating.label); Text(rating.detail).font(.system(size: 10)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
                        }.buttonStyle(QuietButton()).help(rating.detail)
                    } }
                } else {
                    HStack { Text("Try to answer without looking at the note.").font(.system(size: 12)).foregroundStyle(.secondary); Spacer(); Button("Reveal answer") { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { revealed = true } }.buttonStyle(PrimaryButton()).keyboardShortcut(.space, modifiers: []) }
                }
            } else {
                Spacer(); Image(systemName: "checkmark.circle").font(.system(size: 42)).foregroundStyle(Palette.accent).frame(maxWidth: .infinity)
                Text("Review complete").font(.title2).frame(maxWidth: .infinity)
                Text("Your next reviews are scheduled. Cards marked Again will return sooner.").font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                Spacer(); Button("Back to notes") { dismiss() }.buttonStyle(PrimaryButton()).frame(maxWidth: .infinity)
            }
        }.padding(30).frame(width: 700, height: 570)
            .focusable().focused($reviewFocused).defaultFocus($reviewFocused, true).focusEffectDisabled().task { await Task.yield(); reviewFocused = true }
            .onKeyPress(characters: CharacterSet(charactersIn: "1234"), phases: .down) { press in
                guard !KeyboardContext.isEditing, revealed, let card, let value = Int(press.characters) else { return .ignored }
                rate(RecallRating.allCases[value - 1], cardID: card.id); return .handled
            }
            .onExitCommand { dismiss() }
    }
    private func rate(_ rating: RecallRating, cardID: UUID) {
        guard card?.id == cardID, revealed else { return }
        if store.commitCards({ cards in if let i = cards.firstIndex(where: { $0.id == cardID }) { cards[i] = try FlashcardEngine.reviewed(cards[i], rating: rating, encounterID: encounter) } }) { next() }
    }
    private func next() { revealed = false; index += 1; encounter = UUID() }
}
