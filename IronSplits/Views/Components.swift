import SwiftUI

/// Horizontal bar showing how a finish time divided across the legs.
///
/// Transitions are usually about 1% of a race, which at typical widths is under
/// a pixel and vanishes. They get a floor so the bar keeps five segments and
/// the legend keeps matching the picture.
struct SplitBar: View {
    let result: RaceResult
    var height: CGFloat = 10

    private let minimumShare = 0.012

    var body: some View {
        GeometryReader { geometry in
            let shares = normalizedShares()
            HStack(spacing: 1) {
                ForEach(shares, id: \.discipline) { entry in
                    TriPalette.color(for: entry.discipline)
                        .frame(width: max(1, geometry.size.width * entry.share))
                }
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private func normalizedShares() -> [(discipline: Discipline, share: Double, seconds: Int)] {
        let raw = RaceAnalytics.legShares(result)
        guard !raw.isEmpty else { return [] }
        let lifted = raw.map { (discipline: $0.discipline, share: max($0.share, minimumShare), seconds: $0.seconds) }
        let total = lifted.reduce(0.0) { $0 + $1.share }
        return lifted.map { (discipline: $0.discipline, share: $0.share / total, seconds: $0.seconds) }
    }

    private var accessibilityText: String {
        RaceAnalytics.legShares(result)
            .map { "\($0.discipline.title) \(TimeFormat.hms($0.seconds))" }
            .joined(separator: ", ")
    }
}

/// Percentile bar with a marker, ported from StatScout's Savant leaderboard.
struct PercentileBar: View {
    let percentile: Int
    var height: CGFloat = TriGeo.barTrack

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(TriPalette.surfaceSunk)
                Capsule()
                    .fill(TriPalette.color(forPercentile: percentile))
                    .frame(width: max(height, geometry.size.width * CGFloat(percentile) / 100))
            }
        }
        .frame(height: height)
    }
}

/// A row in the locker: the race, its date, the finish time, and the split bar.
struct RaceRow: View {
    let result: RaceResult
    var personalBestLegs: Set<Discipline> = []
    var hasNote: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: TriSpace.x2) {
            HStack(alignment: .firstTextBaseline, spacing: TriSpace.x2) {
                VStack(alignment: .leading, spacing: TriSpace.x1) {
                    Text(result.raceName)
                        .font(TriType.cardTitle)
                        .foregroundStyle(TriPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .layoutPriority(1)
                    ViewThatFits(in: .horizontal) {
                        metadataRow
                        compactMetadataRow
                    }
                }
                Spacer(minLength: TriSpace.x2)
                VStack(alignment: .trailing, spacing: TriSpace.x1) {
                    Text(result.isComplete ? TimeFormat.hms(result.finish) : statusText)
                        .font(TriType.statLarge)
                        .foregroundStyle(result.isComplete ? TriPalette.ink : TriPalette.negative)
                        .fixedSize(horizontal: true, vertical: false)
                    if let group = result.ageGroup, let place = result.finishRankGroup {
                        Text(group + " #" + String(place))
                            .font(TriType.small)
                            .foregroundStyle(TriPalette.inkTertiary)
                    }
                }
            }

            if result.isComplete {
                SplitBar(result: result)
                if !personalBestLegs.isEmpty {
                    HStack(spacing: TriSpace.x1) {
                        ForEach(Discipline.rankable.filter { personalBestLegs.contains($0) }) { leg in
                            TriBadge(text: "PB \(leg.title)", color: TriPalette.sunrise, filled: true)
                        }
                    }
                }
            }
        }
        .frame(minHeight: TriGeo.tapTarget)
        .padding(.vertical, TriSpace.x1)
    }

    private var metadataRow: some View {
        HStack(spacing: TriSpace.x2) {
            Text(dateText)
                .font(TriType.small)
                .foregroundStyle(TriPalette.inkTertiary)
            TriBadge(text: result.kind.title, color: TriPalette.inkTertiary)
            if let bib = result.bib {
                Text("Bib " + String(bib))
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
            }
            if hasNote {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                    .foregroundStyle(TriPalette.inkTertiary)
                    .accessibilityLabel("Has notes")
            }
        }
    }

    private var compactMetadataRow: some View {
        VStack(alignment: .leading, spacing: TriSpace.x1) {
            HStack(spacing: TriSpace.x2) {
                Text(dateText)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                TriBadge(text: result.kind.title, color: TriPalette.inkTertiary)
            }
            HStack(spacing: TriSpace.x2) {
                if let bib = result.bib {
                    Text("Bib " + String(bib))
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                }
                if hasNote {
                    Image(systemName: "note.text")
                        .font(.system(size: 10))
                        .foregroundStyle(TriPalette.inkTertiary)
                        .accessibilityLabel("Has notes")
                }
            }
        }
    }

    private var statusText: String {
        if result.disqualified { return "DQ" }
        if result.didNotStart { return "DNS" }
        return "DNF"
    }

    private var dateText: String {
        guard let date = result.eventDate else {
            return result.year > 0 ? String(result.year) : "Undated"
        }
        return RaceDate.medium(date)
    }
}

