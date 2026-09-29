import XCTest
@testable import ClashDash

final class ClashAPITests: XCTestCase {
    private var session: URLSession!
    private var api: ClashAPI!
    private var server: ClashServer!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        api = ClashAPI(session: session)
        server = ClashServer(host: "127.0.0.1", port: "9090", secret: "test-secret")
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        session.invalidateAndCancel()
        super.tearDown()
    }

    func testProxyGroupIncludesProviderOnlyAndUnresolvedNodes() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-secret")
            switch request.url?.path {
            case "/proxies":
                return (200, """
                {"proxies":{
                  "shaoshuren-auto":{"name":"shaoshuren-auto","type":"URLTest","alive":true,"history":[],"all":["🇺🇸 Pro-美国 06","Missing node"],"now":"🇺🇸 Pro-美国 06"},
                  "Proxy":{"name":"Proxy","type":"Selector","alive":true,"history":[],"all":["DIRECT"],"now":"DIRECT"},
                  "DIRECT":{"name":"DIRECT","type":"Direct","alive":true,"history":[]}
                }}
                """)
            case "/providers/proxies":
                return (200, """
                {"providers":{"shaoshuren":{"name":"shaoshuren","type":"Proxy","vehicleType":"HTTP","proxies":[
                  {"name":"🇺🇸 Pro-美国 06","type":"Trojan","alive":true,"history":[{"time":"2026-09-29T00:00:00Z","delay":126}]}
                ]}}}
                """)
            default:
                XCTFail("Unexpected request: \(request.url?.absoluteString ?? "nil")")
                return (404, "{}")
            }
        }

        let proxies = try await api.fetchProxies(server: server)
        let providers = try await api.fetchProxyProviders(server: server)
        let catalog = ProxyCatalog(proxies: proxies, providers: providers)
        let group = try XCTUnwrap(catalog.groups.first { $0.name == "shaoshuren-auto" })
        let nodes = catalog.nodes(in: group)
        XCTAssertEqual(nodes.map(\.name), ["🇺🇸 Pro-美国 06", "Missing node"])
        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes.first?.delay, 126)
        XCTAssertEqual(nodes.first?.alive, true)
        XCTAssertNil(nodes.last?.alive)
        XCTAssertEqual(catalog.currentNode(in: group)?.name, "🇺🇸 Pro-美国 06")
        XCTAssertEqual(providers.map(\.name), ["shaoshuren"])
    }

    func testRulesAndProvidersPreserveReturnedData() async throws {
        MockURLProtocol.handler = { request in
            switch request.url?.path {
            case "/rules":
                return (200, """
                {"rules":[
                  {"type":"DOMAIN-SUFFIX","payload":"example.com","proxy":"Proxy"},
                  {"type":"DOMAIN-SUFFIX","payload":"example.com","proxy":"DIRECT"},
                  {"type":"RULE-SET","payload":"social","proxy":"Social","size":42},
                  {"type":"MATCH","payload":"","proxy":"DIRECT"}
                ]}
                """)
            case "/providers/rules":
                return (200, """
                {"providers":{"social":{"name":"social","behavior":"domain","type":"Rule","ruleCount":42,"updatedAt":"2026-09-29T00:00:00Z","vehicleType":"HTTP"}}}
                """)
            default:
                XCTFail("Unexpected request")
                return (404, "{}")
            }
        }

        let rules = try await api.fetchRules(server: server)
        let providers = try await api.fetchRuleProviders(server: server)
        XCTAssertEqual(rules.map(\.type), ["DOMAIN-SUFFIX", "DOMAIN-SUFFIX", "RULE-SET", "MATCH"])
        XCTAssertEqual(rules.map(\.proxy), ["Proxy", "DIRECT", "Social", "DIRECT"])
        XCTAssertNil(rules[0].size)
        XCTAssertEqual(rules[2].size, 42)
        XCTAssertEqual(providers.first?.name, "social")
        XCTAssertEqual(providers.first?.ruleCount, 42)
    }

    func testSelectProxyEncodesGroupPathAndBody() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.url?.path, "/proxies/香港/自动 选择")
            XCTAssertTrue(request.url?.absoluteString.contains("%2F") == true)
            let bodyData: Data
            if let directBody = request.httpBody {
                bodyData = directBody
            } else if let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    data.append(contentsOf: buffer.prefix(count))
                }
                bodyData = data
            } else {
                bodyData = Data()
            }
            let body = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String]
            XCTAssertEqual(body?["name"], "🇺🇸 Pro-美国 06")
            return (204, "")
        }
        try await api.selectProxy(server: server, groupName: "香港/自动 选择", proxyName: "🇺🇸 Pro-美国 06")
    }

    func testDelayRequestEncodesNameAndQueryAndReturnsDelay() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/proxies/🇺🇸 Pro-美国 06/delay")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertEqual(components?.queryItems?.first { $0.name == "url" }?.value, "https://example.com/a?b=1&c=2")
            XCTAssertEqual(components?.queryItems?.first { $0.name == "timeout" }?.value, "5000")
            return (200, "{\"delay\":126}")
        }
        let delay = try await api.testProxyDelay(server: server, proxyName: "🇺🇸 Pro-美国 06", testURL: "https://example.com/a?b=1&c=2", timeout: 5000)
        XCTAssertEqual(delay, 126)
    }

    func testGroupDelayReturnsPerNodeData() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/group/shaoshuren-auto/delay")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first { $0.name == "url" }?.value, "https://example.com/check")
            XCTAssertEqual(query?.first { $0.name == "timeout" }?.value, "3000")
            return (200, "{\"🇺🇸 Pro-美国 06\":126,\"DIRECT\":4}")
        }
        let delays = try await api.testProxyGroupDelay(server: server, groupName: "shaoshuren-auto", testURL: "https://example.com/check", timeout: 3000)
        XCTAssertEqual(delays["🇺🇸 Pro-美国 06"], 126)
        XCTAssertEqual(delays["DIRECT"], 4)
    }

    func testVersionAndRuleProviderRefreshRequests() async throws {
        MockURLProtocol.handler = { request in
            switch request.url?.path {
            case "/version":
                XCTAssertEqual(request.httpMethod, "GET")
                return (200, "{\"version\":\"v1.2.3\",\"meta\":true}")
            case "/providers/rules/social/news":
                XCTAssertEqual(request.httpMethod, "PUT")
                XCTAssertTrue(request.url?.absoluteString.contains("social%2Fnews") == true)
                return (204, "")
            default:
                XCTFail("Unexpected request")
                return (404, "{}")
            }
        }
        let version = try await api.getVersion(server)
        XCTAssertEqual(version, "v1.2.3")
        try await api.refreshRulesProvider(server: server, name: "social/news")
    }

    func testProviderListExcludesCompatibleEntryButKeepsRealProviders() async throws {
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/providers/proxies")
            return (200, """
            {"providers":{
              "default":{"name":"default","type":"Proxy","vehicleType":"Compatible","proxies":[]},
              "shaoshuren":{"name":"shaoshuren","type":"Proxy","vehicleType":"HTTP","proxies":[]},
              "local":{"name":"local","type":"Proxy","vehicleType":"File","proxies":[]}
            }}
            """)
        }
        let providers = try await api.fetchProxyProviders(server: server)
        XCTAssertEqual(providers.map(\.name), ["local", "shaoshuren"])
    }

    func testFetchRejectsUnauthorizedResponseBeforeDecoding() async {
        MockURLProtocol.handler = { _ in (401, "{\"rules\":[]}") }
        do {
            _ = try await api.fetchRules(server: server)
            XCTFail("Expected unauthorized error")
        } catch NetworkError.unauthorized {
            // Expected.
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, String))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let (status, body) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
