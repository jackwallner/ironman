import Foundation
import UIKit

/// One leg's change between two like-for-like races.
struct RaceBookLegDelta: Identifiable, Hashable, Sendable {
    let discipline: Discipline
    let earlierSeconds: Int
    let laterSeconds: Int

    var id: Discipline { discipline }
    var change: Int { laterSeconds - earlierSeconds }
    var improved: Bool { change < 0 }
}

/// A dated point in the athlete's progression for one leg.
struct RaceBookProgressionPoint: Identifiable, Hashable, Sendable {
    let result: RaceResult
    let seconds: Int

    var id: String { result.id }
}

/// The parts of a Race Book that matter to a triathlete. The options are also
/// the contract between the in-app builder and the exported PDF or image.
struct RaceBookOptions: Sendable, Hashable, Equatable {
    var kinds: Set<RaceKind>
    var includeCareerSummary: Bool
    var includePodiumHighlights: Bool
    var includePersonalBests: Bool
    var includeProgression: Bool
    var includeRaceHistory: Bool
    var includeSplits: Bool
    var includePlacements: Bool
    var includeRaceNotes: Bool
    var includeIncomplete: Bool

    init(kinds: Set<RaceKind> = RaceKind.supportedKinds,
         includeCareerSummary: Bool = true,
         includePodiumHighlights: Bool = true,
         includePersonalBests: Bool = true,
         includeProgression: Bool = true,
         includeRaceHistory: Bool = true,
         includeSplits: Bool = true,
         includePlacements: Bool = true,
         includeRaceNotes: Bool = true,
         includeIncomplete: Bool = false) {
        self.kinds = kinds
        self.includeCareerSummary = includeCareerSummary
        self.includePodiumHighlights = includePodiumHighlights
        self.includePersonalBests = includePersonalBests
        self.includeProgression = includeProgression
        self.includeRaceHistory = includeRaceHistory
        self.includeSplits = includeSplits
        self.includePlacements = includePlacements
        self.includeRaceNotes = includeRaceNotes
        self.includeIncomplete = includeIncomplete
    }

    static let `default` = RaceBookOptions()
}

/// Free calculations used by the Race Book preview and its paid comparison
/// screen. No method crosses a race kind boundary.
enum RaceBookAnalytics {
    static func comparableRaces(_ results: [RaceResult], kind: RaceKind?) -> [RaceResult] {
        results
            .filter { $0.kind.isSupported && $0.isComplete && (kind == nil || $0.kind == kind) }
            .sortedByDateDescending()
    }

    static func comparisonPair(_ results: [RaceResult], kind: RaceKind?) -> (RaceResult, RaceResult)? {
        let races = comparableRaces(results, kind: kind)
        guard races.count >= 2 else { return nil }
        return (races[1], races[0])
    }

    static func deltas(earlier: RaceResult, later: RaceResult) -> [RaceBookLegDelta] {
        guard earlier.kind == later.kind else { return [] }
        return Discipline.rankable.compactMap { discipline in
            guard let earlierSeconds = earlier.seconds(for: discipline), earlierSeconds > 0,
                  let laterSeconds = later.seconds(for: discipline), laterSeconds > 0 else {
                return nil
            }
            return RaceBookLegDelta(discipline: discipline,
                                    earlierSeconds: earlierSeconds,
                                    laterSeconds: laterSeconds)
        }
    }

    static func progression(_ results: [RaceResult],
                            discipline: Discipline,
                            kind: RaceKind?) -> [RaceBookProgressionPoint] {
        comparableRaces(results, kind: kind)
            .reversed()
            .compactMap { result in
                guard let seconds = result.seconds(for: discipline), seconds > 0 else { return nil }
                return RaceBookProgressionPoint(result: result, seconds: seconds)
            }
    }

    static func bests(_ results: [RaceResult], kind: RaceKind?) -> [PersonalBest] {
        RaceAnalytics.personalBests(results, kind: kind)
    }
}

