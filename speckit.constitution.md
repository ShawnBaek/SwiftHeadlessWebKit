# WKZombie Architecture Document

## Overview

WKZombie is a headless web browser library for iOS (10.3+) and macOS (10.12+) written in Swift 4. It enables programmatic web automation, navigation, and data extraction without displaying a graphical user interface.

---

# Migration Specification: Swift 6 + Server-Side Swift

## Goal

Migrate WKZombie to Swift 6 with server-side Swift (Linux) support while maintaining backward compatibility with Apple platforms. Remove CocoaPods dependency in favor of pure Swift Package Manager.

## Key Constraints

1. **Preserve core logic** - Do not change the fundamental Action<T>/Result<T> chain pattern
2. **Swift 6 compatibility** - Full strict concurrency, Sendable conformance
3. **Cross-platform** - Must run on Linux (server-side Swift) without WebKit
4. **SPM-only** - Remove CocoaPods, use Swift Package Manager exclusively
5. **Swift Testing framework** - Migrate from XCTest to swift-testing
6. **Existing tests must pass** - All current functionality preserved

---

## Architecture Changes

### New Architecture Diagram (Cross-Platform)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Client Application                               │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                            WKZombie                                      │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     Public API Layer                              │   │
│  │  open() │ click() │ submit() │ get() │ execute() │ fetch()       │   │
│  └──────────────────────────────┬───────────────────────────────────┘   │
│                                 │                                        │
│                                 ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                      Action<T> System (Sendable)                   │ │
│  │         Functional composition using >>> operator                  │ │
│  │              Swift 6 Concurrency: async/await                      │ │
│  └────────────────────────────────┬───────────────────────────────────┘ │
│                                   │                                      │
│         ┌─────────────────────────┼─────────────────────────────┐       │
│         │                         │                             │       │
│         ▼                         ▼                             ▼       │
│  ┌──────────────────┐     ┌─────────────┐            ┌─────────────┐   │
│  │ RenderingEngine  │     │   Parser    │            │   Fetcher   │   │
│  │   (Protocol)     │     │ (SwiftSoup) │            │ (URLSession)│   │
│  └────────┬─────────┘     └──────┬──────┘            └──────┬──────┘   │
│           │                      │                          │           │
│     ┌─────┴─────┐                ▼                          ▼           │
│     │           │         ┌─────────────┐            ┌─────────────┐   │
│     ▼           ▼         │   HTMLPage  │            │  HTTP Data  │   │
│ ┌────────┐ ┌────────┐     │ HTMLElement │            └─────────────┘   │
│ │WebKit  │ │Headless│     └─────────────┘                              │
│ │Renderer│ │Renderer│                                                   │
│ │(Apple) │ │(Linux) │                                                   │
│ └────────┘ └────────┘                                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Package.swift Modernization

### Current Package.swift (Legacy SPM 3)
```swift
import PackageDescription

let package = Package(
  name: "WKZombie",
  targets: [
      Target(name: "WKZombie"),
      Target(name: "Example", dependencies:["WKZombie"])
  ],
  dependencies: [
      .Package(url: "https://github.com/mkoehnke/hpple.git", Version(0,2,2))
  ]
)
```

### New Package.swift (SPM 6 / Swift 6)
```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WKZombie",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "WKZombie",
            targets: ["WKZombie"]
        ),
        .library(
            name: "WKZombieApple",
            targets: ["WKZombieApple"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        // Core cross-platform library
        .target(
            name: "WKZombie",
            dependencies: ["SwiftSoup"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        // Apple-specific extensions (WebKit rendering)
        .target(
            name: "WKZombieApple",
            dependencies: ["WKZombie"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        // Tests using Swift Testing framework
        .testTarget(
            name: "WKZombieTests",
            dependencies: ["WKZombie"],
            resources: [
                .copy("Resources/HTMLTestPage.html")
            ]
        ),
        .testTarget(
            name: "WKZombieAppleTests",
            dependencies: ["WKZombieApple"],
            resources: [
                .copy("Resources/HTMLTestPage.html")
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
```

---

## Phase 2: Dependency Replacement

### Remove: hpple (Objective-C, requires libxml2)

**Problem:** hpple is an Objective-C wrapper around libxml2, not cross-platform.

### Replace with: SwiftSoup (Pure Swift)

**SwiftSoup advantages:**
- Pure Swift implementation
- Cross-platform (Linux compatible)
- CSS selectors + XPath-like queries
- Actively maintained
- SPM native

### Migration Map: hpple → SwiftSoup

| hpple API | SwiftSoup Equivalent |
|-----------|---------------------|
| `TFHpple(htmlData:)` | `try SwiftSoup.parse(String(data:encoding:))` |
| `search(withXPathQuery:)` | `select()` with CSS selectors |
| `element.raw` | `element.outerHtml()` |
| `element.text()` | `element.text()` |
| `element.content` | `element.html()` |
| `element.tagName` | `element.tagName()` |
| `element.object(forKey:)` | `element.attr()` |
| `element.children` | `element.children()` |
| `element.hasChildren()` | `!element.children().isEmpty()` |

### XPath to CSS Selector Conversion

| SearchType | XPath (current) | CSS Selector (new) |
|------------|-----------------|-------------------|
| `.id("x")` | `//*[@id='x']` | `#x` |
| `.name("x")` | `//*[@name='x']` | `[name='x']` |
| `.class("x")` | `//*[@class='x']` | `.x` |
| `.text("x")` | `//*[contains(text(),'x')]` | `:containsOwn(x)` |
| `.attribute("k","v")` | `//*[@k='v']` | `[k='v']` |
| `.contains("k","v")` | `//*[contains(@k,'v')]` | `[k*='v']` |
| `.XPathQuery(q)` | Raw XPath | CSS selector (migrate) |

