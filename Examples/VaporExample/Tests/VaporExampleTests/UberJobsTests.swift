//
// UberJobsTests.swift
//
// Copyright (c) 2025 Shawn Baek
//
// Test case for SwiftHeadlessWebKit + Vapor integration on Linux
//

import XCTVapor
@testable import VaporExample

final class UberJobsTests: XCTestCase {

    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try routes(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
    }

    // MARK: - Uber Jobs Test (Same as WKZombieTests but via Vapor)

    func testScrapeUberCareers() async throws {
        try await app.test(.GET, "scrape/uber") { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(ScrapeResponse.self)

            // Log test results (same format as WKZombieTests)
            print("========================================")
            print("VAPOR_UBER_JOBS_TEST_PLATFORM: \(response.platform)")
            print("========================================")
            print("VAPOR_UBER_JOBS_URL: \(response.url)")
            print("VAPOR_UBER_JOBS_HTML_LENGTH: \(response.htmlLength)")
            print("VAPOR_UBER_JOBS_EXTRACTED_COUNT: \(response.jobsFound)")

            if !response.jobs.isEmpty {
                print("VAPOR_UBER_JOBS_EXTRACTED_TITLES:")
                for (index, job) in response.jobs.prefix(10).enumerated() {
                    print("  [\(index + 1)] \(job.title)")
                }
            }

            print("========================================")
            print("VAPOR_UBER_JOBS_TEST_COMPLETE: \(response.platform)")
            print("========================================")

            // Assertions
            XCTAssertGreaterThan(response.htmlLength, 0, "HTML should not be empty")
            XCTAssertGreaterThan(response.jobsFound, 0, "Should extract at least 1 job")

            #if os(Linux)
            XCTAssertEqual(response.platform, "Linux")
            #elseif os(macOS)
            XCTAssertEqual(response.platform, "macOS")
            #endif
        }
    }

    func testHealthCheck() async throws {
        try await app.test(.GET, "/") { res async throws in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "SwiftHeadlessWebKit + Vapor is running!")
        }
    }

    func testGenericScrape() async throws {
        try await app.test(.GET, "scrape?url=https://example.com") { res async throws in
            XCTAssertEqual(res.status, .ok)

            let response = try res.content.decode(ScrapeResponse.self)
            XCTAssertGreaterThan(response.htmlLength, 0)
            XCTAssertEqual(response.url, "https://example.com")
        }
    }

    func testMissingURL() async throws {
        try await app.test(.GET, "scrape") { res async throws in
            XCTAssertEqual(res.status, .badRequest)
        }
    }
}
