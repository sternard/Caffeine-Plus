# Caffeine Plus

Caffeine Plus is a local-only macOS utility that keeps the display and Mac awake until you turn it off. It opens as a normal standalone window when launched from Mac Assistant; Mac Assistant remains the only menu-bar app in the workspace.

Choose any combination of three safeguards:

- **Keep the display awake** uses a `PreventUserIdleDisplaySleep` IOKit assertion, equivalent to the important `caffeinate -d` behavior. This also prevents idle system sleep.
- **Prevent idle system sleep** uses `PreventUserIdleSystemSleep`, equivalent to `caffeinate -i`, while still allowing the display to turn off if the display option is disabled.
- **Send activity pulses while idle** reports native user activity after a configurable period without keyboard, mouse, or tablet input, then once per minute while idle. The delay defaults to 120 seconds and accepts any positive whole number of seconds.

The activity pulse is the supported macOS alternative to a synthetic mouse wiggle. It does not move the pointer and does not need Accessibility access. Option changes apply immediately while Caffeine Plus is active, and the selected options plus active/inactive choice are restored from `~/Library/Application Support/Caffeine Plus/state.json` on the next launch.

## Run

```sh
./scripts/run-app.sh
```

The launcher builds a local `.app` bundle under `.build/debug` and opens its control window. Closing the window quits Caffeine Plus and releases its active assertions.

Because this repository follows the `scripts/run-app.sh` convention, Mac Assistant discovers it automatically when both repos are under `~/Assistant`.

## Verify

Run the tests with:

```sh
swift test
```

While Caffeine Plus is enabled, macOS also reports its assertions in:

```sh
pmset -g assertions
```

## Limits

Caffeine Plus prevents the selected idle behaviors. It deliberately does not override a manual Lock Screen or Sleep command, closing a MacBook lid, shutdown/restart, battery exhaustion, or security policy enforced by device management. Keeping the display awake uses additional power, so turn it off when it is no longer needed.
