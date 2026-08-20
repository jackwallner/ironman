import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var reviewCoordinator: ReviewPromptCoordinator

    @State private var paywallTrigger: PaywallTrigger?
    @State private var showingAthleteSearch = false
    @State private var confirmingUnclaim = false

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                if !store.isPro {
                    Section {
                        Button {
                            paywallTrigger = store.defaultUpgradeTrigger
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(TriPalette.sunrise)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Tri Locker Pro")
                                        .font(TriType.bodyBold)
                                        .foregroundStyle(TriPalette.ink)
                                    Text("Full history, split leaderboards, race resume")
                                        .font(TriType.small)
                                        .foregroundStyle(TriPalette.inkTertiary)
                                }
                                Spacer()
                                Text(store.upgradeCTALabel)
                                    .font(TriType.smallBold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(TriPalette.sunrise, in: Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Athlete") {
                    if let athlete = locker.athlete {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(athlete.name)
                                .font(TriType.bodyBold)
                            if !athlete.subtitle.isEmpty {
                                Text(athlete.subtitle)
                                    .font(TriType.small)
                                    .foregroundStyle(TriPalette.inkTertiary)
                            }
                        }
                    }
                    Button("Change athlete") { showingAthleteSearch = true }
                    Button("Refresh results") {
                        Task { await locker.refresh(force: true) }
                    }
                    Button("Remove my athlete", role: .destructive) {
                        confirmingUnclaim = true
                    }
                }

                Section("Units") {
                    Picker("Distance and pace", selection: Binding(
                        get: { settings.units },
                        set: { settings.units = $0 }
                    )) {
                        ForEach(UnitPreference.allCases, id: \.self) { unit in
                            Text(unit.title).tag(unit)
                        }
                    }
                }

                Section("Subscription") {
                    if store.isPro {
                        Label("Tri Locker Pro is active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(TriPalette.positive)
                    }
                    Button("Restore purchases") {
                        Task { await store.restorePurchases() }
                    }
                    if let error = store.lastError {
                        Text(error)
                            .font(TriType.small)
                            .foregroundStyle(TriPalette.negative)
                    }
                    Link("Manage subscription", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                }

                Section("About") {
                    if AppStoreReviewLinks.isConfigured {
                        Button("Rate or send feedback") {
                            reviewCoordinator.requestEnjoymentPrompt()
                        }
                    } else {
                        Button("Send feedback") {
                            reviewCoordinator.requestFeedback()
                        }
                    }
                    Link("Privacy policy", destination: TriLockerLegal.privacyURL)
                    Link("Terms of use", destination: TriLockerLegal.termsURL)
                    LabeledContent("Version", value: versionText)
                }

                Section {
                    Text("Tri Locker is an independent app. It is not affiliated with, endorsed by, or sponsored by any race organiser. Results are shown as published by each event's timer.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                }

                #if DEBUG
                Section("Debug") {
                    Toggle("Force Pro", isOn: Binding(
                        get: { store.isPro },
                        set: { _ in }
                    ))
                    .disabled(true)
                    Text("Set TRILOCKER_FORCE_PRO=1 on the scheme to unlock Pro locally.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                }
                #endif
            }
            .navigationTitle("Settings")
            // Inline: a large title renders as an empty band here, and the
            // screen's own header is already doing that job.
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .scrollContentBackground(.hidden)
            .background(TriPalette.canvas)
            .sheet(isPresented: $showingAthleteSearch) { AthleteSearchView() }
            .sheet(item: $paywallTrigger) { PaywallView(trigger: $0) }
            .confirmationDialog("Remove your athlete?",
                                isPresented: $confirmingUnclaim,
                                titleVisibility: .visible) {
                Button("Remove", role: .destructive) { locker.unclaim() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your cached results are deleted from this phone. Your race notes are kept, and reappear if you claim the same athlete again.")
            }
        }
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
