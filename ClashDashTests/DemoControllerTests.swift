import XCTest
@testable import ClashDash

final class DemoControllerTests: XCTestCase {
    private var server = ClashServer.demo
    override func setUp() async throws {
        DemoController.shared.reset()
        let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
            LocalDemoServer.shared.start { continuation.resume(with: $0) }
        }
        server.port = String(port)
    }

    func testListenerRestartsWithWorkingHTTPAndWebSockets() async throws {
        let local = LocalDemoServer()
        func start() async throws -> ClashServer {
            let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
                local.start { continuation.resume(with: $0) }
            }
            var endpoint = ClashServer.demo
            endpoint.port = String(port)
            return endpoint
        }
        var endpoint = try await start()
        let api = ClashAPI()
        let initialVersion = try await api.getVersion(endpoint)
        XCTAssertTrue(initialVersion.contains("Demo"))
        try await api.selectProxy(server: endpoint, groupName: "Demo Proxy", proxyName: "🇯🇵 Tokyo")
        // Exercise repeated background/foreground cycles; stale cancellation
        // callbacks must never clear a newly ready listener's endpoint.
        for _ in 0..<3 {
            let oldSocket = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(endpoint.port)/traffic")!)
            oldSocket.resume()
            _ = try await oldSocket.receive()
            await withCheckedContinuation { continuation in
                local.stop { continuation.resume() }
            }
            oldSocket.cancel(with: .goingAway, reason: nil)
            endpoint = try await start()
            let version = try await api.getVersion(endpoint)
            XCTAssertTrue(version.contains("Demo"))
            let proxies = try await api.fetchProxies(server: endpoint)
            XCTAssertEqual(proxies.first { $0.name == "Demo Proxy" }?.now, "🇯🇵 Tokyo")
            let socket = URLSession.shared.webSocketTask(with: URL(string: "ws://127.0.0.1:\(endpoint.port)/traffic")!)
            socket.resume()
            let message = try await socket.receive()
            socket.cancel(with: .goingAway, reason: nil)
            if case .string(let text) = message {
                XCTAssertGreaterThan(try JSONDecoder().decode(TrafficData.self, from: Data(text.utf8)).down, 0)
            } else { XCTFail("Expected traffic JSON") }
        }
        await withCheckedContinuation { continuation in
            local.stop { continuation.resume() }
        }
    }

    func testNewListenerGenerationChangesConnectionIdentityEvenOnSamePort() throws {
        var endpoint = server
        let original = endpoint.connectionIdentifier
        endpoint.connectionGeneration = UUID()
        XCTAssertNotEqual(endpoint.connectionIdentifier, original)
        let restored = try JSONDecoder().decode(ClashServer.self, from: JSONEncoder().encode(endpoint))
        XCTAssertEqual(restored.connectionIdentifier, endpoint.connectionIdentifier)
        endpoint.status = .error
        XCTAssertEqual(endpoint.connectionIdentifier, restored.connectionIdentifier)
    }

    @MainActor
    func testClientsIgnoreOldEndpointFailuresAfterRecovery() async throws {
        let local = LocalDemoServer()
        func start() async throws -> ClashServer {
            let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
                local.start { continuation.resume(with: $0) }
            }
            var endpoint = ClashServer.demo
            endpoint.port = String(port)
            endpoint.connectionGeneration = UUID()
            return endpoint
        }
        let oldEndpoint = try await start()
        let monitor = NetworkMonitor()
        let connections = ConnectionsViewModel()
        monitor.startMonitoring(server: oldEndpoint)
        await withCheckedContinuation { continuation in
            local.stop { continuation.resume() }
        }
        let recovered = try await start()
        // The old HTTP probe completes asynchronously after the replacement.
        connections.startMonitoring(server: oldEndpoint)
        connections.stopMonitoring()
        connections.startMonitoring(server: recovered)
        monitor.restartMonitoring(server: recovered)
        defer { monitor.stopMonitoring(); connections.stopMonitoring(); local.stop() }
        // Include the delayed retry interval so obsolete retries have time to fire.
        try await Task.sleep(nanoseconds: 4_000_000_000)
        XCTAssertEqual(connections.connectionState, .connected)
        XCTAssertTrue(connections.isMonitoring)
        XCTAssertEqual(connections.connections.filter(\.isAlive).count, 3)
        XCTAssertEqual(monitor.activeConnections, 3)
        XCTAssertNotEqual(monitor.downloadSpeed, "0 B/s")
    }

    func testDemoUsesAnOrdinaryLoopbackServer() {
        XCTAssertTrue(ClashServer.demo.isDemo)
        XCTAssertTrue(server.isValid)
        XCTAssertEqual(server.host, "127.0.0.1")
        XCTAssertFalse(server.useSSL)
    }

    func testOfflineAPISelectionAndRuleToggle() async throws {
        let api = ClashAPI()
        let version = try await api.getVersion(server)
        XCTAssertTrue(version.contains("Demo"))
        let providers = try await api.fetchProxyProviders(server: server)
        XCTAssertEqual(providers.first?.proxies.count, 4)
        XCTAssertNotNil(providers.first?.subscriptionInfo)
        try await api.selectProxy(server: server, groupName: "Demo Proxy", proxyName: "🇯🇵 Tokyo")
        let proxies = try await api.fetchProxies(server: server)
        XCTAssertEqual(proxies.first { $0.name == "Demo Proxy" }?.now, "🇯🇵 Tokyo")
        try await api.setRuleDisabled(server: server, ruleIndex: 1, disabled: true)
        let disabled = try await api.fetchRules(server: server)
        XCTAssertTrue(disabled[1].isDisabled)
        try await api.setRuleDisabled(server: server, ruleIndex: 1, disabled: false)
        let enabled = try await api.fetchRules(server: server)
        XCTAssertFalse(enabled[1].isDisabled)
        let delays = try await api.testProxyGroupDelay(server: server, groupName: "Demo Proxy", testURL: "https://example.com", timeout: 5000)
        XCTAssertEqual(delays.count, 4)
        try await api.refreshProxyProvider(server: server, name: "Demo Subscription")
        try await api.refreshRulesProvider(server: server, name: "Demo Streaming")
        let ruleProviders = try await api.fetchRuleProviders(server: server)
        XCTAssertEqual(ruleProviders.first?.ruleCount, 128)
    }

    func testStreamsDecodeAndConnectionDeletionIsLocal() throws {
        XCTAssertGreaterThan(try JSONDecoder().decode(TrafficData.self, from: DemoController.shared.stream("traffic")).down, 0)
        XCTAssertGreaterThan(try JSONDecoder().decode(MemoryData.self, from: DemoController.shared.stream("memory")).inuse, 0)
        XCTAssertEqual(try JSONDecoder().decode(ConnectionsData.self, from: DemoController.shared.stream("connections")).connections.count, 3)
        let log = try JSONDecoder().decode(LogMessage.self, from: DemoController.shared.stream("logs"))
        XCTAssertTrue(log.payload.contains("[Demo]"))
        let result = try DemoController.shared.respond(to: server.makeRequest(path: "connections/demo-connection-0", method: "DELETE"))
        XCTAssertEqual(result.0, 204)
        XCTAssertEqual(try JSONDecoder().decode(ConnectionsData.self, from: DemoController.shared.stream("connections")).connections.count, 2)
    }

    func testConfigAndDNSRemainOffline() async throws {
        var request = server.makeRequest(path: "configs", method: "PATCH")
        request.httpBody = Data(#"{"mode":"global","tun":{"enable":true}}"#.utf8)
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 204)
        let (data, _) = try await URLSession.shared.data(for: server.makeRequest(path: "configs"))
        let config = try JSONDecoder().decode(ClashConfig.self, from: data)
        XCTAssertEqual(config.mode, "global")
        XCTAssertEqual(config.tun?.enable, true)
        var dns = server.makeRequest(path: "dns/query")
        dns.url = URL(string: "http://\(server.host):\(server.port)/dns/query?name=example.com&type=AAAA")!
        let (dnsData, _) = try await URLSession.shared.data(for: dns)
        XCTAssertEqual(try JSONDecoder().decode(DNSResponse.self, from: dnsData).Answer?.first?.data, "2001:db8::1")
    }

    func testRealWebSocketTransportReceivesSimulatedTraffic() async throws {
        let url = URL(string: "ws://\(server.host):\(server.port)/traffic")!
        let socket = URLSession.shared.webSocketTask(with: url)
        socket.resume()
        defer { socket.cancel(with: .goingAway, reason: nil) }
        let message = try await socket.receive()
        let data: Data
        switch message {
        case .string(let text): data = Data(text.utf8)
        case .data(let bytes): data = bytes
        @unknown default: XCTFail("Unexpected WebSocket message"); return
        }
        XCTAssertGreaterThan(try JSONDecoder().decode(TrafficData.self, from: data).down, 0)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            socket.sendPing { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
