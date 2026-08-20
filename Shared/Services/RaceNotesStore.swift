import Foundation

/// The athlete's own account of a race, kept beside the official result.
///
/// Stored locally and never sent anywhere. The result rows come from a public
/// results feed; what the water felt like and what went wrong at mile 18 does
/// not, and shouldn't leave the phone.
struct RaceNote: Codable, Hashable, Sendable {
    var resultID: String
    var conditions: String = ""
    var nutrition: String = ""
    var gear: String = ""
    var notes: String = ""
    var updatedAt: Date = .now

    var isEmpty: Bool {
        [conditions, nutrition, gear, notes].allSatisfy {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// One-line preview for the race row.
    var summary: String? {
        let first = [conditions, notes, nutrition, gear]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return first
    }
}

@MainActor
final class RaceNotesStore: ObservableObject {
    @Published private(set) var notes: [String: RaceNote] = [:]

    private let filename = "race-notes.json"

    init() {
        load()
    }

    func note(for resultID: String) -> RaceNote {
        notes[resultID] ?? RaceNote(resultID: resultID)
    }

    func hasNote(for resultID: String) -> Bool {
        !(notes[resultID]?.isEmpty ?? true)
    }

    func save(_ note: RaceNote) {
        var updated = note
        updated.updatedAt = .now
        if updated.isEmpty {
            notes.removeValue(forKey: note.resultID)
        } else {
            notes[note.resultID] = updated
        }
        persist()
    }

    private var url: URL? {
        guard let directory = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                           in: .userDomainMask,
                                                           appropriateFor: nil,
                                                           create: true) else { return nil }
        return directory.appendingPathComponent(filename)
    }

    private func load() {
        guard let url, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: RaceNote].self, from: data) else { return }
        notes = decoded
    }

    private func persist() {
        guard let url, let data = try? JSONEncoder().encode(notes) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