---

## Phase 3: Source File Restructure

### New Directory Structure

```
Sources/
├── WKZombie/                    # Cross-platform core
│   ├── Core/
│   │   ├── Action.swift         # Action<T> with Sendable
│   │   ├── Result.swift         # Result<T> (or use Swift.Result)
│   │   ├── SearchType.swift     # Element search types
│   │   ├── PostAction.swift     # Post-load actions
│   │   └── Error.swift          # ActionError
│   │
│   ├── Browser/
│   │   ├── WKZombie.swift       # Main API (protocol-based)
│   │   ├── BrowserEngine.swift  # Protocol for rendering engines
│   │   ├── HeadlessEngine.swift # HTTP-only engine (Linux)
│   │   └── ContentFetcher.swift # URL fetching
│   │
│   ├── Parser/
│   │   ├── Parser.swift         # Base parser
│   │   ├── HTMLParser.swift     # SwiftSoup-based HTML parser
│   │   └── JSONParser.swift     # JSON parsing
│   │
│   ├── DOM/
│   │   ├── Page.swift           # Page protocol
│   │   ├── HTMLPage.swift       # HTML page
│   │   ├── JSONPage.swift       # JSON page
│   │   ├── HTMLElement.swift    # Base element
│   │   ├── HTMLLink.swift
│   │   ├── HTMLButton.swift
│   │   ├── HTMLForm.swift
│   │   ├── HTMLImage.swift
│   │   ├── HTMLTable.swift
│   │   ├── HTMLFrame.swift
│   │   └── HTMLFetchable.swift
│   │
│   ├── Operators/
│   │   └── Operators.swift      # >>>, === operators
│   │
│   └── Utilities/
│       ├── Logger.swift
│       └── Functions.swift      # Convenience functions
│
├── WKZombieApple/               # Apple-only (WebKit)
│   ├── WebKitEngine.swift       # WKWebView-based engine
│   ├── Renderer.swift           # Current Renderer
│   ├── RenderOperation.swift    # Current RenderOperation
│   └── Snapshot.swift           # Screenshot support
│
Tests/
├── WKZombieTests/               # Cross-platform tests
│   ├── Resources/
│   │   └── HTMLTestPage.html
│   ├── ActionTests.swift
│   ├── ParserTests.swift
│   ├── SearchTypeTests.swift
│   └── HeadlessEngineTests.swift
│
└── WKZombieAppleTests/          # Apple-specific tests
    ├── Resources/
    │   └── HTMLTestPage.html
    ├── WebKitEngineTests.swift
    └── SnapshotTests.swift
```

---

## Phase 4: Swift 6 Concurrency Migration

### 4.1 Action<T> → Sendable + async/await

**Current Implementation:**
```swift
public struct Action<T> {
    public typealias Completion = (Result<T>) -> ()
    public typealias AsyncOperation = (@escaping Completion) -> ()
    fileprivate let operation: AsyncOperation

    public func start(_ completion: @escaping Completion) {
        self.operation() { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
```

**Swift 6 Implementation:**
```swift
public struct Action<T: Sendable>: Sendable {
    public typealias AsyncOperation = @Sendable () async throws -> T
    private let operation: AsyncOperation

    public init(operation: @escaping AsyncOperation) {
        self.operation = operation
    }

    public init(value: T) {
        self.operation = { value }
    }

    public init(error: ActionError) {
        self.operation = { throw error }
    }

    // Async execution
    public func execute() async throws -> T {
        try await operation()
    }

    // Backward compatibility with completion handlers
    @available(*, deprecated, message: "Use async execute() instead")
    public func start(_ completion: @escaping @Sendable (Result<T, ActionError>) -> Void) {
        Task {
            do {
                let result = try await execute()
                await MainActor.run { completion(.success(result)) }
            } catch let error as ActionError {
                await MainActor.run { completion(.failure(error)) }
            } catch {
                await MainActor.run { completion(.failure(.networkRequestFailure)) }
            }
        }
    }
}
```

### 4.2 Result Type Migration

**Option A: Use Swift.Result**
```swift
// Replace custom Result<T> with Swift.Result<T, ActionError>
public typealias ActionResult<T> = Swift.Result<T, ActionError>
```

**Option B: Keep custom Result with Sendable**
```swift
public enum Result<T: Sendable>: Sendable {
    case success(T)
    case error(ActionError)
}
```

**Recommendation:** Use Swift.Result for consistency with Swift ecosystem.

### 4.3 Operator Updates for async/await

```swift
// Chain operator with async
public func >>> <T: Sendable, U: Sendable>(
    lhs: Action<T>,
    rhs: @escaping @Sendable (T) async throws -> Action<U>
) -> Action<U> {
    Action {
        let result = try await lhs.execute()
        return try await rhs(result).execute()
    }
}

// Completion operator (backward compatibility)
public func === <T: Sendable>(
    action: Action<T>,
    completion: @escaping @Sendable (T?) -> Void
) {
    Task {
        do {
            let result = try await action.execute()
            await MainActor.run { completion(result) }
        } catch {
            await MainActor.run { completion(nil) }
        }
    }
}
```

### 4.4 WKZombie Class → Actor (Apple) / Struct (Linux)

