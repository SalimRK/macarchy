import QtQuick
import Quickshell
import Quickshell.Io

// All state lives here, polled from `macarchy status --json`. Panel.qml
// only reads these properties and calls the CLI directly for actions --
// same split tormarchy's Service.qml / Panel.qml use.
Item {
  id: root

  property var settings: ({})

  // One entry per real interface: {iface, current, permanent, randomized}.
  property var interfaces: []
  property bool installed: false
  property string lastError: ""
  property bool refreshing: false

  readonly property bool anyRandomized: interfaces.some(function(i) { return i.randomized })
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 5, 2, 300)

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

  // Modeled on tormarchy's own statusProcess: onStreamFinished alone never
  // fires if the binary can't be spawned at all (confirmed live -- before
  // `macarchy setup` has installed /usr/local/bin/macarchy, Quickshell logs
  // "Process failed to start" and no stdout stream ever opens), so
  // `installed` would stay stuck at its initial default forever. Checking
  // exitCode in onExited is what actually distinguishes "not installed yet"
  // (127, shell convention for command-not-found) from a real parse error.
  Process {
    id: statusProc
    running: false
    command: ["/usr/local/bin/macarchy", "status", "--json"]
    stdout: StdioCollector { id: statusStdout; waitForEnd: true }
    onExited: function(exitCode) {
      root.refreshing = false
      if (exitCode === 127) {
        root.installed = false
        root.interfaces = []
        root.lastError = ""
        return
      }
      if (exitCode !== 0) {
        root.lastError = "macarchy status exited " + exitCode
        return
      }
      try {
        var parsed = JSON.parse(statusStdout.text)
        root.interfaces = parsed.interfaces || []
        root.installed = true
        root.lastError = ""
      } catch (e) {
        root.lastError = String(e)
      }
    }
  }

  function randomize(iface) {
    Quickshell.execDetached(["/usr/local/bin/macarchy", "randomize", iface])
    root.refresh()
  }

  function restore(iface) {
    Quickshell.execDetached(["/usr/local/bin/macarchy", "restore", iface])
    root.refresh()
  }

  function toggle(iface) {
    Quickshell.execDetached(["/usr/local/bin/macarchy", "toggle", iface])
    root.refresh()
  }

  function panic() {
    Quickshell.execDetached(["/usr/local/bin/macarchy", "panic"])
    root.refresh()
  }
}
