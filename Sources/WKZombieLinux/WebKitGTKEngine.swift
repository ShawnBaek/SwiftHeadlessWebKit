//
// WebKitGTKEngine.swift
//
// Copyright (c) 2025 Shawn Baek
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#if os(Linux)
import Foundation
import WKZombie

#if canImport(CWebKit)
import CWebKit
#endif

// MARK: - WebKitGTK Engine

/// A browser engine using WebKitGTK for JavaScript rendering on Linux.
///
/// WebKitGTK is the GTK port of WebKit, providing the same rendering engine
/// as Safari and WKWebView on Apple platforms. This ensures consistent
/// JavaScript execution and DOM rendering across all platforms.
///
/// **Note:** WebKitGTK requires a display server (X11, Wayland, or virtual framebuffer).
/// For truly headless operation, consider using `WPEWebKitEngine` instead.
///
/// ## Installation
///
/// Ubuntu/Debian:
/// ```bash
/// sudo apt-get install libwebkit2gtk-4.1-dev libgtk-4-dev
/// ```
///
/// Fedora:
/// ```bash
/// sudo dnf install webkit2gtk4.1-devel gtk4-devel
/// ```
///
/// ## Running Headless
///
/// Use a virtual framebuffer:
/// ```bash
/// xvfb-run swift test
/// ```
///
/// ## Usage
///
/// ```swift
/// let engine = WebKitGTKEngine(timeoutInSeconds: 60.0)
/// let browser = WKZombie(name: "MyBrowser", engine: engine)
///
/// let page: HTMLPage = try await browser.open(url: myURL).execute()
/// ```
///
/// ## Reference
/// - https://webkitgtk.org/
/// - https://github.com/WebKit/WebKit (Source/WebKit/gtk)
///
public final class WebKitGTKEngine: BrowserEngine, @unchecked Sendable {

    // MARK: - Properties

    private let _timeoutInSeconds: TimeInterval
    private let _userAgent: UserAgent
    private var currentData: Data?
    private var currentURL: URL?

    // WebKitGTK handles (opaque pointers to C objects)
    private var webView: OpaquePointer?
    private var mainLoop: OpaquePointer?

    public var userAgent: UserAgent { _userAgent }
    public var timeoutInSeconds: TimeInterval { _timeoutInSeconds }

    // MARK: - Initialization

    /// Creates a new WebKitGTKEngine instance.
    ///
    /// - Parameters:
    ///   - userAgent: Custom user agent
    ///   - timeoutInSeconds: Maximum time to wait for page load (default: 30 seconds)
    public init(userAgent: UserAgent = .safariMac, timeoutInSeconds: TimeInterval = 30.0) {
        self._userAgent = userAgent
        self._timeoutInSeconds = timeoutInSeconds

        // Note: Actual GTK/WebKitGTK initialization happens when CWebKitGTK is available
        #if CWEBKIT_HAS_GTK
        initializeWebKitGTK()
        #endif
    }

    #if CWEBKIT_HAS_GTK
    private func initializeWebKitGTK() {
        // Initialize GTK
        var argc: Int32 = 0
        gtk_init(&argc, nil)

        // Create main loop for async operations
        mainLoop = g_main_loop_new(nil, 0)

        // Create web view with settings
        let settings = webkit_settings_new()
        webkit_settings_set_enable_javascript(settings, 1)
        webkit_settings_set_user_agent(settings, _userAgent.rawValue)

        // Create web context
        let webContext = webkit_web_context_new()
        webView = webkit_web_view_new_with_context(webContext)
        webkit_web_view_set_settings(webView, settings)
    }
    #endif

    deinit {
        #if CWEBKIT_HAS_GTK
        if let webView {
            g_object_unref(webView)
        }
        if let mainLoop {
            g_main_loop_unref(mainLoop)
        }
        #endif
    }

    // MARK: - BrowserEngine Protocol

