import Foundation
import CryptoKit
import os

/// Downloads pointer episodes to disk so they can actually be played.
///
/// The episodes are hosted as GitHub release assets, and a release asset is
/// served as `Content-Type: application/octet-stream` with a
/// `Content-Disposition: attachment`, after a redirect to a signed URL whose
/// path has no file extension on it at all. `AVURLAsset` has two ways to work
/// out what a stream is, the MIME type and the path extension, and that
/// response denies it both, so `VideoPlayer` sat on a spinner and then showed a
/// black rectangle. Nothing was wrong with the files: they are H.264, and the
/// `moov` atom is already at the front for streaming.
///
/// Writing the bytes to a local file called `.mp4` gives AVFoundation the
/// extension it needs. It also makes the second viewing instant and works on a
/// start line with no signal, which is when someone is most likely to want
/// "what do I do about mud in my cleats".
///
/// If the media ever moves to a host that sends `video/mp4`, streaming straight
/// from the URL would work again and this can go. Until then the download is
/// not an optimisation, it is the only thing that plays.
actor PointerMediaCache {
    static let shared = PointerMediaCache()

    enum MediaError: LocalizedError {
        case badResponse(Int)
        case empty

        var errorDescription: String? {
            switch self {
            case .badResponse(let code): return "The episode couldn't be downloaded (\(code))."
            case .empty: return "The episode file came back empty."
            }
        }
    }

    private let logger = Logger(subsystem: "com.jackwallner.ironman", category: "PointerMedia")
    private var inFlight: [String: Task<URL, Error>] = [:]

    private var directory: URL? {
        guard let applicationSupport = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                                     in: .userDomainMask,
                                                                     appropriateFor: nil,
                                                                     create: true) else { return nil }
        let directory = applicationSupport.appendingPathComponent("PointerMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func localURL(for pointer: Pointer) -> URL? {
        // Keyed on the pointer id, not on the remote filename, so re-publishing
        // an episode under a new asset name replaces it rather than orphaning it.
        directory?.appendingPathComponent(Self.cacheFilename(for: pointer.id))
    }

    private static func cacheFilename(for id: String) -> String {
        let digest = SHA256.hash(data: Data(id.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return digest + ".mp4"
    }

    /// A already-downloaded file, if there is one. Cheap enough for a view body.
    func cachedFile(for pointer: Pointer) -> URL? {
        guard let url = localURL(for: pointer),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    /// The local file for an episode, downloading it if this is the first time.
    ///
    /// Concurrent callers for the same episode share one download; tapping the
    /// row twice does not fetch it twice.
    func file(for pointer: Pointer, progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        if let cached = cachedFile(for: pointer) { return cached }
        if let existing = inFlight[pointer.id] { return try await existing.value }

        guard let remote = pointer.videoURL.flatMap(URL.init(string:)),
              let destination = localURL(for: pointer) else {
            throw MediaError.empty
        }

        let task = Task<URL, Error> {
            // The task inherits this actor's isolation, so the table can be
            // cleared directly on the way out rather than hopping through
            // another Task to get back here.
            defer { self.clearInFlight(pointer.id) }
            // A download task rather than `bytes(from:)`: URLSession streams
            // straight to a file on its own, so a 7MB episode never has to be
            // held in memory or appended a byte at a time.
            let temporary = try await PointerDownloader.download(remote) { fraction in
                progress?(fraction)
            }
            defer { try? FileManager.default.removeItem(at: temporary) }
            let size = (try? FileManager.default.attributesOfItem(atPath: temporary.path))?[.size] as? Int
            guard (size ?? 0) > 0 else { throw MediaError.empty }
            // Move into place last, so a cancelled or failed download can never
            // leave a truncated file that looks cached and plays as garbage.
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: temporary, to: destination)
            progress?(1.0)
            return destination
        }
        inFlight[pointer.id] = task
        return try await task.value
    }

    /// Isolated on the actor so the in-flight table is only ever touched
    /// from one place, whatever context the download task finished on.
    private func clearInFlight(_ id: String) {
        inFlight[id] = nil
    }

    /// Total bytes held on disk, for the Settings row that offers to clear it.
    func cacheSize() -> Int64 {
        guard let directory,
              let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { total, url in
            total + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    func clear() {
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
        guard let directory else { return }
        try? FileManager.default.removeItem(at: directory)
        _ = self.directory
    }
}


/// `URLSessionDownloadTask` wrapped in async/await, with progress.
///
/// `URLSession.download(from:)` already exists and would be shorter, but it
/// reports no progress at all, and these are multi-megabyte files that people
/// will start on cellular. A silent spinner on a 7MB download over a bad
/// connection is indistinguishable from the bug this whole file exists to fix.
private final class PointerDownloader: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void
    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    /// Where the delegate parked the finished file. `didFinishDownloadingTo`
    /// hands over a URL that URLSession deletes the moment it returns, so the
    /// bytes have to be moved somewhere of our own before resuming the caller.
    private var settled = false

    private init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    static func download(_ url: URL,
                         onProgress: @escaping @Sendable (Double) -> Void) async throws -> URL {
        let downloader = PointerDownloader(onProgress: onProgress)
        return try await downloader.run(url)
    }

    private func run(_ url: URL) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let configuration = URLSessionConfiguration.default
                configuration.timeoutIntervalForResource = 180
                configuration.waitsForConnectivity = true
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                session.downloadTask(with: url).resume()
            }
        } onCancel: {
            session?.invalidateAndCancel()
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !settled else { return }
        settled = true
        session?.finishTasksAndInvalidate()
        continuation?.resume(with: result)
        continuation = nil
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300 ~= http.statusCode) {
            finish(.failure(PointerMediaCache.MediaError.badResponse(http.statusCode)))
            return
        }
        let parked = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")
        do {
            try FileManager.default.moveItem(at: location, to: parked)
            finish(.success(parked))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        } else {
            // A success has already resolved in `didFinishDownloadingTo`; this
            // only guards against a completion with neither an error nor a file.
            finish(.failure(PointerMediaCache.MediaError.empty))
        }
    }
}
