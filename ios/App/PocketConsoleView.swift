import SwiftUI
import UniformTypeIdentifiers
import GameController
import UIKit

struct PocketConsoleView: View {
    @StateObject private var core = SwiftBoyCore()
    @StateObject private var controllerInput = PocketControllerInput()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingMenu = false
    @State private var showingImporter = false
    @State private var wantsROMPickerAfterMenu = false
    @State private var alertMessage: String?
    @State private var heldKeys = Set<GameBoyButton>()
    @AppStorage("pocketDisplayPalette") private var displayPalette = "Classic"
    @AppStorage("pocketButtonScale") private var buttonScale = 1.0
    @AppStorage("pocketControlSpread") private var controlSpread = 1.0
    @AppStorage("pocketHaptics") private var hapticsEnabled = true

    private let silver = Color(red: 0.77, green: 0.79, blue: 0.81)

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 720
            ZStack {
                LinearGradient(colors: [Color(red: 0.88, green: 0.89, blue: 0.91), Color(red: 0.63, green: 0.66, blue: 0.69)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: compact ? 12 : 18) {
                    header
                    screenAssembly
                        .frame(height: min(geometry.size.height * (compact ? 0.39 : 0.43), geometry.size.width * 0.97))
                    controlDeck(compact: compact)
                        .frame(maxHeight: .infinity)
                    footer
                }
                .padding(.horizontal, compact ? 17 : 22)
                .padding(.top, compact ? 6 : 12)
                .padding(.bottom, compact ? 3 : 10)
                .background(
                    LinearGradient(colors: [Color(red: 0.84, green: 0.86, blue: 0.88), silver, Color(red: 0.71, green: 0.73, blue: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.72), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 13)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.light)
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.data], allowsMultipleSelection: false, onCompletion: importROM)
        .sheet(isPresented: $showingMenu, onDismiss: {
            if wantsROMPickerAfterMenu {
                wantsROMPickerAfterMenu = false
                showingImporter = true
            } else if core.isLoaded && scenePhase == .active {
                core.resume()
            }
        }) { menuSheet }
        .alert("Pocket Player", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: { Text(alertMessage ?? "") }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                if !showingMenu && !wantsROMPickerAfterMenu && !showingImporter { core.resume() }
            } else {
                releaseAll()
                core.pause()
                core.flushBatterySave()
            }
        }
        .onDisappear { controllerInput.stop(); releaseAll(); core.pause(); core.flushBatterySave() }
        .onAppear { controllerInput.start(); controllerInput.onInput = setInput }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text("GAME BOY")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color(red: 0.26, green: 0.28, blue: 0.31))
                Text("POCKET")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(4.8)
                    .foregroundStyle(Color(red: 0.47, green: 0.22, blue: 0.33))
            }
            Spacer()
            HStack(spacing: 5) {
                Circle().fill(core.isLoaded ? Color.green : Color(red: 0.48, green: 0.17, blue: 0.14)).frame(width: 7, height: 7)
                Text(core.isLoaded ? "POWER" : "READY")
                    .font(.system(size: 8, weight: .bold, design: .rounded)).tracking(1.1)
            }
            .foregroundStyle(Color.black.opacity(0.54))
            Button { showingMenu = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.65))
                    .frame(width: 38, height: 34)
                    .background(Color.white.opacity(0.36), in: RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Open game menu")
        }
    }

    private var screenAssembly: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                ForEach(0..<5) { _ in Capsule().fill(Color.white.opacity(0.13)).frame(width: 3, height: 4) }
                Text("DOT MATRIX WITH STEREO SOUND")
                    .font(.system(size: 7, weight: .bold, design: .rounded)).tracking(1.1)
                    .foregroundStyle(Color.white.opacity(0.65))
                ForEach(0..<5) { _ in Capsule().fill(Color.white.opacity(0.13)).frame(width: 3, height: 4) }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.045, green: 0.055, blue: 0.06))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.black.opacity(0.9), lineWidth: 2))
                if let frame = core.frame {
                    Image(decorative: frame, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(160.0 / 144.0, contentMode: .fit)
                        .saturation(displayPalette == "Mint" ? 0 : 1)
                        .colorMultiply(displayPalette == "Mint" ? Color(red: 0.77, green: 0.91, blue: 0.75) : .white)
                        .padding(8)
                        .accessibilityLabel("Game screen")
                } else {
                    VStack(spacing: 9) {
                        Image(systemName: "gamecontroller.fill").font(.system(size: 27, weight: .light))
                        Text("INSERT YOUR GAME")
                            .font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(1.2)
                        Text("Use the menu to open a .gb ROM")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 0.55, green: 0.65, blue: 0.54))
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .background(Color(red: 0.12, green: 0.13, blue: 0.14), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.28), lineWidth: 1))
            .shadow(color: .black.opacity(0.38), radius: 7, x: 0, y: 5)
        }
    }

    private func controlDeck(compact: Bool) -> some View {
        GeometryReader { geometry in
            let diameter = min(geometry.size.height * (compact ? 0.68 : 0.73), geometry.size.width * 0.39) * buttonScale
            HStack(alignment: .center, spacing: 0) {
                PocketDPad(onChange: setInput)
                    .frame(width: diameter * 1.18, height: diameter * 1.18)
                    .accessibilityLabel("Directional pad")
                Spacer(minLength: geometry.size.width * 0.06 * controlSpread)
                HStack(spacing: diameter * 0.13) {
                    actionButton(.b, label: "B", color: UIColor(red: 0.49, green: 0.18, blue: 0.32, alpha: 1), diameter: diameter * 0.86)
                        .offset(y: -diameter * 0.15)
                    actionButton(.a, label: "A", color: UIColor(red: 0.49, green: 0.18, blue: 0.32, alpha: 1), diameter: diameter * 0.86)
                        .offset(y: diameter * 0.1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 150)
    }

    private func actionButton(_ key: GameBoyButton, label: String, color: UIColor, diameter: CGFloat) -> some View {
        PocketTouchButton(key: key, color: color, label: label, onChange: setInput)
            .frame(width: diameter, height: diameter)
            .accessibilityLabel("\(label) button")
    }

    private var footer: some View {
        VStack(spacing: 13) {
            HStack(spacing: 28) {
                systemButton(.select, title: "SELECT")
                systemButton(.start, title: "START")
            }
            HStack(spacing: 4) {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 9))
                Text("POCKET PLAYER").font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(2.2)
            }
            .foregroundStyle(Color.black.opacity(0.33))
        }
    }

    private func systemButton(_ key: GameBoyButton, title: String) -> some View {
        VStack(spacing: 4) {
            PocketTouchButton(key: key, color: UIColor(red: 0.27, green: 0.29, blue: 0.31, alpha: 1), label: "", onChange: setInput)
                .frame(width: 48, height: 13)
                .rotationEffect(.degrees(-25))
            Text(title).font(.system(size: 7, weight: .bold, design: .rounded)).tracking(0.8)
                .foregroundStyle(Color.black.opacity(0.57))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title.lowercased()) button")
    }

    private var menuSheet: some View {
        NavigationStack {
            Form {
                Section("Game") {
                    Button { wantsROMPickerAfterMenu = true; showingMenu = false } label: {
                        Label(core.isLoaded ? "Change ROM" : "Open ROM…", systemImage: "folder")
                    }
                    Button { core.resume(); showingMenu = false } label: { Label("Resume", systemImage: "play.fill") }
                        .disabled(!core.isLoaded)
                    Button { runCoreAction(core.saveState) } label: { Label("Save state", systemImage: "square.and.arrow.down") }
                        .disabled(!core.isLoaded)
                    Button { runCoreAction(core.loadState) } label: { Label("Load state", systemImage: "square.and.arrow.up") }
                        .disabled(!core.isLoaded)
                }
                Section("Display") {
                    Picker("Palette", selection: $displayPalette) {
                        Text("Classic color").tag("Classic")
                        Text("Pocket mint").tag("Mint")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Controls") {
                    VStack(alignment: .leading) {
                        HStack { Text("Button size"); Spacer(); Text("\(Int(buttonScale * 100))%") }
                        Slider(value: $buttonScale, in: 0.78...1.18)
                    }
                    VStack(alignment: .leading) {
                        HStack { Text("Control spacing"); Spacer(); Text("\(Int(controlSpread * 100))%") }
                        Slider(value: $controlSpread, in: 0.7...1.4)
                    }
                    Toggle("Game sound", isOn: Binding(get: { core.audioEnabled }, set: { core.setSoundEnabled($0) }))
                    Toggle("Light haptics", isOn: $hapticsEnabled)
                    Text(controllerInput.connected ? "External controller connected." : "Connect a Bluetooth or wired controller to play with its buttons and D-pad.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let message = core.errorMessage {
                    Section("Emulator") { Text(message).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Pocket menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingMenu = false } } }
            .onAppear { core.pause(); releaseAll() }
        }
        .presentationDetents([.medium, .large])
    }

    private func setInput(_ key: GameBoyButton, _ pressed: Bool) {
        if pressed {
            guard heldKeys.insert(key).inserted else { return }
            core.setButton(key, pressed: true)
            if hapticsEnabled { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.35) }
        } else {
            guard heldKeys.remove(key) != nil else { return }
            core.setButton(key, pressed: false)
        }
    }

    private func releaseAll() {
        heldKeys.removeAll()
        core.releaseAllButtons()
    }

    private func importROM(_ result: Result<[URL], Error>) {
        do {
            guard let source = try result.get().first else { throw CocoaError(.fileReadNoSuchFile) }
            guard source.pathExtension.lowercased() == "gb" else { throw ImportError.unsupportedType }
            let hasAccess = source.startAccessingSecurityScopedResource()
            defer { if hasAccess { source.stopAccessingSecurityScopedResource() } }
            // SwiftBoyCore copies the security-scoped file into Documents/ROMs before loading it.
            try core.loadROM(from: source)
            core.resume()
            showingMenu = false
        } catch {
            let nsError = error as NSError
            if error is CancellationError || nsError.code == NSUserCancelledError {
                if core.isLoaded && scenePhase == .active { core.resume() }
                return
            }
            alertMessage = "Could not open ROM: \(error.localizedDescription)"
            if core.isLoaded && scenePhase == .active { core.resume() }
        }
    }

    private func runCoreAction(_ action: () throws -> Void) {
        do { try action() }
        catch { alertMessage = error.localizedDescription }
    }

    private enum ImportError: LocalizedError {
        case unsupportedType
        var errorDescription: String? { "Choose a Game Boy .gb ROM file." }
    }
}

@MainActor
final class PocketControllerInput: ObservableObject {
    @Published private(set) var connected = false
    var onInput: ((GameBoyButton, Bool) -> Void)?
    private var observers: [NSObjectProtocol] = []
    private var controller: GCController?
    private var active = Set<GameBoyButton>()
    private var controllerGeneration = 0

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in self?.attach(controller) }
        })
        observers.append(center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
            guard let controller = note.object as? GCController else { return }
            Task { @MainActor in self?.detach(controller) }
        })
        GCController.controllers().forEach(attach)
    }

    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        if let controller { detach(controller) }
    }

    private func attach(_ newController: GCController) {
        guard controller == nil, let pad = newController.extendedGamepad else { return }
        controller = newController
        controllerGeneration += 1
        let generation = controllerGeneration
        connected = true
        pad.dpad.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                guard let self, self.controllerGeneration == generation else { return }
                self.setDirections(x: x, y: y)
            }
        }
        bind(pad.buttonA, to: .a, generation: generation)
        bind(pad.buttonB, to: .b, generation: generation)
        bind(pad.buttonX, to: .a, generation: generation)
        bind(pad.buttonY, to: .b, generation: generation)
        bind(pad.buttonMenu, to: .start, generation: generation)
        bind(pad.buttonOptions, to: .select, generation: generation)
    }

    private func bind(_ button: GCControllerButtonInput?, to key: GameBoyButton, generation: Int) {
        button?.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                guard let self, self.controllerGeneration == generation else { return }
                self.set(key, pressed: pressed)
            }
        }
    }

    private func detach(_ oldController: GCController) {
        guard controller === oldController else { return }
        controllerGeneration += 1
        setDirections(x: 0, y: 0)
        active.forEach { onInput?($0, false) }
        active.removeAll()
        controller = nil
        connected = false
    }

    private func setDirections(x: Float, y: Float) {
        var directions = Set<GameBoyButton>()
        if x < -0.35 { directions.insert(.left) }
        if x > 0.35 { directions.insert(.right) }
        if y < -0.35 { directions.insert(.down) }
        if y > 0.35 { directions.insert(.up) }
        let oldDirections = Set(active.filter { [.up, .down, .left, .right].contains($0) })
        for key in oldDirections.subtracting(directions) { set(key, pressed: false) }
        for key in directions { set(key, pressed: true) }
    }

    private func set(_ key: GameBoyButton, pressed: Bool) {
        if pressed {
            guard active.insert(key).inserted else { return }
        } else {
            guard active.remove(key) != nil else { return }
        }
        onInput?(key, pressed)
    }
}
