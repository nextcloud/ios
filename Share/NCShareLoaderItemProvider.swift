// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import UniformTypeIdentifiers

/// Imports one representation per attachment, in source order. File copies are
/// completed inside provider callbacks, before iOS releases its temporary URLs.
@MainActor
final class NCShareLoaderItemProvider {
    struct Output: Sendable {
        var fileNames: [String] = []
        var failures: [String] = []
    }

    private enum LoadedURL: Sendable {
        case file(String)
        case remote(URL)
    }

    /// NSItemProvider does not guarantee a completion callback after cancellation.
    /// This gate resumes exactly once and synchronizes only callback state.
    private final class Pending<Value: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Value, Error>?
        private var cancellation: (@Sendable () -> Void)?
        private var finished = false
        private var cancelled = false

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        func install(_ continuation: CheckedContinuation<Value, Error>) -> Bool {
            lock.lock()
            let cancelled = cancelled
            if !cancelled { self.continuation = continuation }
            lock.unlock()
            if cancelled { continuation.resume(throwing: CancellationError()) }
            return !cancelled
        }

        func setCancellation(_ cancellation: @escaping @Sendable () -> Void) {
            lock.lock()
            let cancelled = cancelled
            if !finished { self.cancellation = cancellation }
            lock.unlock()
            if cancelled { cancellation() }
        }

        func finish(_ result: Result<Value, Error>) {
            lock.lock()
            guard !finished else { lock.unlock(); return }
            finished = true
            let continuation = continuation
            self.continuation = nil
            cancellation = nil
            lock.unlock()
            continuation?.resume(with: result)
        }