/// Legend for the split bar's colours.
struct SplitLegend: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TriSpace.x3) {
                ForEach([Discipline.swim, .t1, .bike, .t2, .run]) { leg in
                    HStack(spacing: TriSpace.x1) {
                        Circle()
                            .fill(TriPalette.color(for: leg))
                            .frame(width: 7, height: 7)
                        Text(leg.title)
                            .font(TriType.micro)
                            .foregroundStyle(TriPalette.inkTertiary)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, TriSpace.x1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Split colors: swim, T1, bike, T2, run")
    }
}

/// The standard "this needs Pro" row, used wherever a list is truncated.
///
/// The legacy row remains available for any future paid surface that needs a
/// concise call to action. The current product keeps the result history free
/// and uses Race Book actions for the only purchase boundary.
struct LockedRow: View {
    let title: String
    let subtitle: String
    var cta: String = "Unlock"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: TriSpace.x3) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TriPalette.sunrise)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: TriSpace.x1) {
                    Text(title)
                        .font(TriType.bodyBold)
                        .foregroundStyle(TriPalette.ink)
                    Text(subtitle)
                        .font(TriType.small)
                        .foregroundStyle(TriPalette.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: TriSpace.x2)
                Text(cta)
                    .font(TriType.smallBold)
                    .foregroundStyle(TriPalette.inkOnDark)
                    .padding(.horizontal, TriSpace.x3)
                    .padding(.vertical, TriSpace.x1)
                    .background(TriPalette.sunrise, in: Capsule())
            }
            .padding(.vertical, TriSpace.x1)
            .frame(minHeight: TriGeo.tapTarget)
        }
        .buttonStyle(.triPress)
    }
}

/// Empty / error / loading placeholder with one consistent shape.
struct TriPlaceholder: View {
    let systemImage: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: TriSpace.x3) {
            Image(systemName: systemImage)
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(TriPalette.inkTertiary)
            Text(title)
                .font(TriType.cardTitle)
                .foregroundStyle(TriPalette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(message)
                    .font(TriType.small)
                    .foregroundStyle(TriPalette.inkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle) {
                    Haptics.tap()
                    action()
                }
                .font(TriType.bodyBold)
                .foregroundStyle(TriPalette.sunrise)
                .frame(minHeight: TriGeo.tapTarget)
                .buttonStyle(.triPressSilent)
                .padding(.top, TriSpace.x1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, TriSpace.x8)
        .padding(.vertical, TriSpace.x8)
    }
}

/// Big number + caption, used across the locker header and race detail.
struct StatTile: View {
    let value: String
    let caption: String
    var tint: Color = TriPalette.ink

    var body: some View {
        VStack(spacing: TriSpace.x1) {
            Text(value)
                .font(TriType.statMed)
                .foregroundStyle(tint)
            Text(caption.uppercased())
                .font(TriType.micro)
                .kerning(0.4)
                .foregroundStyle(TriPalette.inkTertiary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .allowsTightening(true)
        }
        .frame(minWidth: TriSpace.x10 + TriSpace.x8)
    }
}
