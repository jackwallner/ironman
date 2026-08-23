import CoreText
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

/// Free calculations used by the Race Book preview and its paid comparison
/// screen. No method crosses a race kind boundary.
enum RaceBookAnalytics {
    static func comparableRaces(_ results: [RaceResult], kind: RaceKind?) -> [RaceResult] {
        results
            .filter { $0.isComplete && (kind == nil || $0.kind == kind) }
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

/// Builds the artifact people pay for. The output is local, deterministic and
/// contains only the official results plus notes the athlete wrote on-device.
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
                          notes: [String: RaceNote]) -> String {
        let summary = RaceAnalytics.summary(results)
        var lines: [String] = [
            "RACE BOOK: \(athlete.name.uppercased())",
            athlete.location ?? "",
            "\(summary.finishes) finishes, \(summary.podiums) podiums"
        ]
        if let years = summary.years {
            lines.append("Racing from \(years.lowerBound) to \(years.upperBound)")
        }
        lines.append("")

        for kind in RaceAnalytics.availableKinds(results) {
            lines.append(kind.longTitle.uppercased())
            for best in RaceBookAnalytics.bests(results, kind: kind) {
                lines.append("  Best \(best.discipline.title): \(TimeFormat.hms(best.seconds)) at \(best.result.raceName)")
            }
            let points = RaceBookAnalytics.progression(results, discipline: .finish, kind: kind)
            if let first = points.first,
               let latest = points.last,
               first.result.id != latest.result.id {
                lines.append("  Progression: \(TimeFormat.hms(first.seconds)) to \(TimeFormat.hms(latest.seconds))")
            }
            lines.append("")
        }

        lines.append("RACE HISTORY")
        for result in results.sortedByDateDescending() {
            let status = result.isComplete ? TimeFormat.hms(result.finish) : (ResumeBuilder.statusLabel(for: result) ?? "Incomplete")
            var line = "\(dateText(result))  \(result.raceName)  \(status)"
            if let bib = result.bib { line += "  Bib \(bib)" }
            if let group = result.ageGroup, let place = result.finishRankGroup {
                line += "  \(group) #\(place)"
            } else if let place = result.finishRankGroup {
                line += "  Division #\(place)"
            }
            if let overall = result.finishRankOverall {
                line += "  \(overall) overall"
            }
            lines.append(line)

            if result.isComplete {
                let splitLine = [Discipline.swim, .t1, .bike, .t2, .run]
                    .compactMap { discipline -> String? in
                        guard let seconds = result.seconds(for: discipline), seconds > 0 else { return nil }
                        return "\(discipline.title) \(TimeFormat.hms(seconds))"
                    }
                if !splitLine.isEmpty {
                    lines.append("  Splits: " + splitLine.joined(separator: "  "))
                }
            }

            if let note = notes[result.id], !note.isEmpty {
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

        lines.append("")
        lines.append("Generated by IM Tri Tracker. Official times as published by the event timer.")
        return lines.joined(separator: "\n")
    }

    /// A paginated letter-sized PDF. Core Text gives long race histories a
    /// measured frame, so the last race cannot be silently clipped.
    static func pdf(athlete: Athlete,
                    results: [RaceResult],
                    notes: [String: RaceNote]) -> URL? {
        let text = plainText(athlete: athlete, results: results, notes: notes)
        let pageSize = CGSize(width: 612, height: 792)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(fileSafe(athlete.name))-race-book.pdf")
        let bodyFont = UIFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)
        let body = NSAttributedString(string: text, attributes: [
            .font: bodyFont,
            .foregroundColor: UIColor(red: 0.075, green: 0.098, blue: 0.129, alpha: 1)
        ])
        let framesetter = CTFramesetterCreateWithAttributedString(body)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        let margin: CGFloat = 48
        let bodyRect = CGRect(x: margin,
                              y: 148,
                              width: pageSize.width - margin * 2,
                              height: pageSize.height - 188)

        do {
            try renderer.writePDF(to: url) { context in
                var location = 0
                repeat {
                    context.beginPage()
                    guard let cgContext = UIGraphicsGetCurrentContext() else { return }
                    cgContext.saveGState()
                    cgContext.translateBy(x: 0, y: pageSize.height)
                    cgContext.scaleBy(x: 1, y: -1)

                    cgContext.setFillColor(UIColor(red: 0.051, green: 0.149, blue: 0.271, alpha: 1).cgColor)
                    cgContext.fill(CGRect(x: 0, y: 0, width: pageSize.width, height: 120))
                    drawHeader(athlete: athlete, in: cgContext, pageSize: pageSize)

                    let path = CGPath(rect: bodyRect, transform: nil)
                    let frame = CTFramesetterCreateFrame(framesetter,
                                                         CFRangeMake(location, 0),
                                                         path,
                                                         nil)
                    CTFrameDraw(frame, cgContext)
                    let visible = CTFrameGetVisibleStringRange(frame)
                    cgContext.restoreGState()
                    guard visible.length > 0 else { return }
                    location += visible.length
                } while location < body.length
            }
            return url
        } catch {
            return nil
        }
    }

    /// A complete, tall image for messages and social sharing. It includes the
    /// same history as the PDF, with measured wrapping so long race names and
    /// private notes remain visible instead of disappearing below a fixed card.
    static func image(athlete: Athlete,
                      results: [RaceResult],
                      notes: [String: RaceNote]) -> URL? {
        let text = plainText(athlete: athlete, results: results, notes: notes)
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
            cg.setFillColor(UIColor(red: 0.949, green: 0.953, blue: 0.961, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            cg.setFillColor(UIColor(red: 0.051, green: 0.149, blue: 0.271, alpha: 1).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: size.width, height: 354))

            let summary = RaceAnalytics.summary(results)
            draw("RACE BOOK", in: CGRect(x: 72, y: 72, width: 1026, height: 40),
                 font: .systemFont(ofSize: 25, weight: .semibold), color: .white)
            draw(athlete.name, in: CGRect(x: 72, y: 122, width: 1026, height: 100),
                 font: .boldSystemFont(ofSize: 48), color: .white)
            var subtitle = ["\(summary.finishes) finishes  •  \(summary.podiums) podiums"]
            if let location = athlete.location, !location.isEmpty { subtitle.append(location) }
            draw(subtitle.joined(separator: "\n"),
                 in: CGRect(x: 72, y: 246, width: 1026, height: 72),
                 font: .systemFont(ofSize: 24, weight: .regular), color: .white.withAlphaComponent(0.82))

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
                 font: .systemFont(ofSize: 22, weight: .regular),
                 color: UIColor(red: 0.439, green: 0.471, blue: 0.522, alpha: 1))
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
                return ImageLine(text: "", font: .systemFont(ofSize: 18),
                                 color: .clear, indent: 0, spacingAfter: 8)
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == trimmed.uppercased() && !line.hasPrefix("  ") {
                return ImageLine(text: trimmed, font: .systemFont(ofSize: 25, weight: .semibold),
                                 color: UIColor(red: 0.051, green: 0.149, blue: 0.271, alpha: 1),
                                 indent: 0, spacingAfter: 16)
            }
            if line.hasPrefix("  Splits:") || line.hasPrefix("  Conditions:")
                || line.hasPrefix("  Nutrition:") || line.hasPrefix("  Gear:")
                || line.hasPrefix("  Notes:") {
                return ImageLine(text: trimmed, font: .systemFont(ofSize: 21),
                                 color: UIColor(red: 0.439, green: 0.471, blue: 0.522, alpha: 1),
                                 indent: 38, spacingAfter: 7)
            }
            if line.hasPrefix("  Best ") || line.hasPrefix("  Progression:") {
                return ImageLine(text: trimmed, font: .systemFont(ofSize: 22),
                                 color: UIColor(red: 0.259, green: 0.290, blue: 0.333, alpha: 1),
                                 indent: 24, spacingAfter: 8)
            }
            return ImageLine(text: trimmed, font: .systemFont(ofSize: 23, weight: .medium),
                             color: UIColor(red: 0.075, green: 0.098, blue: 0.129, alpha: 1),
                             indent: 0, spacingAfter: 10)
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

    private static func drawHeader(athlete: Athlete,
                                   in context: CGContext,
                                   pageSize: CGSize) {
        let header = NSAttributedString(string: "RACE BOOK\n\(athlete.name)", attributes: [
            .font: UIFont.systemFont(ofSize: 21, weight: .semibold),
            .foregroundColor: UIColor.white
        ])
        let path = CGPath(rect: CGRect(x: 48, y: 28, width: pageSize.width - 96, height: 76), transform: nil)
        let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(header),
                                             CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, context)
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
}
