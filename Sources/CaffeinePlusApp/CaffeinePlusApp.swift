import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
struct CaffeinePlusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = CaffeinePlusController()

    var body: some Scene {
        WindowGroup("Caffeine Plus") {
            CaffeinePlusView(controller: controller)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 520, height: 580)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

private struct CaffeinePlusView: View {
    @ObservedObject var controller: CaffeinePlusController

    var body: some View {
        Group {
            if controller.isActive {
                compactView
            } else {
                expandedView
            }
        }
        .background {
            CaffeinePlusWindowConfigurator(isActive: controller.isActive)
        }
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            safeguards
            primaryAction

            if let errorMessage = controller.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Text("Caffeine Plus does not move the cursor or require Accessibility access. Manual Lock Screen or Sleep commands, closing a MacBook lid, and enforced security policies still take priority.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(
            minWidth: CaffeinePlusWindowMetrics.expandedMinimumContentSize.width,
            minHeight: CaffeinePlusWindowMetrics.expandedMinimumContentSize.height
        )
    }

    private var compactView: some View {
        VStack(spacing: 16) {
            header

            Button {
                controller.toggle()
            } label: {
                Label("Allow Normal Sleep", systemImage: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(
            width: CaffeinePlusWindowMetrics.compactContentSize.width,
            height: CaffeinePlusWindowMetrics.compactContentSize.height
        )
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(controller.isActive ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(controller.isActive ? Color.green : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Caffeine Plus")
                    .font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    Circle()
                        .fill(controller.isActive ? Color.green : Color.secondary)
                        .frame(width: 8, height: 8)
                    Text(controller.statusText)
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    private var safeguards: some View {
        GroupBox("Safeguards") {
            VStack(alignment: .leading, spacing: 16) {
                OptionToggle(
                    title: "Keep the display awake",
                    detail: "Prevents idle dimming and display sleep. This also prevents idle system sleep.",
                    isOn: Binding(
                        get: { controller.options.keepDisplayAwake },
                        set: { controller.setKeepDisplayAwake($0) }
                    )
                )

                Divider()

                OptionToggle(
                    title: "Prevent idle system sleep",
                    detail: "Keeps the Mac running even if you choose to let the display turn off.",
                    isOn: Binding(
                        get: { controller.options.preventIdleSystemSleep },
                        set: { controller.setPreventIdleSystemSleep($0) }
                    )
                )

                Divider()

                OptionToggle(
                    title: "Send activity pulses while idle",
                    detail: "Reports native activity without moving the pointer, then renews once a minute while idle.",
                    isOn: Binding(
                        get: { controller.options.sendActivityPulses },
                        set: { controller.setSendActivityPulses($0) }
                    )
                )

                HStack(spacing: 8) {
                    Text("Start after")
                    TextField(
                        "Seconds",
                        value: activityPulseIdleSeconds,
                        format: .number
                    )
                    .frame(width: 76)
                    .multilineTextAlignment(.trailing)

                    Text("seconds of inactivity")

                    Stepper(value: activityPulseIdleSeconds, step: 1) {
                        EmptyView()
                    }
                    .labelsHidden()

                    Spacer(minLength: 0)
                }
                .font(.caption)
                .padding(.leading, 22)
                .disabled(!controller.options.sendActivityPulses)

                Text(controller.isActive ? "Option changes apply immediately." : "All three safeguards are enabled by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
    }

    private var primaryAction: some View {
        Button {
            controller.toggle()
        } label: {
            Label(
                controller.isActive ? "Allow Normal Sleep" : "Keep Mac Awake",
                systemImage: controller.isActive ? "stop.fill" : "play.fill"
            )
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(controller.isActive ? .red : .accentColor)
        .disabled(!controller.isActive && !controller.canEnable)
        .keyboardShortcut(.defaultAction)
    }

    private var activityPulseIdleSeconds: Binding<Int> {
        Binding(
            get: { controller.options.activityPulseIdleSeconds },
            set: { controller.setActivityPulseIdleSeconds($0) }
        )
    }
}

private enum CaffeinePlusWindowMetrics {
    static let compactContentSize = NSSize(width: 242, height: 130)
    static let expandedMinimumContentSize = NSSize(width: 500, height: 550)
}

private struct CaffeinePlusWindowConfigurator: NSViewRepresentable {
    let isActive: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WindowReferenceView {
        let view = WindowReferenceView()
        update(view, coordinator: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: WindowReferenceView, context: Context) {
        update(nsView, coordinator: context.coordinator)
    }

    private func update(_ view: WindowReferenceView, coordinator: Coordinator) {
        view.onWindowChange = { window in
            guard let window else {
                return
            }
            coordinator.scheduleConfiguration(for: window, isActive: isActive)
        }

        if let window = view.window {
            coordinator.scheduleConfiguration(for: window, isActive: isActive)
        }
    }

    final class Coordinator {
        private weak var configuredWindow: NSWindow?
        private var wasActive = false
        private var expandedFrame: NSRect?
        private var expandedCollectionBehavior: NSWindow.CollectionBehavior = []

        func scheduleConfiguration(for window: NSWindow, isActive: Bool) {
            DispatchQueue.main.async { [weak self, weak window] in
                guard let self, let window else {
                    return
                }
                self.configure(window, isActive: isActive)
            }
        }

        func configure(_ window: NSWindow, isActive: Bool) {
            if configuredWindow !== window {
                configuredWindow = window
                wasActive = false
                expandedFrame = nil
                expandedCollectionBehavior = window.collectionBehavior
            }

            guard isActive != wasActive else {
                window.level = isActive ? .floating : .normal
                return
            }

            if isActive {
                enterCompactMode(window)
            } else {
                leaveCompactMode(window)
            }

            wasActive = isActive
        }

        private func enterCompactMode(_ window: NSWindow) {
            expandedFrame = window.frame
            expandedCollectionBehavior = window.collectionBehavior

            window.level = .floating
            window.collectionBehavior.formUnion([.canJoinAllSpaces, .fullScreenAuxiliary])
            window.contentMinSize = CaffeinePlusWindowMetrics.compactContentSize
            window.contentMaxSize = CaffeinePlusWindowMetrics.compactContentSize

            let compactFrameSize = window.frameRect(
                forContentRect: NSRect(origin: .zero, size: CaffeinePlusWindowMetrics.compactContentSize)
            ).size
            var compactFrame = window.frame
            compactFrame.origin.y = compactFrame.maxY - compactFrameSize.height
            compactFrame.size = compactFrameSize
            window.setFrame(compactFrame, display: true, animate: true)
        }

        private func leaveCompactMode(_ window: NSWindow) {
            window.level = .normal
            window.collectionBehavior = expandedCollectionBehavior
            window.contentMinSize = CaffeinePlusWindowMetrics.expandedMinimumContentSize
            window.contentMaxSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )

            let fallbackContentRect = NSRect(
                origin: .zero,
                size: NSSize(width: 520, height: 552)
            )
            let fallbackFrame = window.frameRect(forContentRect: fallbackContentRect)
            let targetFrame = expandedFrame ?? NSRect(
                origin: window.frame.origin,
                size: fallbackFrame.size
            )
            window.setFrame(targetFrame, display: true, animate: true)
            expandedFrame = nil
        }
    }
}

private final class WindowReferenceView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}

private struct OptionToggle: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.checkbox)
    }
}
