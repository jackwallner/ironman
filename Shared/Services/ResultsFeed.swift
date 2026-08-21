import Foundation

/// Where the results come from, and how a query is spelled.
///
/// The feed is an OData table fronted by a proxy that holds the subscription
/// key. Neither is ours, so the shape of a request is the one thing in this app
/// most likely to change without warning, and an App Store update takes days
/// to reach anyone. Every piece of it therefore lives in a struct that can be
/// replaced at runtime by `FeedConfigLoader`, and the compiled-in values are
/// only the fallback for a first launch with no network.
struct FeedConfig: Codable, Sendable, Equatable {
    /// Proxy that signs and forwards an absolute upstream URL.
    var proxyURL: String
    /// Query-item name the proxy reads the upstream URL from.
    var proxyURLParameter: String
    /// Query-item name for the upstream page size.
    var pageSizeParameter: String
    /// Upstream OData collection.
    var resultsURL: String
    /// Rows per page. The upstream caps this; 2000 is what the web client asks for.
    var pageSize: Int
    /// Hard stop on pagination so a pathological filter can't page forever.
    var maxPages: Int
    /// Sent as Referer. The proxy has rejected requests without it in the past.
    var referer: String

    static let bundled = FeedConfig(
        proxyURL: "https://labs-v2.competitor.com/api/results-proxy",
        proxyURLParameter: "url",
        pageSizeParameter: "pageSize",
        resultsURL: "https://api.competitor.com/web/results",
        pageSize: 500,
        maxPages: 12,
        referer: "https://labs-v2.competitor.com/"
    )

    /// Build the proxied request URL for one OData query string.
    func requestURL(query: String, pageSize overridePageSize: Int? = nil) -> URL? {
        guard var upstream = URLComponents(string: resultsURL) else { return nil }
        upstream.percentEncodedQuery = query
        guard let upstreamURL = upstream.url?.absoluteString,
              var components = URLComponents(string: proxyURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: proxyURLParameter, value: upstreamURL),
            URLQueryItem(name: pageSizeParameter, value: String(overridePageSize ?? pageSize)),
        ]
        return components.url
    }

    /// A `@odata.nextLink` is already an absolute upstream URL; it still has to
    /// go back through the proxy to be signed.
    func requestURL(nextLink: String) -> URL? {
        guard var components = URLComponents(string: proxyURL) else { return nil }
        components.queryItems = [
            URLQueryItem(name: proxyURLParameter, value: nextLink),
            URLQueryItem(name: pageSizeParameter, value: String(pageSize)),
        ]
        return components.url
    }
}

/// Fetches an override for `FeedConfig` from the app's own marketing site.
///
/// This is the hotfix channel. If the upstream moves, publishing a new JSON to
/// GitHub Pages repoints every installed copy of the app within one launch,
/// with no review queue in between.
actor FeedConfigLoader {
    static let shared = FeedConfigLoader()

    private static let remoteURL = URL(string: "https://jackwallner.github.io/ironman/api-config.json")!
    private static let cacheKey = "feed.config.cached"
    private static let cacheDateKey = "feed.config.cachedAt"
    private static let refreshInterval: TimeInterval = 60 * 60 * 6

    private var current: FeedConfig?

    /// Best config available right now, without waiting on the network.
    func config() -> FeedConfig {
        if let current { return current }
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(FeedConfig.self, from: data) {
            current = cached
            return cached
        }
        return .bundled
    }

    /// Refresh from the network at most every few hours. Failures are silent
    /// and non-fatal: the bundled or cached config still works.
    func refreshIfStale() async {
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: Self.cacheDateKey) as? Date,
           Date.now.timeIntervalSince(last) < Self.refreshInterval {
            return
        }
        var request = URLRequest(url: Self.remoteURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 10
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
              let config = try? JSONDecoder().decode(FeedConfig.self, from: data) else {
            // Stamp the attempt anyway so a persistently unreachable config
            // file doesn't mean a request on every single launch.
            defaults.set(Date.now, forKey: Self.cacheDateKey)
            return
        }
        current = config
        defaults.set(data, forKey: Self.cacheKey)
        defaults.set(Date.now, forKey: Self.cacheDateKey)
    }
}