**Cross-platform protocol:**
```swift
public protocol BrowserEngine: Sendable {
    func open<T: Page>(_ url: URL) async throws -> T
    func execute(_ script: String) async throws -> String
    var userAgent: String? { get set }
    var timeoutInSeconds: TimeInterval { get set }
}
```

**Apple implementation (actor for WKWebView thread safety):**
```swift
@MainActor
public final class WebKitEngine: BrowserEngine {
    private let renderer: Renderer
    // ... WKWebView-based implementation
}
```

**Linux implementation:**
```swift
public struct HeadlessEngine: BrowserEngine, Sendable {
    private let session: URLSession

    public func open<T: Page>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw ActionError.networkRequestFailure
        }
        return try T.pageWithData(data, url: url)
    }

    public func execute(_ script: String) async throws -> String {
        // JavaScript execution not available on Linux headless
        throw ActionError.notSupported
    }
}
```

---

## Phase 5: Parser Migration (hpple → SwiftSoup)

### 5.1 HTMLParser Rewrite

**Current (hpple):**
```swift
import hpple

public class HTMLParser : Parser {
    fileprivate var doc : TFHpple?

    required public init(data: Data, url: URL? = nil) {
        super.init(data: data, url: url)
        self.doc = TFHpple(htmlData: data)
    }

    public func searchWithXPathQuery(_ xPathOrCSS: String) -> [AnyObject]? {
        return doc?.search(withXPathQuery: xPathOrCSS) as [AnyObject]?
    }
}
```

**New (SwiftSoup):**
```swift
import SwiftSoup

public final class HTMLParser: Parser, Sendable {
    private let document: Document
    private let rawData: Data

    public required init(data: Data, url: URL? = nil) throws {
        self.rawData = data
        guard let html = String(data: data, encoding: .utf8) else {
            throw ActionError.parsingFailure
        }
        self.document = try SwiftSoup.parse(html, url?.absoluteString ?? "")
        super.init(url: url)
    }

    public func select(_ cssQuery: String) throws -> Elements {
        try document.select(cssQuery)
    }

    public var data: Data { rawData }

    public var html: String {
        (try? document.outerHtml()) ?? ""
    }
}
```

### 5.2 HTMLParserElement Rewrite

**Current (hpple):**
```swift
public class HTMLParserElement : CustomStringConvertible {
    fileprivate var element : TFHppleElement?

    public var innerContent : String? {
        return element?.raw as String?
    }

    public func objectForKey(_ key: String) -> String? {
        return element?.object(forKey: key.lowercased()) as String?
    }
}
```

**New (SwiftSoup):**
```swift
public final class HTMLParserElement: CustomStringConvertible, Sendable {
    private let element: Element
    public let xPathQuery: String?

    public init(element: Element, xPathQuery: String? = nil) {
        self.element = element
        self.xPathQuery = xPathQuery
    }

    public var innerContent: String? {
        try? element.outerHtml()
    }

    public var text: String? {
        try? element.text()
    }

    public var content: String? {
        try? element.html()
    }

    public var tagName: String {
        element.tagName()
    }

    public func objectForKey(_ key: String) -> String? {
        try? element.attr(key.lowercased())
    }

    public func children<T: HTMLElement>() -> [T] {
        element.children().array().compactMap { T(element: $0) }
    }

    public func hasChildren() -> Bool {
        !element.children().isEmpty()
    }

    public var description: String {
        (try? element.outerHtml()) ?? ""
    }
}
```

### 5.3 SearchType CSS Selector Generation

```swift
public enum SearchType<T: HTMLElement>: Sendable {
    case id(String)
    case name(String)
    case text(String)
    case `class`(String)
    case attribute(String, String)
    case contains(String, String)
    case cssSelector(String)

    @available(*, deprecated, renamed: "cssSelector")
    case XPathQuery(String)

    public func cssQuery() -> String {
        let tagName = T.tagName  // Each HTMLElement subclass defines this
        switch self {
        case .id(let value):
            return "\(tagName)#\(value)"
        case .name(let value):
            return "\(tagName)[name='\(value)']"
        case .text(let value):
            return "\(tagName):containsOwn(\(value))"
        case .class(let className):
            return "\(tagName).\(className)"
        case .attribute(let key, let value):
            return "\(tagName)[\(key)='\(value)']"
        case .contains(let key, let value):
            return "\(tagName)[\(key)*='\(value)']"
        case .cssSelector(let query), .XPathQuery(let query):
            return query
        }
    }
}
```

---

## Phase 6: Test Migration (XCTest → Swift Testing)

### 6.1 Test File Structure

**Current (XCTest):**
```swift
import XCTest
import WKZombie

class Tests: XCTestCase {
    var browser: WKZombie!

    override func setUp() {
        super.setUp()
        browser = WKZombie(name: "WKZombie Tests")
    }

    func testExecute() {
        let expectation = self.expectation(description: "JavaScript Done.")
        browser.open(startURL())
        >>> browser.execute("document.title")
        === { (result: JavaScriptResult?) in
            XCTAssertEqual(result, "WKZombie Test Page")
            expectation.fulfill()
        }
        waitForExpectations(timeout: 20.0, handler: nil)
    }
}
```

