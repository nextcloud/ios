// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Testing
@testable import Nextcloud

@Suite("Collectives pages")
struct NCCollectivePageTests {
    private func page(id: Int, parentId: Int, title: String, filePath: String = "", fileName: String? = nil, subpageOrder: [Int] = []) -> NCCollectivePage {
        NCCollectivePage(id: id,
                         parentId: parentId,
                         title: title,
                         emoji: nil,
                         timestamp: 0,
                         fileName: fileName ?? "\(title).md",
                         filePath: filePath,
                         collectivePath: ".Collectives/Handbook",
                         lastUserDisplayName: nil,
                         subpageOrder: subpageOrder)
    }

    @Test("Decodes a page as returned by the Collectives API")
    func decodePage() throws {
        let json = """
        {"id":83,"slug":"Intro","lastUserId":"admin","lastUserDisplayName":"Admin","emoji":"🚀","subpageOrder":[85],
         "isFullWidth":false,"tags":[],"trashTimestamp":null,"title":"Intro","timestamp":1792004005,"size":0,
         "fileName":"Readme.md","filePath":"Intro","filePathString":"","collectivePath":".Collectives/Handbook",
         "collectiveNameWithEmoji":null,"parentId":81,"shareToken":null,"linkedPageIds":[]}
        """
        let page = try JSONDecoder().decode(NCCollectivePage.self, from: Data(json.utf8))

        #expect(page.id == 83)
        #expect(page.emoji == "🚀")
        #expect(page.subpageOrder == [85])
        #expect(page.relativeFilePath == ".Collectives/Handbook/Intro/Readme.md")
        #expect(!page.isLandingPage)
    }

    @Test("The landing page lives at the collective's root")
    func landingPagePath() {
        let landing = page(id: 1, parentId: 0, title: "Landing page", fileName: "Readme.md")
        #expect(landing.isLandingPage)
        #expect(landing.relativeFilePath == ".Collectives/Handbook/Readme.md")
    }

    @Test("Subpages follow the custom order, then the title")
    func treeOrder() {
        let pages = [
            page(id: 1, parentId: 0, title: "Landing page", fileName: "Readme.md", subpageOrder: [4]),
            page(id: 2, parentId: 1, title: "Beta"),
            page(id: 3, parentId: 1, title: "Alpha", filePath: "Alpha", fileName: "Readme.md"),
            page(id: 4, parentId: 1, title: "Zulu"),
            page(id: 5, parentId: 3, title: "Child", filePath: "Alpha")
        ]

        let tree = NCCollectivePageNode.tree(pages: pages, parentId: 1)

        #expect(tree.map(\.id) == [4, 3, 2])
        #expect(tree[1].children?.map(\.id) == [5])
        #expect(tree[0].children == nil)
    }

    @Test("Links to pages are resolved by file id or URL slug",
          arguments: [
            ("Intro/Readme.md?fileId=83", 83),
            ("https://cloud.example.com/index.php/apps/collectives/Handbook-1/Intro-83", 83),
            ("https://cloud.example.com/apps/collectives/p/token/Handbook/Intro?fileId=12", 12)
          ])
    func linkedPage(link: String, id: Int) throws {
        let url = try #require(URL(string: link))
        #expect(NCCollectivePage.pageId(linkedBy: url) == id)
    }

    @Test("External links are not resolved to pages")
    func externalLink() throws {
        let url = try #require(URL(string: "https://example.com/blog/post-12"))
        #expect(NCCollectivePage.pageId(linkedBy: url) == nil)
    }

    @Test("Relative sources resolve against the page's folder")
    func relativeSourcePath() {
        let intro = page(id: 83, parentId: 81, title: "Intro", filePath: "Intro", fileName: "Readme.md")

        #expect(intro.relativePath(forSource: ".attachments.83/Berg%20Panorama.png") == ".Collectives/Handbook/Intro/.attachments.83/Berg Panorama.png")
        #expect(intro.relativePath(forSource: "../.attachments.81/logo.png") == ".Collectives/Handbook/.attachments.81/logo.png")
        #expect(intro.relativePath(forSource: "https://example.com/image.png") == nil)
    }

    @Test("Embeds match attachments by their Markdown source")
    func embedAttachment() {
        let intro = page(id: 83, parentId: 81, title: "Intro", filePath: "Intro", fileName: "Readme.md")
        let attachment = NCCollectivePageAttachment(id: 113, name: "Berg Panorama.png", filesize: 1, mimetype: "image/png",
                                                    path: "/.Collectives/Handbook/Intro/.attachments.83/Berg Panorama.png",
                                                    src: ".attachments.83/Berg%20Panorama.png", hasPreview: true)

        let embed = NCCollectivesEmbed(alt: "Berg Panorama.png", source: ".attachments.83/Berg Panorama.png", page: intro, attachments: [attachment])

        #expect(embed.attachment == attachment)
        #expect(embed.isImage)
        #expect(embed.caption == nil)
        #expect(embed.relativePath == ".Collectives/Handbook/Intro/.attachments.83/Berg Panorama.png")
    }
}
