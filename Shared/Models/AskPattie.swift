import Foundation

/// The Ask Pattie decision tree.
///
/// Three deterministic steps, no model in the loop: pick what you're training
/// for, pick what's bothering you, get the pointers Pattie has already recorded
/// on exactly that. Everything an answer says is a paraphrase of one of her own
/// clips, and it carries the audio cut from that clip plus a link to the full
/// episode, so the app is routing to her rather than speaking for her.
///
/// A tree beats a chat box here for three reasons and one of them is the bill.
/// It costs nothing per question, it can only ever surface an answer she has
/// actually given, and it works on a start line with no signal. The generator in
/// `scripts/` refuses to publish a tree with a dead end, so every path a thumb
/// can take lands on at least one answer.
struct AskPattieGuide: Codable, Sendable, Equatable {
    var version: Int
    var title: String
    var subtitle: String
    var goalQuestion: String
    var goals: [Goal]
    var topics: [Topic]
    var answers: [Answer]

    struct Goal: Codable, Sendable, Equatable, Identifiable {
        var id: String
        var title: String
        var subtitle: String
        var symbol: String
        /// Topic ids offered for this goal, in the order they are shown.
        var topics: [String]
    }

    struct Topic: Codable, Sendable, Equatable, Identifiable {
        var id: String
        var title: String
        var symbol: String
        /// The second question, worded for this topic.
        var question: String
    }

    struct Answer: Codable, Sendable, Equatable, Identifiable {
        var id: String
        var topic: String
        var goals: [String]
        var headline: String
        /// Her setup, in her framing: "here's the situation".
        var situation: String
        /// Her fix: "here's the solution".
        var solution: String
        /// The episode this came out of, so the answer can offer the full clip.
        var pointerID: String?
        /// Bundled audio, cut from that episode. Names are bundle resource
        /// names without the `.m4a`.
        var situationVoice: String?
        var solutionVoice: String?
        var signoffVoice: String?
    }

    // MARK: - Lookups

    func goal(_ id: String) -> Goal? { goals.first { $0.id == id } }
    func topic(_ id: String) -> Topic? { topics.first { $0.id == id } }

    /// Validate every path a user can take before accepting hosted content.
    /// Nonempty goals and answers are not enough: a typo in one topic id can
    /// still turn a visible goal into a dead end.
    var isValid: Bool {
        guard version > 0, !goals.isEmpty, !topics.isEmpty, !answers.isEmpty else { return false }

        let goalIDs = Set(goals.map(\.id))
        let topicIDs = Set(topics.map(\.id))
        guard goalIDs.count == goals.count, topicIDs.count == topics.count else { return false }

        for goal in goals {
            guard !goal.topics.isEmpty,
                  goal.topics.allSatisfy({ topicIDs.contains($0) }),
                  goal.topics.allSatisfy({ answers(for: goal.id, topic: $0).isEmpty == false }) else {
                return false
            }
        }

        for answer in answers {
            guard topicIDs.contains(answer.topic),
                  !answer.goals.isEmpty,
                  answer.goals.allSatisfy({ goalIDs.contains($0) }),
                  !answer.headline.isEmpty,
                  !answer.situation.isEmpty,
                  !answer.solution.isEmpty else {
                return false
            }
        }
        return true
    }

    /// Topics offered for a goal, in the tree's order, with any that have no
    /// answers dropped. The generator guarantees there are none, but a
    /// hot-loaded tree is a file on the internet and this screen should degrade
    /// rather than show a heading with nothing under it.
    func topics(for goal: Goal) -> [Topic] {
        goal.topics.compactMap { id in
            guard let topic = topic(id), !answers(for: goal.id, topic: id).isEmpty else { return nil }
            return topic
        }
    }

    func answers(for goalID: String, topic topicID: String) -> [Answer] {
        answers.filter { $0.topic == topicID && $0.goals.contains(goalID) }
    }

    static let empty = AskPattieGuide(
        version: 0,
        title: "Ask Pattie",
        subtitle: "",
        goalQuestion: "What are you training for?",
        goals: [], topics: [], answers: []
    )
}

/// Loads the guide: bundled first so the screen is never empty, then the hosted
/// copy, on the same hotfix channel `FeedConfig` and the pointer catalog use.
actor AskPattieLibrary {
    static let shared = AskPattieLibrary()

    private static let remoteURL = URL(string: "https://jackwallner.github.io/ironman/ask-pattie.json")!
    private static let cacheKey = "askpattie.guide.cached"
    private static let cacheDateKey = "askpattie.guide.cachedAt"
    private static let refreshInterval: TimeInterval = 60 * 60 * 12

    private var current: AskPattieGuide?

    /// The best guide available without touching the network.
    func guide() -> AskPattieGuide {
        if let current { return current }
        if let data = UserDefaults.standard.data(forKey: Self.cacheKey),
           let cached = try? JSONDecoder().decode(AskPattieGuide.self, from: data),
           cached.isValid {
            current = cached
            return cached
        }
        if let url = Bundle.main.url(forResource: "ask-pattie", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let bundled = try? JSONDecoder().decode(AskPattieGuide.self, from: data),
           bundled.isValid {
            current = bundled
            return bundled
        }
        return .empty
    }

    @discardableResult
    func refresh(force: Bool = false) async -> AskPattieGuide {
        let defaults = UserDefaults.standard
        if !force, let last = defaults.object(forKey: Self.cacheDateKey) as? Date,
           Date.now.timeIntervalSince(last) < Self.refreshInterval {
            return guide()
        }
        var request = URLRequest(url: Self.remoteURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode,
              let fetched = try? JSONDecoder().decode(AskPattieGuide.self, from: data),
              fetched.isValid,
              // Never let a truncated or reordered publish replace a good tree
              // with a broken path or an empty screen.
              fetched.version >= guide().version else {
            defaults.set(Date.now, forKey: Self.cacheDateKey)
            return guide()
        }
        current = fetched
        defaults.set(data, forKey: Self.cacheKey)
        defaults.set(Date.now, forKey: Self.cacheDateKey)
        return fetched
    }
}