**New (Swift Testing):**
```swift
import Testing
@testable import WKZombie

@Suite("WKZombie Core Tests")
struct WKZombieTests {
    let browser: WKZombie

    init() {
        browser = WKZombie(name: "WKZombie Tests")
    }

    @Test("Execute JavaScript returns document title")
    func executeJavaScript() async throws {
        let page: HTMLPage = try await browser.open(testPageURL()).execute()
        let result = try await browser.execute("document.title").execute()
        #expect(result == "WKZombie Test Page")
    }

    @Test("Form submission navigates to result page")
    func formSubmit() async throws {
        let page: HTMLPage = try await browser.open(testPageURL()).execute()
        let form: HTMLForm = try await browser.get(by: .id("test_form"))(page).execute()
        let resultPage: HTMLPage = try await browser.submit(form).execute()
        let title = try await browser.execute("document.title").execute()
        #expect(title == "WKZombie Result Page")
    }

    @Test("Button press triggers navigation")
    func buttonPress() async throws {
        let page: HTMLPage = try await browser.open(testPageURL()).execute()
        let button: HTMLButton = try await browser.get(by: .name("button"))(page).execute()
        let _: HTMLPage = try await browser.press(button).execute()
        let title = try await browser.execute("document.title").execute()
        #expect(title == "WKZombie Result Page")
    }

    private func testPageURL() -> URL {
        Bundle.module.url(forResource: "HTMLTestPage", withExtension: "html")!
    }
}
```

### 6.2 Platform-Conditional Tests

```swift
import Testing
@testable import WKZombie

#if canImport(WebKit)
import WKZombieApple

@Suite("WebKit Engine Tests")
struct WebKitEngineTests {
    @Test("Snapshot captures page image")
    @available(iOS 15.0, macOS 12.0, *)
    func snapshotCapture() async throws {
        let browser = WKZombie(engine: WebKitEngine())
        var snapshots: [Snapshot] = []
        browser.snapshotHandler = { snapshots.append($0) }

        let _: HTMLPage = try await browser.open(testPageURL()).execute()
        try await browser.snap().execute()

        #expect(snapshots.count == 1)
        #expect(snapshots[0].image != nil)
    }
}
#endif

@Suite("Headless Engine Tests (Linux Compatible)")
struct HeadlessEngineTests {
    @Test("Parse HTML without WebKit")
    func parseHTML() async throws {
        let engine = HeadlessEngine()
        let page: HTMLPage = try await engine.open(URL(string: "https://example.com")!)
        let elements = try page.findElements(.cssSelector("h1"))
        #expect(!elements.isEmpty)
    }
}
```

### 6.3 Test Migration Mapping

| XCTest | Swift Testing |
|--------|---------------|
| `XCTestCase` | `@Suite struct` |
| `setUp()` | `init()` |
| `tearDown()` | `deinit` or no-op |
| `func testX()` | `@Test func x()` |
| `XCTAssertEqual(a, b)` | `#expect(a == b)` |
| `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertNotNil(x)` | `#expect(x != nil)` |
| `XCTAssertThrows` | `#expect(throws:)` |
| `expectation + fulfill` | `async/await` |
| `waitForExpectations` | Native async |

---

## Phase 7: Platform-Specific Code Isolation

### 7.1 Conditional Compilation Strategy

```swift
// In WKZombie core (cross-platform)
public protocol ImageType: Sendable {}

#if canImport(UIKit)
import UIKit
extension UIImage: ImageType {}
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
extension NSImage: ImageType {}
public typealias PlatformImage = NSImage
#else
// Linux: No native image type
public struct DataImage: ImageType, Sendable {
    public let data: Data
    public let mimeType: String
}
public typealias PlatformImage = DataImage
#endif
```

### 7.2 HTMLFetchable Cross-Platform

```swift
public protocol HTMLFetchableContent: Sendable {
    static func instanceFromData(_ data: Data) -> Result<Self, ActionError>
}

extension Data: HTMLFetchableContent {
    public static func instanceFromData(_ data: Data) -> Result<Data, ActionError> {
        .success(data)
    }
}

#if canImport(UIKit)
extension UIImage: HTMLFetchableContent {
    public static func instanceFromData(_ data: Data) -> Result<UIImage, ActionError> {
        guard let image = UIImage(data: data) else {
            return .failure(.transformFailure)
        }
        return .success(image)
    }
}
#elseif canImport(AppKit)
extension NSImage: HTMLFetchableContent {
    public static func instanceFromData(_ data: Data) -> Result<NSImage, ActionError> {
        guard let image = NSImage(data: data) else {
            return .failure(.transformFailure)
        }
        return .success(image)
    }
}
#endif
```

### 7.3 Remove objc_associated_object (Not Available on Linux)

**Current (uses Objective-C runtime):**
```swift
import ObjectiveC

private var WKZFetchedDataKey: UInt8 = 0

extension HTMLFetchable {
    internal var fetchedData: Data? {
        get { objc_getAssociatedObject(self, &WKZFetchedDataKey) as? Data }
        set { objc_setAssociatedObject(self, &WKZFetchedDataKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}
```

**New (pure Swift):**
```swift
// Option 1: Store in the element itself
public protocol HTMLFetchable: Sendable {
    var fetchURL: URL? { get }
    var fetchedData: Data? { get set }
}

// Option 2: Use a concurrent dictionary cache
import Foundation

actor FetchedDataCache {
    static let shared = FetchedDataCache()
    private var storage: [ObjectIdentifier: Data] = [:]

    func get(for object: AnyObject) -> Data? {
        storage[ObjectIdentifier(object)]
    }

    func set(_ data: Data?, for object: AnyObject) {
        storage[ObjectIdentifier(object)] = data
    }
}
```

---

## Phase 8: Error Handling Updates

