// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Nextcloud

// The Share importer source is included directly in this test target because
// an application extension cannot be imported as a framework by the app tests.
@MainActor
@Suite("Share extension input preparation")
struct NCShareLoaderItemProviderTests {
    @Test("Repeated names retain every attachment and its source order")
    func duplicateNames() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let payloads = [Data("first".utf8), Data("second".utf8), Data("third".utf8)]
        let providers = payloads.map { provider(data: $0, type: .pdf, name: "report.pdf") }

        let output = try await load(providers, directory: directory)

        #expect(output.failures.isEmpty)
        #expect(output.fileNames.count == 3)
        #expect(Set(output.fileNames).count == 3)
        let imported = try output.fileNames.map { try Data(contentsOf: directory.appendingPathComponent($0)) }
        #expect(imported == payloads)
    }

    @Test("JPEG bytes and extension are preserved without PNG conversion")
    func originalImageFormat() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let jpeg = Data([0xff, 0xd8, 0xff, 0xd9])

        let output = try await load([provider(data: jpeg, type: .jpeg, name: "photo.jpg")], directory: directory)

        let name = try #require(output.fileNames.first)
        #expect(output.failures.isEmpty)
        #expect(UTType(filenameExtension: (name as NSString).pathExtension) == .jpeg)
        #expect(try Data(contentsOf: directory.appendingPathComponent(name)) == jpeg)
    }

    @Test("A provider with multiple formats imports only its preferred representation")
    func multipleRepresentations() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let item = provider(data: Data("preferred".utf8), type: .png, name: "image.png")
        item.registerDataRepresentation(forTypeIdentifier: UTType.jpeg.identifier, visibility: .all) { completion in
            completion(Data("alternative".utf8), nil)
            return nil
        }

        let output = try await load([item], directory: directory)

        #expect(output.fileNames.count == 1)
        let name = try #require(output.fileNames.first)
        #expect(try Data(contentsOf: directory.appendingPathComponent(name)) == Data("preferred".utf8))
    }

    @Test("Shared text is saved as UTF-8 without altering its content")
    func unicodeText() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let text = "Caffè ☕️\nSeconda riga"
        let item = NSItemProvider(object: text as NSString)

        let output = try await load([item], directory: directory)

        #expect(output.failures.isEmpty)
        let name = try #require(output.fileNames.first)
        #expect((name as NSString).pathExtension == "txt")
        #expect(try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) == text)
    }

    @Test("An empty file is valid input")
    func emptyFile() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let output = try await load([provider(data: Data(), type: .pdf, name: "empty.pdf")], directory: directory)

        let name = try #require(output.fileNames.first)
        #expect(output.failures.isEmpty)
        #expect(try Data(contentsOf: directory.appendingPathComponent(name)).isEmpty)
    }

    @Test("Failures are reported alongside successfully imported attachments")
    func partialFailure() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let broken = NSItemProvider()
        broken.registerDataRepresentation(forTypeIdentifier: UTType.pdf.identifier, visibility: .all) { completion in
            completion(nil, CocoaError(.fileReadNoPermission))
            return nil
        }

        let output = try await load([broken, provider(data: Data("ok".utf8), type: .pdf, name: "ok.pdf")], directory: directory)

        #expect(output.failures.count == 1)
        #expect(output.fileNames.count == 1)
        let name = try #require(output.fileNames.first)
        #expect(try Data(contentsOf: directory.appendingPathComponent(name)) == Data("ok".utf8))
    }

    @Test("Suggested paths cannot escape the request directory or replace unrelated files")
    func pathConfinement() async throws {
        let root = temporaryDirectory()
        let directory = root.appendingPathComponent("request", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("outside.pdf")
        let original = Data("keep me".utf8)
        try original.write(to: outside)

        let output = try await load([provider(data: Data("new".utf8), type: .pdf, name: "../outside.pdf")], directory: directory)

        let name = try #require(output.fileNames.first)
        #expect(!name.contains("/"))
        #expect(directory.appendingPathComponent(name).deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
        #expect(try Data(contentsOf: outside) == original)
    }

    @Test("A file URL is copied while the original remains untouched")
    func fileURL() async throws {
        let root = temporaryDirectory()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.pdf")
        let bytes = Data("original contents".utf8)
        try bytes.write(to: source)
        let directory = root.appendingPathComponent("request", isDirectory: true)
        let item = NSItemProvider(object: source as NSURL)

        let output = try await load([item], directory: directory)

        let name = try #require(output.fileNames.first)
        #expect(output.failures.isEmpty)
        #expect(try Data(contentsOf: source) == bytes)
        #expect(try Data(contentsOf: directory.appendingPathComponent(name)) == bytes)
    }

    @Test("Unsupported and missing attachments complete with an explicit result")
    func unsupportedInput() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let unsupported = try await load([NSItemProvider()], directory: directory)
        #expect(unsupported.fileNames.isEmpty)
        #expect(unsupported.failures.count == 1)
        let empty = try await load([], directory: directory)
        #expect(empty.fileNames.isEmpty)
        #expect(empty.failures.isEmpty)
    }

    @Test("Cancellation stops a provider even when it never calls its completion", .timeLimit(.minutes(1)))
    func cancelledProvider() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stalled = NSItemProvider()
        let (stream, started) = AsyncStream<Void>.makeStream()
        stalled.registerDataRepresentation(forTypeIdentifier: UTType.pdf.identifier, visibility: .all) { _ in
            started.yield(())
            started.finish()
            return Progress(totalUnitCount: 1)
        }
        let task = Task { try await load([stalled], directory: directory) }
        for await _ in stream { break }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation")
        } catch is CancellationError {
            #expect(!FileManager.default.fileExists(atPath: directory.path))
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ShareInputTests-" + UUID().uuidString, isDirectory: true)
    }

    private func provider(data: Data, type: UTType, name: String) -> NSItemProvider {
        let item = NSItemProvider()
        item.suggestedName = name
        item.registerDataRepresentation(forTypeIdentifier: type.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return item
    }

    private func load(_ providers: [NSItemProvider], directory: URL) async throws -> NCShareLoaderItemProvider.Output {
        let item = NSExtensionItem()
        item.attachments = providers
        return try await NCShareLoaderItemProvider.load(items: [item], directory: directory)
    }
}
