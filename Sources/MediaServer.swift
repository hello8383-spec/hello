import Foundation
import Network

struct Media: Equatable {
    var title = "Unknown video"
    var channel = ""
    var state = "playing"
    var videoId = ""
    var thumbnailUrl = ""
    var currentTime = 0.0
    var totalTime = 0.0
}

/// HTTP server on 0.0.0.0:5001, same API as the desktop app:
///   POST /update  (title, channel, state, video_id, thumbnail_url, current_time, total_time)
///   GET  /health
final class MediaServer {
    static let port: UInt16 = 5001
    var onMedia: ((Media) -> Void)?
    var onStatus: ((String) -> Void)?
    var healthProvider: (() -> [String: Any])?

    private var listener: NWListener?
    private let lock = NSLock()
    private var last = (title: "", currentTime: -1.0, time: Date.distantPast)

    func start() {
        listener?.cancel()
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: Self.port)!)
            l.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready: self?.onStatus?("Listening on port \(Self.port)")
                case .failed(let e):
                    self?.onStatus?("Server failed: \(e.localizedDescription), retrying")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self?.start() }
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] c in
                c.start(queue: .global(qos: .userInitiated))
                self?.receive(c, buffer: Data())
            }
            l.start(queue: .global(qos: .userInitiated))
            listener = l
        } catch {
            onStatus?("Server error: \(error.localizedDescription)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in self?.start() }
        }
    }

    private func receive(_ c: NWConnection, buffer: Data) {
        c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self else { return }
            var buf = buffer
            if let data { buf.append(data) }
            if let req = Self.parse(buf) { self.respond(req, on: c); return }
            if complete || error != nil { c.cancel(); return }
            self.receive(c, buffer: buf)
        }
    }

    private struct Request { let method: String; let path: String; let body: Data }

    private static func parse(_ data: Data) -> Request? {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let head = String(decoding: data[..<sep.lowerBound], as: UTF8.self)
        let lines = head.components(separatedBy: "\r\n")
        let first = lines[0].split(separator: " ")
        guard first.count >= 2 else { return nil }
        var length = 0
        for l in lines.dropFirst() where l.lowercased().hasPrefix("content-length:") {
            length = Int(l.dropFirst(15).trimmingCharacters(in: .whitespaces)) ?? 0
        }
        let body = data[sep.upperBound...]
        guard body.count >= length else { return nil }
        return Request(method: String(first[0]), path: String(first[1]), body: Data(body.prefix(length)))
    }

    private func respond(_ req: Request, on c: NWConnection) {
        var status = "200 OK"
        var json: [String: Any] = ["ok": true]

        switch (req.method, req.path) {
        case ("POST", "/update"):
            if let o = try? JSONSerialization.jsonObject(with: req.body) as? [String: Any] {
                if let m = accept(o) { DispatchQueue.main.async { self.onMedia?(m) } }
                else { json["skipped"] = true }
            } else { status = "400 Bad Request"; json = ["ok": false] }
        case ("GET", "/health"):
            json = healthProvider?() ?? ["ok": true]
        case ("OPTIONS", _):
            status = "204 No Content"
        default:
            status = "404 Not Found"; json = ["ok": false]
        }

        let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data("{}".utf8)
        let head = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        c.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in c.cancel() })
    }

    /// Same de-dupe as the desktop app: drop identical "playing" ticks within 1s.
    private func accept(_ o: [String: Any]) -> Media? {
        func num(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }
        var m = Media()
        m.title = (o["title"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown video"
        m.channel = o["channel"] as? String ?? ""
        m.state = o["state"] as? String ?? "playing"
        m.videoId = o["video_id"] as? String ?? ""
        m.thumbnailUrl = o["thumbnail_url"] as? String ?? ""
        m.currentTime = num(o["current_time"])
        m.totalTime = num(o["total_time"])

        lock.lock(); defer { lock.unlock() }
        let now = Date()
        if m.state == "playing", m.title == last.title, m.currentTime == last.currentTime,
           now.timeIntervalSince(last.time) < 1 { return nil }
        last = (m.title, m.currentTime, now)
        return m
    }

    static func localIP() -> String {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else { return "127.0.0.1" }
        defer { freeifaddrs(addrs) }
        var fallback: String?
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = p.pointee
            guard i.ifa_addr.pointee.sa_family == UInt8(AF_INET), (i.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(i.ifa_addr, socklen_t(i.ifa_addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            let ip = String(cString: host)
            if String(cString: i.ifa_name) == "en0" { return ip }
            fallback = fallback ?? ip
        }
        return fallback ?? "127.0.0.1"
    }
}
