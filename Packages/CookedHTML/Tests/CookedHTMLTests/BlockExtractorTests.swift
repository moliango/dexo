import XCTest
@testable import CookedHTML

final class BlockExtractorTests: XCTestCase {

    // MARK: - Paragraph

    func testSimpleParagraph() {
        let html = "<p>Hello world</p>"
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 1)
        if case .paragraph(let inlines) = blocks[0] {
            XCTAssertEqual(inlines, [.text("Hello world")])
        } else {
            XCTFail("Expected paragraph, got \(blocks[0])")
        }
    }

    func testMultipleParagraphs() {
        let html = "<p>First</p><p>Second</p>"
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 2)
    }

    // MARK: - Headings

    func testHeadings() {
        let html = "<h1>Title</h1><h2>Subtitle</h2><h3>Section</h3>"
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 3)

        if case .heading(let level, let content) = blocks[0] {
            XCTAssertEqual(level, 1)
            XCTAssertEqual(content, [.text("Title")])
        } else {
            XCTFail("Expected h1")
        }

        if case .heading(let level, _) = blocks[1] {
            XCTAssertEqual(level, 2)
        } else {
            XCTFail("Expected h2")
        }
    }

    // MARK: - Code Block

    func testCodeBlock() {
        let html = """
        <pre><code class="lang-swift">let x = 42</code></pre>
        """
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 1)
        if case .codeBlock(let lang, let code) = blocks[0] {
            XCTAssertEqual(lang, "swift")
            XCTAssertEqual(code, "let x = 42")
        } else {
            XCTFail("Expected codeBlock, got \(blocks[0])")
        }
    }

    func testCodeBlockNoLanguage() {
        let html = "<pre><code>plain code</code></pre>"
        let blocks = CookedHTMLParser.parse(html: html)
        if case .codeBlock(let lang, let code) = blocks[0] {
            XCTAssertNil(lang)
            XCTAssertEqual(code, "plain code")
        } else {
            XCTFail("Expected codeBlock")
        }
    }

    // MARK: - Blockquote

    func testBlockquote() {
        let html = "<blockquote><p>Quoted text</p></blockquote>"
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 1)
        if case .blockquote(let inner) = blocks[0] {
            XCTAssertEqual(inner.count, 1)
            if case .paragraph(let inlines) = inner[0] {
                XCTAssertEqual(inlines, [.text("Quoted text")])
            }
        } else {
            XCTFail("Expected blockquote")
        }
    }

    // MARK: - Divider

    func testHorizontalRule() {
        let html = "<p>Before</p><hr><p>After</p>"
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[1], .divider)
    }

    // MARK: - Image

    func testStandaloneImage() {
        let html = "<p><img src=\"/uploads/test.png\" alt=\"test\" width=\"100\" height=\"50\"></p>"
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 1)
        if case .image(let src, let alt, let w, let h, _) = blocks[0] {
            XCTAssertEqual(src, "/uploads/test.png")
            XCTAssertEqual(alt, "test")
            XCTAssertEqual(w, 100)
            XCTAssertEqual(h, 50)
        } else {
            XCTFail("Expected image, got \(blocks[0])")
        }
    }

    func testImageWithBaseURL() {
        let html = "<p><img src=\"/uploads/test.png\"></p>"
        let blocks = CookedHTMLParser.parse(html: html, baseURL: "https://linux.do")
        if case .image(let src, _, _, _, _) = blocks[0] {
            XCTAssertEqual(src, "https://linux.do/uploads/test.png")
        } else {
            XCTFail("Expected image")
        }
    }

    // MARK: - Details

    func testDetails() {
        let html = """
        <details>
            <summary>Click me</summary>
            <p>Hidden content</p>
        </details>
        """
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 1)
        if case .details(let summary, let content) = blocks[0] {
            XCTAssertEqual(summary, [.text("Click me")])
            XCTAssertEqual(content.count, 1)
        } else {
            XCTFail("Expected details, got \(blocks[0])")
        }
    }

    // MARK: - Empty/Whitespace

    func testEmptyParagraphsAreSkipped() {
        let html = "<p>   </p><p>Real content</p>"
        let blocks = CookedHTMLParser.parse(html: html)
        XCTAssertEqual(blocks.count, 1)
    }
}
