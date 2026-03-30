import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    let controller: MenuBarController
    @ObservedObject var library: GIFLibrary
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var selectedID: UUID? = nil
    @State private var isAnimating = false
    @State private var spotifyEnabled: Bool = UserDefaults.standard.bool(forKey: "spotify_mode")
    @State private var isAuthenticated: Bool = SpotifyAPI.shared.isAuthenticated
    @State private var isConnecting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Mbanimator")
                    .font(.title2).bold()
                Spacer()
                Button {
                    pickGIF()
                } label: {
                    Label("GIF hinzufügen", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Bibliothek
            if library.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Noch keine GIFs hinzugefügt")
                        .foregroundStyle(.secondary)
                    Button("GIF hinzufügen") { pickGIF() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selectedID) {
                    ForEach(library.entries) { entry in
                        HStack(spacing: 12) {
                            if let thumb = entry.thumbnail {
                                Image(nsImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.quaternary)
                                    .frame(width: 36, height: 36)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                    .fontWeight(.medium)
                                Text(entry.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            if isAnimating && selectedID == entry.id {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .tag(entry.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedID = entry.id
                            controller.loadGIF(from: URL(fileURLWithPath: entry.path))
                            isAnimating = true
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                if let idx = library.entries.firstIndex(where: { $0.id == entry.id }) {
                                    library.remove(at: IndexSet(integer: idx))
                                }
                            } label: {
                                Label("Entfernen", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            // Spotify Section
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "music.note")
                        .foregroundStyle(.green)
                        .frame(width: 16)

                    if isAuthenticated {
                        Text("Spotify verbunden")
                            .fontWeight(.medium)
                        Spacer()
                        if spotifyEnabled {
                            Button { controller.spotifyPreviousTrack() } label: { Image(systemName: "backward.fill") }
                                .buttonStyle(.borderless)
                            Button { controller.spotifyPlayPause() } label: { Image(systemName: "playpause.fill") }
                                .buttonStyle(.borderless)
                            Button { controller.spotifyNextTrack() } label: { Image(systemName: "forward.fill") }
                                .buttonStyle(.borderless)
                            Divider().frame(height: 16)
                        }
                        Toggle("", isOn: $spotifyEnabled)
                            .toggleStyle(.switch)
                            .onChange(of: spotifyEnabled) { enabled in
                                if enabled {
                                    controller.stopAnimation()
                                    isAnimating = false
                                    selectedID = nil
                                    controller.startSpotifyMode()
                                } else {
                                    controller.stopSpotifyMode()
                                }
                            }
                        Button("Trennen") {
                            SpotifyAPI.shared.disconnect()
                            isAuthenticated = false
                            spotifyEnabled = false
                            controller.stopSpotifyMode()
                        }
                        .foregroundStyle(.red)
                        .buttonStyle(.borderless)
                        .font(.caption)
                    } else {
                        Text("Spotify")
                            .fontWeight(.medium)
                        Spacer()
                        if isConnecting {
                            ProgressView().scaleEffect(0.7)
                            Text("Warte auf Anmeldung…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Button("Anmelden") {
                                isConnecting = true
                                SpotifyAPI.shared.authenticate { success in
                                    isAuthenticated = success
                                    isConnecting = false
                                    if success {
                                        spotifyEnabled = true
                                        controller.stopAnimation()
                                        isAnimating = false
                                        selectedID = nil
                                        controller.startSpotifyMode()
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            Divider()

            // Footer: Spinner + Autostart
            HStack(spacing: 16) {
                Button {
                    selectedID = nil
                    isAnimating = true
                    spotifyEnabled = false
                    controller.stopSpotifyMode()
                    controller.startSpinnerAnimation()
                } label: {
                    Label("Spinner", systemImage: "arrow.circlepath")
                }

                Button {
                    controller.stopAnimation()
                    isAnimating = false
                    selectedID = nil
                } label: {
                    Label("Stoppen", systemImage: "stop.fill")
                }
                .disabled(!isAnimating || spotifyEnabled)

                Spacer()

                Toggle("Autostart", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !enabled
                        }
                    }
            }
            .padding()
        }
        .frame(width: 460, height: 460)
    }

    private func pickGIF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.gif]
        panel.allowsMultipleSelection = true
        if panel.runModal() == .OK {
            panel.urls.forEach { library.add(url: $0) }
        }
    }
}
