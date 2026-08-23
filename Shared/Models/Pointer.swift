import Foundation

/// One coaching clip in the Tri Pointers library.
///
/// Content is not compiled in. The catalog is fetched from the app's own site
/// and cached, so episodes can be added, re-ordered, or corrected without an
/// App Store release, on the same hotfix channel `FeedConfig` uses. An episode
/// can point at a hosted video file or at a watch URL; the app plays the first
/// and hands the second to the system.
struct Pointer: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var episode: Int?
    var title: String
    var summary: String?
    /// Which leg of the race this is about, used to file it under the right tab.
    var discipline: Discipline?
    /// Direct video file (mp4/m3u8) the in-app player can stream.
    var videoURL: String?
    /// External page to open instead, when there is no direct file.
    var linkURL: String?
    var thumbnailURL: String?
    var durationSeconds: Int?
    /// Free episodes are the sample; the rest sit behind Pro.
    var isFree: Bool = false

    var durationText: String? {
        guard let durationSeconds, durationSeconds > 0 else { return nil }
        return TimeFormat.hms(durationSeconds)
    }

    var playableURL: URL? {
        if let videoURL, let url = URL(string: videoURL) { return url }
        if let linkURL, let url = URL(string: linkURL) { return url }
        return nil
    }

    var opensExternally: Bool {
        videoURL == nil && linkURL != nil
    }
}

struct PointerCatalog: Codable, Sendable {
    var title: String
    var subtitle: String?
    /// Shown when `pointers` is empty, so the empty state can say something
    /// true about *why* rather than a generic "nothing here".
    var emptyMessage: String?
    var pointers: [Pointer]

    static let empty = PointerCatalog(
        title: "Tri Pointers",
        subtitle: nil,
        emptyMessage: "The Tri Pointers episodes aren't published yet. They'll appear here as soon as they are, with no app update needed.",
        pointers: []
    )
}

/// Loads and caches the pointer catalog.
actor PointerLibrary {
    static let shared = PointerLibrary()

    private static let remoteURL = URL(string: "https://jackwallner.github.io/ironman/pointers.json")!
    private static let cacheKey = "pointers.catalog.cached"
    private static let cacheDateKey = "pointers.catalog.cachedAt"
    private static let refreshInterval: TimeInterval = 60 * 60 * 12

    private var current: PointerCatalog?
    private var lastErrorMessage: String?

    func catalog() -> PointerCatalog {
        if let current { return current }
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(PointerCatalog.self, from: data) {
            current = cached
            return cached
        }
        return .empty
    }

    func errorMessage() -> String? {
        lastErrorMessage
    }

    @discardableResult
    func refresh(force: Bool = false) async -> PointerCatalog {
        let defaults = UserDefaults.standard
        if !force, let last = defaults.object(forKey: Self.cacheDateKey) as? Date,
           Date.now.timeIntervalSince(last) < Self.refreshInterval {
            if catalog().pointers.isEmpty {
                lastErrorMessage = "The episode library couldn't be reached. Check your connection and try again."
            }
            return catalog()
        }
        var request = URLRequest(url: Self.remoteURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
              let catalog = try? JSONDecoder().decode(PointerCatalog.self, from: data) else {
            defaults.set(Date.now, forKey: Self.cacheDateKey)
            lastErrorMessage = "The episode library couldn't be reached. Check your connection and try again."
            return catalog()
        }
        current = catalog
        lastErrorMessage = nil
        defaults.set(data, forKey: Self.cacheKey)
        defaults.set(Date.now, forKey: Self.cacheDateKey)
        return catalog
    }
}
