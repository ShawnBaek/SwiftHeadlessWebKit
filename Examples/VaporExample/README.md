# Vapor + SwiftHeadlessWebKit Example

This example demonstrates how to use **SwiftHeadlessWebKit** with **Vapor** for web scraping on Linux servers.

## Features

- Scrape Uber careers page and extract job listings
- Generic URL scraping endpoint
- Full JavaScript rendering support
- Works on both macOS and Linux

## Running the Server

```bash
cd Examples/VaporExample
swift run
```

Server starts at `http://localhost:8080`

## API Endpoints

### Health Check
```bash
curl http://localhost:8080/
```

### Scrape Uber Careers
```bash
curl http://localhost:8080/scrape/uber
```

Response:
```json
{
  "platform": "Linux",
  "url": "https://www.uber.com/us/en/careers/list/",
  "jobsFound": 10,
  "jobs": [
    {"title": "Software Engineer", "url": "/careers/..."},
    ...
  ],
  "htmlLength": 327330
}
```

### Generic Scrape
```bash
curl "http://localhost:8080/scrape?url=https://example.com"
```

## Running Tests

```bash
cd Examples/VaporExample
swift test
```

The test output will show:
- Platform (Linux/macOS)
- HTML length fetched
- Number of jobs extracted
- Extracted job titles

## Linux Deployment

This example works great on Linux servers:

```bash
# Build release
swift build -c release

# Run
.build/release/VaporExample
```

## Docker

```dockerfile
FROM swift:latest
WORKDIR /app
COPY . .
RUN swift build -c release
CMD [".build/release/VaporExample"]
```