### 8.1 ActionError Enhancement

```swift
public enum ActionError: Error, Sendable, CustomDebugStringConvertible {
    case networkRequestFailure
    case notFound
    case parsingFailure
    case transformFailure
    case snapshotFailure
    case notSupported  // New: for unsupported operations on Linux
    case timeout
    case invalidURL

    public var debugDescription: String {
        switch self {
        case .networkRequestFailure: return "Network Request Failure"
        case .notFound: return "Element Not Found"
        case .parsingFailure: return "Parsing Failure"
        case .transformFailure: return "Transform Failure"
        case .snapshotFailure: return "Snapshot Failure"
        case .notSupported: return "Operation Not Supported on This Platform"
        case .timeout: return "Operation Timed Out"
        case .invalidURL: return "Invalid URL"
        }
    }
}
```

### 8.2 Remove Custom ErrorType Protocol

**Current:**
```swift
public protocol ErrorType { }
public enum NoError: ErrorType { }
public enum ActionError: ErrorType { ... }
```

**New:**
```swift
// Use Swift.Error directly
public enum ActionError: Error, Sendable { ... }
```

---

## Phase 9: Files to Delete

| File | Reason |
|------|--------|
| `WKZombie.podspec` | CocoaPods removed |
| `.travis.yml` | Update to GitHub Actions |
| Old `Package.swift` | Replace with Swift 6 version |

---

## Phase 10: Files to Create

| File | Purpose |
|------|---------|
| `Sources/WKZombie/Core/BrowserEngine.swift` | Protocol for rendering engines |
| `Sources/WKZombie/Browser/HeadlessEngine.swift` | Linux-compatible HTTP engine |
| `Sources/WKZombieApple/WebKitEngine.swift` | Apple WebKit wrapper |
| `.github/workflows/ci.yml` | GitHub Actions CI |
| `Tests/WKZombieTests/ParserTests.swift` | SwiftSoup parser tests |

---

## Migration Checklist

### Pre-Migration
- [ ] Create feature branch `swift6-migration`
- [ ] Backup existing tests
- [ ] Document current test coverage

### Phase 1: Package.swift
- [ ] Update to swift-tools-version: 6.0
- [ ] Add SwiftSoup dependency
- [ ] Create WKZombie and WKZombieApple targets
- [ ] Configure test targets with resources

### Phase 2: Core Types
- [ ] Add Sendable conformance to Action<T>
- [ ] Migrate to Swift.Result or add Sendable to custom Result
- [ ] Update operators for async/await
- [ ] Add BrowserEngine protocol

### Phase 3: Parser
- [ ] Replace hpple import with SwiftSoup
- [ ] Rewrite HTMLParser
- [ ] Rewrite HTMLParserElement
- [ ] Update SearchType to use CSS selectors
- [ ] Add XPath deprecation warnings

### Phase 4: Platform Isolation
- [ ] Move WebKit code to WKZombieApple
- [ ] Create HeadlessEngine for Linux
- [ ] Remove objc_associated_object usage
- [ ] Add platform conditionals

### Phase 5: Tests
- [ ] Migrate to Swift Testing framework
- [ ] Convert async expectations to async/await
- [ ] Add Linux-compatible tests
- [ ] Verify all existing tests pass

### Phase 6: Cleanup
- [ ] Delete podspec
- [ ] Update README
- [ ] Add GitHub Actions CI
- [ ] Update documentation

---

## Backward Compatibility Notes

### Deprecated APIs (Keep for 1 release cycle)
```swift
@available(*, deprecated, message: "Use async execute() instead")
public func start(_ completion: @escaping (Result<T>) -> Void)

@available(*, deprecated, renamed: "cssSelector")
case XPathQuery(String)

@available(*, deprecated, message: "Use WKZombieApple for WebKit features")
public var snapshotHandler: SnapshotHandler?
```

### Breaking Changes
1. Minimum deployment targets increased (macOS 12, iOS 15)
2. XPath queries should be migrated to CSS selectors
3. Snapshot functionality moved to WKZombieApple
4. JavaScript execution unavailable on Linux

---

## Version Plan

| Version | Changes |
|---------|---------|
| 2.0.0-alpha | Swift 6, async/await, SwiftSoup |
| 2.0.0-beta | Full test coverage, Linux CI |
| 2.0.0 | Stable release |
| 2.1.0 | Remove deprecated APIs |
| 2.2.0 | JavaScript rendering support on Linux via WebKitGTK |

---

## Phase 11: JavaScript Rendering on Linux (New Feature)

### Problem Statement

The current `HeadlessEngine` on Linux performs HTTP fetching only and cannot execute JavaScript. Modern websites like https://www.uber.com/us/en/careers/list/ use client-side rendering where:

1. Initial HTML is a minimal shell with `<div id="root"></div>`
2. JavaScript bundles are loaded and executed
3. Content is dynamically rendered in the browser
4. Only after JavaScript execution is the full DOM available

This means that scraping such sites on Linux returns incomplete/empty content while Apple platforms (using `WebKitEngine`) can render the full page.

### Solution: WebKit-Based Rendering on Linux

Use the same WebKit engine on Linux via **WebKitGTK** (the GTK port of WebKit). This provides:
1. Consistent rendering behavior across all platforms
2. Same JavaScript engine (JavaScriptCore) as Apple platforms
3. Full DOM manipulation and JavaScript execution

