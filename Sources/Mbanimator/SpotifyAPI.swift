import Foundation
import AppKit
import Network

struct SpotifyTrack {
    let name: String
    let artist: String
    let isPlaying: Bool
}

class SpotifyAPI {
    static let shared = SpotifyAPI()
    private init() {}

    private let clientID     = "***REMOVED***"
    private let clientSecret = "***REMOVED***"
    private let redirectURI  = "http://127.0.0.1:5173/callback"
    private let scopes       = "user-read-currently-playing user-read-playback-state user-modify-playback-state"

    private var accessToken: String? {
        get { UserDefaults.standard.string(forKey: "sp_access") }
        set { UserDefaults.standard.set(newValue, forKey: "sp_access") }
    }
    var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "sp_refresh") }
        set { UserDefaults.standard.set(newValue, forKey: "sp_refresh") }
    }
    private var tokenExpiry: Date? {
        get { UserDefaults.standard.object(forKey: "sp_expiry") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "sp_expiry") }
    }

    var isAuthenticated: Bool { refreshToken != nil }

    private var listener: NWListener?

    // MARK: - Auth

    func authenticate(completion: @escaping (Bool) -> Void) {
        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",     value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri",  value: redirectURI),
            URLQueryItem(name: "scope",         value: scopes),
        ]
        NSWorkspace.shared.open(comps.url!)
        startCallbackServer(completion: completion)
    }

    func disconnect() {
        accessToken = nil
        refreshToken = nil
        tokenExpiry  = nil
    }

    // MARK: - Currently Playing

    func currentlyPlaying(completion: @escaping (SpotifyTrack?) -> Void) {
        ensureValidToken { [weak self] ok in
            guard ok, let token = self?.accessToken else { completion(nil); return }
            var req = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { data, resp, _ in
                guard
                    let data, !data.isEmpty,
                    let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let item    = json["item"] as? [String: Any],
                    let name    = item["name"] as? String,
                    let artists = item["artists"] as? [[String: Any]],
                    let artist  = artists.first?["name"] as? String,
                    let playing = json["is_playing"] as? Bool
                else { completion(nil); return }
                completion(SpotifyTrack(name: name, artist: artist, isPlaying: playing))
            }.resume()
        }
    }

    // MARK: - Playback Controls

    func play(completion: (() -> Void)? = nil) {
        playerRequest(method: "PUT", path: "/v1/me/player/play", completion: completion)
    }

    func pause(completion: (() -> Void)? = nil) {
        playerRequest(method: "PUT", path: "/v1/me/player/pause", completion: completion)
    }

    func nextTrack(completion: (() -> Void)? = nil) {
        playerRequest(method: "POST", path: "/v1/me/player/next", completion: completion)
    }

    func previousTrack(completion: (() -> Void)? = nil) {
        playerRequest(method: "POST", path: "/v1/me/player/previous", completion: completion)
    }

    // MARK: - Private

    private func playerRequest(method: String, path: String, completion: (() -> Void)?) {
        ensureValidToken { [weak self] ok in
            guard ok, let token = self?.accessToken else { return }
            var req = URLRequest(url: URL(string: "https://api.spotify.com\(path)")!)
            req.httpMethod = method
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: req) { _, _, _ in
                DispatchQueue.main.async { completion?() }
            }.resume()
        }
    }

    private func ensureValidToken(completion: @escaping (Bool) -> Void) {
        if let expiry = tokenExpiry, Date() < expiry, accessToken != nil {
            completion(true)
            return
        }
        guard let refresh = refreshToken else { completion(false); return }
        refreshAccessToken(refreshToken: refresh, completion: completion)
    }

    private func refreshAccessToken(refreshToken: String, completion: @escaping (Bool) -> Void) {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("Basic \(basicAuth)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody(["grant_type": "refresh_token", "refresh_token": refreshToken])
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard
                let data,
                let json      = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let access    = json["access_token"] as? String,
                let expiresIn = json["expires_in"] as? Int
            else { DispatchQueue.main.async { completion(false) }; return }
            DispatchQueue.main.async {
                self?.accessToken  = access
                self?.tokenExpiry  = Date().addingTimeInterval(Double(expiresIn) - 60)
                if let newRefresh = json["refresh_token"] as? String { self?.refreshToken = newRefresh }
                completion(true)
            }
        }.resume()
    }

    private func exchangeCode(_ code: String, completion: @escaping (Bool) -> Void) {
        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("Basic \(basicAuth)", forHTTPHeaderField: "Authorization")
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.httpBody = formBody([
            "grant_type":   "authorization_code",
            "code":         code,
            "redirect_uri": redirectURI,
        ])
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard
                let data,
                let json      = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let access    = json["access_token"] as? String,
                let refresh   = json["refresh_token"] as? String,
                let expiresIn = json["expires_in"] as? Int
            else { DispatchQueue.main.async { completion(false) }; return }
            DispatchQueue.main.async {
                self?.accessToken  = access
                self?.refreshToken = refresh
                self?.tokenExpiry  = Date().addingTimeInterval(Double(expiresIn) - 60)
                completion(true)
            }
        }.resume()
    }

    private func startCallbackServer(completion: @escaping (Bool) -> Void) {
        listener?.cancel()
        guard let listener = try? NWListener(using: .tcp, on: 5173) else {
            completion(false)
            return
        }
        self.listener = listener
        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
                let html = "<html><body style='font-family:system-ui;text-align:center;padding:60px'><h2>✅ Erfolgreich verbunden!</h2><p>Du kannst dieses Fenster schließen.</p></body></html>"
                let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
                conn.send(content: response.data(using: .utf8), completion: .idempotent)

                self?.listener?.cancel()
                self?.listener = nil

                guard
                    let data,
                    let req       = String(data: data, encoding: .utf8),
                    let firstLine = req.components(separatedBy: "\r\n").first,
                    let path      = firstLine.components(separatedBy: " ").dropFirst().first,
                    let comps     = URLComponents(string: "http://localhost\(path)"),
                    let code      = comps.queryItems?.first(where: { $0.name == "code" })?.value
                else { DispatchQueue.main.async { completion(false) }; return }

                self?.exchangeCode(code, completion: completion)
            }
        }
        listener.start(queue: .main)
    }

    private var basicAuth: String {
        Data("\(clientID):\(clientSecret)".utf8).base64EncodedString()
    }

    private func formBody(_ params: [String: String]) -> Data {
        var comps = URLComponents()
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        return (comps.percentEncodedQuery ?? "").data(using: .utf8) ?? Data()
    }
}
