import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Ui
import qs.Commons

// Structure mirrors tormarchy's Panel.qml: a BarIconButton for the bar
// slot, a KeyboardPanel anchored to it for the popup, real qs.Ui content
// components inside (PanelSectionHeader/PanelSeparator/Button) rather than
// hand-rolled chrome. Kept deliberately simpler than tormarchy's own panel
// (no keyboard row-navigation yet, mouse-only for v1) -- see README.md's
// "Not yet built" section.
Panel {
  id: root
  moduleName: "oniomarchy.macarchy"
  ipcTarget: "oniomarchy.macarchy"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Lit when at least one interface is currently randomized -- mirrors
  // tormarchy's rule that the bar icon only ever reports real state.
  readonly property color barIconColor: service.anyRandomized ? barForeground : dim
  readonly property string icon: String.fromCodePoint(0xf074) // fa-random

  // Client-side gate only, for the Set button's enabled state -- the real
  // validation the security boundary relies on lives in the CLI script
  // itself (is_valid_mac), not here.
  readonly property var macRe: /^[0-9a-fA-F]{2}(:[0-9a-fA-F]{2}){5}$/

  // Whether each row's "set a specific MAC" input is expanded. Keyed by
  // iface name and kept here rather than on the delegate Item itself:
  // service.interfaces is a whole new array on every poll (no stable
  // object identity), so any state that lived on the delegate would be
  // at risk of resetting whenever a refresh lands mid-interaction.
  property var expandedIfaces: ({})

  function isExpanded(iface) { return !!expandedIfaces[iface] }
  function toggleExpanded(iface) {
    var next = Object.assign({}, expandedIfaces)
    next[iface] = !next[iface]
    expandedIfaces = next
  }

  // Verb shown on a row's action button while its own action is running;
  // "" for every other row, which keeps their normal Randomize/Restore text.
  function actionLabel(iface) {
    if (service.pendingIface !== iface) return ""
    if (service.pendingAction === "randomize") return "Randomizing…"
    if (service.pendingAction === "restore") return "Restoring…"
    if (service.pendingAction === "toggle") return "Working…"
    if (service.pendingAction === "set") return "Setting…"
    return ""
  }

  Service {
    id: service
    settings: root.settings
  }

  IpcHandler {
    target: "oniomarchy.macarchy"
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: service.refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    foreground: root.barIconColor

    onPressed: function(b) {
      if (root.opened) root.close()
      else root.open()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(300))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t === "r" || t === "R") service.refresh() }
    }

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(10)

      PanelSectionHeader {
        text: "MAC ADDRESSES"
        foreground: root.foreground
        fontFamily: root.fontFamily
      }

      // Setup hasn't run yet, or the CLI's own JSON came back unparsable.
      Text {
        visible: !service.installed
        width: parent.width
        wrapMode: Text.WordWrap
        text: "Not set up yet. Run: macarchy setup"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Text {
        visible: service.installed && service.interfaces.length === 0
        width: parent.width
        text: "No real network interfaces found."
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }

      Repeater {
        model: service.installed ? service.interfaces : []

        delegate: Item {
          id: row
          required property var modelData
          width: column.width
          implicitHeight: rowColumn.implicitHeight

          Column {
            id: rowColumn
            width: parent.width
            spacing: Style.space(6)

            RowLayout {
              width: parent.width
              spacing: Style.space(10)

              Column {
                Layout.fillWidth: true
                spacing: Style.space(2)

                Text {
                  text: row.modelData.iface
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }

                Text {
                  text: row.modelData.current
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }

                // Separate line rather than crammed onto the current-MAC
                // line -- two MAC addresses plus a label don't fit
                // alongside the Randomize/Restore button on one line
                // without truncating (confirmed live: it was cutting off).
                Text {
                  visible: row.modelData.randomized
                  text: "permanent: " + row.modelData.permanent
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                  width: parent.width
                }
              }

              Button {
                readonly property string label: root.actionLabel(row.modelData.iface)
                text: label !== "" ? label : (row.modelData.randomized ? "Restore" : "Randomize")
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !service.busy
                onClicked: service.toggle(row.modelData.iface)
              }
            }

            // Collapsed by default -- always showing a text field per row
            // was clutter for the common case (most clicks are just
            // Randomize/Restore), confirmed against the first version.
            // Accent color + bold + underline-on-hover so it reads as a
            // link rather than a plain label -- the initial dim/plain
            // version didn't signal clickability.
            Text {
              id: customMacToggle
              property bool hovered: false
              text: root.isExpanded(row.modelData.iface) ? "▾ custom MAC" : "▸ custom MAC"
              color: hovered ? root.foreground : Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.underline: hovered

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: customMacToggle.hovered = true
                onExited: customMacToggle.hovered = false
                onClicked: root.toggleExpanded(row.modelData.iface)
              }
            }

            // Set to a specific address rather than a random one. Enabled
            // only once the text matches a real MAC -- the CLI's own
            // is_valid_mac is the actual security boundary, this is just
            // UI feedback.
            RowLayout {
              visible: root.isExpanded(row.modelData.iface)
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: macField
                Layout.fillWidth: true
                placeholderText: "xx:xx:xx:xx:xx:xx"
                foreground: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                verticalPadding: Style.space(4)
                enabled: !service.busy
                onAccepted: {
                  if (!root.macRe.test(text)) return
                  service.setMac(row.modelData.iface, text)
                  text = ""
                }
              }

              Button {
                readonly property string label: root.actionLabel(row.modelData.iface)
                text: label !== "" ? label : "Set"
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !service.busy && root.macRe.test(macField.text)
                onClicked: {
                  service.setMac(row.modelData.iface, macField.text)
                  macField.text = ""
                }
              }
            }
          }
        }
      }

      PanelSeparator {
        visible: service.installed && service.interfaces.length > 0
        foreground: root.foreground
      }

      Button {
        visible: service.installed && (service.anyRandomized || service.pendingAction === "panic")
        text: service.pendingAction === "panic" ? "Restoring All…" : "Restore All"
        foreground: root.urgent
        fontFamily: root.fontFamily
        enabled: !service.busy
        onClicked: service.panic()
      }
    }
  }
}
