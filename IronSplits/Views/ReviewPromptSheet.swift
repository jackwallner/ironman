import SwiftUI
import UIKit

/// Manual presentation from About bypasses passive eligibility gates.
@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    enum Presentation {
        case enjoymentPrompt
        case feedbackOnly
    }

    @Published var pendingPresentation: Presentation?

    private init() {}

    func requestEnjoymentPrompt() {
        pendingPresentation = .enjoymentPrompt
    }

    func requestFeedback() {
        pendingPresentation = .feedbackOnly
    }

    func clear() {
        pendingPresentation = nil
    }
}

enum ReviewPromptDismissOutcome: Sendable {
    case notNow
    case feedbackSubmitted
    case openedWriteReview
    /// User chose "Yes" but dismissed the pitch without opening the store, host may call `requestReview()` once in `onDismiss`.
    case enjoyedMaybeLater
}

struct ReviewPromptSheet: View {
    enum Step {
        case enjoyment
        case reviewPitch
        case feedback
    }

    let initialStep: Step
    let onFinish: (ReviewPromptDismissOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var feedbackText = ""
    @FocusState private var feedbackFocused: Bool

    init(initialStep: Step = .enjoyment, onFinish: @escaping (ReviewPromptDismissOutcome) -> Void) {
        self.initialStep = initialStep
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enjoyment:
                    enjoymentContent
                case .reviewPitch:
                    reviewPitchContent
                case .feedback:
                    feedbackContent
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        handleNotNow()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents(step == .feedback ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .background(TriPalette.canvas.ignoresSafeArea())
    }

    private var navigationTitle: String {
        switch step {
        case .enjoyment: "Enjoying IM Iron Splits?"
        case .reviewPitch: "Support an indie app"
        case .feedback: "Help us improve"
        }
    }

    private var enjoymentContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(TriPalette.sunrise)
                    .frame(width: 64, height: 64)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, TriSpace.x2)

            Text("If IM Iron Splits is keeping your race history straight, a quick rating on the App Store makes a real difference.")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button {
                    step = .reviewPitch
                } label: {
                    primaryButtonLabel("Yes, I'm enjoying it")
                }
                .buttonStyle(.plain)

                Button {
                    step = .feedback
                } label: {
                    secondaryButtonLabel("Not really")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, TriSpace.x6)
        .padding(.bottom, TriSpace.x6)
    }

    private var reviewPitchContent: some View {
        VStack(spacing: 18) {
            Text("IM Iron Splits is built by one indie developer. No ads, no accounts, and your locker stays on your phone.")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, TriSpace.x2)

            Text("An honest App Store review takes seconds and helps more fans find a clean Statcast percentile scout.")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button {
                    ReviewPromptTracker.markOpenedWriteReview()
                    UIApplication.shared.open(AppStoreReviewLinks.writeReviewURL)
                    finish(.openedWriteReview)
                } label: {
                    primaryButtonLabel("Rate on the App Store")
                }
                .buttonStyle(.plain)

                Button {
                    ReviewPromptTracker.markShown()
                    finish(.enjoyedMaybeLater)
                } label: {
                    secondaryButtonLabel("Maybe later")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, TriSpace.x6)
        .padding(.bottom, TriSpace.x6)
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would make IM Iron Splits work better for you?")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $feedbackText)
                .font(TriType.body)
                .frame(minHeight: 140)
                .padding(10)
                .background(TriPalette.surface, in: RoundedRectangle(cornerRadius: TriGeo.radiusCard))
                .overlay(
                    RoundedRectangle(cornerRadius: TriGeo.radiusCard)
                        .stroke(TriPalette.hairline, lineWidth: 0.5)
                )
                .focused($feedbackFocused)

            Text("Opens your mail app with a draft to the developer. No analytics, just your words.")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)

            Button {
                sendFeedback()
            } label: {
                primaryButtonLabel("Send feedback")
            }
            .buttonStyle(.plain)
            .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, TriSpace.x6)
        .padding(.bottom, TriSpace.x6)
        .onAppear { feedbackFocused = true }
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(TriType.bodyBold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: TriGeo.tapTarget + TriSpace.x1)
            .background(TriPalette.sunrise, in: Capsule())
    }

    private func secondaryButtonLabel(_ title: String) -> some View {
        // `inkSecondary` rather than a blue of its own. A one-off link colour
        // was the only token in the palette that existed for a single call
        // site, and one accent per app is the rule that keeps a screen from
        // reading as three screens.
        Text(title)
            .font(TriType.smallBold)
            .foregroundStyle(TriPalette.inkSecondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: TriGeo.tapTarget)
    }

    private func handleNotNow() {
        ReviewPromptTracker.markShown()
        finish(.notNow)
    }

    private func sendFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = Self.feedbackMailURL(body: trimmed) else { return }
        ReviewPromptTracker.markFeedbackSubmitted()
        UIApplication.shared.open(url)
        finish(.feedbackSubmitted)
    }

    private func finish(_ outcome: ReviewPromptDismissOutcome) {
        onFinish(outcome)
        dismiss()
    }

    static func feedbackMailURL(body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "jackwallner+tri@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "IM Iron Splits feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