### Architecture Change

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BrowserEngine Protocol                               │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────────┐
        │                         │                             │
        ▼                         ▼                             ▼
 ┌──────────────────┐   ┌───────────────────┐        ┌───────────────────────┐
 │   WebKitEngine   │   │  HeadlessEngine   │        │  WebKitGTKEngine      │
 │   (Apple only)   │   │ (HTTP fetch only) │        │  (Linux with WebKit)  │
 │   WKWebView      │   │  No JS execution  │        │  Full JS support      │
 └──────────────────┘   └───────────────────┘        └───────────────────────┘
```

### Option Analysis

#### Option 1: WebKitGTK (Recommended)

Use WebKitGTK, the official WebKit port for Linux/GTK.

**Pros:**
- Same WebKit engine as Apple platforms (consistent behavior)
- Same JavaScriptCore for JavaScript execution
- Official WebKit project, well-maintained
- No external browser dependency
- Headless mode supported via virtual display (Xvfb) or `GTK_DISPLAY_MODE=offscreen`

**Cons:**
- Requires system library installation (`libwebkit2gtk-4.0-dev`)
- Need Swift C bindings for WebKitGTK

**Implementation:**
```swift
// New file: Sources/WKZombieLinux/WebKitGTKEngine.swift

#if os(Linux)
import Foundation
import CWebKitGTK  // Swift module for WebKitGTK C bindings

/// A browser engine using WebKitGTK for JavaScript rendering on Linux.
/// This provides the same WebKit engine used on Apple platforms.
public final class WebKitGTKEngine: BrowserEngine, @unchecked Sendable {

    private var webView: WebKitWebView?
    private let timeoutSeconds: TimeInterval
    private var currentData: Data?
    private var currentURL: URL?

    public var userAgent: String? { nil }
    public var timeoutInSeconds: TimeInterval { timeoutSeconds }

    public init(timeoutInSeconds: TimeInterval = 30.0) {
        self.timeoutSeconds = timeoutInSeconds
        initializeGTK()
        setupWebView()
    }

    private func initializeGTK() {
        // Initialize GTK in headless mode
        gtk_init(nil, nil)
    }

    private func setupWebView() {
        // Create WebKitWebView
        webView = webkit_web_view_new()
    }

    public func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?) {
        // Load URL in WebKitWebView
        webkit_web_view_load_uri(webView, url.absoluteString)

        // Wait for page to load
        try await waitForLoadComplete()

        // Handle post action
        if case .wait(let time) = postAction {
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        }

        // Get rendered HTML
        let html = try await getPageHTML()
        let data = html.data(using: .utf8) ?? Data()
        self.currentData = data
        self.currentURL = url

        return (data, url)
    }

    public func execute(_ script: String) async throws -> String {
        // Execute JavaScript using webkit_web_view_run_javascript
        return try await withCheckedThrowingContinuation { continuation in
            webkit_web_view_run_javascript(webView, script, nil) { result, error in
                if let error = error {
                    continuation.resume(throwing: ActionError.networkRequestFailure)
                } else {
                    let jsResult = webkit_javascript_result_get_js_value(result)
                    let value = jsc_value_to_string(jsResult)
                    continuation.resume(returning: String(cString: value!))
                }
            }
        }
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        _ = try await execute(script)
        try await waitForLoadComplete()

        if case .wait(let time) = postAction {
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        }

        let html = try await getPageHTML()
        let data = html.data(using: .utf8) ?? Data()
        return (data, currentURL)
    }

    public func currentContent() async throws -> (Data, URL?) {
        guard let data = currentData else { throw ActionError.notFound }
        return (data, currentURL)
    }

    private func waitForLoadComplete() async throws {
        // Wait for WebKitLoadEvent.WEBKIT_LOAD_FINISHED
    }

    private func getPageHTML() async throws -> String {
        return try await execute("document.documentElement.outerHTML")
    }
}
#endif
```

#### Option 2: Chrome DevTools Protocol (Fallback)

Use Chrome/Chromium's DevTools Protocol for headless browser control.

**Pros:**
- Full JavaScript support
- Cross-platform (Linux, macOS, Windows)
- Well-maintained and stable
- Supports waiting for network idle, DOM elements, etc.

**Cons:**
- External dependency (Chromium binary required)
- Different rendering engine than Apple platforms
- More complex setup

**Implementation:**
```swift
// New file: Sources/WKZombie/Browser/ChromeDevToolsProtocolEngine.swift

#if os(Linux) || os(macOS) || os(Windows)
import Foundation

/// A browser engine using headless Chromium via Chrome DevTools Protocol.
public final class ChromeDevToolsProtocolEngine: BrowserEngine, @unchecked Sendable {

    private let debuggerURL: URL
    private let timeoutSeconds: TimeInterval
    private var currentData: Data?
    private var currentURL: URL?

    /// Creates a ChromeDevToolsProtocolEngine connecting to a Chrome debugger endpoint.
    ///
    /// - Parameters:
    ///   - debuggerURL: The Chrome DevTools Protocol WebSocket URL (e.g., ws://localhost:9222)
    ///   - timeoutInSeconds: Maximum time to wait for page load
    public init(debuggerURL: URL, timeoutInSeconds: TimeInterval = 30.0) {
        self.debuggerURL = debuggerURL
        self.timeoutSeconds = timeoutInSeconds
    }

    public var userAgent: String? { nil }
    public var timeoutInSeconds: TimeInterval { timeoutSeconds }