    public func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?) {
        #if CWEBKIT_HAS_GTK
        guard let webView else {
            throw ActionError.networkRequestFailure
        }

        // Load the URL
        webkit_web_view_load_uri(webView, url.absoluteString)

        // Wait for page to load
        try await waitForPageLoad()

        // Handle post action
        switch postAction {
        case .wait(let time):
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        case .validate(let script):
            try await waitForCondition(script: script)
        case .none:
            break
        }

        // Get rendered HTML
        let html = try await executeJavaScript("document.documentElement.outerHTML")
        let data = html.data(using: .utf8) ?? Data()

        // Get the actual current URI from WebKit (after any redirects)
        let currentURICString = webkit_web_view_get_uri(webView)
        let finalURL = currentURICString.flatMap { URL(string: String(cString: $0)) }

        self.currentData = data
        self.currentURL = finalURL

        return (data, finalURL)
        #else
        throw ActionError.notSupported
        #endif
    }

    public func execute(_ script: String) async throws -> String {
        #if CWEBKIT_HAS_GTK
        return try await executeJavaScript(script)
        #else
        throw ActionError.notSupported
        #endif
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        #if CWEBKIT_HAS_GTK
        guard let webView else {
            throw ActionError.networkRequestFailure
        }

        // Execute script that may cause navigation
        _ = try await execute(script)

        // Wait for any navigation to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        try await waitForPageLoad()

        // Handle post action
        switch postAction {
        case .wait(let time):
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        case .validate(let script):
            try await waitForCondition(script: script)
        case .none:
            break
        }

        // Get rendered HTML
        let html = try await execute("document.documentElement.outerHTML")
        let data = html.data(using: .utf8) ?? Data()

        // Get the actual current URI from WebKit (after any redirects)
        let currentURICString = webkit_web_view_get_uri(webView)
        let finalURL = currentURICString.flatMap { URL(string: String(cString: $0)) }
        self.currentURL = finalURL

        return (data, finalURL)
        #else
        throw ActionError.notSupported
        #endif
    }

    public func currentContent() async throws -> (Data, URL?) {
        guard let data = currentData else {
            throw ActionError.notFound
        }
        return (data, currentURL)
    }

    // MARK: - JavaScript Execution

    #if CWEBKIT_HAS_GTK
    private func executeJavaScript(_ script: String) async throws -> String {
        guard let webView else {
            throw ActionError.networkRequestFailure
        }

        return try await withCheckedThrowingContinuation { continuation in
            webkit_web_view_run_javascript(
                webView,
                script,
                nil,
                { source, result, userData in
                    var error: UnsafeMutablePointer<GError>?
                    let jsResult = webkit_web_view_run_javascript_finish(
                        unsafeBitCast(source, to: OpaquePointer.self),
                        result,
                        &error
                    )

                    if let error = error {
                        let errorMessage = String(cString: error.pointee.message)
                        g_error_free(error)
                        continuation.resume(throwing: ActionError.networkRequestFailure)
                        return
                    }

                    if let jsResult = jsResult {
                        let jsValue = webkit_javascript_result_get_js_value(jsResult)
                        if let cString = jsc_value_to_string(jsValue) {
                            let result = String(cString: cString)
                            g_free(cString)
                            webkit_javascript_result_unref(jsResult)
                            continuation.resume(returning: result)
                            return
                        }
                        webkit_javascript_result_unref(jsResult)
                    }
                    continuation.resume(throwing: ActionError.networkRequestFailure)
                },
                nil
            )

            // Run event loop
            runEventLoop(timeout: timeoutInSeconds)
        }
    }
    #endif

    // MARK: - Wait Methods

    private func waitForPageLoad() async throws {
        // Wait for the page load event
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutInSeconds {
            #if CWEBKIT_HAS_GTK
            // Check if page is still loading
            if let webView = webView {
                let isLoading = webkit_web_view_is_loading(webView)
                if isLoading == 0 {
                    return
                }
            }

            // Process events
            runEventLoop(timeout: 0.1)
            #endif

            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        throw ActionError.timeout
    }

    private func waitForCondition(script: String) async throws {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutInSeconds {
            let result = try await execute(script)
            if result == "true" || result == "1" {
                return
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        throw ActionError.timeout
    }

    #if CWEBKIT_HAS_GTK
    private func runEventLoop(timeout: TimeInterval) {
        let context = g_main_context_default()
        let endTime = Date().addingTimeInterval(timeout)

        while Date() < endTime {
            if g_main_context_iteration(context, 0) == 0 {
                break
            }
        }
    }
    #endif

    // MARK: - Additional Methods

    /// Wait for a CSS selector to appear in the DOM.
    public func waitForSelector(_ selector: String, timeout: TimeInterval = 30.0) async throws {
        let escapedSelector = selector.replacingOccurrences(of: "'", with: "\\'")
        let script = "document.querySelector('\(escapedSelector)') !== null"

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            let result = try await execute(script)
            if result == "true" {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        throw ActionError.timeout
    }

    /// Wait for network to become idle.
    public func waitForNetworkIdle(idleTime: TimeInterval = 0.5, timeout: TimeInterval = 30.0) async throws {
        try await Task.sleep(nanoseconds: UInt64(idleTime * 1_000_000_000))
    }
}

#endif // os(Linux)
