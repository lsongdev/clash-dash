import Foundation
import Network
import CryptoKit

/// A real, loopback-only Clash HTTP/WebSocket endpoint. The app's normal
/// URLSession transport connects to it just like any remote controller.
final class LocalDemoServer {
    static let shared = LocalDemoServer()
    private let queue = DispatchQueue(label: "org.lsong.clashhandy.demo")
    private var listener: NWListener?
    private var peers: [UUID: DemoPeer] = [:]
    private var port: UInt16?
    private var waiters: [(Result<UInt16, Error>) -> Void] = []

    func start(completion: @escaping (Result<UInt16, Error>) -> Void) {
        queue.async {
            if let port = self.port { completion(.success(port)); return }
            self.waiters.append(completion)
            guard self.listener == nil else { return }
            do {
                let parameters = NWParameters.tcp
                // Never bind 0.0.0.0: the synthetic controller is private to this device.
                parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
                let listener = try NWListener(using: parameters)
                self.listener = listener
                listener.stateUpdateHandler = { [weak self, weak listener] state in
                    guard let self, let listener, self.listener === listener else { return }
                    switch state {
                    case .ready:
                        guard let port = listener.port?.rawValue else { return }
                        self.port = port
                        self.finish(.success(port))
                    case .waiting:
                        self.port = nil
                    case .cancelled:
                        self.stopListening(error: CancellationError())
                    case .failed(let error):
                        self.stopListening(error: error)
                    default: break
                    }
                }
                listener.newConnectionHandler = { [weak self, weak listener] connection in
                    guard let self, let listener, self.listener === listener, self.peers.count < 32 else { connection.cancel(); return }
                    let id = UUID()
                    let peer = DemoPeer(connection: connection, queue: self.queue) { [weak self] in
                        self?.peers.removeValue(forKey: id)
                    }
                    self.peers[id] = peer
                    peer.start()
                }
                listener.start(queue: self.queue)
            } catch { self.finish(.failure(error)) }
        }
    }

    /// Serialize shutdown with startup so delayed callbacks from the cancelled
    /// listener cannot erase the next listener's port or peers.
    func stop(completion: @escaping () -> Void = {}) {
        queue.async {
            self.stopListening(error: CancellationError())
            completion()
        }
    }

    private func stopListening(error: Error) {
        let oldListener = listener
        listener = nil
        port = nil
        oldListener?.cancel()
        let oldPeers = Array(peers.values)
        peers.removeAll()
        oldPeers.forEach { $0.close() }
        finish(.failure(error))
    }

    private func finish(_ result: Result<UInt16, Error>) {
        let callbacks = waiters; waiters = []
        callbacks.forEach { $0(result) }
    }
}

private final class DemoPeer {
    private let connection: NWConnection
    private let queue: DispatchQueue
    private let onClose: () -> Void
    private var buffer = Data()
    private var timer: DispatchSourceTimer?
    private var timeout: DispatchWorkItem?
    private var channel: String?
    private var finished = false
    private var message = Data()