/// Builds the local artifact people pay for. It contains official results plus
/// notes the athlete wrote on-device, and never sends either anywhere.
enum RaceBookBuilder {
    private struct ImageLine {
        let text: String
        let font: UIFont
        let color: UIColor
        let indent: CGFloat
        let spacingAfter: CGFloat
    }

    static func plainText(athlete: Athlete,
                          results: [RaceResult],
                          notes: [String: RaceNote],
                          options: RaceBookOptions = .default) -> String {
        let scopedResults = filteredResults(results, options: options)
        let summary = RaceAnalytics.summary(scopedResults)
        var lines: [String] = [
            "RACE BOOK: \(athlete.name.uppercased())"
        ]
        if let location = athlete.location, !location.isEmpty {
            lines.append(location)
        }

        if options.includeCareerSummary {
            lines.append("")
            lines.append("CAREER AT A GLANCE")
            lines.append("\(summary.finishes) finishes, \(summary.podiums) podiums, \(summary.starts) starts")
            lines.append("\(summary.fullDistance) full distance, \(summary.halfDistance) half distance")
            if let years = summary.years {
                lines.append("Racing from \(years.lowerBound) to \(years.upperBound)")
            }
        }

        if options.includePodiumHighlights {
            lines.append("")
            lines.append("PODIUM HIGHLIGHTS")
            let podiums = scopedResults.filter { $0.isComplete && ($0.finishRankGroup ?? .max) <= 3 }
            if podiums.isEmpty {
                lines.append("No podium finishes recorded.")
            } else {
                for result in podiums {
                    var line = "\(dateText(result)) - \(result.raceName) - \(TimeFormat.hms(result.finish))"
                    if let place = result.finishRankGroup {
                        let group = result.ageGroup ?? "Division"
                        line += " - \(group) #\(place)"
                    }
                    lines.append(line)
                }
            }
        }

        if options.includePersonalBests {
            lines.append("")
            lines.append("PERSONAL BESTS")
            for kind in RaceAnalytics.availableKinds(scopedResults) {
                lines.append(kind.longTitle.uppercased())
                for best in RaceBookAnalytics.bests(scopedResults, kind: kind) {
                    lines.append("  Best \(best.discipline.title): \(TimeFormat.hms(best.seconds)) at \(best.result.raceName)")
                }
            }
        }

        if options.includeProgression {
            lines.append("")
            lines.append("PROGRESSION")
            var progressionCount = 0
            for kind in RaceAnalytics.availableKinds(scopedResults) {
                let points = RaceBookAnalytics.progression(scopedResults, discipline: .finish, kind: kind)
                guard let first = points.first,
                      let latest = points.last,
                      first.result.id != latest.result.id else { continue }
                lines.append("  \(kind.longTitle): \(TimeFormat.hms(first.seconds)) to \(TimeFormat.hms(latest.seconds))")
                progressionCount += 1
            }
            if progressionCount == 0 {
                lines.append("No second complete race at a distance yet.")
            }
        }

        if options.includeRaceHistory {
            lines.append("")
            lines.append("RACE HISTORY")
            if scopedResults.isEmpty {
                lines.append("No races match these choices.")
            }
            for result in scopedResults {
                lines.append(historyLine(for: result, includePlacements: options.includePlacements))

                if options.includeSplits, result.isComplete {
                    let splitLine = [Discipline.swim, .t1, .bike, .t2, .run]
                        .compactMap { discipline -> String? in
                            guard let seconds = result.seconds(for: discipline), seconds > 0 else { return nil }
                            return "\(discipline.title) \(TimeFormat.hms(seconds))"
                        }
                    if !splitLine.isEmpty {
                        lines.append("  Splits: " + splitLine.joined(separator: "  "))
                    }
                }

                if options.includeRaceNotes, let note = notes[result.id], !note.isEmpty {
                    let fields: [(String, String)] = [
                        ("Conditions", note.conditions),
                        ("Nutrition", note.nutrition),
                        ("Gear", note.gear),
                        ("Notes", note.notes)
                    ]
                    for (label, value) in fields {
                        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            lines.append("  \(label): \(trimmed)")
                        }
                    }
                }
            }
        }

