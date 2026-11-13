function batteryPercentage(device) {
  if (!device || !device.isPresent) return -1
  return Math.round(Number(device.percentage || 0) * 100)
}

function isDischarging(device, onBattery, dischargingState) {
  return !!(device && device.isPresent && onBattery && device.state === dischargingState)
}

function shouldWarnLowBattery(device, onBattery, dischargingState, threshold, alreadyNotified) {
  var level = batteryPercentage(device)
  if (level < 0) return { level: level, notify: false, notifiedLowBattery: false }

  var low = isDischarging(device, onBattery, dischargingState) && level <= threshold
  return {
    level: level,
    notify: low && !alreadyNotified,
    notifiedLowBattery: low
  }
}

// Charge-mode glyphs (Nerd Font / Material Design Icons; supplementary plane,
// hence the surrogate-pair escapes):
//   Fast      U+F0084 nf-md-battery_charging
//   Standard  U+F0079 nf-md-battery
//   Long_Life U+F1211 nf-md-battery_heart_variant
var CHARGE_MODE_ICONS = {
  Fast: "\uDB80\uDC84",
  Standard: "\uDB80\uDC79",
  Long_Life: "\uDB84\uDE11"
}

// Unknown/empty charge type renders as the plain battery: the widget's
// pre-existing glyph, so a failed charge_types read changes nothing.
function chargeModeIcon(chargeType) {
  return CHARGE_MODE_ICONS[String(chargeType || "")] || CHARGE_MODE_ICONS.Standard
}

// ThinkPads have no Fast mode; an 80% end threshold is the Long_Life cap.
var LONG_LIFE_THRESHOLD = 80

function chargeModesFor(backend) {
  if (backend === "types") return ["Fast", "Standard", "Long_Life"]
  if (backend === "threshold") return ["Standard", "Long_Life"]
  return []
}

// Parses the Service detect script output: "<backend> <battery dir>\n<value>".
function parseChargeState(text) {
  var lines = String(text || "").trim().split("\n")
  var head = lines[0] || ""
  var space = head.indexOf(" ")
  var backend = space > 0 ? head.slice(0, space) : ""
  var batteryDir = space > 0 ? head.slice(space + 1) : ""
  var value = lines[1] || ""
  var chargeType = ""
  if (backend === "types") {
    var m = value.match(/\[([^\]]+)\]/)
    chargeType = m ? m[1] : ""
  } else if (backend === "threshold") {
    var n = parseInt(value, 10)
    chargeType = isNaN(n) ? "" : (n <= LONG_LIFE_THRESHOLD ? "Long_Life" : "Standard")
  } else {
    batteryDir = ""
  }
  return { backend: chargeModesFor(backend).length ? backend : "", batteryDir: batteryDir, chargeType: chargeType }
}

if (typeof module !== "undefined") {
  module.exports = {
    batteryPercentage: batteryPercentage,
    isDischarging: isDischarging,
    shouldWarnLowBattery: shouldWarnLowBattery,
    chargeModeIcon: chargeModeIcon,
    chargeModesFor: chargeModesFor,
    parseChargeState: parseChargeState
  }
}
