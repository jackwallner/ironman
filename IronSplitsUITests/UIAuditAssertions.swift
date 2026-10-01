import UIKit
import XCTest

/// Pixel and frame assertions shared by `ChromeLegibilityUITests` and
/// `DesignAuditUITests`. They turn "does this look right" into numbers a test
/// can fail on.
@MainActor
extension XCTestCase {

    /// Fails when the brightest-contrast detail inside the control (its label or
    /// symbol) is below 4.5:1 against the control's own dominant colour.
    func assertLegible(_ element: XCUIElement, _ name: String,
                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name) must exist", file: file, line: line)
        let shot = element.screenshot()
        let ratio = LegibilityProbe.contrast(of: shot.image)
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = String(format: "%@ %.1f-to-1", name, ratio)
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThanOrEqual(ratio, 4.5,
                                    "\(name) reads at \(String(format: "%.2f", ratio)):1, below 4.5:1",
                                    file: file, line: line)
    }

    /// Every visible static text must sit inside the screen horizontally. A label
    /// that runs past the edge is being clipped by something, usually a scroller
    /// or a fixed-size row that did not fit. Reads one snapshot of the tree,
    /// because querying each element's frame separately took minutes on a long
    /// list.
    func assertNoTextRunsOffScreen(_ app: XCUIApplication, screen: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        guard let root = try? app.snapshot() else {
            XCTFail("\(screen): could not snapshot the UI", file: file, line: line)
            return
        }
        let bounds = root.frame
        var pending: [XCUIElementSnapshot] = [root]
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children)
            guard node.elementType == .staticText else { continue }
            let frame = node.frame
            guard !frame.isEmpty, frame.minY >= bounds.minY, frame.maxY <= bounds.maxY else { continue }
            XCTAssertTrue(frame.minX >= bounds.minX - 0.5 && frame.maxX <= bounds.maxX + 0.5,
                          "\(screen): \"\(node.label)\" runs off screen at \(frame)",
                          file: file, line: line)
        }
    }

    /// Runs `assertLegible` on every button in the visible navigation bar, and
    /// fails any bar button VoiceOver would read as unlabeled. (A toolbar `Menu`
    /// nests an unlabeled button inside its labeled one at the same frame; that
    /// wrapper is not a separate control and is skipped.)
    func assertNavigationBarLegible(_ app: XCUIApplication, screen: String,
                                    file: StaticString = #filePath, line: UInt = #line) {
        // Hittable only: a sheet leaves the bar underneath it in the tree, and
        // a screenshot of a covered button is a screenshot of the sheet.
        let buttons = app.navigationBars.buttons.allElementsBoundByIndex
            .filter { $0.exists && !$0.frame.isEmpty && $0.isHittable }
        let labeledFrames = buttons.filter { !$0.label.isEmpty }.map(\.frame)
        for button in buttons {
            if button.label.isEmpty {
                XCTAssertTrue(labeledFrames.contains(button.frame),
                              "\(screen): unlabeled bar button at \(button.frame)",
                              file: file, line: line)
                continue
            }
            assertLegible(button, "\(screen) bar \"\(button.label)\"", file: file, line: line)
        }
    }
}

/// Pixel maths for `assertLegible`, kept apart so the rule is easy to read.
enum LegibilityProbe {

    /// The contrast ratio between a control's own fill and its label.
    ///
    /// Only the inside of the control is measured: the band that stays clear of
    /// a capsule's rounded ends, or the inner square of a circle. Measuring the
    /// whole frame let the navy bar showing through the corners pass white text
    /// on pale glass at 11:1. Inside that band the dominant colour is the fill,
    /// and the 97th-percentile most contrasting pixel is the label's core; the
    /// percentile, not the maximum, keeps one antialiased pixel from passing an
    /// unreadable control.
    static func contrast(of image: UIImage) -> Double {
        guard let cg = image.cgImage else { return 0 }
        let width = cg.width, height = cg.height
        guard width > 0, height > 0 else { return 0 }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return 0 }

        let insetX = Int(Double(min(width, height)) * 0.3)
        let insetY = Int(Double(height) * 0.2)
        var luminances = [Double]()
        for y in insetY..<max(insetY + 1, height - insetY) {
            for x in insetX..<max(insetX + 1, width - insetX) {
                let index = (y * width + x) * 4
                luminances.append(relativeLuminance(pixels[index], pixels[index + 1], pixels[index + 2]))
            }
        }

        // Dominant colour: the fullest of 64 luminance buckets.
        var buckets = [[Double]](repeating: [], count: 64)
        for value in luminances {
            buckets[min(63, Int(value * 64))].append(value)
        }
        guard let dominant = buckets.max(by: { $0.count < $1.count }), !dominant.isEmpty else { return 0 }
        let background = dominant.reduce(0, +) / Double(dominant.count)

        let ratios = luminances.map { ratio($0, background) }.sorted()
        return ratios[min(ratios.count - 1, Int(Double(ratios.count) * 0.97))]
    }

    private static func ratio(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func relativeLuminance(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Double {
        func channel(_ value: UInt8) -> Double {
            let c = Double(value) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
