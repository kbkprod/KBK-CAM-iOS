import Foundation
import Network

/// Tiny HTTP server for the remote control: another phone on the same Wi-Fi opens
/// http://<this-iphone-ip>:<port> and gets buttons for points, clock, undo and highlights.
final class RemoteServer {
    typealias Handler = (_ cmd: String, _ arg: String) async -> String

    private var listener: NWListener?
    private let port: UInt16
    private let handler: Handler

    init(port: UInt16, handler: @escaping Handler) {
        self.port = port
        self.handler = handler
    }

    func start() {
        guard listener == nil, let p = NWEndpoint.Port(rawValue: port),
              let l = try? NWListener(using: .tcp, on: p) else { return }
        l.newConnectionHandler = { [weak self] c in self?.serve(c) }
        l.start(queue: .global(qos: .userInitiated))
        listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func serve(_ c: NWConnection) {
        c.start(queue: .global(qos: .userInitiated))
        c.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, _, _ in
            guard let self, let data, let req = String(data: data, encoding: .utf8) else { c.cancel(); return }
            let firstLine = req.components(separatedBy: "\r\n").first ?? ""
            let parts = firstLine.split(separator: " ")
            let path = parts.count > 1 ? String(parts[1]) : "/"
            Task {
                let (status, type, body) = await self.respond(path)
                let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n"
                    + "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
                var out = Data(head.utf8)
                out.append(body)
                c.send(content: out, completion: .contentProcessed { _ in c.cancel() })
            }
        }
    }

    private func respond(_ path: String) async -> (String, String, Data) {
        if path == "/" || path.hasPrefix("/index") {
            let data = Bundle.main.url(forResource: "remote", withExtension: "html").flatMap { try? Data(contentsOf: $0) } ?? Data()
            return ("200 OK", "text/html; charset=utf-8", data)
        }
        if path.hasPrefix("/api/") {
            var cmd = String(path.dropFirst(5))
            var arg = ""
            if let q = cmd.firstIndex(of: "?") {
                arg = String(cmd[cmd.index(after: q)...])
                cmd = String(cmd[..<q])
            }
            if arg.hasPrefix("t=") { arg = String(arg.dropFirst(2)) }
            let json = await handler(cmd, arg)
            return ("200 OK", "application/json; charset=utf-8", Data(json.utf8))
        }
        return ("404 Not Found", "text/plain", Data("not found".utf8))
    }

    /// The iPhone's Wi-Fi (or hotspot) IPv4 address.
    static func localIP() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var fallback: String?
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard let sa = ptr.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET),
                  (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: host)
            let name = String(cString: ptr.pointee.ifa_name)
            if name == "en0" { return ip }
            if name.hasPrefix("bridge") || fallback == nil { fallback = ip }
        }
        return fallback
    }
}
