import AppKit
import SwiftUI

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem
    private var gifTimer: Timer?
    private var spotifyTimer: Timer?
    private var frames: [NSImage] = []
    private var currentFrame = 0
    private var gifDelay: Double = 0.1
    private var settingsWindow: NSWindow?
    private let library = GIFLibrary()
    private let lastPlayedKey = "last_played"
    private let spotifyModeKey = "spotify_mode"
    private let maxLabelLength = 40
    private var currentTrack: SpotifyTrack? = nil

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Mbanimator")
        setupMenu()
        restoreLastPlayed()
    }

    private func restoreLastPlayed() {
        if UserDefaults.standard.bool(forKey: spotifyModeKey) && SpotifyAPI.shared.isAuthenticated {
            startSpotifyMode()
            return
        }
        guard let last = UserDefaults.standard.string(forKey: lastPlayedKey) else { return }
        if last == "__spinner__" {
            startSpinnerAnimation()
        } else if FileManager.default.fileExists(atPath: last) {
            loadGIF(from: URL(fileURLWithPath: last))
        }
    }

    // MARK: - Menu

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Einstellungen", action: #selector(openSettings), keyEquivalent: ",")
            .with(target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - GIF

    func loadGIF(from url: URL) {
        UserDefaults.standard.set(url.path, forKey: lastPlayedKey)
        guard let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else { return }

        let frameCount = rep.value(forProperty: .frameCount) as? Int ?? 1
        rep.setProperty(.currentFrame, withValue: 0)
        gifDelay = rep.value(forProperty: .currentFrameDuration) as? Double ?? 0.1

        let menuBarSize = NSSize(width: 18, height: 18)
        frames = (0..<frameCount).compactMap { i in
            rep.setProperty(.currentFrame, withValue: i)
            guard let cgImage = rep.cgImage else { return nil }
            let scaled = NSImage(size: menuBarSize)
            scaled.lockFocus()
            NSImage(cgImage: cgImage, size: rep.size).draw(
                in: NSRect(origin: .zero, size: menuBarSize),
                from: NSRect(origin: .zero, size: rep.size),
                operation: .copy, fraction: 1.0)
            scaled.unlockFocus()
            return scaled
        }

        if isSpotifyModeActive {
            // In Spotify mode: GIF will animate when music plays
            updateCombinedDisplay(track: currentTrack)
        } else {
            startGIFAnimation()
        }
    }

    func startSpinnerAnimation() {
        UserDefaults.standard.set("__spinner__", forKey: lastPlayedKey)
        let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        var index = 0
        gifTimer?.invalidate()
        gifTimer = nil
        frames = []
        statusItem.button?.image = nil
        statusItem.button?.title = spinnerFrames[0]
        statusItem.button?.imagePosition = .imageOnly
        statusItem.length = NSStatusItem.variableLength
        gifTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.statusItem.button?.title = spinnerFrames[index]
            index = (index + 1) % spinnerFrames.count
        }
    }

    func stopAnimation() {
        UserDefaults.standard.removeObject(forKey: lastPlayedKey)
        gifTimer?.invalidate()
        gifTimer = nil
        frames = []
        currentFrame = 0
        statusItem.length = NSStatusItem.squareLength
        statusItem.button?.title = ""
        statusItem.button?.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Mbanimator")
        statusItem.button?.imagePosition = .imageOnly
    }

    private func startGIFAnimation() {
        gifTimer?.invalidate()
        currentFrame = 0
        guard !frames.isEmpty else { return }
        statusItem.button?.image = frames[0]
        statusItem.button?.title = ""
        statusItem.button?.imagePosition = .imageOnly
        statusItem.length = NSStatusItem.squareLength
        gifTimer = Timer.scheduledTimer(withTimeInterval: gifDelay, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.currentFrame = (self.currentFrame + 1) % self.frames.count
            self.statusItem.button?.image = self.frames[self.currentFrame]
        }
    }

    private func pauseGIFAnimation() {
        gifTimer?.invalidate()
        gifTimer = nil
        currentFrame = 0
        if !frames.isEmpty {
            statusItem.button?.image = frames[0]
        }
    }

    private func resumeGIFAnimation() {
        guard gifTimer == nil, !frames.isEmpty else { return }
        gifTimer = Timer.scheduledTimer(withTimeInterval: gifDelay, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.currentFrame = (self.currentFrame + 1) % self.frames.count
            self.statusItem.button?.image = self.frames[self.currentFrame]
        }
    }

    // MARK: - Spotify Mode

    var isSpotifyModeActive: Bool { spotifyTimer != nil }

    func startSpotifyMode() {
        UserDefaults.standard.set(true, forKey: spotifyModeKey)
        statusItem.length = NSStatusItem.variableLength
        pollSpotify()
        spotifyTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.pollSpotify()
        }
    }

    func stopSpotifyMode() {
        UserDefaults.standard.set(false, forKey: spotifyModeKey)
        spotifyTimer?.invalidate()
        spotifyTimer = nil
        currentTrack = nil
        // Restore GIF or default icon
        if !frames.isEmpty {
            startGIFAnimation()
        } else {
            pauseGIFAnimation()
            statusItem.length = NSStatusItem.squareLength
            statusItem.button?.title = ""
            statusItem.button?.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Mbanimator")
            statusItem.button?.imagePosition = .imageOnly
        }
    }

    private func pollSpotify() {
        SpotifyAPI.shared.currentlyPlaying { [weak self] track in
            DispatchQueue.main.async {
                self?.currentTrack = track
                self?.updateCombinedDisplay(track: track)
            }
        }
    }

    private func updateCombinedDisplay(track: SpotifyTrack?) {
        let playing = track?.isPlaying == true

        if playing, let track {
            // Song läuft: GIF animiert + Songtext
            let label = truncated("\(track.name)  –  \(track.artist)")
            statusItem.length = NSStatusItem.variableLength
            statusItem.button?.imagePosition = frames.isEmpty ? .noImage : .imageLeft
            statusItem.button?.image = frames.isEmpty ? nil : frames[currentFrame]
            statusItem.button?.title = frames.isEmpty ? label : "  \(label)"
            resumeGIFAnimation()
        } else {
            // Kein Song / pausiert: nur statisches GIF, kein Text
            pauseGIFAnimation()
            statusItem.button?.title = ""
            statusItem.button?.imagePosition = .imageOnly
            if frames.isEmpty {
                statusItem.length = NSStatusItem.squareLength
                statusItem.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Spotify")
            } else {
                statusItem.length = NSStatusItem.squareLength
                statusItem.button?.image = frames[currentFrame]
            }
        }
    }

    // MARK: - Spotify Controls

    func spotifyPlayPause() {
        if let track = currentTrack {
            if track.isPlaying {
                SpotifyAPI.shared.pause { [weak self] in self?.pollSpotify() }
            } else {
                SpotifyAPI.shared.play { [weak self] in self?.pollSpotify() }
            }
        } else {
            SpotifyAPI.shared.play { [weak self] in self?.pollSpotify() }
        }
    }

    func spotifyNextTrack() {
        SpotifyAPI.shared.nextTrack { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.pollSpotify() }
        }
    }

    func spotifyPreviousTrack() {
        SpotifyAPI.shared.previousTrack { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.pollSpotify() }
        }
    }

    // MARK: - Helpers

    private func truncated(_ text: String) -> String {
        guard text.count > maxLabelLength else { return text }
        return String(text.prefix(maxLabelLength)) + "…"
    }

    // MARK: - Settings Window

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 460),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false)
            window.isReleasedWhenClosed = false
            window.title = "Mbanimator"
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView(controller: self, library: library))
            window.delegate = self
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.orderFrontRegardless()
    }
}

extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        settingsWindow = nil
    }
}

private extension NSMenuItem {
    func with(target: AnyObject) -> NSMenuItem {
        self.target = target
        return self
    }
}