        func cancel() {
            lock.lock()
            guard !finished else { lock.unlock(); return }
            finished = true
            cancelled = true
            let continuation = continuation
            let cancellation = cancellation
            self.continuation = nil
            self.cancellation = nil
            lock.unlock()
            cancellation?()
            continuation?.resume(throwing: CancellationError())
        }
    }

    private static func request<Value: Sendable>(_ start: (Pending<Value>) -> (@Sendable () -> Void)) async throws -> Value {
        let pending = Pending<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard pending.install(continuation) else { return }
                pending.setCancellation(start(pending))
            }
        } onCancel: {
            pending.cancel()
        }
    }

    static func load(items: [NSExtensionItem], directory: URL) async throws -> Output {
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            var output = Output()
            // Sequential imports bound peak memory use and preserve attachment order.
            for (index, provider) in items.flatMap({ $0.attachments ?? [] }).enumerated() {
                try Task.checkCancellation()
                do {
                    let name = try await load(provider: provider, index: index, directory: directory)
                    output.fileNames.append(name)
                } catch {
                    let format = NSLocalizedString("_share_import_item_error_", comment: "")
                    output.failures.append(String(format: format, index + 1, error.localizedDescription))
                }
                try Task.checkCancellation()
            }
            return output
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private static func load(provider: NSItemProvider, index: Int, directory: URL) async throws -> String {
        let suggestedName = provider.suggestedName
        let fallbackName = "Shared item \(index + 1)"
        var lastError: Error = CocoaError(.featureUnsupported)

        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           provider.canLoadObject(ofClass: NSURL.self) {
            // A file URL is a reference to a file, not data to save as a .file-url.
            do {
                return try await loadLink(provider: provider, name: suggestedName, fallbackName: fallbackName, directory: directory)
            } catch {
                lastError = error
            }
            try Task.checkCancellation()
        }

        let types = provider.registeredTypeIdentifiers.compactMap { UTType($0) }.filter {
            $0.conforms(to: .data) && !$0.conforms(to: .url) && !$0.conforms(to: .plainText)
        }
        for type in types {
            try Task.checkCancellation()
            do {
                return try await loadFile(provider: provider, type: type, name: suggestedName, fallbackName: fallbackName, directory: directory)
            } catch {
                lastError = error
            }
            try Task.checkCancellation()
            do {
                return try await loadData(provider: provider, type: type, name: suggestedName, fallbackName: fallbackName, directory: directory)
            } catch {
                lastError = error
            }
        }

        if provider.canLoadObject(ofClass: UIImage.self) {
            return try await loadImage(provider: provider, name: suggestedName, fallbackName: fallbackName, directory: directory)
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           provider.canLoadObject(ofClass: NSURL.self) {
            return try await loadLink(provider: provider, name: suggestedName, fallbackName: fallbackName, directory: directory)
        }
        if provider.canLoadObject(ofClass: NSString.self) {
            return try await loadText(provider: provider, name: suggestedName, fallbackName: fallbackName, directory: directory)
        }
        throw lastError
    }

    private static func loadFile(provider: NSItemProvider, type: UTType, name: String?, fallbackName: String, directory: URL) async throws -> String {
        try await request { pending in
            let progress = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                guard !pending.isCancelled else { return }
                do {
                    if let error { throw error }
                    guard let url else { throw CocoaError(.fileReadUnknown) }
                    let result = try copy(source: url, name: name, fallbackName: fallbackName, type: type, directory: directory)
                    pending.finish(.success(result))
                } catch {
                    pending.finish(.failure(error))
                }
            }
            return { progress.cancel() }
        }
    }

    private static func loadData(provider: NSItemProvider, type: UTType, name: String?, fallbackName: String, directory: URL) async throws -> String {
        try await request { pending in
            let progress = provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, error in
                guard !pending.isCancelled else { return }
                do {
                    if let error { throw error }
                    guard let data else { throw CocoaError(.fileReadUnknown) }
                    let destination = destination(name: name ?? fallbackName, type: type, directory: directory)
                    try data.write(to: destination, options: .atomic)
                    pending.finish(.success(destination.lastPathComponent))
                } catch {
                    pending.finish(.failure(error))
                }
            }
            return { progress.cancel() }
        }
    }

    private static func loadImage(provider: NSItemProvider, name: String?, fallbackName: String, directory: URL) async throws -> String {
        try await request { pending in
            let progress = provider.loadObject(ofClass: UIImage.self) { object, error in
                guard !pending.isCancelled else { return }
                do {
                    if let error { throw error }
                    guard let image = object as? UIImage,
                          let data = autoreleasepool(invoking: { image.pngData() }) else { throw CocoaError(.fileReadCorruptFile) }
                    let destination = destination(name: name ?? fallbackName, type: .png, directory: directory)
                    try data.write(to: destination, options: .atomic)
                    pending.finish(.success(destination.lastPathComponent))
                } catch {
                    pending.finish(.failure(error))
                }
            }
            return { progress.cancel() }
        }
    }

    private static func loadText(provider: NSItemProvider, name: String?, fallbackName: String, directory: URL) async throws -> String {
        try await request { pending in
            let progress = provider.loadObject(ofClass: NSString.self) { object, error in
                guard !pending.isCancelled else { return }
                do {
                    if let error { throw error }
                    guard let text = object as? String else { throw CocoaError(.fileReadCorruptFile) }
                    let destination = destination(name: name ?? fallbackName, type: .utf8PlainText, directory: directory)
                    try Data(text.utf8).write(to: destination, options: .atomic)
                    pending.finish(.success(destination.lastPathComponent))
                } catch {
                    pending.finish(.failure(error))
                }
            }
            return { progress.cancel() }
        }
    }

    private static func loadLink(provider: NSItemProvider, name: String?, fallbackName: String, directory: URL) async throws -> String {
        let content: LoadedURL = try await request { pending in
            let progress = provider.loadObject(ofClass: NSURL.self) { object, error in
                guard !pending.isCancelled else { return }
                do {
                    if let error { throw error }
                    guard let url = object as? URL else { throw URLError(.badURL) }
                    if url.isFileURL {
                        // Even a provider advertising only public.url may return
                        // a file reference. Copy it before this callback returns.
                        let name = try copyReferencedFile(source: url, name: name, fallbackName: fallbackName, directory: directory)
                        pending.finish(.success(.file(name)))
                    } else {
                        pending.finish(.success(.remote(url)))
                    }
                } catch {
                    pending.finish(.failure(error))
                }
            }
            return { progress.cancel() }
        }
        switch content {
        case .file(let name):
            return name
        case .remote(let url):
            guard ["https", "http"].contains(url.scheme?.lowercased() ?? "") else {
                throw URLError(.unsupportedURL)
            }
            // Preserve the previous behavior: a shared web link uploads the
            // downloaded resource. URLSession streams it to disk, not Data.
            try Task.checkCancellation()
            return try await download(url: url, name: name, fallbackName: fallbackName, directory: directory)
        }
    }

    private static func download(url: URL, name: String?, fallbackName: String, directory: URL) async throws -> String {
        try await request { pending in
            let task = URLSession.shared.downloadTask(with: url) { temporaryURL, response, error in
                guard !pending.isCancelled else { return }
                do {
                    if let error { throw error }
                    guard let response = response as? HTTPURLResponse,
                          (200..<300).contains(response.statusCode),
                          let temporaryURL else { throw URLError(.badServerResponse) }
                    let type = response.mimeType.flatMap { UTType(mimeType: $0) }
                    let destination = destination(name: name ?? response.suggestedFilename ?? fallbackName, type: type, directory: directory)
                    try FileManager.default.copyItem(at: temporaryURL, to: destination)
                    pending.finish(.success(destination.lastPathComponent))
                } catch {
                    pending.finish(.failure(error))
                }
            }
            task.resume()
            return { task.cancel() }
        }
    }

    nonisolated private static func copyReferencedFile(source: URL, name: String?, fallbackName: String, directory: URL) throws -> String {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<String, Error>?
        // Coordinate references to external documents, including File Provider
        // files that may need to be materialized before they can be read.
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readableURL in
            result = Result { try copy(source: readableURL, name: name, fallbackName: fallbackName, type: nil, directory: directory) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return try result.get()
    }

    nonisolated private static func copy(source: URL, name: String?, fallbackName: String, type: UTType?, directory: URL) throws -> String {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let values = try source.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile == true else { throw CocoaError(.featureUnsupported) }
        let sourceName = source.lastPathComponent.isEmpty ? fallbackName : source.lastPathComponent
        let sourceType = UTType(filenameExtension: source.pathExtension)
        let contentType: UTType?
        if let sourceType, sourceType.conforms(to: type ?? .data) {
            contentType = sourceType
        } else {
            contentType = type
        }
        let destination = destination(name: name ?? sourceName, type: contentType, directory: directory)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
            return destination.lastPathComponent
        } catch {
            // A failed copy may leave a partial file behind.
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    nonisolated private static func destination(name: String, type: UTType?, directory: URL) -> URL {
        // Suggested names are untrusted paths. Keep only a single filename.
        var name = (name as NSString).lastPathComponent
            .components(separatedBy: .controlCharacters).joined()
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        if name.isEmpty || name == "." || name == ".." { name = "Shared item" }
        if let type, let preferredExtension = type.preferredFilenameExtension {
            let existingExtension = (name as NSString).pathExtension
            if existingExtension.isEmpty {
                name += "." + preferredExtension
            } else if UTType(filenameExtension: existingExtension)?.conforms(to: type) != true {
                name = (name as NSString).deletingPathExtension + "." + preferredExtension
            }
        }
        let ext = (name as NSString).pathExtension
        var stem = ext.isEmpty ? name : (name as NSString).deletingPathExtension
        // Leave room for an extension and collision suffix on common file systems.
        while stem.utf8.count > 180 { stem.removeLast() }
        let suffix = ext.isEmpty ? "" : "." + String(ext.prefix(32))
        var candidate = directory.appendingPathComponent(stem + suffix)
        var counter = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent(stem + " (\(counter))" + suffix)
            counter += 1
        }
        return candidate
    }
}
