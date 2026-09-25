import QtQuick
import Quickshell.Io

// All state lives here, polled from `macarchy status --json`. Panel.qml
// only reads these properties and calls the CLI directly for actions --
// same split tormarchy's Service.qml / Panel.qml use.
Item {
  id: root

  property var settings: ({})

  // One entry per real interface: {iface, current, permanent, randomized}.
  property var interfaces: []
  // False until the first status read lands (or if it keeps failing).
  property bool loaded: false
  property string lastError: ""
  property bool refreshing: false

  readonly property bool anyRandomized: interfaces.some(function(i) { return i.randomized })
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 5, 2, 300)

  // The CLI runs straight from this plugin checkout, as the user -- there
  // is no installed copy. If it elevates at all, it is only for `ip link set`.
  readonly property string cli: decodeURIComponent(Qt.resolvedUrl("macarchy").toString().replace(/^file:\/\//, ""))

  // Which interface (if any) has an action in flight, and which one --
  // "randomize" | "restore" | "set" | "panic" ("" iface for panic, since
  // it touches every interface at once). Tracked here rather than left to
  // a fire-and-forget execDetached so the panel can show real progress
  // instead of going quiet for up to refreshIntervalSec seconds after a
  // click, and so other rows can disable themselves while one action is
  // mid-flight -- same reasoning as tormarchy's own `busy` gate.
  property string pendingIface: ""
  property string pendingAction: ""
  readonly property bool busy: pendingAction !== ""

  function intSetting(name, fallback, min, max) {
    var value = settings ? settings[name] : undefined
    var n = Number(value)
    if (isNaN(n)) return fallback
    return Math.max(min, Math.min(max, n))
  }

  function refresh() {
    if (statusProc.running) return
    refreshing = true
    statusProc.running = true
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    running: false
    command: ["/bin/bash", root.cli, "status", "--json"]
    stdout: StdioCollector { id: statusStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode !== 0) {
        root.lastError = "macarchy status exited " + exitCode
        return
      }
      try {
        var parsed = JSON.parse(statusStdout.text)
        root.interfaces = parsed.interfaces || []
        root.loaded = true
        root.lastError = ""
      } catch (e) {
        root.lastError = String(e)
      }
    }
  }

  // One action at a time, same serialization tormarchy's runNetworkAction
  // uses -- a second click while one is already running would otherwise
  // race the same interface.
  function runAction(iface, args, action) {
    if (actionProc.running) return
    pendingIface = iface
    pendingAction = action
    actionProc.command = ["/bin/bash", root.cli].concat(args)
    actionProc.running = true
  }

  function randomize(iface) { runAction(iface, ["randomize", iface], "randomize") }
  function restore(iface) { runAction(iface, ["restore", iface], "restore") }
  function toggle(iface) { runAction(iface, ["toggle", iface], "toggle") }
  function setMac(iface, mac) { runAction(iface, ["set", iface, mac], "set") }
  function panic() { runAction("", ["panic"], "panic") }

  Process {
    id: actionProc
    running: false
    command: []
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = String(actionStderr.text || actionStdout.text
          || ("macarchy " + root.pendingAction + " exited " + exitCode))
      }
      root.pendingIface = ""
      root.pendingAction = ""
      root.refresh()
    }
  }
}
