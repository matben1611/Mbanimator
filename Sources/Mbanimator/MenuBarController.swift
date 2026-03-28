import AppKit
import SwiftUI

class MenuBarController {
    private var statusItem: NSStatusItem
    private var timer: Timer?
    private var frames: [NSImage] = []
    private var currentFrame = 0
    private var settingsWindow: NSWindow?
    private let library = GIFLibrary()
    private let lastPlayedKey = "last_played"

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Mbanimator")
        setupMenu()
        restoreLastPlayed()
    }

    private func restoreLastPlayed() {
        guard let last = UserDefaults.standard.string(forKey: lastPlayedKey) else { return }
        if last == "__spinner__" {
            startSpinnerAnimation()
        } else if FileManager.default.fileExists(atPath: last) {
            loadGIF(from: URL(fileURLWithPath: last))
        }
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Einstellungen", action: #selector(openSettings), keyEquivalent: ",")
            .with(target: self))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func loadGIF(from url: URL) {
        UserDefaults.standard.set(url.path, forKey: lastPlayedKey)
        guard let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else { return }

        let frameCount = rep.value(forProperty: .frameCount) as? Int ?? 1
        // Frame-Delay aus GIF auslesen (Standard: 0.1s)
        rep.setProperty(.currentFrame, withValue: 0)
        let delay = rep.value(forProperty: .currentFrameDuration) as? Double ?? 0.1

        let menuBarSize = NSSize(width: 18, height: 18)
        frames = (0..<frameCount).compactMap { i in
            rep.setProperty(.currentFrame, withValue: i)
            guard let cgImage = rep.cgImage else { return nil }
            // Auf Menüleisten-Größe skalieren
            let scaled = NSImage(size: menuBarSize)
            scaled.lockFocus()
            NSImage(cgImage: cgImage, size: rep.size).draw(
                in: NSRect(origin: .zero, size: menuBarSize),
                from: NSRect(origin: .zero, size: rep.size),
                operation: .copy,
                fraction: 1.0
            )
            scaled.unlockFocus()
            return scaled
        }
        startAnimation(delay: delay)
    }

    func startSpinnerAnimation() {
        UserDefaults.standard.set("__spinner__", forKey: lastPlayedKey)
        let spinnerFrames = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
        var index = 0
        timer?.invalidate()
        statusItem.button?.image = nil
        statusItem.button?.title = spinnerFrames[0]
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.statusItem.button?.title = spinnerFrames[index]
            index = (index + 1) % spinnerFrames.count
        }
    }

    func stopAnimation() {
        UserDefaults.standard.removeObject(forKey: lastPlayedKey)
        timer?.invalidate()
        timer = nil
        statusItem.button?.title = ""
        statusItem.button?.image = NSImage(systemSymbolName: "play.circle", accessibilityDescription: "Mbanimator")
    }

    private func startAnimation(delay: Double = 0.1) {
        timer?.invalidate()
        currentFrame = 0
        guard !frames.isEmpty else { return }
        statusItem.button?.title = ""
        statusItem.button?.image = frames[0]
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.statusItem.button?.image = self.frames[self.currentFrame]
            self.currentFrame = (self.currentFrame + 1) % self.frames.count
        }
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Mbanimator"
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView(controller: self, library: library))
            window.delegate = self
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
