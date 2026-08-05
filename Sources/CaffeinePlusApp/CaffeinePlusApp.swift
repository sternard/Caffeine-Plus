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
                .frame(minWidth: 500, minHeight: 510)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 520, height: 540)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

private struct CaffeinePlusView: View {
    @ObservedObject var controller: CaffeinePlusController

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            safeguards
            primaryAction

            if controller.isActive,
               controller.options.sendActivityPulses,
               let lastPulseDate = controller.lastPulseDate {
                HStack(spacing: 5) {
                    Image(systemName: "wave.3.right")
                    Text("Last activity pulse:")
                    Text(lastPulseDate, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

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
                    detail: "After two minutes without input, reports native activity once a minute without moving the pointer.",
                    isOn: Binding(
                        get: { controller.options.sendActivityPulses },
                        set: { controller.setSendActivityPulses($0) }
                    )
                )

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
