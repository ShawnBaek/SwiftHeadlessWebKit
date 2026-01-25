# SwiftHeadlessWebKit

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat)](https://swift.org)
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
```

## Quick Start

### Basic Usage (Cross-Platform)

```swift
import SwiftHeadlessWebKit

let browser = WKZombie()

// Open a URL and parse HTML
let page: HTMLPage = try await browser.open(url: myURL).execute()

// Find elements using CSS selectors
let links = page.findElements(.class("nav-link"))

// Get element attributes
for case .success(let elements) in [links] {
    for link in elements {
        print(link.objectForKey("href"))
    }
}
```

### With WebKit (Apple Platforms)

```swift
import SwiftHeadlessWebKitApple

@MainActor
func scrapeWithJS() async throws {
    let browser = WKZombie(name: "MyScraper", processPool: nil)

    // Open page with full JavaScript support
    let page: HTMLPage = try await browser.open(url: loginURL).execute()

    // Find and submit form
    let form = try await browser.get(by: .name("loginForm"))(page).execute()
    let resultPage: HTMLPage = try await browser.submit(form).execute()
}
```

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
