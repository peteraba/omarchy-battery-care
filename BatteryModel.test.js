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

test("low battery warns at 25% then every 5%, resets on charge", () => {
  const { shouldWarnLowBattery } = require("./BatteryModel.js")
  const DIS = 2
  const dev = (pct, state = DIS) => ({ isPresent: true, percentage: pct / 100, state })
  let last = -1
  const step = (pct, onBattery = true, state = DIS) => {
    const r = shouldWarnLowBattery(dev(pct, state), onBattery, DIS, 25, last, 5)
    last = r.lastWarnedLevel
    return r.notify
  }
  expect(step(26)).toBe(false)
  expect(step(25)).toBe(true)
  expect(step(23)).toBe(false)
  expect(step(20)).toBe(true)
  expect(step(19)).toBe(false)
  expect(step(15)).toBe(true)
  expect(step(15, false, 1)).toBe(false)
  expect(last).toBe(-1)
  expect(step(22)).toBe(true)
})

test("repeat step 0 warns once per discharge", () => {
  const { shouldWarnLowBattery } = require("./BatteryModel.js")
  const dev = (pct) => ({ isPresent: true, percentage: pct / 100, state: 2 })
  let r = shouldWarnLowBattery(dev(10), true, 2, 10, -1, 0)
  expect(r.notify).toBe(true)
  r = shouldWarnLowBattery(dev(3), true, 2, 10, r.lastWarnedLevel, 0)
  expect(r.notify).toBe(false)
})

test("intSetting parses and clamps", () => {
  const { intSetting } = require("./BatteryModel.js")
  expect(intSetting("25", 10, 1, 100)).toBe(25)
  expect(intSetting(undefined, 10, 1, 100)).toBe(10)
  expect(intSetting("abc", 0, 0, 100)).toBe(0)
  expect(intSetting(500, 10, 1, 100)).toBe(100)
})
