import SwiftUI
@preconcurrency import RevenueCat

enum PaywallTrigger: Identifiable, Hashable {
    var id: Self { self }

    /// Reached for a race older than the free window.
    case fullHistory
    /// A specific locked year the athlete tapped. Naming the year they were
    /// curious about converts better than a generic "unlock more" pitch.
    case lockedYear(Int)
    case splitLeaderboards
    case raceResume
    case fieldPercentiles
    case raceNotes
    case pointers
    case onboarding
    case upgrade
    case winback

    var icon: String {
        switch self {
        case .fullHistory:       return "clock.arrow.circlepath"
        case .lockedYear:        return "calendar.badge.clock"
        case .splitLeaderboards: return "list.number"
        case .raceResume:        return "doc.text.fill"
        case .fieldPercentiles:  return "chart.bar.fill"
        case .raceNotes:         return "note.text"
        case .pointers:          return "play.rectangle.fill"
        case .onboarding:        return "crown.fill"
        case .upgrade:           return "crown.fill"
        case .winback:           return "arrow.counterclockwise.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .fullHistory:       return "Unlock Every Race"
        case .lockedYear(let year): return "Unlock \(year)"
        case .splitLeaderboards: return "Your Best Splits"
        case .raceResume:        return "Race Resume"
        case .fieldPercentiles:  return "How You Ranked"
        case .raceNotes:         return "Race Notes"
        case .pointers:          return "Tri Pointers"
        case .onboarding:        return "Your Whole Racing Career"
        case .upgrade:           return "Your Whole Racing Career"
        case .winback:           return "Welcome Back"
        }
    }

    var subtitle: String {
        switch self {
        case .fullHistory:
            return "Every race you have ever finished, with full splits, bib numbers and division places, back to your first start."
        case .lockedYear(let year):
            return "See your \(year) races with full splits, and put them beside every other season you have raced."
        case .splitLeaderboards:
            return "Your races ranked by swim, bike, run and transitions, so you can see the personal best on every leg and how far off you are today."
        case .raceResume:
            return "One tap for the sheet every race entry asks for: date, distance, bib, official time and division place, ready to share."
        case .fieldPercentiles:
            return "Where each of your splits landed in the field that raced it. A rank means nothing without the size of the field behind it."
        case .raceNotes:
            return "Keep the conditions, nutrition and gear that produced each result attached to the result itself."
        case .pointers:
            return "The full Tri Pointers library, on every leg of the race."
        case .onboarding, .upgrade:
            return "Every race, every split, ranked. Personal bests on all four legs, field percentiles, race notes and a resume you can send."
        case .winback:
            return "Your Iron Splits+ access has lapsed. Pick it back up for your full history, split leaderboards and race resume."
        }
    }

    /// RevenueCat custom-paywall impression id for this entry point.
    var paywallImpressionId: String {
        switch self {
        case .fullHistory:       return "ironsplits_paywall_full_history"
        case .lockedYear:        return "ironsplits_paywall_locked_year"
        case .splitLeaderboards: return "ironsplits_paywall_split_leaderboards"
        case .raceResume:        return "ironsplits_paywall_race_resume"
        case .fieldPercentiles:  return "ironsplits_paywall_field_percentiles"
        case .raceNotes:         return "ironsplits_paywall_race_notes"
        case .pointers:          return "ironsplits_paywall_pointers"
        case .onboarding:        return "ironsplits_paywall_onboarding"
        case .upgrade:           return "ironsplits_paywall_upgrade"
        case .winback:           return "ironsplits_paywall_winback"
        }
    }

    /// What the subscription actually opens. Keep this in step with the gates
    /// in `ProGate` — a pitch that sells less than the product does is the
    /// failure mode this list exists to prevent.
    private static let proFeatures: [(icon: String, title: String)] = [
        ("clock.arrow.circlepath", "Your full race history, not just the last three"),
        ("list.number", "Split leaderboards: best swim, bike, run and transitions"),
        ("chart.bar.fill", "Field percentiles on every leg of every race"),
        ("doc.text.fill", "Race resume export with bibs, times and division places"),
        ("note.text", "Race notes: conditions, nutrition and gear per result")
    ]