        lines.append("")
        lines.append("Generated by IM Tri Tracker. Official times as published by the event timer.")
        return lines.joined(separator: "\n")
    }

    /// A paginated letter-sized career artifact with measured cards and
    /// distance-specific highlights.
    static func pdf(athlete: Athlete,
                    results: [RaceResult],
                    notes: [String: RaceNote],
                    options: RaceBookOptions = .default) -> URL? {
        RaceBookPDFRenderer.make(athlete: athlete,
                                 results: results,
                                 notes: notes,
                                 options: options)
    }

    /// A complete, tall image for messages and social sharing. It uses the same
    /// selected sections as the PDF, with measured wrapping for long race names
    /// and private notes.
    static func image(athlete: Athlete,
                      results: [RaceResult],
                      notes: [String: RaceNote],
                      options: RaceBookOptions = .default) -> URL? {
        let text = plainText(athlete: athlete, results: results, notes: notes, options: options)
        let lines = imageLines(from: text)
        let contentWidth: CGFloat = 1026
        let bodyTop: CGFloat = 426
        let bodyBottom: CGFloat = 84
        let bodyHeight = lines.reduce(CGFloat.zero) { total, line in
            total + imageLineHeight(line, width: contentWidth - line.indent)
        }
        let size = CGSize(width: 1170,
                          height: max(1500, bodyTop + bodyHeight + bodyBottom))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.setFillColor(pdfCanvas.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setFillColor(pdfDeep.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: size.width, height: 354))

            let summary = RaceAnalytics.summary(filteredResults(results, options: options))
            draw("RACE BOOK", in: CGRect(x: 72, y: 72, width: 1026, height: 40),
                 font: UIFont.systemFont(ofSize: 25, weight: .semibold), color: .white)
            draw(athlete.name, in: CGRect(x: 72, y: 122, width: 1026, height: 100),
                 font: UIFont.boldSystemFont(ofSize: 48), color: .white)
            var subtitle: [String] = []
            if options.includeCareerSummary {
                subtitle.append("\(summary.finishes) finishes - \(summary.podiums) podiums")
            }
            if let location = athlete.location, !location.isEmpty { subtitle.append(location) }
            draw(subtitle.joined(separator: "\n"),
                 in: CGRect(x: 72, y: 246, width: 1026, height: 72),
                 font: UIFont.systemFont(ofSize: 24), color: .white.withAlphaComponent(0.82))

            var y = bodyTop
            for line in lines {
                let height = imageLineHeight(line, width: contentWidth - line.indent)
                if !line.text.isEmpty {
                    draw(line.text,
                         in: CGRect(x: 72 + line.indent, y: y,
                                    width: contentWidth - line.indent, height: height),
                         font: line.font,
                         color: line.color)
                }
                y += height
            }
            draw("Official results, private notes, one clear story.",
                 in: CGRect(x: 72, y: size.height - bodyBottom + 12,
                            width: 1026, height: 40),
                 font: UIFont.systemFont(ofSize: 22),
                 color: pdfMuted)
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileSafe(athlete.name))-race-book.png")
        guard let data = image.pngData() else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func filteredResults(_ results: [RaceResult], options: RaceBookOptions) -> [RaceResult] {
        results
            .filter { $0.kind.isSupported && options.kinds.contains($0.kind) }
            .filter { options.includeIncomplete || $0.isComplete }
            .sortedByDateDescending()
    }

    private static func historyLine(for result: RaceResult, includePlacements: Bool) -> String {
        let status = result.isComplete
            ? TimeFormat.hms(result.finish)
            : (ResumeBuilder.statusLabel(for: result) ?? "Incomplete")
        var line = "\(dateText(result)) - \(result.raceName) - \(status)"
        if let bib = result.bib { line += " - Bib \(bib)" }
        guard includePlacements else { return line }
        if let group = result.ageGroup, let place = result.finishRankGroup {
            line += " - \(group) #\(place)"
        } else if let place = result.finishRankGroup {
            line += " - Division #\(place)"
        }
        if let overall = result.finishRankOverall {
            line += " - \(overall) overall"
        }
        return line
    }

    private static func imageLines(from text: String) -> [ImageLine] {
        let rawLines = text.components(separatedBy: .newlines)
        let bodyLines: ArraySlice<String>
        if let firstBlank = rawLines.firstIndex(where: { $0.isEmpty }) {
            bodyLines = rawLines.dropFirst(firstBlank + 1)
        } else {
            bodyLines = rawLines[...]
        }

        return bodyLines.map { line in
            guard !line.isEmpty else {
                return ImageLine(text: "", font: UIFont.systemFont(ofSize: 18),
                                 color: .clear, indent: 0, spacingAfter: 8)
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == trimmed.uppercased() && !line.hasPrefix("  ") {
                return ImageLine(text: trimmed, font: UIFont.systemFont(ofSize: 25, weight: .semibold),
                                 color: pdfDeep, indent: 0, spacingAfter: 16)
            }
            if line.hasPrefix("  Splits:") || line.hasPrefix("  Conditions:")
                || line.hasPrefix("  Nutrition:") || line.hasPrefix("  Gear:")
                || line.hasPrefix("  Notes:") {
                return ImageLine(text: trimmed, font: UIFont.systemFont(ofSize: 21),
                                 color: pdfMuted, indent: 38, spacingAfter: 7)
            }
            if line.hasPrefix("  Best ") || line.hasPrefix("  Progression:") {
                return ImageLine(text: trimmed, font: UIFont.systemFont(ofSize: 22),
                                 color: pdfSecondary, indent: 24, spacingAfter: 8)
            }
            return ImageLine(text: trimmed, font: UIFont.systemFont(ofSize: 23, weight: .medium),
                             color: pdfInk, indent: 0, spacingAfter: 10)
        }
    }

    private static func imageLineHeight(_ line: ImageLine, width: CGFloat) -> CGFloat {
        guard !line.text.isEmpty else { return line.font.lineHeight + line.spacingAfter }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: line.font,
            .paragraphStyle: paragraphStyle
        ]
        let bounds = (line.text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes,
            context: nil
        )
        return ceil(bounds.height) + line.spacingAfter
    }

    private static func draw(_ text: String,
                             in rect: CGRect,
                             font: UIFont,
                             color: UIColor) {
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ])
    }

    private static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.lineSpacing = 5
        return style
    }

    private static func dateText(_ result: RaceResult) -> String {
        guard let date = result.eventDate else { return result.year > 0 ? String(result.year) : "Undated" }
        return RaceDate.medium(date)
    }

    private static func fileSafe(_ name: String) -> String {
        let safe = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return safe.isEmpty ? "iron-splits" : safe
    }

    private static let pdfDeep = UIColor(red: 0.051, green: 0.149, blue: 0.271, alpha: 1)
    private static let pdfAccent = UIColor(red: 0.910, green: 0.400, blue: 0.086, alpha: 1)
    private static let pdfCanvas = UIColor(red: 0.949, green: 0.953, blue: 0.961, alpha: 1)
    private static let pdfInk = UIColor(red: 0.075, green: 0.098, blue: 0.129, alpha: 1)
    private static let pdfSecondary = UIColor(red: 0.259, green: 0.290, blue: 0.333, alpha: 1)
    private static let pdfMuted = UIColor(red: 0.439, green: 0.471, blue: 0.522, alpha: 1)
}
