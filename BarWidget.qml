import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "BatteryModel.js" as BatteryModel

Panel {
  id: root
  moduleName: "pixeltux.battery"
  ipcTarget: "pixeltux.battery"

  readonly property var svc: bar && bar.shell ? bar.shell.serviceFor("pixeltux.battery") : null
  readonly property bool available: svc ? svc.conservationAvailable : false
  readonly property bool conservationOn: svc ? svc.conservationOn : false
  readonly property string chargeType: svc ? svc.chargeType : ""

  // Mode glyph comes from BatteryModel; color is per mode: accent for Fast,
  // the theme green for Long_Life, a dimmed foreground for Standard.
  // Empty/unknown charge type keeps the plain battery in the normal color.
  readonly property string chargeGlyph: BatteryModel.chargeModeIcon(root.chargeType)

  function modeColor(id) {
    if (!root.bar) return Color.foreground
    if (id === "Fast") return Color.accent
    if (id === "Long_Life") return root.svc ? root.svc.healthyColor : root.bar.foreground
    if (id === "Standard") return Qt.darker(root.bar.foreground, 1.45)
    return root.bar.foreground
  }

  readonly property var chargeModes: [
    { id: "Fast", label: "Fast", hint: "Rapid charge to 100%" },
    { id: "Standard", label: "Standard", hint: "Normal charge to 100%" },
    { id: "Long_Life", label: "Long life", hint: "Stops at 80% — best for battery lifespan" }
  ]

  readonly property bool batteryPresent: !!(UPower.displayDevice && UPower.displayDevice.isPresent)
  readonly property real batteryPercent: batteryPresent ? Math.round(UPower.displayDevice.percentage * 100) : 0
  readonly property bool discharging: batteryPresent && UPower.onBattery
  readonly property string batteryState: {
    if (!batteryPresent) return ""
    if (!discharging && UPower.displayDevice.state === UPowerDeviceState.FullyCharged) return "Fully charged"
    return discharging ? "Discharging" : "Charging"
  }
  readonly property int batteryHealth: svc ? svc.batteryHealthPct : -1

  onOpenedChanged: {
    if (root.svc) {
      root.svc.panelOpen = opened
      if (opened) root.svc.refreshConservation()
    }
  }

  visible: root.available
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.chargeGlyph
    active: root.conservationOn
    useActiveColor: false
    foreground: root.modeColor(root.chargeType)
    tooltipText: {
      if (root.chargeType === "Long_Life") return "Charge cap ON (stops at 80%) — click for options, right-click for Standard"
      if (root.chargeType === "Fast") return "Fast charging to 100% — click for options"
      return "Charging to 100% — click for options, right-click for the 80% cap"
    }
    onPressed: function(b) {
      if (!root.available) return
      if (b === Qt.RightButton) root.svc.setChargeType(root.chargeType === "Long_Life" ? "Standard" : "Long_Life")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened && root.available
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: battery glyph · title · percentage/state ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            text: root.chargeGlyph
            color: root.modeColor(root.chargeType)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.spacing.labelGap

            Text {
              text: "Battery care"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
            }

            Text {
              text: root.batteryPresent
                ? root.batteryPercent + "% · " + root.batteryState
                : "No battery detected"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
            }
          }
        }

        // ---------- Charge mode picker ----------
        PanelSectionHeader {
          text: "CHARGE MODE"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: root.chargeModes

            delegate: Column {
              required property var modelData
              width: (parent.width - parent.spacing * 2) / 3
              spacing: Style.space(6)

              Button {
                width: parent.width
                iconText: BatteryModel.chargeModeIcon(modelData.id)
                iconSize: Style.font.title
                text: modelData.label
                fontSize: Style.font.bodySmall
                foreground: root.modeColor(modelData.id)
                fontFamily: root.bar.fontFamily
                horizontalPadding: Style.spacing.controlPaddingX
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                active: root.chargeType === modelData.id
                onClicked: root.svc.setChargeType(modelData.id)
              }

              Text {
                width: parent.width
                text: modelData.hint
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }
        }

        // ---------- Battery health ----------
        PanelSeparator {
          foreground: root.bar.foreground
        }

        Row {
          width: parent.width
          spacing: Style.space(20)

          InfoPair {
            width: (parent.width - parent.spacing) / 2
            label: "Charge cycles"
            value: root.svc && root.svc.cycleCount >= 0 ? String(root.svc.cycleCount) : "—"
          }

          InfoPair {
            width: (parent.width - parent.spacing) / 2
            label: "Battery health"
            value: root.batteryHealth > 0 ? root.batteryHealth + "%" : "—"
          }
        }
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    spacing: Style.space(8)

    Text {
      text: label
      color: root.bar.foreground
      opacity: 0.6
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Item {
      width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2)
      height: 1
    }

    Text {
      text: value
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}

