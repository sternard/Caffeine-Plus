import AppKit
import CaffeinePlusCore
import CoreGraphics
import Foundation

@MainActor
final class CaffeinePlusController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var options: CaffeineOptions
    @Published private(set) var lastPulseDate: Date?
    @Published private(set) var errorMessage: String?

    private let engine: CaffeinePlusEngine
    private let stateStore: CaffeinePlusStateStore
    private var heartbeatTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []

    init(
        engine: CaffeinePlusEngine = CaffeinePlusEngine(),
        stateStore: CaffeinePlusStateStore = CaffeinePlusStateStore()
    ) {
        self.engine = engine
        self.stateStore = stateStore

        let state = stateStore.load()
        self.options = state.options

        observeSessionChanges()
        if state.isEnabled {
            enable()
        }
    }

    var statusText: String {
        if isActive {
            let count = options.enabledSafeguardCount
            return count == 1 ? "1 safeguard is active" : "\(count) safeguards are active"
        }
        return options.hasEnabledSafeguard
            ? "Your Mac can sleep normally"
            : "Choose at least one safeguard"
    }

    var canEnable: Bool {
        options.hasEnabledSafeguard
    }

    func toggle() {
        isActive ? disable() : enable()
    }

    func setKeepDisplayAwake(_ enabled: Bool) {
        updateOptions { $0.keepDisplayAwake = enabled }
    }

    func setPreventIdleSystemSleep(_ enabled: Bool) {
        updateOptions { $0.preventIdleSystemSleep = enabled }
    }

    func setSendActivityPulses(_ enabled: Bool) {
        updateOptions { $0.sendActivityPulses = enabled }
    }

    private func enable() {
        do {
            try engine.start(options: options)
            isActive = true
            lastPulseDate = engine.lastPulseDate
            errorMessage = nil
            configureHeartbeat()
            persistState(isEnabled: true)
        } catch {
            engine.stop()
            isActive = false
            lastPulseDate = nil
            errorMessage = error.localizedDescription
            try? stateStore.save(CaffeinePlusState(isEnabled: false, options: options))
            stopHeartbeat()
        }
    }

    private func disable() {
        stopHeartbeat()
        engine.stop()
        isActive = false
        lastPulseDate = nil
        errorMessage = nil
        persistState(isEnabled: false)
    }

    private func updateOptions(_ update: (inout CaffeineOptions) -> Void) {
        var updatedOptions = options
        update(&updatedOptions)
        guard updatedOptions != options else {
            return
        }

        options = updatedOptions

        guard isActive else {
            errorMessage = nil
            persistState(isEnabled: false)
            return
        }

        if options.hasEnabledSafeguard {
            restoreSafeguards()
        } else {
            disable()
        }
    }

    private func persistState(isEnabled: Bool) {
        do {
            try stateStore.save(CaffeinePlusState(isEnabled: isEnabled, options: options))
        } catch {
            errorMessage = "Settings could not be saved: \(error.localizedDescription)"
        }
    }

    private func configureHeartbeat() {
        if isActive && options.sendActivityPulses {
            startHeartbeat()
        } else {
            stopHeartbeat()
        }
    }

    private func startHeartbeat() {
        stopHeartbeat()

        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.heartbeat()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        heartbeatTimer = timer
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func heartbeat() {
        guard isActive, options.sendActivityPulses else {
            return
        }

        let idleDuration = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: UInt32.max)!
        )

        do {
            if try engine.pulseIfNeeded(inputIdleDuration: idleDuration) {
                lastPulseDate = engine.lastPulseDate
            }
        } catch {
            restoreSafeguards(after: error)
        }
    }

    private func restoreSafeguards(after originalError: Error? = nil) {
        guard isActive else {
            return
        }

        do {
            try engine.restart(options: options)
            lastPulseDate = engine.lastPulseDate
            errorMessage = nil
            configureHeartbeat()
            persistState(isEnabled: true)
        } catch {
            stopHeartbeat()
            engine.stop()
            isActive = false
            lastPulseDate = nil
            try? stateStore.save(CaffeinePlusState(isEnabled: false, options: options))

            if let originalError {
                errorMessage = "\(originalError.localizedDescription) Retry also failed: \(error.localizedDescription)"
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func observeSessionChanges() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.restoreSafeguards()
                }
            }
            workspaceObservers.append(observer)
        }
    }
}
