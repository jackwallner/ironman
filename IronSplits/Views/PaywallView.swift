import SwiftUI
@preconcurrency import RevenueCat

enum PaywallTrigger: Identifiable, Hashable {
    var id: Self { self }

    case raceBookCompare
    case raceBookExport
    case upgrade

    var icon: String {
        switch self {
        case .raceBookCompare:    return "arrow.left.arrow.right"
        case .raceBookExport:     return "square.and.arrow.up"
        case .upgrade:           return "crown.fill"
        }
    }

    var title: String {
        switch self {
        case .raceBookCompare:    return "Compare your races"
        case .raceBookExport:     return "Share your Race Book"
        case .upgrade:           return "Unlock Race Book"
        }
    }

    var subtitle: String {
        switch self {
        case .raceBookCompare:
            return "See exactly where one like-for-like race gained or lost time against another."
        case .raceBookExport:
            return "Create a polished race-history PDF or image with splits, podiums, notes and career stats."
        case .upgrade:
            return "Compare like-for-like races and create unlimited polished exports with one lifetime purchase."
        }
    }

    /// RevenueCat custom-paywall impression id for this entry point.
    var paywallImpressionId: String {
        switch self {
        case .raceBookCompare:    return "ironsplits_paywall_race_book_compare"
        case .raceBookExport:     return "ironsplits_paywall_race_book_export"
        case .upgrade:           return "ironsplits_paywall_upgrade"
        }
    }

    /// What the one-time unlock actually opens. The underlying race data is
    /// intentionally absent because it is free for everyone.
    private static let proFeatures: [(icon: String, title: String)] = [
        ("arrow.left.arrow.right", "Compare like-for-like races leg by leg"),
        ("chart.xyaxis.line", "Career personal-best and progression timeline"),
        ("doc.richtext", "Beautiful race-history PDF and image exports"),
        ("note.text", "Unlimited exports with notes, podiums and splits")
    ]

    var features: [(icon: String, title: String)] {
        Self.proFeatures
    }
}

/// Native Race Book paywall. Purchases flow through `StoreService.purchase`
/// → `Purchases.shared.purchase` so RevenueCat records transactions unchanged.
struct PaywallView: View {
    @EnvironmentObject private var store: StoreService
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
        VStack(spacing: TriSpace.x3) {
            ProgressView()
                .tint(TriPalette.sunrise)
            Text("Loading plans…")
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: TriSpace.x3) {
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
                .padding(.horizontal, TriSpace.x8)
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

                VStack(spacing: TriSpace.x4) {
                    featureList
                    trustRow
                    planCards
                    purchaseSection
                }
                .padding(.horizontal, TriSpace.x5)
                .padding(.top, TriSpace.x4)
                .padding(.bottom, TriSpace.x5)
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
                .padding(.horizontal, TriSpace.x6)
                .padding(.bottom, TriSpace.x3)

            VStack(spacing: TriSpace.x3) {
                ZStack {
                    Circle()
                        .fill(TriPalette.inkOnDark.opacity(0.12))
                        .frame(width: 70, height: 70)
                    Image(systemName: trigger.icon)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(TriPalette.inkOnDark)
                }

                Text("RACE BOOK")
                    .font(TriType.micro)
                    .tracking(2.5)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.65))