    public func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?) {
        // Connect to Chrome DevTools Protocol WebSocket
        // Send Page.navigate command
        // Wait for load event or network idle
        // Execute Page.getDocument + DOM.getOuterHTML
        // Return rendered HTML
    }

    public func execute(_ script: String) async throws -> String {
        // Send Runtime.evaluate command via Chrome DevTools Protocol
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        // Execute script and wait for navigation
    }

    public func currentContent() async throws -> (Data, URL?) {
        guard let data = currentData else { throw ActionError.notFound }
        return (data, currentURL)
    }
}
#endif
```

#### Option 3: Selenium WebDriver Protocol

Use W3C WebDriver protocol to communicate with any browser.

**Pros:**
- Browser-agnostic (Chrome, Firefox, Safari)
- Standard protocol (W3C)

**Cons:**
- Requires separate WebDriver server
- More complex setup

### Recommended Approach: WebKitGTK

WebKitGTK is the recommended approach because:

1. **Consistency**: Same WebKit engine as Apple platforms ensures identical rendering
2. **No External Dependencies**: WebKitGTK is a system library, not a separate browser
3. **Maintained by WebKit Project**: Official port, actively maintained
4. **JavaScriptCore**: Same JavaScript engine as Safari/WKWebView

### WebKitGTK Setup Instructions

#### Installing WebKitGTK on Linux

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y libwebkit2gtk-4.1-dev libgtk-4-dev

# Fedora
sudo dnf install webkit2gtk4.1-devel gtk4-devel

# Arch Linux
sudo pacman -S webkit2gtk-4.1 gtk4
```

#### Running Headless (No Display)

```bash
# Option 1: Virtual framebuffer
sudo apt-get install -y xvfb
xvfb-run swift test

# Option 2: GTK Broadway backend (web-based display)
GDK_BACKEND=broadway swift test

# Option 3: Offscreen rendering
GDK_BACKEND=wayland WAYLAND_DISPLAY= swift test
```

### Test Specification: Uber Careers Page

#### Test Case: Extract Job Listings from Uber Careers

```swift
@Suite("JavaScript Rendering Tests")
struct JavaScriptRenderingTests {

    struct UberJob: Sendable, Equatable {
        let title: String
        let team: String
        let location: String
        let url: String
    }

    @Test("Extract jobs from Uber careers page (requires JavaScript rendering)")
    func extractUberJobs() async throws {
        // Create engine based on platform
        #if os(Linux)
        let engine = WebKitGTKEngine(timeoutInSeconds: 60.0)
        #else
        let engine = WebKitEngine()
        #endif

        let browser = WKZombie(name: "UberCareersTest", engine: engine)

        let careersURL = URL(string: "https://www.uber.com/us/en/careers/list/")!
        let page: HTMLPage = try await browser.open(careersURL).execute()

        // Wait for job listings to render (JavaScript)
        // The page should contain job cards after rendering

        // Find job listing elements
        let jobCards: [HTMLElement] = page.findElements(
            .cssSelector("[data-testid='job-card'], .job-listing, [class*='JobCard']")
        ).successValue ?? []

        #expect(!jobCards.isEmpty, "Should find job listings after JavaScript rendering")

        // Extract job information
        var jobs: [UberJob] = []
        for card in jobCards {
            if let title = card.findElements(.cssSelector("h3, [class*='title']")).successValue?.first?.text,
               let team = card.findElements(.cssSelector("[class*='team'], [class*='department']")).successValue?.first?.text,
               let location = card.findElements(.cssSelector("[class*='location']")).successValue?.first?.text,
               let link = card.findElements(.cssSelector("a")).successValue?.first as? HTMLLink {
                jobs.append(UberJob(
                    title: title,
                    team: team,
                    location: location,
                    url: link.href ?? ""
                ))
            }
        }

        #expect(!jobs.isEmpty, "Should extract job details")

        // Verify job has required fields
        for job in jobs {
            #expect(!job.title.isEmpty, "Job title should not be empty")
            // Team and location may be optional for some listings
        }

        print("Extracted \(jobs.count) jobs from Uber careers page")
        for job in jobs.prefix(5) {
            print("- \(job.title) (\(job.team)) - \(job.location)")
        }
    }

    @Test("Compare Linux and Apple rendering results")
    func compareRenderingResults() async throws {
        // This test verifies that WebKitGTKEngine on Linux produces
        // similar results to WebKitEngine on Apple platforms

        #if os(Linux)
        let engine = WebKitGTKEngine()
        #else
        let engine = WebKitEngine()
        #endif

        let browser = WKZombie(name: "CompareTest", engine: engine)
        let testURL = URL(string: "https://www.uber.com/us/en/careers/list/")!

        let page: HTMLPage = try await browser.open(testURL).execute()

        // Both should render the page with job listings
        let jobElements = page.findElements(.cssSelector("[data-testid='job-card'], .job-listing"))

        switch jobElements {
        case .success(let elements):
            #expect(!elements.isEmpty, "Should find job elements on all platforms")
        case .failure(let error):
            Issue.record("Failed to find elements: \(error)")
        }
    }
}
```

### Docker Setup for CI

```dockerfile
# Dockerfile.test
FROM swift:latest

# Install WebKitGTK and virtual display
RUN apt-get update && apt-get install -y \
    libwebkit2gtk-4.1-dev \
    libgtk-4-dev \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# Run tests with virtual framebuffer
CMD xvfb-run swift test
```

### CI/CD Integration

Update `.github/workflows/ci.yml`:

