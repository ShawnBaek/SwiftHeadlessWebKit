# SwiftHeadlessWebKit

[![CI](https://github.com/anthropics/SwiftHeadlessWebKit/actions/workflows/ci.yml/badge.svg)](https://github.com/anthropics/SwiftHeadlessWebKit/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.2-orange.svg?style=flat)](https://swift.org)
[![SPM compatible](https://img.shields.io/badge/SPM-compatible-brightgreen.svg?style=flat)](https://github.com/apple/swift-package-manager)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20Linux-blue.svg?style=flat)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat)](LICENSE)

> **This is a revamp of [WKZombie](https://github.com/mkoehnke/WKZombie)**, modernized for **Swift 6** with strict concurrency, the new **Swift Testing** framework, and **cross-platform support** including Linux for server-side Swift applications.
>
> Refactored by **[Claude Code](https://claude.ai/claude-code)** with **Spec Driven Kit** methodology.

---

SwiftHeadlessWebKit is a **headless web browser** for Swift. It enables web scraping, automation, and data collection without a graphical user interface.

## Key Features

- **Swift 6** with strict concurrency (`Sendable`, `async/await`)
- **Cross-platform**: Works on iOS, macOS, tvOS, watchOS, visionOS, and **Linux**
- **Pure Swift**: Uses [SwiftSoup](https://github.com/scinfu/SwiftSoup) for HTML parsing (no C dependencies)
- **Swift Testing**: Modern test framework with `@Suite`, `@Test`, `#expect`
- **Modular Design**: Core library + optional WebKit extensions for Apple platforms

## Architecture

| Module | Description | Platforms |
|--------|-------------|-----------|
| `SwiftHeadlessWebKit` | Core headless browser with HTTP fetching and HTML parsing | All (including Linux) |
| `SwiftHeadlessWebKitApple` | WebKit-based engine with full JavaScript support | Apple only |
| `SwiftHeadlessWebKitLinux` | WebKit-based engine using WPE WebKit or WebKitGTK | Linux only |

### WebKit on Linux

For JavaScript rendering on Linux, the library uses the official WebKit ports from https://github.com/WebKit/WebKit:

- **WPE WebKit** (recommended): Headless WebKit designed for embedded systems and servers
- **WebKitGTK**: WebKit with GTK integration (requires display server or xvfb)

Both use the same WebKit engine as Safari, ensuring consistent behavior across platforms.

## Use Cases

- Collect data without an API
- Web scraping
- Automating website interactions
- Running automated tests
- Server-side Swift web automation

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/anthropics/SwiftHeadlessWebKit.git", from: "2.0.0")
]
```

Then add the target dependency:

```swift
// For cross-platform (including Linux)
.target(name: "YourTarget", dependencies: ["SwiftHeadlessWebKit"])

// For Apple platforms with WebKit support
.target(name: "YourTarget", dependencies: ["SwiftHeadlessWebKitApple"])

// For Linux with WebKit JavaScript support
.target(name: "YourTarget", dependencies: ["SwiftHeadlessWebKitLinux"])
```

### Linux WebKit Dependencies

For JavaScript rendering on Linux, install WebKit:

```bash
# WPE WebKit (recommended for headless/server use)
# Ubuntu/Debian
sudo apt-get install libwpewebkit-1.1-dev libwpe-1.0-dev

# Fedora
sudo dnf install wpewebkit-devel wpebackend-fdo-devel

# WebKitGTK (requires display server)
# Ubuntu/Debian
sudo apt-get install libwebkit2gtk-4.1-dev xvfb

# Run with virtual framebuffer
xvfb-run swift run myapp
```

## How to Use

### iOS / macOS App

Use `SwiftHeadlessWebKitApple` for full WebKit support with JavaScript execution.

**1. Add dependency to your Xcode project:**

File → Add Package Dependencies → Enter URL:
```
https://github.com/anthropics/SwiftHeadlessWebKit.git
```

**2. Import and use in your app:**

```swift
import SwiftHeadlessWebKitApple

class WebScraperViewModel: ObservableObject {
    @Published var results: [String] = []

    @MainActor
    func scrapeWebsite() async {
        let browser = WKZombie(name: "MyApp", processPool: nil)

        do {
            // Open a webpage
            let page: HTMLPage = try await browser.open(
                url: URL(string: "https://example.com")!
            ).execute()

            // Find all links
            let linksResult = page.findElements(.cssSelector("a.product-link"))

            if case .success(let links) = linksResult {
                results = links.compactMap { $0.objectForKey("href") }
            }
        } catch {
            print("Scraping failed: \(error)")
        }
    }
}
```

**3. Form submission with JavaScript:**

```swift
@MainActor
func login(username: String, password: String) async throws -> HTMLPage {
    let browser = WKZombie(name: "LoginBot", processPool: nil)

    // Open login page
    let page: HTMLPage = try await browser.open(url: loginURL).execute()

    // Find and fill form
    let form: HTMLForm = try await browser.get(by: .id("loginForm"))(page).execute()

    // Set form values using JavaScript
    _ = try await browser.execute("document.getElementById('username').value = '\(username)'")(page).execute()
    _ = try await browser.execute("document.getElementById('password').value = '\(password)'")(page).execute()

    // Submit form
    let resultPage: HTMLPage = try await browser.submit(form).execute()
    return resultPage
}
```

**4. Taking snapshots (iOS):**

```swift
import SwiftHeadlessWebKitApple

@MainActor
func captureScreenshot() async throws -> UIImage? {
    let browser = WKZombie(name: "Snapshot", processPool: nil)

    let page: HTMLPage = try await browser.open(url: targetURL).execute()

    var capturedImage: UIImage?
    let _: HTMLPage = try await browser.snap(page) { snapshot in
        capturedImage = snapshot.image
    }.execute()

    return capturedImage
}
```

---

### Vapor Server (Linux / Server-Side Swift)

Use `SwiftHeadlessWebKit` for cross-platform headless browsing without WebKit dependency.

**1. Add to your `Package.swift`:**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyVaporApp",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/anthropics/SwiftHeadlessWebKit.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftHeadlessWebKit", package: "SwiftHeadlessWebKit")
            ]
        )
    ]
)
```

**2. Create a scraping service:**

```swift
import Vapor
import SwiftHeadlessWebKit

struct ScrapingService: Sendable {

    func scrapeProducts(from url: URL) async throws -> [Product] {
        let browser = WKZombie(name: "VaporScraper")

        // Fetch and parse the page
        let page: HTMLPage = try await browser.open(url: url).execute()

        // Find product elements
        let productsResult = page.findElements(.cssSelector("div.product-card"))

        guard case .success(let productElements) = productsResult else {
            return []
        }

        return productElements.compactMap { element -> Product? in
            guard let name = element.text,
                  let price = element.objectForKey("data-price") else {
                return nil
            }
            return Product(name: name, price: price)
        }
    }

    func fetchJSON<T: JSONDecodable>(from url: URL) async throws -> T {
        let browser = WKZombie(name: "APIClient")
        let jsonPage: JSONPage = try await browser.open(url: url).execute()
        return try await browser.decode(jsonPage).execute()
    }
}

struct Product: Content {
    let name: String
    let price: String
}
```

**3. Create Vapor routes:**

```swift
import Vapor
import SwiftHeadlessWebKit

func routes(_ app: Application) throws {
    let scraper = ScrapingService()

    // Scrape products endpoint
    app.get("scrape", "products") { req async throws -> [Product] in
        guard let urlString = req.query[String.self, at: "url"],
              let url = URL(string: urlString) else {
            throw Abort(.badRequest, reason: "Invalid URL")
        }
        return try await scraper.scrapeProducts(from: url)
    }

    // Scrape page title
    app.get("scrape", "title") { req async throws -> String in
        guard let urlString = req.query[String.self, at: "url"],
              let url = URL(string: urlString) else {
            throw Abort(.badRequest, reason: "Invalid URL")
        }

        let browser = WKZombie()
        let page: HTMLPage = try await browser.open(url: url).execute()

        let titleResult = page.findElements(.cssSelector("title"))
        if case .success(let titles) = titleResult, let title = titles.first {
            return title.text ?? "No title"
        }
        return "No title found"
    }

    // Health check
    app.get("health") { req -> String in
        return "OK"
    }
}
```

**4. Configure with custom settings:**

```swift
import SwiftHeadlessWebKit

// Custom engine with timeout and user agent
let engine = HeadlessEngine(
    userAgent: "MyVaporBot/1.0 (Server-Side Swift)",
    timeoutInSeconds: 60.0
)

let browser = WKZombie(name: "CustomBot", engine: engine)
```

**5. Deploy to Linux:**

```dockerfile
# Dockerfile
FROM swift:6.0-jammy as builder
WORKDIR /app
COPY . .
RUN swift build -c release

FROM swift:6.0-jammy-slim
WORKDIR /app
COPY --from=builder /app/.build/release/App .
EXPOSE 8080
CMD ["./App", "serve", "--env", "production", "--hostname", "0.0.0.0"]
```

```bash
# Build and run
docker build -t my-vapor-scraper .
docker run -p 8080:8080 my-vapor-scraper

# Test the endpoint
curl "http://localhost:8080/scrape/title?url=https://example.com"
```

---

### Chaining Actions

```swift
// Actions can be chained using andThen
let result = browser.open(url: startURL)
    .andThen { page in
        browser.get(by: .id("searchForm"))(page)
    }
    .andThen { form in
        browser.submit(form)
    }

let finalPage: HTMLPage = try await result.execute()
```

## Search Types

Find elements using CSS selectors:

| SearchType | Example | CSS Query |
|------------|---------|-----------|
| `.id(String)` | `.id("header")` | `#header` |
| `.name(String)` | `.name("email")` | `[name='email']` |
| `.class(String)` | `.class("btn")` | `.btn` |
| `.text(String)` | `.text("Submit")` | `:contains('Submit')` |
| `.attribute(String, String)` | `.attribute("data-id", "123")` | `[data-id='123']` |
| `.contains(String, String)` | `.contains("href", "/login")` | `[href*='/login']` |
| `.cssSelector(String)` | `.cssSelector("div.card > a")` | `div.card > a` |

## HTML Elements

Available element types:

- `HTMLPage` - Represents a parsed HTML document
- `HTMLElement` - Base class for all elements
- `HTMLForm` - Form elements with input handling
- `HTMLLink` - Anchor elements
- `HTMLButton` - Button elements
- `HTMLImage` - Image elements
- `HTMLTable`, `HTMLTableRow`, `HTMLTableColumn` - Table elements
- `HTMLFrame` - iframe elements

## JSON Support

```swift
// Open JSON endpoint
let jsonPage: JSONPage = try await browser.open(url: apiURL).execute()

// Access JSON content
if let json = jsonPage.content() {
    // Process JSON data
}

// Decode into model
struct Book: JSONDecodable {
    let title: String

    static func decode(_ json: JSONElement) -> Book? {
        guard let title = json["title"] as? String else { return nil }
        return Book(title: title)
    }
}

let book: Book = try await browser.decode(jsonPage).execute()
```

## Configuration

### Logging

```swift
Logger.enabled = false  // Disable logging
```

### Timeout

```swift
let engine = HeadlessEngine(timeoutInSeconds: 60.0)
let browser = WKZombie(engine: engine)
```

### User Agent

```swift
let engine = HeadlessEngine(userAgent: "MyBot/1.0")
let browser = WKZombie(engine: engine)
```

## Testing

The project uses the Swift Testing framework:

```bash
swift test
```

## Running GitHub Actions Locally

You can run the CI workflow locally using [act](https://github.com/nektos/act), which simulates GitHub Actions on your machine.

### Install act

```bash
brew install act
```

### Run CI Locally

Run all jobs with self-hosted runner simulation:

```bash
# Run macOS job
act -P macos-latest=-self-hosted

# Run Ubuntu/Linux job
act -P ubuntu-latest=-self-hosted

# Run Windows job (if applicable)
act -P windows-latest=-self-hosted
```

### Run Specific Jobs

```bash
# Run only the macOS build job
act -j build-macos -P macos-latest=-self-hosted

# Run only the Linux build job
act -j build-linux -P ubuntu-latest=-self-hosted
```

### Run with Verbose Output

```bash
act -P macos-latest=-self-hosted -v
```

### List Available Jobs

```bash
act -l
```

> **Note**: The `-self-hosted` flag tells act to use your local machine instead of Docker containers, which is useful for Swift builds that require Xcode or specific toolchains.

## Migration from WKZombie

### Key Changes

1. **Swift 6 Concurrency**: All async operations use `async/await`
2. **CSS Selectors**: XPath queries replaced with CSS selectors
3. **Module Split**: Core functionality separated from WebKit-specific features
4. **SPM Only**: CocoaPods and Carthage support removed

### Migration Examples

```swift
// Before (WKZombie)
browser.open(url)
>>> browser.get(by: .XPathQuery("//div[@id='content']"))
=== handleResult

// After (SwiftHeadlessWebKit)
let page = try await browser.open(url: url).execute()
let element = try await browser.get(by: .id("content"))(page).execute()
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

- Original [WKZombie](https://github.com/mkoehnke/WKZombie) by [Mathias Köhnke](https://twitter.com/mkoehnke)
- Swift 6 migration and modernization by [Claude Code](https://claude.ai/claude-code)
- HTML parsing powered by [SwiftSoup](https://github.com/scinfu/SwiftSoup)

## License

SwiftHeadlessWebKit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.
