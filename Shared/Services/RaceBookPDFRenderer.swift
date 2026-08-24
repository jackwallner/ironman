import Foundation
import UIKit

/// Draws the Race Book as an editorial career artifact rather than a text dump.
/// Every block measures its own text before drawing, and history cards are
/// paginated as whole units so a long race name or note cannot be clipped.
enum RaceBookPDFRenderer {
    private static let pageSize = CGSize(width: 612, height: 792)
    private static let pageMargin: CGFloat = 40

    private enum Palette {
        static let deep = UIColor(red: 0.020, green: 0.094, blue: 0.208, alpha: 1)
        static let deepLift = UIColor(red: 0.055, green: 0.165, blue: 0.360, alpha: 1)
        static let coral = UIColor(red: 0.780, green: 0.200, blue: 0.165, alpha: 1)
        static let aqua = UIColor(red: 0.122, green: 0.396, blue: 0.729, alpha: 1)
        static let green = UIColor(red: 0.361, green: 0.706, blue: 0.145, alpha: 1)
        static let canvas = UIColor(red: 0.949, green: 0.953, blue: 0.961, alpha: 1)
        static let card = UIColor.white
        static let ink = UIColor(red: 0.075, green: 0.098, blue: 0.129, alpha: 1)
        static let secondary = UIColor(red: 0.259, green: 0.290, blue: 0.333, alpha: 1)
        static let muted = UIColor(red: 0.439, green: 0.471, blue: 0.522, alpha: 1)
        static let line = UIColor(red: 0.827, green: 0.839, blue: 0.859, alpha: 1)
        static let paleBlue = UIColor(red: 0.895, green: 0.932, blue: 0.988, alpha: 1)
        static let paleCoral = UIColor(red: 0.988, green: 0.914, blue: 0.902, alpha: 1)
    }

    private final class Document {
        let context: UIGraphicsPDFRendererContext
        let size: CGSize
        private(set) var pageNumber = 0

        var contentBottom: CGFloat { size.height - 56 }

        init(context: UIGraphicsPDFRendererContext, size: CGSize) {
            self.context = context
            self.size = size
        }

        func beginPage() {
            context.beginPage()
            pageNumber += 1
            fill(CGRect(origin: .zero, size: size), Palette.canvas)
        }

        func beginContentPage(kicker: String, title: String) -> CGFloat {
            beginPage()
            fill(CGRect(x: 0, y: 0, width: size.width, height: 8), Palette.deep)
            text(kicker.uppercased(),
                 in: CGRect(x: Self.margin, y: 34, width: size.width - Self.margin * 2, height: 14),
                 font: .systemFont(ofSize: 8, weight: .bold),
                 color: Palette.coral,
                 tracking: 1.1)
            text(title,
                 in: CGRect(x: Self.margin, y: 52, width: size.width - Self.margin * 2, height: 34),
                 font: .systemFont(ofSize: 25, weight: .bold),
                 color: Palette.deep)
            line(from: CGPoint(x: Self.margin, y: 100),
                 to: CGPoint(x: size.width - Self.margin, y: 100),
                 color: Palette.line,
                 width: 0.7)
            return 120
        }

        func endPage() {
            line(from: CGPoint(x: Self.margin, y: size.height - 38),
                 to: CGPoint(x: size.width - Self.margin, y: size.height - 38),
                 color: Palette.line,
                 width: 0.7)
            text("IM TRI TRACKER  |  OFFICIAL RESULTS, PRIVATE NOTES",
                 in: CGRect(x: Self.margin, y: size.height - 30, width: 420, height: 12),
                 font: .systemFont(ofSize: 7.5, weight: .semibold),
                 color: Palette.muted,
                 tracking: 0.3)
            text("\(pageNumber)",
                 in: CGRect(x: size.width - Self.margin - 36, y: size.height - 30, width: 36, height: 12),
                 font: .monospacedDigitSystemFont(ofSize: 8, weight: .semibold),
                 color: Palette.muted,
                 alignment: .right)
        }

        func fill(_ rect: CGRect, _ color: UIColor) {
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fill(rect)
        }

        func card(_ rect: CGRect,
                  fill color: UIColor = Palette.card,
                  stroke: UIColor = Palette.line,
                  radius: CGFloat = 12) {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
            context.cgContext.addPath(path)
            context.cgContext.setFillColor(color.cgColor)
            context.cgContext.fillPath()
            context.cgContext.addPath(path)
            context.cgContext.setStrokeColor(stroke.cgColor)
            context.cgContext.setLineWidth(0.7)
            context.cgContext.strokePath()
        }

        func line(from start: CGPoint, to end: CGPoint, color: UIColor, width: CGFloat) {
            context.cgContext.setStrokeColor(color.cgColor)
            context.cgContext.setLineWidth(width)
            context.cgContext.move(to: start)
            context.cgContext.addLine(to: end)
            context.cgContext.strokePath()
        }

        @discardableResult
        func text(_ value: String,
                  in rect: CGRect,
                  font: UIFont,
                  color: UIColor,
                  alignment: NSTextAlignment = .left,
                  lineSpacing: CGFloat = 1.5,
                  tracking: CGFloat = 0) -> CGFloat {
            guard !value.isEmpty, rect.width > 0 else { return 0 }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = alignment
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = lineSpacing
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph
            ]
            if tracking != 0 {
                attributes[.kern] = tracking
            }
            context.cgContext.saveGState()
            context.cgContext.clip(to: rect)
            (value as NSString).draw(in: rect, withAttributes: attributes)
            context.cgContext.restoreGState()
            return Self.textHeight(value, font: font, width: rect.width, lineSpacing: lineSpacing)
        }

