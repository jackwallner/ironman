import SwiftUI
import UIKit

/// Manual presentation from About bypasses passive eligibility gates.
@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    enum Presentation: Equatable {
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
    case feedbackDraftOpened
    case openedWriteReview
    case enjoyed
}

struct ReviewPromptSheet: View {
    enum Step {
        case enjoyment
        case feedback
    }

    let initialStep: Step
    let onFinish: (ReviewPromptDismissOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var feedbackText = ""
    @State private var showingMailFallback = false
    @FocusState private var feedbackFocused: Bool

    init(initialStep: Step = .enjoyment, onFinish: @escaping (ReviewPromptDismissOutcome) -> Void) {
        self.initialStep = initialStep
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                Group {
                    switch step {
                    case .enjoyment:
                        enjoymentContent
                    case .feedback:
                        feedbackContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .safeAreaPadding(.bottom, TriSpace.x6)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if step == .feedback {
                    feedbackAction
                        .padding(.horizontal, TriSpace.x6)
                        .padding(.vertical, TriSpace.x2)
                        .background(TriPalette.canvas)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        handleNotNow()
                    }
                    .foregroundStyle(TriPalette.inkOnDark)
                    .buttonStyle(.triPressSilent)
                    .padding(.horizontal, TriSpace.x4)
                    .triTapTarget()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents(step == .feedback ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .background(TriPalette.canvas.ignoresSafeArea())
        .alert("Mail isn't available", isPresented: $showingMailFallback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your message was copied. Email it to jackwallner+tri@gmail.com.")
        }
    }

    private var navigationTitle: String {
        switch step {
        case .enjoyment: "Enjoying IM Tri Tracker?"
        case .feedback: "Help us improve"
        }
    }

    private var enjoymentContent: some View {
        VStack(spacing: TriSpace.x5) {
            ZStack {
                Circle()
                    .fill(TriPalette.sunrise)
                    .frame(width: TriSpace.x10 + TriSpace.x6, height: TriSpace.x10 + TriSpace.x6)
                Image(systemName: "flag.checkered")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(TriPalette.inkOnSunrise)
            }
            .padding(.top, TriSpace.x2)

            Text("If IM Tri Tracker is keeping your race history straight, a quick rating on the App Store makes a real difference.")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, TriSpace.x2)

            VStack(spacing: TriSpace.x2 + TriSpace.x1) {
                Button {
                    finish(.enjoyed)
                } label: {
                    primaryButtonLabel("Yes, I'm enjoying it")
                }
                .buttonStyle(.triPress)

                Button {
                    step = .feedback
                } label: {
                    secondaryButtonLabel("Not really")
                }
                .buttonStyle(.triPressSilent)
            }
        }
        .padding(.horizontal, TriSpace.x6)
        .padding(.bottom, TriSpace.x6)
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: TriSpace.x4) {
            Text("What would make IM Tri Tracker work better for you?")
                .font(TriType.body)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $feedbackText)
                .font(TriType.body)
                .frame(minHeight: TriSpace.x10 * 3 + TriSpace.x4)
                .padding(TriSpace.x2)
                .background(TriPalette.surface,
                            in: RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                        .stroke(TriPalette.hairline, lineWidth: TriGeo.hairline)
                )
                .focused($feedbackFocused)

            Text("Continues in your mail app with a draft. Your message is sent only if you send it there.")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
        }
        .padding(.horizontal, TriSpace.x6)
        .padding(.bottom, TriSpace.x6)
        .onAppear { feedbackFocused = true }
    }

    private var feedbackAction: some View {
        Button {
            sendFeedback()
        } label: {
            primaryButtonLabel("Continue in email")
        }
        .buttonStyle(.triPress)
        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(TriType.bodyBold)
            .foregroundStyle(TriPalette.inkOnSunrise)
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
        guard UIApplication.shared.canOpenURL(url) else {
            copyFeedback(trimmed)
            return
        }
        UIApplication.shared.open(url) { opened in
            Task { @MainActor in
                guard opened else {
                    copyFeedback(trimmed)
                    return
                }
                ReviewPromptTracker.markFeedbackDraftOpened()
                finish(.feedbackDraftOpened)
            }
        }
    }

    private func copyFeedback(_ text: String) {
        UIPasteboard.general.string = text
        showingMailFallback = true
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
            URLQueryItem(name: "subject", value: "IM Tri Tracker feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