    var features: [(icon: String, title: String)] {
        Self.proFeatures
    }
}

/// Native Iron Splits+ paywall. Purchases flow through `StoreService.purchase`
/// → `Purchases.shared.purchase` so RevenueCat records transactions unchanged.
struct PaywallView: View {
    @EnvironmentObject private var store: StoreService
    @EnvironmentObject private var pattie: PattieMode
    @Environment(\.dismiss) private var dismiss

    let trigger: PaywallTrigger

    @State private var selectedPlan: PlanOption?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var restoreMessage: String?
    @State private var isRestoring = false
    @State private var hasDismissed = false

    init(trigger: PaywallTrigger = .upgrade) {
        self.trigger = trigger
    }

    var body: some View {
        ZStack {
            TriPalette.canvas.ignoresSafeArea()

            if store.isLoadingProducts && store.planOptions.isEmpty {
                loadingState
            } else if store.planOptions.isEmpty {
                emptyState
            } else {
                content
            }

            closeButton
        }
        .onAppear { PaywallGate.shared.markPresented(trigger) }
        .pattieMoment(.paywall, pattie)
        .onChange(of: store.isPro) { _, isPro in
            if isPro { dismissOnce() }
        }
        .task {
            store.trackPaywallImpression(id: trigger.paywallImpressionId)
            if store.planOptions.isEmpty { await store.fetchProducts() }
            selectDefaultPlanIfNeeded()
        }
        .onChange(of: store.planOptions.count) { _, _ in selectDefaultPlanIfNeeded() }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(TriPalette.sunrise)
            Text("Loading plans…")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(TriPalette.inkTertiary)
            Text("Couldn't Load Plans")
                .font(TriType.cardTitle)
                .foregroundStyle(TriPalette.inkSecondary)
            Text(store.lastError ?? "Check your connection and try again.")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task {
                    await store.fetchProducts()
                    selectDefaultPlanIfNeeded()
                }
            }
            .font(TriType.bodyBold)
            .foregroundStyle(TriPalette.sunrise)
        }
    }

    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroHeader

                VStack(spacing: 16) {
                    featureList
                    trustRow
                    planCards
                    purchaseSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 20)
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    // Bold navy hero: the entry-point icon over a faint percentile-bar motif,
    // a "Pro" eyebrow, the benefit headline, and the emotional subtitle. Sells
    // the upgrade before any pricing, pricing/feature density comes below.
    private var heroHeader: some View {
        ZStack {
            LinearGradient(
                colors: [TriPalette.deep, TriPalette.deep.opacity(0.88)],
                startPoint: .top,
                endPoint: .bottom
            )

            PaywallBarBackdrop()
                .opacity(0.16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 28)
                .padding(.bottom, 12)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 70, height: 70)
                    Image(systemName: trigger.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text("IRON SPLITS+")
                    .font(TriType.micro)
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.65))

                Text(trigger.title)
                    .font(TriType.athleteName)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)

                Text(trigger.subtitle)
                    .font(TriType.small)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.9)
                    .padding(.horizontal, 22)
            }
            .padding(.top, 64)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(trigger.features, id: \.title) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TriPalette.sunrise)
                        .frame(width: 26)
                    Text(feature.title)
                        .font(TriType.body)
                        .foregroundStyle(TriPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Reassurance + real credibility: these are the official timing
    // results, not times anyone typed in. No fabricated ratings or user
    // counts.
    private var trustRow: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Official race results")
                    .font(TriType.smallBold)
                    .tracking(0.2)
            }
            Text("·")
                .font(TriType.smallBold)
            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Cancel anytime")
                    .font(TriType.smallBold)
                    .tracking(0.2)
            }
        }
        .foregroundStyle(TriPalette.inkTertiary)
        .frame(maxWidth: .infinity)
    }

    private var planCards: some View {
        VStack(spacing: 8) {
            ForEach(store.planOptions) { option in
                PaywallPlanCard(
                    option: option,
                    isSelected: selectedPlan?.id == option.id,
                    isMostPopular: option.kind == .yearly,
                    savingsPercent: savingsPercent(for: option),
                    monthlyAnchorLabel: option.kind == .yearly ? store.monthlyAnchorPriceLabel : nil
                ) {
                    selectedPlan = option
                }
            }
        }
    }

    /// Yearly savings against 12x the monthly plan, computed from whichever
    /// source the options came from so the badge survives a simulator render.
    private func savingsPercent(for option: PlanOption) -> Int? {
        guard option.kind == .yearly else { return nil }
        if let package = store.package(for: option) {
            return store.yearlySavingsPercent(yearly: package)
        }
        guard let monthly = store.planOptions.first(where: { $0.kind == .monthly }),
              let yearlyPerMonth = Self.amount(from: option.perMonthLabel),
              let monthlyPrice = Self.amount(from: monthly.priceLabel),
              monthlyPrice > 0, yearlyPerMonth < monthlyPrice else { return nil }
        let percent = Int((((monthlyPrice - yearlyPerMonth) / monthlyPrice) * 100).rounded())
        return percent > 0 ? percent : nil
    }

    private static func amount(from label: String?) -> Double? {
        guard let label else { return nil }
        let digits = label.filter { $0.isNumber || $0 == "." }
        return Double(digits)
    }

    private var purchaseSection: some View {
        VStack(spacing: 10) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .font(TriType.bodyBold)
                        .foregroundStyle(.white)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(TriPalette.sunrise)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || selectedPlan?.isPurchasable != true)

            if let disclosure = disclosureText {
                Text(disclosure)
                    .font(TriType.micro)
                    .tracking(0.2)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.sunrise)
                    .multilineTextAlignment(.center)
            }
            if let restoreMessage {
                Text(restoreMessage)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: startRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(TriType.smallBold)
                    .foregroundStyle(TriPalette.inkSecondary)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: 12) {
                Link("Terms", destination: IronSplitsLegal.termsURL)
                Link("Privacy", destination: IronSplitsLegal.privacyURL)
            }
            .font(TriType.micro)
            .tracking(0.3)
            .foregroundStyle(TriPalette.inkTertiary)
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismissOnce() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white, .black.opacity(0.28))
                        .padding(16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            Spacer()
        }
    }

    // MARK: - Copy

    private var ctaTitle: String {
        guard let plan = selectedPlan else { return "Continue" }
        #if DEBUG
        // Simulator render of the configured catalog: there is no transaction
        // behind this card, and the button says so rather than failing on tap.
        if !plan.isPurchasable { return "Preview only" }
        #endif
        if plan.kind == .lifetime { return "Unlock Lifetime" }
        if plan.introOfferLabel != nil { return "Start Free Trial" }
        return "Subscribe"
    }

    /// Apple 3.1.2 disclosure adjacent to the purchase button.
    private var disclosureText: String? {
        guard let plan = selectedPlan else { return nil }
        let price = plan.priceLabel
        if plan.kind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        let renew = "Auto-renews unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple ID › Subscriptions."
        if let trial = plan.introOfferLabel {
            return "\(trial.capitalized), then \(price). \(renew)"
        }
        return "\(price). \(renew)"
    }

    // MARK: - Actions

    private func selectDefaultPlanIfNeeded() {
        #if DEBUG
        if let mode = PaywallScreenshotMode.current, !store.planOptions.isEmpty {
            switch mode {
            case .monthly:
                selectedPlan = store.planOptions.first { $0.kind == .monthly }
            case .lifetime:
                selectedPlan = store.planOptions.first { $0.kind == .lifetime }
            case .yearly, .trial:
                selectedPlan = store.planOptions.first { $0.kind == .yearly }
            }
            return
        }
        #endif
        guard selectedPlan == nil, !store.planOptions.isEmpty else { return }
        selectedPlan = store.planOptions.first { $0.kind == .yearly } ?? store.planOptions.first
    }

    private func startPurchase() {
        guard let plan = selectedPlan, let package = store.package(for: plan) else { return }
        errorMessage = nil
        restoreMessage = nil
        isPurchasing = true
        Task { @MainActor in
            defer { isPurchasing = false }
            do {
                switch try await store.purchase(package) {
                case .purchased:
                    break
                case .pending:
                    // Ask-to-Buy / deferred payment: nothing is unlocked yet and
                    // no error occurred, tell the user instead of going silent.
                    restoreMessage = "Purchase pending approval. Iron Splits+ unlocks automatically once it's approved."
                case .cancelled:
                    errorMessage = "Purchase cancelled. Tap again to continue."
                }
            } catch {
                errorMessage = store.lastError ?? "Couldn't complete the purchase. Please try again."
            }
        }
    }

    private func startRestore() {
        errorMessage = nil
        restoreMessage = nil
        isRestoring = true
        Task { @MainActor in
            defer { isRestoring = false }
            await store.restorePurchases()
            if !store.isPro {
                restoreMessage = store.lastError ?? "No active Iron Splits+ purchase was found for this Apple ID."
            }
        }
    }

    private func dismissOnce() {
        guard !hasDismissed else { return }
        hasDismissed = true
        dismiss()
    }
}