```yaml
  # Linux Build and Test with JavaScript Rendering
  build-linux-webkit:
    name: Linux (WebKitGTK JavaScript Rendering)
    runs-on: ubuntu-latest
    container:
      image: swift:latest
    steps:
      - uses: actions/checkout@v4

      - name: Install WebKitGTK
        run: |
          apt-get update
          apt-get install -y libwebkit2gtk-4.1-dev libgtk-4-dev xvfb

      - name: Show Swift version
        run: swift --version

      - name: Build
        run: swift build -v

      - name: Run tests with Xvfb
        run: xvfb-run swift test -v
```

### API Design

#### New Convenience Initializer

```swift
public extension WKZombie {
    /// Creates a WKZombie instance with JavaScript rendering support.
    ///
    /// On Apple platforms, uses WebKitEngine (WKWebView).
    /// On Linux, uses WebKitGTKEngine (WebKitGTK).
    ///
    /// - Parameters:
    ///   - name: Instance name
    static func withJavaScriptSupport(name: String? = nil) -> WKZombie {
        #if canImport(WebKit)
        return WKZombie(name: name, engine: WebKitEngine())
        #elseif os(Linux)
        return WKZombie(name: name, engine: WebKitGTKEngine())
        #else
        fatalError("JavaScript rendering not supported on this platform")
        #endif
    }
}
```

#### Wait for JavaScript Rendering

```swift
public extension BrowserEngine {
    /// Wait for JavaScript to render content matching a selector.
    func waitForSelector(_ selector: String, timeout: TimeInterval = 30.0) async throws

    /// Wait for network to become idle.
    func waitForNetworkIdle(timeout: TimeInterval = 30.0) async throws
}
```

### File Changes Summary

| File | Action | Description |
|------|--------|-------------|
| `Sources/WKZombieLinux/WebKitGTKEngine.swift` | Create | WebKitGTK-based browser engine for Linux |
| `Sources/WKZombieLinux/CWebKitGTK/` | Create | Swift C bindings for WebKitGTK |
| `Tests/WKZombieTests/JavaScriptRenderingTests.swift` | Create | Tests for JavaScript rendering |
| `Package.swift` | Update | Add WKZombieLinux target with system library |
| `.github/workflows/ci.yml` | Update | Add Linux WebKitGTK tests |
| `README.md` | Update | Document JavaScript rendering setup |

### Package.swift Changes

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftHeadlessWebKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftHeadlessWebKit", targets: ["WKZombie"]),
        .library(name: "SwiftHeadlessWebKitApple", targets: ["WKZombieApple"]),
        #if os(Linux)
        .library(name: "SwiftHeadlessWebKitLinux", targets: ["WKZombieLinux"]),
        #endif
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        .target(
            name: "WKZombie",
            dependencies: ["SwiftSoup"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "WKZombieApple",
            dependencies: ["WKZombie"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        #if os(Linux)
        .systemLibrary(
            name: "CWebKitGTK",
            pkgConfig: "webkit2gtk-4.1",
            providers: [
                .apt(["libwebkit2gtk-4.1-dev"]),
                .yum(["webkit2gtk4.1-devel"])
            ]
        ),
        .target(
            name: "WKZombieLinux",
            dependencies: ["WKZombie", "CWebKitGTK"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        #endif
        .testTarget(
            name: "WKZombieTests",
            dependencies: ["WKZombie"],
            resources: [.copy("Resources")]
        ),
        .testTarget(
            name: "WKZombieAppleTests",
            dependencies: ["WKZombieApple"],
            resources: [.copy("Resources")]
        )
    ]
)
```

### Migration Path

1. **Phase 1**: Create CWebKitGTK system library bindings
2. **Phase 2**: Implement `WebKitGTKEngine` using WebKitGTK APIs
3. **Phase 3**: Add wait methods for JavaScript rendering
4. **Phase 4**: Create integration tests with Uber careers page
5. **Phase 5**: Update CI to install WebKitGTK and run with Xvfb
6. **Phase 6**: Document setup and usage

---

## Appendix: Current Architecture (Reference)

### Core Components

1. **WKZombie** - Main API class
2. **Action<T>** - Monadic async operation
3. **Result<T>** - Success/error wrapper
4. **Renderer** - WKWebView manager
5. **RenderOperation** - NSOperation for rendering
6. **HTMLParser** - hpple wrapper
7. **HTMLParserElement** - DOM element wrapper
8. **SearchType<T>** - Element search specification
9. **PostAction** - Post-load actions
10. **ContentFetcher** - URLSession wrapper

### Platform-Specific Files

| File | iOS | macOS | Linux |
|------|-----|-------|-------|
| WKZombie.swift | Partial | Partial | Core only |
| Renderer.swift | Yes | Yes | No |
| RenderOperation.swift | Yes | Yes | No |
| Snapshot.swift | Yes | Yes | No |
| HTMLFetchable.swift | Partial | Partial | Data only |
| Functions.swift | Partial | Full | Core only |

### Test Coverage

| Test | Purpose | Platform |
|------|---------|----------|
| testExecute | JavaScript execution | Apple |
| testInspect | Page inspection | Apple |
| testButtonPress | Button click | Apple |
| testFormSubmit | Form submission | Apple |
| testFormWithXPathQuerySubmit | XPath form query | Apple |
| testDivOnClick | onClick handler | Apple |
| testDivHref | href navigation | Apple |
| testUserAgent | Custom user agent | Apple |
| testSnapshot | Page screenshot | iOS only |
| testSwap | iframe context | Apple |
| testBasicAuthentication | Basic auth | Apple |
| testSelfSignedCertificates | SSL handling | Apple |