        private static let margin = RaceBookPDFRenderer.pageMargin

        static func textHeight(_ value: String,
                               font: UIFont,
                               width: CGFloat,
                               lineSpacing: CGFloat = 1.5) -> CGFloat {
            guard !value.isEmpty, width > 0 else { return 0 }
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.lineSpacing = lineSpacing
            let rect = (value as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font, .paragraphStyle: paragraph],
                context: nil
            )
            return max(font.lineHeight, ceil(rect.height))
        }
    }

    static func make(athlete: Athlete,
                     results: [RaceResult],
                     notes: [String: RaceNote],
                     options: RaceBookOptions) -> URL? {
        let scoped = RaceBookBuilder.filteredResults(results, options: options)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeFileName(athlete.name))-race-book.pdf")
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "Race Book - \(athlete.name)",
            kCGPDFContextAuthor as String: athlete.name,
            kCGPDFContextCreator as String: "IM Tri Tracker"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)

        do {
            try renderer.writePDF(to: url) { context in
                let document = Document(context: context, size: pageSize)
                if options.onePage {
                    renderOnePage(document,
                                  athlete: athlete,
                                  results: scoped,
                                  options: options)
                } else {
                    renderCover(document, athlete: athlete, results: scoped, options: options)

                    if options.includePersonalBests || options.includePodiumHighlights || options.includeProgression {
                        renderHighlights(document,
                                         athlete: athlete,
                                         results: scoped,
                                         options: options)
                    }

                    if options.includeRaceHistory {
                        renderHistory(document,
                                      results: scoped,
                                      notes: notes,
                                      options: options)
                    }
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private static func renderOnePage(_ document: Document,
                                      athlete: Athlete,
                                      results: [RaceResult],
                                      options: RaceBookOptions) {
        document.beginPage()
        let heroHeight: CGFloat = 164
        document.fill(CGRect(x: 0, y: 0, width: pageSize.width, height: heroHeight), Palette.deep)
        document.fill(CGRect(x: 0, y: 0, width: 12, height: heroHeight), Palette.coral)
        document.text("IM TRI TRACKER  |  ONE-PAGE RACE BOOK",
                      in: CGRect(x: pageMargin, y: 32, width: pageSize.width - pageMargin * 2, height: 14),
                      font: .systemFont(ofSize: 8.5, weight: .bold),
                      color: Palette.coral,
                      tracking: 1)
        document.text(athlete.name,
                      in: CGRect(x: pageMargin, y: 58, width: pageSize.width - pageMargin * 2, height: 42),
                      font: .systemFont(ofSize: 30, weight: .bold),
                      color: .white,
                      lineSpacing: 0)
        if let location = athlete.location, !location.isEmpty {
            document.text(location,
                          in: CGRect(x: pageMargin, y: 108, width: pageSize.width - pageMargin * 2, height: 16),
                          font: .systemFont(ofSize: 10, weight: .regular),
                          color: UIColor.white.withAlphaComponent(0.72))
        }

        let summary = RaceAnalytics.summary(results)
        var y: CGFloat = 184
        if options.includeCareerSummary {
            let statsRect = CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: 82)
            document.card(statsRect, fill: Palette.card, stroke: Palette.card)
            let statWidth = statsRect.width / 4
            let statY = statsRect.minY + 14
            drawStat(document, value: "\(summary.starts)", label: "STARTS", x: statsRect.minX, width: statWidth, y: statY)
            drawStat(document, value: "\(summary.finishes)", label: "FINISHES", x: statsRect.minX + statWidth, width: statWidth, y: statY)
            drawStat(document, value: "\(summary.podiums)", label: "PODIUMS", x: statsRect.minX + statWidth * 2, width: statWidth, y: statY, accent: true)
            drawStat(document,
                     value: "\(Int((summary.finishRate * 100).rounded()))%",
                     label: "FINISH RATE",
                     x: statsRect.minX + statWidth * 3,
                     width: statWidth,
                     y: statY)
            y = statsRect.maxY + 22
        }

        if options.includePersonalBests {
            let bests = RaceAnalytics.availableKinds(results).flatMap {
                RaceBookAnalytics.bests(results, kind: $0).prefix(2)
            }.prefix(4)
            let rows = Array(bests)
            let cardHeight = CGFloat(max(rows.count, 1)) * 24 + 36
            let rect = CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: cardHeight)
            document.card(rect, fill: Palette.paleBlue, stroke: Palette.paleBlue)
            document.text("PERSONAL BESTS",
                          in: CGRect(x: rect.minX + 18, y: rect.minY + 12, width: rect.width - 36, height: 14),
                          font: .systemFont(ofSize: 8, weight: .bold),
                          color: Palette.aqua,
                          tracking: 0.8)
            if rows.isEmpty {
                document.text("No complete splits are available yet.",
                              in: CGRect(x: rect.minX + 18, y: rect.minY + 30, width: rect.width - 36, height: 16),
                              font: .systemFont(ofSize: 9, weight: .regular),
                              color: Palette.secondary)
            } else {
                for (index, best) in rows.enumerated() {
                    let rowY = rect.minY + 32 + CGFloat(index) * 24
                    document.fill(CGRect(x: rect.minX + 18, y: rowY + 4, width: 7, height: 7), color(for: best.discipline))
                    document.text("\(best.discipline.title)  ·  \(singleLine(best.result.raceName, limit: 42))",
                                  in: CGRect(x: rect.minX + 32, y: rowY, width: rect.width - 172, height: 16),
                                  font: .systemFont(ofSize: 8.5, weight: .regular),
                                  color: Palette.secondary)
                    document.text(TimeFormat.hms(best.seconds),
                                  in: CGRect(x: rect.maxX - 128, y: rowY, width: 110, height: 16),
                                  font: .monospacedDigitSystemFont(ofSize: 8.5, weight: .semibold),
                                  color: Palette.deep,
                                  alignment: .right,
                                  lineSpacing: 0)
                }
            }
            y = rect.maxY + 14
        }

        if options.includePodiumHighlights {
            let podiums = results.filter { $0.isComplete && ($0.finishRankGroup ?? .max) <= 3 }.prefix(2)
            let rows = Array(podiums)
            let cardHeight = CGFloat(max(rows.count, 1)) * 24 + 36
            let rect = CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: cardHeight)
            document.card(rect, fill: Palette.paleCoral, stroke: Palette.paleCoral)
            document.text("PODIUM MOMENTS",
                          in: CGRect(x: rect.minX + 18, y: rect.minY + 12, width: rect.width - 36, height: 14),
                          font: .systemFont(ofSize: 8, weight: .bold),
                          color: Palette.coral,
                          tracking: 0.8)
            if rows.isEmpty {
                document.text("No podium finishes recorded yet.",
                              in: CGRect(x: rect.minX + 18, y: rect.minY + 30, width: rect.width - 36, height: 16),
                              font: .systemFont(ofSize: 9, weight: .regular),
                              color: Palette.secondary)
            } else {
                for (index, result) in rows.enumerated() {
                    let rowY = rect.minY + 32 + CGFloat(index) * 24
                    document.text("#\(result.finishRankGroup ?? 0)  \(singleLine(result.raceName, limit: 44))",
                                  in: CGRect(x: rect.minX + 18, y: rowY, width: rect.width - 174, height: 16),
                                  font: .systemFont(ofSize: 8.5, weight: .regular),
                                  color: Palette.secondary)
                    document.text(dateText(result),
                                  in: CGRect(x: rect.maxX - 140, y: rowY, width: 122, height: 16),
                                  font: .systemFont(ofSize: 8, weight: .regular),
                                  color: Palette.muted,
                                  alignment: .right)
                }
            }
            y = rect.maxY + 14
        }

        if options.includeRaceHistory {
            let rows = Array(results.prefix(5))
            let cardHeight = CGFloat(max(rows.count, 1)) * 26 + 36
            let rect = CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: cardHeight)
            document.card(rect, fill: Palette.card)
            document.text("RECENT RACE HISTORY",
                          in: CGRect(x: rect.minX + 18, y: rect.minY + 12, width: rect.width - 36, height: 14),
                          font: .systemFont(ofSize: 8, weight: .bold),
                          color: Palette.coral,
                          tracking: 0.8)
            if rows.isEmpty {
                document.text("No races match these choices.",
                              in: CGRect(x: rect.minX + 18, y: rect.minY + 30, width: rect.width - 36, height: 16),
                              font: .systemFont(ofSize: 9, weight: .regular),
                              color: Palette.muted)
            } else {
                for (index, result) in rows.enumerated() {
                    let rowY = rect.minY + 32 + CGFloat(index) * 26
                    document.text(dateText(result),
                                  in: CGRect(x: rect.minX + 18, y: rowY, width: 76, height: 16),
                                  font: .systemFont(ofSize: 7.5, weight: .bold),
                                  color: Palette.coral)
                    document.text(singleLine(result.raceName, limit: 44),
                                  in: CGRect(x: rect.minX + 100, y: rowY, width: rect.width - 226, height: 16),
                                  font: .systemFont(ofSize: 8.5, weight: .semibold),
                                  color: Palette.ink)
                    let status = result.isComplete
                        ? TimeFormat.hms(result.finish)
                        : (ResumeBuilder.statusLabel(for: result) ?? "Incomplete")
                    document.text(status,
                                  in: CGRect(x: rect.maxX - 110, y: rowY, width: 92, height: 16),
                                  font: .monospacedDigitSystemFont(ofSize: 8, weight: .semibold),
                                  color: result.isComplete ? Palette.deep : Palette.coral,
                                  alignment: .right,
                                  lineSpacing: 0)
                }
            }
            if results.count > rows.count {
                document.text("+\(results.count - rows.count) more races in the full report",
                              in: CGRect(x: rect.minX + 18, y: rect.maxY - 18, width: rect.width - 36, height: 12),
                              font: .systemFont(ofSize: 7.5, weight: .regular),
                              color: Palette.muted,
                              alignment: .right)
            }
        }
        document.endPage()
    }

    private static func renderCover(_ document: Document,
                                   athlete: Athlete,
                                   results: [RaceResult],
                                   options: RaceBookOptions) {
        document.beginPage()
        let heroHeight: CGFloat = 286
        document.fill(CGRect(x: 0, y: 0, width: pageSize.width, height: heroHeight), Palette.deep)
        document.fill(CGRect(x: 0, y: 0, width: 12, height: heroHeight), Palette.coral)
        document.fill(CGRect(x: 462, y: -34, width: 210, height: 210), Palette.deepLift)
        document.context.cgContext.setAlpha(0.7)
        document.context.cgContext.fillEllipse(in: CGRect(x: 492, y: 24, width: 110, height: 110))
        document.context.cgContext.setAlpha(1)

        document.text("IM TRI TRACKER  |  RACE BOOK",
                      in: CGRect(x: pageMargin, y: 42, width: 400, height: 16),
                      font: .systemFont(ofSize: 9, weight: .bold),
                      color: Palette.coral,
                      tracking: 1.2)
        document.text("A career in motion",
                      in: CGRect(x: pageMargin, y: 70, width: 430, height: 24),
                      font: .systemFont(ofSize: 15, weight: .semibold),
                      color: UIColor.white.withAlphaComponent(0.75))

        let nameFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        let nameHeight = Document.textHeight(athlete.name,
                                             font: nameFont,
                                             width: 410,
                                             lineSpacing: 0)
        document.text(athlete.name,
                      in: CGRect(x: pageMargin, y: 108, width: 410, height: nameHeight),
                      font: nameFont,
                      color: .white,
                      lineSpacing: 0)
        if let location = athlete.location, !location.isEmpty {
            document.text(location,
                          in: CGRect(x: pageMargin, y: 108 + nameHeight + 12, width: 390, height: 18),
                          font: .systemFont(ofSize: 11, weight: .regular),
                          color: UIColor.white.withAlphaComponent(0.72))
        }
        if let years = RaceAnalytics.summary(results).years {
            document.text("RACING \(years.lowerBound) TO \(years.upperBound)",
                          in: CGRect(x: pageMargin, y: 226, width: 300, height: 16),
                          font: .systemFont(ofSize: 8.5, weight: .bold),
                          color: UIColor.white.withAlphaComponent(0.66),
                          tracking: 1)
        }
        document.text("01",
                      in: CGRect(x: pageSize.width - pageMargin - 80, y: 220, width: 80, height: 40),
                      font: .monospacedDigitSystemFont(ofSize: 30, weight: .bold),
                      color: UIColor.white.withAlphaComponent(0.2),
                      alignment: .right)

        let summary = RaceAnalytics.summary(results)
        if options.includeCareerSummary {
            let statsRect = CGRect(x: pageMargin, y: 244, width: pageSize.width - pageMargin * 2, height: 116)
            document.card(statsRect, fill: Palette.card, stroke: Palette.card)
            let statWidth = statsRect.width / 4
            drawStat(document, value: "\(summary.starts)", label: "STARTS", x: statsRect.minX, width: statWidth, y: 267)
            drawStat(document, value: "\(summary.finishes)", label: "FINISHES", x: statsRect.minX + statWidth, width: statWidth, y: 267)
            drawStat(document, value: "\(summary.podiums)", label: "PODIUMS", x: statsRect.minX + statWidth * 2, width: statWidth, y: 267, accent: true)
            drawStat(document,
                     value: "\(Int((summary.finishRate * 100).rounded()))%",
                     label: "FINISH RATE",
                     x: statsRect.minX + statWidth * 3,
                     width: statWidth,
                     y: 267)
        }

        var y: CGFloat = 398
        document.text("THE DISTANCE STORY",
                      in: CGRect(x: pageMargin, y: y, width: 300, height: 16),
                      font: .systemFont(ofSize: 9, weight: .bold),
                      color: Palette.coral,
                      tracking: 1)
        y += 28
        let total = max(summary.fullDistance + summary.halfDistance, 1)
        let fullWidth = (pageSize.width - pageMargin * 2) * CGFloat(summary.fullDistance) / CGFloat(total)
        let track = CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: 14)
        document.card(track, fill: Palette.line, stroke: Palette.line, radius: 7)
        if summary.fullDistance > 0 {
            document.fill(CGRect(x: track.minX,
                                 y: track.minY,
                                 width: max(14, fullWidth),
                                 height: track.height), Palette.deep)
        }
        if summary.halfDistance > 0 {
            document.fill(CGRect(x: track.minX + fullWidth,
                                 y: track.minY,
                                 width: max(14, track.width - fullWidth),
                                 height: track.height), Palette.aqua)
        }
        drawDistanceLabel(document,
                          title: "FULL DISTANCE",
                          value: "\(summary.fullDistance)",
                          color: Palette.deep,
                          x: pageMargin,
                          y: y + 34)
        drawDistanceLabel(document,
                          title: "HALF DISTANCE",
                          value: "\(summary.halfDistance)",
                          color: Palette.aqua,
                          x: pageSize.width / 2 + 8,
                          y: y + 34)

        if let latest = results.first(where: \.isComplete) {
            let milestoneY: CGFloat = 560
            document.text("LATEST MILESTONE",
                          in: CGRect(x: pageMargin, y: milestoneY, width: 300, height: 16),
                          font: .systemFont(ofSize: 9, weight: .bold),
                          color: Palette.coral,
                          tracking: 1)
            let cardRect = CGRect(x: pageMargin, y: milestoneY + 26, width: pageSize.width - pageMargin * 2, height: 100)
            document.card(cardRect, fill: Palette.paleCoral, stroke: Palette.paleCoral)
            document.text(dateText(latest).uppercased(),
                          in: CGRect(x: cardRect.minX + 18, y: cardRect.minY + 16, width: 260, height: 14),
                          font: .systemFont(ofSize: 8, weight: .bold),
                          color: Palette.coral,
                          tracking: 0.7)
            let latestNameFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
            document.text(latest.raceName,
                          in: CGRect(x: cardRect.minX + 18, y: cardRect.minY + 36, width: 330, height: 36),
                          font: latestNameFont,
                          color: Palette.ink)
            document.text(TimeFormat.hms(latest.finish),
                          in: CGRect(x: cardRect.maxX - 165, y: cardRect.minY + 30, width: 145, height: 24),
                          font: .monospacedDigitSystemFont(ofSize: 19, weight: .bold),
                          color: Palette.deep,
                          alignment: .right,
                          lineSpacing: 0)
            document.text(latest.kind.longTitle.uppercased(),
                          in: CGRect(x: cardRect.maxX - 165, y: cardRect.minY + 60, width: 145, height: 14),
                          font: .systemFont(ofSize: 8, weight: .semibold),
                          color: Palette.secondary,
                          alignment: .right,
                          tracking: 0.5)
        }
        document.endPage()
    }

    private static func renderHighlights(_ document: Document,
                                         athlete: Athlete,
                                         results: [RaceResult],
                                         options: RaceBookOptions) {
        var y = document.beginContentPage(kicker: "THE NUMBERS", title: "The work behind the finish")
        let kinds = RaceAnalytics.availableKinds(results)

        if options.includePersonalBests {
            for kind in kinds {
                let bests = RaceBookAnalytics.bests(results, kind: kind)
                let height: CGFloat = 164
                ensureSpace(document, y: &y, height: height, title: "The work behind the finish")
                drawBestCard(document, bests: bests, kind: kind, y: y, height: height)
                y += height + 14
            }
        }

        if options.includePodiumHighlights {
            let podiums = results.filter { $0.isComplete && ($0.finishRankGroup ?? .max) <= 3 }
            ensureSpace(document, y: &y, height: 64, title: "The work behind the finish")
            document.text("PODIUM MOMENTS",
                          in: CGRect(x: pageMargin, y: y, width: 300, height: 16),
                          font: .systemFont(ofSize: 9, weight: .bold),
                          color: Palette.coral,
                          tracking: 1)
            y += 24
            if podiums.isEmpty {
                document.text("No podium finishes recorded yet.",
                              in: CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: 20),
                              font: .systemFont(ofSize: 10, weight: .regular),
                              color: Palette.muted)
                y += 32
            } else {
                for result in podiums {
                    let height: CGFloat = 48
                    ensureSpace(document, y: &y, height: height, title: "The work behind the finish")
                    drawPodiumRow(document, result: result, y: y)
                    y += height
                }
            }
        }

        if options.includeProgression {
            let progressionKinds = kinds.filter { kind in
                RaceBookAnalytics.progression(results, discipline: .finish, kind: kind).count >= 2
            }
            if !progressionKinds.isEmpty {
                ensureSpace(document, y: &y, height: 190, title: "The work behind the finish")
                document.text("PROGRESSION",
                              in: CGRect(x: pageMargin, y: y, width: 300, height: 16),
                              font: .systemFont(ofSize: 9, weight: .bold),
                              color: Palette.coral,
                              tracking: 1)
                y += 24
                for kind in progressionKinds {
                    let points = RaceBookAnalytics.progression(results, discipline: .finish, kind: kind)
                    ensureSpace(document, y: &y, height: 136, title: "The work behind the finish")
                    drawProgression(document, points: points, kind: kind, y: y)
                    y += 150
                }
            }
        }
        document.endPage()
    }

    private static func renderHistory(_ document: Document,
                                      results: [RaceResult],
                                      notes: [String: RaceNote],
                                      options: RaceBookOptions) {
        var y = document.beginContentPage(kicker: "THE ARCHIVE", title: "Race history")
        guard !results.isEmpty else {
            document.text("No races match these choices.",
                          in: CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: 24),
                          font: .systemFont(ofSize: 11, weight: .regular),
                          color: Palette.muted)
            document.endPage()
            return
        }

        let groupedKinds = [RaceKind.fullDistance, .halfDistance]
        for kind in groupedKinds {
            let kindResults = results.filter { $0.kind == kind }
            guard !kindResults.isEmpty else { continue }

            let headingHeight: CGFloat = 38
            ensureSpace(document, y: &y, height: headingHeight, title: "Race history")
            if y > 120 { y += 8 }
            document.text(kind.longTitle.uppercased(),
                          in: CGRect(x: pageMargin, y: y, width: 260, height: 16),
                          font: .systemFont(ofSize: 9, weight: .bold),
                          color: Palette.coral,
                          tracking: 1)
            y += 24

            for result in kindResults {
                let note = notes[result.id]
                let height = historyCardHeight(result: result, note: note, options: options)
                ensureSpace(document, y: &y, height: height, title: "Race history")
                drawHistoryCard(document, result: result, note: note, options: options, y: y, height: height)
                y += height + 12
            }
        }
        document.endPage()
    }

    private static func drawStat(_ document: Document,
                                 value: String,
                                 label: String,
                                 x: CGFloat,
                                 width: CGFloat,
                                 y: CGFloat,
                                 accent: Bool = false) {
        document.text(value,
                      in: CGRect(x: x, y: y, width: width, height: 30),
                      font: .monospacedDigitSystemFont(ofSize: 23, weight: .bold),
                      color: accent ? Palette.coral : Palette.deep,
                      alignment: .center,
                      lineSpacing: 0)
        document.text(label,
                      in: CGRect(x: x + 4, y: y + 38, width: width - 8, height: 16),
                      font: .systemFont(ofSize: 7.5, weight: .bold),
                      color: Palette.muted,
                      alignment: .center,
                      tracking: 0.6)
    }

    private static func drawDistanceLabel(_ document: Document,
                                          title: String,
                                          value: String,
                                          color: UIColor,
                                          x: CGFloat,
                                          y: CGFloat) {
        document.fill(CGRect(x: x, y: y + 3, width: 8, height: 8), color)
        document.text(value,
                      in: CGRect(x: x + 16, y: y - 2, width: 38, height: 24),
                      font: .monospacedDigitSystemFont(ofSize: 18, weight: .bold),
                      color: Palette.ink,
                      lineSpacing: 0)
        document.text(title,
                      in: CGRect(x: x + 58, y: y + 2, width: 150, height: 16),
                      font: .systemFont(ofSize: 8, weight: .bold),
                      color: Palette.muted,
                      tracking: 0.5)
    }

    private static func drawBestCard(_ document: Document,
                                     bests: [PersonalBest],
                                     kind: RaceKind,
                                     y: CGFloat,
                                     height: CGFloat) {
        let rect = CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: height)
        document.card(rect, fill: Palette.card)
        document.text(kind.longTitle.uppercased(),
                      in: CGRect(x: rect.minX + 18, y: rect.minY + 16, width: 180, height: 16),
                      font: .systemFont(ofSize: 8.5, weight: .bold),
                      color: Palette.coral,
                      tracking: 0.8)
        document.text("PERSONAL BESTS",
                      in: CGRect(x: rect.maxX - 180, y: rect.minY + 16, width: 162, height: 16),
                      font: .systemFont(ofSize: 8, weight: .semibold),
                      color: Palette.muted,
                      alignment: .right,
                      tracking: 0.4)
        guard !bests.isEmpty else {
            document.text("No complete splits are available at this distance yet.",
                          in: CGRect(x: rect.minX + 18, y: rect.minY + 56, width: rect.width - 36, height: 24),
                          font: .systemFont(ofSize: 10, weight: .regular),
                          color: Palette.muted)
            return
        }

        let positions: [(CGFloat, CGFloat)] = [
            (rect.minX + 18, rect.minY + 48),
            (rect.minX + 190, rect.minY + 48),
            (rect.minX + 362, rect.minY + 48),
            (rect.minX + 18, rect.minY + 98),
            (rect.minX + 190, rect.minY + 98)
        ]
        for (index, position) in positions.enumerated() {
            let discipline: Discipline = [.finish, .swim, .bike, .run, .transitions][index]
            let best = bests.first { $0.discipline == discipline }
            drawMetric(document,
                       title: discipline.title.uppercased(),
                       value: best.map { TimeFormat.hms($0.seconds) } ?? "-",
                       source: best?.result.raceName ?? "No recorded split",
                       color: color(for: discipline),
                       x: position.0,
                       y: position.1)
        }
    }

    private static func drawMetric(_ document: Document,
                                   title: String,
                                   value: String,
                                   source: String,
                                   color: UIColor,
                                   x: CGFloat,
                                   y: CGFloat) {
        document.fill(CGRect(x: x, y: y + 3, width: 7, height: 7), color)
        document.text(title,
                      in: CGRect(x: x + 13, y: y, width: 140, height: 12),
                      font: .systemFont(ofSize: 7.5, weight: .bold),
                      color: Palette.muted,
                      tracking: 0.4)
        document.text(value,
                      in: CGRect(x: x, y: y + 14, width: 150, height: 20),
                      font: .monospacedDigitSystemFont(ofSize: 15, weight: .bold),
                      color: Palette.ink,
                      lineSpacing: 0)
        document.text(source,
                      in: CGRect(x: x, y: y + 36, width: 150, height: 18),
                      font: .systemFont(ofSize: 7.5, weight: .regular),
                      color: Palette.secondary,
                      lineSpacing: 0.5)
    }

    private static func drawPodiumRow(_ document: Document, result: RaceResult, y: CGFloat) {
        let place = result.finishRankGroup ?? 0
        document.fill(CGRect(x: pageMargin, y: y + 8, width: 28, height: 28), Palette.coral)
        document.text("#\(place)",
                      in: CGRect(x: pageMargin, y: y + 14, width: 28, height: 16),
                      font: .monospacedDigitSystemFont(ofSize: 9, weight: .bold),
                      color: .white,
                      alignment: .center,
                      lineSpacing: 0)
        document.text(result.raceName,
                      in: CGRect(x: pageMargin + 42, y: y + 7, width: 300, height: 18),
                      font: .systemFont(ofSize: 10.5, weight: .semibold),
                      color: Palette.ink)
        document.text("\(dateText(result))  |  \(result.ageGroup ?? "Division")",
                      in: CGRect(x: pageMargin + 42, y: y + 27, width: 300, height: 14),
                      font: .systemFont(ofSize: 8, weight: .regular),
                      color: Palette.muted)
        document.text(TimeFormat.hms(result.finish),
                      in: CGRect(x: pageSize.width - pageMargin - 150, y: y + 11, width: 150, height: 20),
                      font: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
                      color: Palette.deep,
                      alignment: .right,
                      lineSpacing: 0)
    }

    private static func drawProgression(_ document: Document,
                                        points: [RaceBookProgressionPoint],
                                        kind: RaceKind,
                                        y: CGFloat) {
        let rect = CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: 126)
        document.card(rect, fill: Palette.paleBlue, stroke: Palette.paleBlue)
        document.text(kind.longTitle.uppercased(),
                      in: CGRect(x: rect.minX + 18, y: rect.minY + 14, width: 180, height: 14),
                      font: .systemFont(ofSize: 8, weight: .bold),
                      color: Palette.aqua,
                      tracking: 0.7)
        let chart = CGRect(x: rect.minX + 22, y: rect.minY + 42, width: rect.width - 44, height: 54)
        let values = points.map(\.seconds)
        guard let minValue = values.min(), let maxValue = values.max() else { return }
        for step in 0...2 {
            let gridY = chart.minY + CGFloat(step) * chart.height / 2
            document.line(from: CGPoint(x: chart.minX, y: gridY),
                          to: CGPoint(x: chart.maxX, y: gridY),
                          color: Palette.line.withAlphaComponent(0.7),
                          width: 0.6)
        }
        let spread = max(maxValue - minValue, 1)
        let pointsOnChart = points.enumerated().map { index, point in
            let x = chart.minX + chart.width * CGFloat(index) / CGFloat(max(points.count - 1, 1))
            let normalized = CGFloat(point.seconds - minValue) / CGFloat(spread)
            return CGPoint(x: x, y: chart.maxY - normalized * chart.height)
        }
        if pointsOnChart.count > 1 {
            document.context.cgContext.setStrokeColor(Palette.aqua.cgColor)
            document.context.cgContext.setLineWidth(2)
            document.context.cgContext.move(to: pointsOnChart[0])
            for point in pointsOnChart.dropFirst() { document.context.cgContext.addLine(to: point) }
            document.context.cgContext.strokePath()
        }
        for point in pointsOnChart {
            document.context.cgContext.setFillColor(Palette.coral.cgColor)
            document.context.cgContext.fillEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
        }
        if let first = points.first, let latest = points.last {
            document.text("FIRST  \(TimeFormat.hms(first.seconds))",
                          in: CGRect(x: chart.minX, y: rect.maxY - 22, width: 180, height: 14),
                          font: .monospacedDigitSystemFont(ofSize: 7.5, weight: .semibold),
                          color: Palette.secondary)
            document.text("LATEST  \(TimeFormat.hms(latest.seconds))",
                          in: CGRect(x: chart.maxX - 180, y: rect.maxY - 22, width: 180, height: 14),
                          font: .monospacedDigitSystemFont(ofSize: 7.5, weight: .semibold),
                          color: Palette.secondary,
                          alignment: .right)
        }
    }

    private static func historyCardHeight(result: RaceResult,
                                          note: RaceNote?,
                                          options: RaceBookOptions) -> CGFloat {
        let nameFont = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        let nameWidth = pageSize.width - pageMargin * 2 - 200
        let nameHeight = max(18, Document.textHeight(result.raceName, font: nameFont, width: nameWidth, lineSpacing: 1))
        var height: CGFloat = 20 + nameHeight + 14
        if result.isComplete, options.includeSplits {
            height += 32
        }
        if options.includeRaceNotes, let note, let noteText = noteText(note), !noteText.isEmpty {
            height += 16 + Document.textHeight(noteText,
                                               font: .systemFont(ofSize: 8.5),
                                               width: pageSize.width - pageMargin * 2 - 52,
                                               lineSpacing: 1.5) + 8
        }
        return max(86, height + 30)
    }

    private static func drawHistoryCard(_ document: Document,
                                        result: RaceResult,
                                        note: RaceNote?,
                                        options: RaceBookOptions,
                                        y: CGFloat,
                                        height: CGFloat) {
        let rect = CGRect(x: pageMargin, y: y, width: pageSize.width - pageMargin * 2, height: height)
        document.card(rect, fill: Palette.card)
        document.text(dateText(result).uppercased(),
                      in: CGRect(x: rect.minX + 18, y: rect.minY + 14, width: 180, height: 14),
                      font: .systemFont(ofSize: 7.5, weight: .bold),
                      color: Palette.coral,
                      tracking: 0.6)
        document.text(result.kind.title.uppercased(),
                      in: CGRect(x: rect.maxX - 100, y: rect.minY + 14, width: 82, height: 14),
                      font: .systemFont(ofSize: 7.5, weight: .bold),
                      color: Palette.muted,
                      alignment: .right,
                      tracking: 0.5)

        let nameFont = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        let nameWidth = rect.width - 200
        let nameHeight = max(18, Document.textHeight(result.raceName, font: nameFont, width: nameWidth, lineSpacing: 1))
        document.text(result.raceName,
                      in: CGRect(x: rect.minX + 18, y: rect.minY + 34, width: nameWidth, height: nameHeight),
                      font: nameFont,
                      color: Palette.ink,
                      lineSpacing: 1)
        let status = result.isComplete
            ? TimeFormat.hms(result.finish)
            : (ResumeBuilder.statusLabel(for: result) ?? "Incomplete")
        document.text(status,
                      in: CGRect(x: rect.maxX - 170, y: rect.minY + 34, width: 152, height: 22),
                      font: .monospacedDigitSystemFont(ofSize: 15, weight: .bold),
                      color: result.isComplete ? Palette.deep : Palette.coral,
                      alignment: .right,
                      lineSpacing: 0)

        var currentY = max(rect.minY + 34 + nameHeight, rect.minY + 58) + 8
        var placement: [String] = []
        if let bib = result.bib { placement.append("Bib \(bib)") }
        if options.includePlacements {
            if let group = result.ageGroup, let place = result.finishRankGroup {
                placement.append("\(group) #\(place)")
            } else if let place = result.finishRankGroup {
                placement.append("Division #\(place)")
            }
            if let overall = result.finishRankOverall { placement.append("\(overall) overall") }
        }
        if !placement.isEmpty {
            document.text(placement.joined(separator: "  |  "),
                          in: CGRect(x: rect.minX + 18, y: currentY, width: rect.width - 36, height: 14),
                          font: .systemFont(ofSize: 8, weight: .regular),
                          color: Palette.muted)
            currentY += 18
        }

        if result.isComplete, options.includeSplits {
            drawSplitBar(document, result: result, x: rect.minX + 18, y: currentY, width: rect.width - 36)
            currentY += 25
        }

        if options.includeRaceNotes, let note, let noteText = noteText(note), !noteText.isEmpty {
            document.fill(CGRect(x: rect.minX + 18, y: currentY + 1, width: 3, height: max(14, Document.textHeight(noteText, font: .systemFont(ofSize: 8.5), width: rect.width - 52))), Palette.coral)
            document.text(noteText,
                          in: CGRect(x: rect.minX + 30, y: currentY, width: rect.width - 52, height: rect.maxY - currentY - 10),
                          font: .systemFont(ofSize: 8.5),
                          color: Palette.secondary,
                          lineSpacing: 1.5)
        }
    }

    private static func drawSplitBar(_ document: Document,
                                     result: RaceResult,
                                     x: CGFloat,
                                     y: CGFloat,
                                     width: CGFloat) {
        let track = CGRect(x: x, y: y, width: width, height: 8)
        document.card(track, fill: Palette.line, stroke: Palette.line, radius: 4)
        let shares = RaceAnalytics.legShares(result)
        guard !shares.isEmpty else { return }
        var currentX = x
        for share in shares {
            let segmentWidth = max(2, width * share.share)
            document.fill(CGRect(x: currentX, y: y, width: segmentWidth, height: 8), color(for: share.discipline))
            currentX += segmentWidth
        }
        let labels = shares.map { "\($0.discipline.shortTitle) \(TimeFormat.hms($0.seconds))" }.joined(separator: "  |  ")
        document.text(labels,
                      in: CGRect(x: x, y: y + 12, width: width, height: 14),
                      font: .monospacedDigitSystemFont(ofSize: 6.8, weight: .regular),
                      color: Palette.muted,
                      lineSpacing: 0)
    }

    private static func ensureSpace(_ document: Document,
                                    y: inout CGFloat,
                                    height: CGFloat,
                                    title: String) {
        guard y + height <= document.contentBottom else {
            document.endPage()
            y = document.beginContentPage(kicker: "CONTINUED", title: title)
            return
        }
    }

    private static func noteText(_ note: RaceNote) -> String? {
        let fields: [(String, String)] = [
            ("Conditions", note.conditions),
            ("Nutrition", note.nutrition),
            ("Gear", note.gear),
            ("Notes", note.notes)
        ]
        let values = fields.compactMap { label, value -> String? in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : "\(label): \(trimmed)"
        }
        return values.isEmpty ? nil : values.joined(separator: "  |  ")
    }

    private static func dateText(_ result: RaceResult) -> String {
        result.eventDate.map(RaceDate.medium) ?? (result.year > 0 ? String(result.year) : "Undated")
    }

    private static func singleLine(_ value: String, limit: Int) -> String {
        let normalized = value.replacingOccurrences(of: "\\n", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard normalized.count > limit else { return normalized }
        let end = normalized.index(normalized.startIndex, offsetBy: max(limit - 1, 1))
        return String(normalized[..<end]) + "…"
    }

    private static func color(for discipline: Discipline) -> UIColor {
        switch discipline {
        case .swim: return Palette.aqua
        case .bike: return Palette.green
        case .run: return Palette.coral
        case .t1, .t2, .transitions: return Palette.muted
        case .finish: return Palette.deep
        }
    }

    private static func safeFileName(_ name: String) -> String {
        let safe = name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return safe.isEmpty ? "iron-splits" : safe
    }
}
