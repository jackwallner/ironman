import SwiftUI
import UIKit

/// Feedback is its own path, never a branch of a rating question. Guideline
/// 5.6.1 rejected 1.1.2 for asking "Enjoying it?" and sending only the yes
/// answers to the App Store, so ratings go straight to Apple's own prompt.
@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    @Published var feedbackRequested = false

    private init() {}

    func requestFeedback() {
        feedbackRequested = true
    }

    func clear() {
        feedbackRequested = false
    }
}

enum ReviewPromptDismissOutcome: Sendable {
    case notNow
    case feedbackDraftOpened
}

struct ReviewPromptSheet: View {
    let onFinish: (ReviewPromptDismissOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var showingMailFallback = false
    @FocusState private var feedbackFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                feedbackContent
                    .frame(maxWidth: .infinity, alignment: .top)
                    .safeAreaPadding(.bottom, TriSpace.x6)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Help us improve")
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                feedbackAction
                    .padding(.horizontal, TriSpace.x6)
                    .padding(.vertical, TriSpace.x2)
                    .background(TriPalette.canvas)
            }
            .toolbar {
                TriBarItem(placement: .cancellationAction) {
                    Button {
                        handleNotNow()
                    } label: {
                        TriBarLabel(title: "Not now")
                    }
                    .buttonStyle(.triPressSilent)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .background(TriPalette.canvas.ignoresSafeArea())
        .alert("Mail isn't available", isPresented: $showingMailFallback) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your message was copied. Email it to jackwallner+tri@gmail.com.")
        }
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