/// Faint split-bar motif behind the hero, ties the paywall to the
/// app's split-bar visual language without competing with the copy.
private struct PaywallBarBackdrop: View {
    private let percentiles: [Int] = [94, 81, 67, 52, 38, 88, 73, 60, 45, 83, 70]

    var body: some View {
        HStack(alignment: .bottom, spacing: 7) {
            ForEach(Array(percentiles.enumerated()), id: \.offset) { _, pct in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white)
                    .frame(width: 13, height: CGFloat(pct) * 1.05)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

private struct PaywallPlanCard: View {
    let option: PlanOption
    let isSelected: Bool
    let isMostPopular: Bool
    /// Integer savings vs. 12x monthly (yearly only), drives the SAVE X% chip.
    let savingsPercent: Int?
    /// Strike-through monthly anchor, e.g. "$1.99/mo".
    let monthlyAnchorLabel: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? TriPalette.sunrise : TriPalette.hairline, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(TriPalette.sunrise)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(option.displayName)
                            .font(TriType.bodyBold)
                            .foregroundStyle(TriPalette.ink)
                        if let savingsPercent {
                            Text("SAVE \(savingsPercent)%")
                                .font(TriType.micro)
                                .tracking(0.4)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TriPalette.sunrise, in: Capsule())
                        }
                    }
                    if let trial = option.introOfferLabel {
                        Text(trial.capitalized)
                            .font(TriType.micro)
                            .tracking(0.3)
                            .foregroundStyle(TriPalette.sunrise)
                    } else if isMostPopular {
                        Text("Best value")
                            .font(TriType.micro)
                            .tracking(0.3)
                            .foregroundStyle(TriPalette.sunrise)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(option.priceLabel)
                        .font(TriType.smallBold)
                        .foregroundStyle(TriPalette.inkSecondary)
                    if let perMonthLabel = option.perMonthLabel {
                        HStack(spacing: 5) {
                            if let monthlyAnchorLabel, savingsPercent != nil {
                                Text(monthlyAnchorLabel)
                                    .font(TriType.micro)
                                    .foregroundStyle(TriPalette.inkTertiary)
                                    .strikethrough(true, color: TriPalette.inkTertiary)
                            }
                            Text("\(perMonthLabel)/mo")
                                .font(TriType.micro)
                                .tracking(0.2)
                                .foregroundStyle(TriPalette.ink)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(TriPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard))
            .overlay {
                RoundedRectangle(cornerRadius: TriGeo.radiusCard)
                    .stroke(isSelected ? TriPalette.sunrise : TriPalette.hairline, lineWidth: isSelected ? 2 : 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