                Text(trigger.title)
                    .font(TriType.athleteName)
                    .foregroundStyle(TriPalette.inkOnDark)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(trigger.subtitle)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkOnDark.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, TriSpace.x6)
            }
            .padding(.top, TriSpace.x10 + TriSpace.x6)
            .padding(.bottom, TriSpace.x5)
            .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            ForEach(trigger.features, id: \.title) { feature in
                HStack(spacing: TriSpace.x3) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TriPalette.sunrise)
                        .frame(width: TriSpace.x6)
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
        ViewThatFits(in: .horizontal) {
            trustHorizontal
            trustVertical
        }
        .font(TriType.smallBold)
        .tracking(0.2)
        .foregroundStyle(TriPalette.inkTertiary)
        .frame(maxWidth: .infinity)
    }

    private var trustHorizontal: some View {
        HStack(spacing: TriSpace.x3) {
            HStack(spacing: TriSpace.x1) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("Official race results")
                    .font(TriType.smallBold)
                    .tracking(0.2)
            }
            Text("·")
            HStack(spacing: TriSpace.x1) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11, weight: .semibold))
                    Text("No subscription")
                    .font(TriType.smallBold)
                    .tracking(0.2)
            }
        }
    }

    private var trustVertical: some View {
        VStack(spacing: TriSpace.x1) {
            Text("Official race results")
            Text("No subscription")
        }
    }

    private var planCards: some View {
        VStack(spacing: TriSpace.x2) {
            ForEach(store.planOptions) { option in
                PaywallPlanCard(
                    option: option,
                    isSelected: selectedPlan?.id == option.id,
                    isMostPopular: false,
                    savingsPercent: nil,
                    monthlyAnchorLabel: nil
                ) {
                    selectedPlan = option
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(spacing: TriSpace.x3) {
            Button(action: startPurchase) {
                ZStack {
                    Text(ctaTitle)
                        .font(TriType.bodyBold)
                        .foregroundStyle(TriPalette.inkOnDark)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing {
                        ProgressView().tint(TriPalette.inkOnDark)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: TriGeo.tapTarget + TriSpace.x1)
                .background(TriPalette.sunrise)
                .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
            }
            .buttonStyle(.triPressSilent)
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
            .buttonStyle(.triPressSilent)
            .disabled(isRestoring || isPurchasing)

            HStack(spacing: TriSpace.x3) {
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
                        .foregroundStyle(TriPalette.inkOnDark, TriPalette.ink.opacity(0.28))
                        .frame(width: TriGeo.tapTarget, height: TriGeo.tapTarget)
                }
                .buttonStyle(.triPressSilent)
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
        if plan.kind == .lifetime { return "Unlock Race Book" }
        return "Continue"
    }

    /// Apple 3.1.2 disclosure adjacent to the purchase button.
    private var disclosureText: String? {
        guard let plan = selectedPlan else { return nil }
        let price = plan.priceLabel
        if plan.kind == .lifetime {
            return "\(price). One-time purchase. Lifetime access, no subscription."
        }
        return "\(price). One-time purchase. Lifetime access to Race Book. No subscription."
    }

    // MARK: - Actions

    private func selectDefaultPlanIfNeeded() {
        #if DEBUG
        if let mode = PaywallScreenshotMode.current, !store.planOptions.isEmpty {
            switch mode {
            case .lifetime:
                selectedPlan = store.planOptions.first { $0.kind == .lifetime }
            case .monthly, .yearly, .trial:
                selectedPlan = store.planOptions.first { $0.kind == .lifetime }
            }
            return
        }
        #endif
        guard selectedPlan == nil, !store.planOptions.isEmpty else { return }
        selectedPlan = store.planOptions.first { $0.kind == .lifetime } ?? store.planOptions.first
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
                    restoreMessage = "Purchase pending approval. Race Book unlocks automatically once it's approved."
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
                restoreMessage = store.lastError ?? "No Race Book purchase was found for this Apple ID."
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
        HStack(alignment: .bottom, spacing: TriSpace.x2) {
            ForEach(Array(percentiles.enumerated()), id: \.offset) { _, pct in
                RoundedRectangle(cornerRadius: TriGeo.radiusInner, style: .continuous)
                    .fill(TriPalette.inkOnDark)
                    .frame(width: TriSpace.x3, height: CGFloat(pct) * 1.05)
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
            ViewThatFits(in: .horizontal) {
                horizontalLayout
                verticalLayout
            }
            .padding(.horizontal, TriSpace.x3)
            .padding(.vertical, TriSpace.x3)
            .background(TriPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: TriGeo.radiusCard, style: .continuous)
                    .stroke(isSelected ? TriPalette.sunrise : TriPalette.hairline, lineWidth: isSelected ? 2 : 0.5)
            }
        }
        .buttonStyle(.triPressSilent)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: TriSpace.x3) {
            selectionIndicator
            planInfo
            Spacer(minLength: TriSpace.x2)
            priceInfo
        }
    }

    private var verticalLayout: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            HStack(alignment: .top, spacing: TriSpace.x3) {
                selectionIndicator
                planInfo
            }
            priceInfo
                .padding(.leading, TriSpace.x8 + TriSpace.x3)
        }
    }

    private var selectionIndicator: some View {
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
        .accessibilityHidden(true)
    }

    private var planInfo: some View {
        VStack(alignment: .leading, spacing: TriSpace.x1) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TriSpace.x1) {
                    planTitle
                    savingsBadge
                }
                VStack(alignment: .leading, spacing: TriSpace.x1) {
                    planTitle
                    savingsBadge
                }
            }
            if let trial = option.introOfferLabel {
                Text(trial.capitalized)
                    .font(TriType.micro)
                    .tracking(0.3)
                    .foregroundStyle(TriPalette.sunrise)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isMostPopular {
                Text("Best value")
                    .font(TriType.micro)
                    .tracking(0.3)
                    .foregroundStyle(TriPalette.sunrise)
            }
        }
        .layoutPriority(1)
    }

    private var planTitle: some View {
        Text(option.displayName)
            .font(TriType.bodyBold)
            .foregroundStyle(TriPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var savingsBadge: some View {
        if let savingsPercent {
            Text("SAVE \(savingsPercent)%")
                .font(TriType.micro)
                .tracking(0.4)
                .foregroundStyle(TriPalette.inkOnDark)
                .padding(.horizontal, TriSpace.x2)
                .padding(.vertical, TriSpace.x1)
                .background(TriPalette.sunrise, in: Capsule())
        }
    }

    private var priceInfo: some View {
        VStack(alignment: .trailing, spacing: TriSpace.x1) {
            Text(option.priceLabel)
                .font(TriType.smallBold)
                .foregroundStyle(TriPalette.inkSecondary)
                .fixedSize(horizontal: true, vertical: false)
            if let perMonthLabel = option.perMonthLabel {
                HStack(spacing: TriSpace.x1) {
                    if let monthlyAnchorLabel, savingsPercent != nil {
                        Text(monthlyAnchorLabel)
                            .font(TriType.micro)
                            .foregroundStyle(TriPalette.inkTertiary)
                            .strikethrough(true, color: TriPalette.inkTertiary)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Text("\(perMonthLabel)/mo")
                        .font(TriType.micro)
                        .tracking(0.2)
                        .foregroundStyle(TriPalette.ink)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}
