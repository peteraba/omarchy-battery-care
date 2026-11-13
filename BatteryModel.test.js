import { expect, test } from "bun:test"
const { parseChargeState, chargeModesFor } = require("./BatteryModel.js")

test("ideapad charge_types", () => {
  expect(parseChargeState("types /sys/class/power_supply/BAT1\nFast [Long_Life] Standard\n"))
    .toEqual({ backend: "types", batteryDir: "/sys/class/power_supply/BAT1", chargeType: "Long_Life" })
})

test("thinkpad thresholds", () => {
  expect(parseChargeState("threshold /sys/class/power_supply/BAT0\n80\n").chargeType).toBe("Long_Life")
  expect(parseChargeState("threshold /sys/class/power_supply/BAT0\n100\n").chargeType).toBe("Standard")
  expect(chargeModesFor("threshold")).toEqual(["Standard", "Long_Life"])
})

test("no backend", () => {
  expect(parseChargeState("")).toEqual({ backend: "", batteryDir: "", chargeType: "" })
  expect(chargeModesFor("")).toEqual([])
})
