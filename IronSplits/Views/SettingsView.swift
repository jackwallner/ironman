import SwiftUI
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var locker: LockerStore
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var pattie: PattieMode
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var reviewCoordinator: ReviewPromptCoordinator

    @State private var showingAthleteSearch = false
    @State private var showingAlternateSearch = false
    @State private var confirmingUnclaim = false
    @State private var cacheBytes: Int64 = 0

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
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
                    Button("Change athlete") {
                        pattie.react(.selection)
                        showingAthleteSearch = true
                    }
                    Button {
                        pattie.react(.selection)
                        showingAlternateSearch = true
                    } label: {
                        Label("Find another registered name", systemImage: "person.crop.circle.badge.plus")
                    }
                    Text("If one race was entered under a different name, search the official results database and add that registration to this profile.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                    Button("Refresh results") {
                        pattie.react(.refresh)
                        Task { await locker.refresh(force: true) }
                    }
                    Button("Remove my athlete", role: .destructive) {
                        pattie.react(.choice)
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
                    .onChange(of: settings.units) { _, _ in pattie.react(.selection) }
                }

                Section("Iron Splits+") {
                    Label("Everything is unlocked", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(TriPalette.positive)
                    Text("Full history, split leaderboards, field percentiles, race notes, resume export and every one of Pattie's pointers. No purchase, nothing held back.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                    // Restore stays. Anyone who bought Iron Splits+ before the
                    // gates came down still needs a way to reattach the receipt
                    // to a new device, and hiding the button does not make the
                    // purchase go away.
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

                Section("Pattie Mode") {
                    Toggle("Pattie Mode", isOn: $pattie.isEnabled)
                    .onChange(of: pattie.isEnabled) { _, on in
                        Haptics.selection()
                        if on { pattie.demo() }
                    }
                    if pattie.isEnabled {
                        Button("Show me one now") { pattie.demo() }
                    }
                    Text("Pattie stays just above the tab bar and chimes in with flattering race thoughts as you explore. Turn Pattie Mode off any time to hide her and stop her voice. Her profile portrait is natural, and every spoken line is cut from her own video audio.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                }

                Section("Downloads") {
                    LabeledContent("Saved episodes", value: cacheSizeText)
                    Button("Clear downloaded episodes", role: .destructive) {
                        Task {
                            await PointerMediaCache.shared.clear()
                            await refreshCacheSize()
                            Haptics.success()
                        }
                    }
                    .disabled(cacheBytes == 0)
                    Text("Episodes are saved the first time you watch them so they play offline. Clearing them just means the next play downloads again.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
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
                    Link("Privacy policy", destination: IronSplitsLegal.privacyURL)
                    Link("Terms of use", destination: IronSplitsLegal.termsURL)
                    LabeledContent("Version", value: versionText)
                }

                Section {
                    Text("IM Iron Splits is an independent app. It is not affiliated with, endorsed by, or sponsored by any race organiser. Results are shown as published by each event's timer. IRONMAN\u{00AE} and 70.3\u{00AE} are registered trademarks of the World Triathlon Corporation, used here only to describe the races an athlete has entered.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                }

                #if DEBUG
                Section("Debug") {
                    LabeledContent("Everything unlocked",
                                   value: ProGate.everythingUnlocked ? "Yes" : "No")
                    Text("Flip `ProGate.everythingUnlocked` to put the paywall and the free window back. The gates are all still there and all still read that one flag.")
                        .font(TriType.micro)
                        .foregroundStyle(TriPalette.inkTertiary)
                }
                #endif
            }
            .navigationTitle("Settings")
            .pattieMoment(.settings, pattie)
            .task { await refreshCacheSize() }
            // Inline: a large title renders as an empty band here, and the
            // screen's own header is already doing that job.
            .navigationBarTitleDisplayMode(.inline)
            .triNavBar()
            .scrollContentBackground(.hidden)
            .background(TriPalette.canvas)
            .sheet(isPresented: $showingAthleteSearch) { AthleteSearchView() }
            .sheet(isPresented: $showingAlternateSearch) {
                AthleteSearchView(addingToCurrentAthlete: true)
            }
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

    private var cacheSizeText: String {
        cacheBytes == 0
            ? "None"
            : ByteCountFormatter.string(fromByteCount: cacheBytes, countStyle: .file)
    }

    private func refreshCacheSize() async {
        cacheBytes = await PointerMediaCache.shared.cacheSize()
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
