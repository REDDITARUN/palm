import Foundation
import FSRS

public enum ReviewScheduler {
    public static func schedule(_ item: ReviewItem, attempts: [Attempt], now: Date = Date()) throws -> ReviewItem {
        let valid = attempts.filter { !$0.disputed && !$0.grade.uncertain }
        guard !valid.isEmpty else { return item }
        let independent = valid.filter { $0.independent && $0.grade.correct }.count
        let ratio = Double(independent) / Double(valid.count)
        let rating: Rating = ratio >= 0.8 ? .good : (ratio >= 0.5 ? .hard : .again)
        let scheduler = FSRS(parameters: .init(w: FSRSDefaults.defaultWv6))
        let card = try item.cardJSON.map { try JSONDecoder().decode(Card.self, from: $0) } ?? Card(due: now)
        let next = try scheduler.next(card: card, now: now, grade: rating)
        var updated = item
        updated.cardJSON = try JSONEncoder().encode(next.card); updated.due = next.card.due
        updated.lastReview = now; updated.repetitions += 1
        return updated
    }
}
