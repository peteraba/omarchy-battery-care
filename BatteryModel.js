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

if (typeof module !== "undefined") {
  module.exports = {
    batteryPercentage: batteryPercentage,
    isDischarging: isDischarging,
    shouldWarnLowBattery: shouldWarnLowBattery,
    chargeModeIcon: chargeModeIcon
  }
}
