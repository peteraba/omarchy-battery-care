import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import "BatteryModel.js" as BatteryModel

Item {
  id: root

  property var shell: null
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  // Set by BarWidget from its shell.json entry (lowBatteryThreshold, lowBatteryRepeatStep).
  property int batteryThreshold: 10
  property int batteryWarnStep: 0
  property string pendingPowerSource: ""

  PersistentProperties {
    id: persisted
    reloadableId: "omarchy-battery"
    property int lastWarnedLevel: -1
  }

  function batteryPercentage() {
    return BatteryModel.batteryPercentage(UPower.displayDevice)
  }

  function isDischarging() {
    return BatteryModel.isDischarging(UPower.displayDevice, UPower.onBattery, UPowerDeviceState.Discharging)
  }

  function checkBattery() {
    var state = BatteryModel.shouldWarnLowBattery(UPower.displayDevice, UPower.onBattery, UPowerDeviceState.Discharging, batteryThreshold, persisted.lastWarnedLevel, batteryWarnStep)
    persisted.lastWarnedLevel = state.lastWarnedLevel
    if (state.notify) sendLowBatteryWarning(state.level)
  }

  function sendLowBatteryWarning(level) {
    if (warningProcess.running) return
    warningProcess.command = [
      "omarchy-battery-low",
      String(level)
    ]
    warningProcess.running = true
  }

  function applyPowerProfile() {
    pendingPowerSource = UPower.onBattery ? "battery" : "ac"
    if (!powerProfileProcess.running) runPendingPowerProfile()
  }

  function runPendingPowerProfile() {
    powerProfileProcess.command = ["omarchy-powerprofiles-set", pendingPowerSource]
    pendingPowerSource = ""
    powerProfileProcess.running = true
  }

  Process { id: warningProcess }

  Process {
    id: powerProfileProcess
    onExited: if (root.pendingPowerSource !== "") root.runPendingPowerProfile()
  }

  // No check on start: BarWidget's settings Bindings must land first, or a reload
  // with a raised threshold resets lastWarnedLevel and repeats the last warning.
  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.checkBattery()
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      root.checkBattery()
      root.applyPowerProfile()
    }
  }

  // ------------------------------------------------- charge modes
  // Two backends, picked from the first BAT* that has one:
  //   "types":     ideapad_acpi charge_types (Fast / Standard / Long_Life)
  //   "threshold": thinkpad_acpi charge_control_end_threshold (80 = Long_Life)
  // Writes go through the passwordless-sudo root helper at
  // /usr/local/bin/omarchy-battery-conservation.
  readonly property string detectScript: "for b in /sys/class/power_supply/BAT*; do " +
    "if [ -r \"$b/charge_types\" ]; then echo \"types $b\"; cat \"$b/charge_types\"; exit; fi; " +
    "if [ -r \"$b/charge_control_end_threshold\" ]; then echo \"threshold $b\"; cat \"$b/charge_control_end_threshold\"; exit; fi; " +
    "done; exit 1"
  property string backend: ""
  property string batteryDir: ""
  readonly property var chargeModes: BatteryModel.chargeModesFor(backend)
  property bool conservationAvailable: false
  property string chargeType: ""
  property int cycleCount: -1
  property int batteryHealthPct: -1
  // Cycle count and health are only shown inside the panel; the bar glyph
  // needs the charge type live at all times.
  property bool panelOpen: false

  // Long_Life is the only capped mode; kept as a flag for simple bindings.
  readonly property bool conservationOn: chargeType === "Long_Life"

  function refreshConservation() {
    if (!chargeTypeProcess.running) chargeTypeProcess.running = true
    if (root.panelOpen && root.batteryDir !== "") {
      if (!cycleCountProcess.running) cycleCountProcess.running = true
      if (!healthProcess.running) healthProcess.running = true
    }
  }

  function setChargeType(t) {
    if (root.chargeModes.indexOf(t) < 0) return
    if (chargeTypeProc.running) return
    chargeTypeProc.command = ["sudo", "-n", "/usr/local/bin/omarchy-battery-conservation", "set-type", t]
    chargeTypeProc.running = true
  }

  Process {
    id: chargeTypeProc
    onExited: root.refreshConservation()
  }

  Process {
    id: chargeTypeProcess
    command: ["sh", "-c", root.detectScript]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var state = BatteryModel.parseChargeState(text)
        root.backend = state.backend
        root.batteryDir = state.batteryDir
        root.chargeType = state.chargeType
      }
    }
    onExited: function(exitCode) {
      root.conservationAvailable = (exitCode === 0)
      if (exitCode !== 0) root.chargeType = ""
    }
  }


  Process {
    id: healthProcess
    command: ["cat", root.batteryDir + "/energy_full", root.batteryDir + "/energy_full_design"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = text.trim().split("\n")
        var full = parseInt(lines[0], 10)
        var design = parseInt(lines[1], 10)
        root.batteryHealthPct = (!isNaN(full) && !isNaN(design) && design > 0)
          ? Math.round(full / design * 100) : -1
      }
    }
  }

  Process {
    id: cycleCountProcess
    command: ["cat", root.batteryDir + "/cycle_count"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var n = parseInt(text.trim(), 10)
        root.cycleCount = isNaN(n) ? -1 : n
      }
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshConservation()
  }

  // ------------------------------------------------- theme "healthy" color
  // Long_Life draws a green glyph, but qs.Commons.Color exposes only
  // foreground/background/accent/urgent/muted — not the theme's raw green
  // tokens. Read them straight from the active theme's colors.toml.
  // omarchy-theme-set replaces the whole current/theme directory (so the
  // colors.toml watcher may detach) and then rewrites current/theme.name in
  // place; that rewrite is the reliable re-read trigger.
  readonly property string themeColorsFile: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
  readonly property string themeNameFile: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
  property color healthyColor: Color.foreground

  function applyHealthyColor(raw) {
    var text = String(raw || "")
    var m = text.match(/^\s*green\s*=\s*["']?(#[0-9A-Fa-f]{6})/m)
    if (!m) m = text.match(/^\s*bright_green\s*=\s*["']?(#[0-9A-Fa-f]{6})/m)
    healthyColor = m ? m[1] : Color.foreground
  }

  FileView {
    id: themeColorsView
    path: root.themeColorsFile
    watchChanges: true
    printErrors: false
    onLoaded: root.applyHealthyColor(text())
    onLoadFailed: root.applyHealthyColor("")
  }

  FileView {
    path: root.themeNameFile
    watchChanges: true
    printErrors: false
    onFileChanged: themeColorsView.reload()
  }
}