    init(connection: NWConnection, queue: DispatchQueue, onClose: @escaping () -> Void) {
        self.connection = connection; self.queue = queue; self.onClose = onClose
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.close() }
            if case .cancelled = state { self?.close() }
        }
        connection.start(queue: queue)
        let timeout = DispatchWorkItem { [weak self] in self?.close() }
        self.timeout = timeout
        queue.asyncAfter(deadline: .now() + 10, execute: timeout)
        receive()
    }

    private func receive() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, complete, error in
            guard let self, !self.finished else { return }
            if let data { self.buffer.append(data) }
            guard self.buffer.count <= 131072 else { self.close(); return }
            if self.channel == nil { self.readHTTP() } else { self.readFrames() }
            if complete || error != nil { self.close() }
            else if !self.finished { self.receive() }
        }
    }

    private func readHTTP() {
        guard let delimiter = buffer.range(of: Data("\r\n\r\n".utf8)) else {
            if buffer.count > 16384 { close() }; return
        }
        guard let header = String(data: buffer[..<delimiter.lowerBound], encoding: .utf8) else { close(); return }
        let lines = header.components(separatedBy: "\r\n")
        let first = (lines.first ?? "").split(separator: " ")
        guard first.count == 3, first[1].hasPrefix("/"),
              let url = URL(string: "http://127.0.0.1" + String(first[1])) else { close(); return }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { close(); return }
            let key = parts[0].lowercased()
            guard headers[key] == nil else { close(); return }
            headers[key] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        guard headers["transfer-encoding"] == nil else { close(); return }
        let size: Int
        if let length = headers["content-length"] {
            guard let parsed = Int(length), (0...65536).contains(parsed) else { close(); return }
            size = parsed
        } else { size = 0 }
        guard buffer.count >= delimiter.upperBound + size else { return }

        if headers["upgrade"]?.lowercased() == "websocket" {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard first[0] == "GET", ["traffic", "memory", "connections", "logs"].contains(path),
                  headers["sec-websocket-version"] == "13", let key = headers["sec-websocket-key"],
                  Data(base64Encoded: key)?.count == 16 else { close(); return }
            let hash = Insecure.SHA1.hash(data: Data((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").utf8))
            let accept = Data(hash).base64EncodedString()
            channel = path
            buffer.removeFirst(delimiter.upperBound + size)
            timeout?.cancel(); timeout = nil
            send(Data("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n".utf8))
            let timer = DispatchSource.makeTimerSource(queue: queue)
            self.timer = timer
            timer.schedule(deadline: .now(), repeating: 1)
            timer.setEventHandler { [weak self] in
                guard let self, let channel = self.channel else { return }
                self.sendFrame(DemoController.shared.stream(channel), opcode: 1)
            }
            timer.resume()
            readFrames()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = String(first[0])
        request.httpBody = Data(buffer[delimiter.upperBound..<(delimiter.upperBound + size)])
        do {
            let (status, body) = try DemoController.shared.respond(to: request)
            let reason = status == 204 ? "No Content" : status == 200 ? "OK" : status == 400 ? "Bad Request" : "Not Found"
            var data = Data("HTTP/1.1 \(status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".utf8)
            data.append(body)
            timeout?.cancel()
            connection.send(content: data, completion: .contentProcessed { [weak self] _ in self?.close() })
        } catch { close() }
    }

    private func readFrames() {
        while buffer.count >= 2 {
            let bytes = [UInt8](buffer)
            let opcode = bytes[0] & 15
            let final = bytes[0] & 128 != 0
            guard bytes[0] & 112 == 0, bytes[1] & 128 != 0 else { close(); return }
            var length = Int(bytes[1] & 127)
            var offset = 2
            if length == 126 {
                guard bytes.count >= 4 else { return }
                length = Int(bytes[2]) * 256 + Int(bytes[3]); offset = 4
            } else if length == 127 { close(); return }
            guard length <= 65536, opcode < 8 || (final && length <= 125) else { close(); return }
            guard bytes.count >= offset + 4 + length else { return }
            let mask = Array(bytes[offset..<(offset + 4)]); offset += 4
            let payload = Data((0..<length).map { bytes[offset + $0] ^ mask[$0 % 4] })
            buffer.removeFirst(offset + length)
            switch opcode {
            case 8: sendFrame(payload, opcode: 8); close(); return
            case 9: sendFrame(payload, opcode: 10)
            case 10: break
            case 0, 1, 2:
                message.append(payload)
                guard message.count <= 65536 else { close(); return }
                if final {
                    if String(data: message, encoding: .utf8) == "ping" { sendFrame(Data("ping".utf8), opcode: 1) }
                    message.removeAll()
                }
            default: close(); return
            }
        }
    }

    private func sendFrame(_ payload: Data, opcode: UInt8) {
        var frame = Data([128 | opcode])
        if payload.count < 126 { frame.append(UInt8(payload.count)) }
        else { frame.append(126); frame.append(UInt8(payload.count >> 8)); frame.append(UInt8(payload.count & 255)) }
        frame.append(payload); send(frame)
    }
    private func send(_ data: Data) {
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if error != nil { self?.close() }
        })
    }
    fileprivate func close() {
        guard !finished else { return }
        finished = true
        timer?.cancel(); timer = nil
        timeout?.cancel(); timeout = nil
        connection.cancel(); onClose()
    }
}
