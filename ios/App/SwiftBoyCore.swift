import AVFoundation
import CoreGraphics
import Foundation
import SwiftUI

public enum GameBoyButton: String, CaseIterable {
    case up, down, left, right, a, b, select, start
}

@MainActor
public final class SwiftBoyCore: ObservableObject {
    @Published public private(set) var frame: CGImage?
    @Published public private(set) var isLoaded = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var audioEnabled = true

    private var emulator: OpaquePointer?
    private var timer: Timer?
    private var romURL: URL?
    private let width = 160
    private let height = 144
    private var audioEngine: AVAudioEngine?
    private var audioSource: AVAudioSourceNode?
    private let audioState = AudioState()

    public init() {}
    deinit {
        timer?.invalidate()
        if let emulator { sb_destroy(emulator) }
    }

    public func loadROM(from url: URL) throws {
        pause()
        isLoaded = false
        frame = nil
        audioEngine?.stop()
        audioEngine = nil
        audioSource = nil
        audioState.emulator = nil
        if let emulator { sb_destroy(emulator) }
        emulator = nil
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let roms = docs.appendingPathComponent("ROMs", isDirectory: true)
            try FileManager.default.createDirectory(at: roms, withIntermediateDirectories: true)
            let destination = roms.appendingPathComponent(url.lastPathComponent)
            if url.standardizedFileURL != destination.standardizedFileURL {
                if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
                try FileManager.default.copyItem(at: url, to: destination)
            }
            let bytes = try Data(contentsOf: destination, options: .mappedIfSafe)
            guard let core = sb_create() else { throw EmulatorError.initialization }
            guard bytes.withUnsafeBytes({ raw in
                sb_load_rom(core, raw.bindMemory(to: UInt8.self).baseAddress, bytes.count)
            }) else {
                sb_destroy(core)
                throw EmulatorError.invalidROM
            }
            emulator = core
            audioState.emulator = core
            romURL = destination
            let batteryURL = batterySaveURL
            if let save = try? Data(contentsOf: batteryURL), !save.isEmpty {
                save.withUnsafeBytes { raw in sb_load_battery(core, raw.bindMemory(to: UInt8.self).baseAddress, save.count) }
            }
            isLoaded = true
            errorMessage = nil
            startAudio()
            resume()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    public func setButton(_ button: GameBoyButton, pressed: Bool) {
        guard let emulator else { return }
        sb_set_button(emulator, bridgeButton(button), pressed)
    }

    public func releaseAllButtons() {
        for button in GameBoyButton.allCases { setButton(button, pressed: false) }
    }

    public func setSoundEnabled(_ enabled: Bool) {
        audioEnabled = enabled
        if enabled {
            if emulator != nil && audioEngine == nil { startAudio() }
            else { try? audioEngine?.start() }
        } else {
            audioEngine?.pause()
        }
    }

    public func pause() {
        timer?.invalidate()
        timer = nil
        releaseAllButtons()
        flushBatterySave()
    }

    public func resume() {
        guard emulator != nil, timer == nil else { return }
        let displayTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.advanceFrame() }
        }
        timer = displayTimer
        RunLoop.main.add(displayTimer, forMode: .common)
    }

    public func saveState() throws {
        guard let emulator else { throw EmulatorError.noROM }
        let count = sb_save_state_size(emulator)
        guard count > 0 else { throw EmulatorError.saveFailed }
        var data = Data(count: count)
        let ok = data.withUnsafeMutableBytes { raw in sb_save_state(emulator, raw.bindMemory(to: UInt8.self).baseAddress, count) }
        guard ok else { throw EmulatorError.saveFailed }
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        try data.write(to: stateURL, options: .atomic)
    }

    public func loadState() throws {
        guard let emulator else { throw EmulatorError.noROM }
        let data = try Data(contentsOf: stateURL)
        let ok = data.withUnsafeBytes { raw in sb_load_state(emulator, raw.bindMemory(to: UInt8.self).baseAddress, data.count) }
        guard ok else { throw EmulatorError.invalidState }
        advanceFrame()
    }

    public func flushBatterySave() {
        guard let emulator else { return }
        let count = sb_battery_size(emulator)
        guard count > 0 else { return }
        var data = Data(count: count)
        let ok = data.withUnsafeMutableBytes { raw in sb_save_battery(emulator, raw.bindMemory(to: UInt8.self).baseAddress, count) }
        guard ok else { return }
        try? FileManager.default.createDirectory(at: batterySaveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: batterySaveURL, options: .atomic)
    }

    private var batterySaveURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("BatterySaves", isDirectory: true)
        let name = (romURL?.deletingPathExtension().lastPathComponent ?? "game") + ".sav"
        return directory.appendingPathComponent(name)
    }

    private var stateDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("SaveStates", isDirectory: true)
    }

    private var stateURL: URL {
        let name = (romURL?.deletingPathExtension().lastPathComponent ?? "game") + ".state"
        return stateDirectory.appendingPathComponent(name)
    }

    private func advanceFrame() {
        guard let emulator else { return }
        sb_run_frame(emulator)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBufferPointer { sb_copy_frame(emulator, $0.baseAddress, $0.count) }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return }
        frame = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    private func bridgeButton(_ button: GameBoyButton) -> SBButton {
        switch button {
        case .up: return SB_UP
        case .down: return SB_DOWN
        case .left: return SB_LEFT
        case .right: return SB_RIGHT
        case .a: return SB_A
        case .b: return SB_B
        case .select: return SB_SELECT
        case .start: return SB_START
        }
    }

    private func startAudio() {
        // SameBoy supplies 44.1 kHz stereo samples through the bridge. An audio source node
        // drains them directly into AVAudioEngine's output callback.
        guard audioEnabled else { return }
        let engine = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let state = audioState
        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            guard let emulator = state.emulator else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let capacity = Int(frameCount) * 2
            var samples = [Int16](repeating: 0, count: capacity)
            let copied = samples.withUnsafeMutableBufferPointer { sb_read_audio(emulator, $0.baseAddress, capacity) }
            let floats = samples.withUnsafeBufferPointer { $0 }
            if let left = buffers.first?.mData?.assumingMemoryBound(to: Float.self) {
                for i in 0..<Int(frameCount) { left[i] = i * 2 < copied ? Float(floats[i * 2]) / 32768 : 0 }
            }
            if buffers.count > 1, let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
                for i in 0..<Int(frameCount) { right[i] = i * 2 + 1 < copied ? Float(floats[i * 2 + 1]) / 32768 : 0 }
            } else if let interleaved = buffers.first?.mData?.assumingMemoryBound(to: Float.self) {
                for i in 0..<Int(frameCount) { interleaved[i * 2 + 1] = i * 2 + 1 < copied ? Float(floats[i * 2 + 1]) / 32768 : 0 }
            }
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        do { try engine.start(); audioSource = node; audioEngine = engine }
        catch { errorMessage = "Audio could not start: \(error.localizedDescription)" }
    }

    private enum EmulatorError: LocalizedError {
        case initialization, invalidROM, noROM, saveFailed, invalidState
        var errorDescription: String? {
            switch self {
            case .initialization: return "Could not start the Game Boy core."
            case .invalidROM: return "This file could not be loaded as a Game Boy ROM."
            case .noROM: return "Load a ROM first."
            case .saveFailed: return "Could not save the game state."
            case .invalidState: return "The saved state is invalid for this ROM."
            }
        }
    }
}

private final class AudioState: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEmulator: OpaquePointer?
    var emulator: OpaquePointer? {
        get { lock.lock(); defer { lock.unlock() }; return storedEmulator }
        set { lock.lock(); defer { lock.unlock() }; storedEmulator = newValue }
    }
}
