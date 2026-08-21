import Foundation

/// The athlete's own results, cached on disk and refreshed from the feed.
///
/// Everything the app shows hangs off this one object. The cache is not an
/// optimization: results for a race that happened three years ago never change,
/// the feed is somebody else's service that can be slow or down, and an athlete
/// opening their locker on a start line with one bar of signal should still see
/// their bib numbers.
@MainActor
final class LockerStore: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var athlete: Athlete?
    @Published private(set) var results: [RaceResult] = []
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var lastRefreshed: Date?

    private let api: ResultsProviding
    private let storage: LockerStorage

    init(api: ResultsProviding = ResultsAPI(), storage: LockerStorage = .init()) {
        self.api = api
        self.storage = storage
        if let snapshot = storage.load() {
            athlete = snapshot.athlete
            results = snapshot.results
            lastRefreshed = snapshot.refreshedAt
            state = .loaded
        }
    }

    var hasClaimedAthlete: Bool { athlete != nil }

    /// Kinds this athlete has actually raced, for the segmented pickers.
    var availableKinds: [RaceKind] { RaceAnalytics.availableKinds(results) }

    func claim(_ athlete: Athlete) async {
        self.athlete = athlete
        results = []
        state = .loading
        await refresh(force: true)
    }

    func unclaim() {
        athlete = nil
        results = []
        lastRefreshed = nil
        state = .idle
        storage.clear()
    }

    /// Pull the athlete's results again.
    ///
    /// A refresh that fails after we already have a cached locker is not an
    /// error worth interrupting anyone over — the screen is still correct, just
    /// not newer — so the failure only surfaces when there is nothing to show.
    func refresh(force: Bool = false) async {
        guard let athlete else { return }
        if !force, let lastRefreshed, Date.now.timeIntervalSince(lastRefreshed) < 60 * 30 { return }
        if results.isEmpty { state = .loading }
        await FeedConfigLoader.shared.refreshIfStale()
        do {
            let fetched = try await api.results(forContactIDs: athlete.contactIDs)
            results = fetched
            lastRefreshed = .now
            state = .loaded
            persist()
        } catch {
            guard !isTaskCancellation(error) else { return }
            if results.isEmpty {
                state = .failed(error.localizedDescription)
            } else {
                state = .loaded
            }
        }
    }

    private func persist() {
        guard let athlete else { return }
        storage.save(.init(athlete: athlete, results: results, refreshedAt: lastRefreshed ?? .now))
    }
}

/// On-disk snapshot of the locker.
struct LockerSnapshot: Codable, Sendable {
    var athlete: Athlete
    var results: [RaceResult]
    var refreshedAt: Date
}

struct LockerStorage: Sendable {
    private let filename = "locker.json"

    private var url: URL? {
        guard let directory = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                           in: .userDomainMask,
                                                           appropriateFor: nil,
                                                           create: true) else { return nil }
        return directory.appendingPathComponent(filename)
    }

    func load() -> LockerSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LockerSnapshot.self, from: data)
    }

    func save(_ snapshot: LockerSnapshot) {
        guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func clear() {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
