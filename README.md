# Macarchy

A MAC-address toggle for the Omarchy bar. Click an interface, its MAC
randomizes. Click it again, it's back to the permanent one.

---

Needs Omarchy 4.x and `macchanger`. `setup` installs `macchanger` itself if
it isn't already there.

## Install

```bash
omarchy plugin add https://github.com/SalimRK/macarchy.git --enable
sudo ~/.config/omarchy/plugins/oniomarchy.macarchy/macarchy setup
```

`setup` needs a terminal and tells you everything it touches as it goes.
For the record, that's: `macchanger` installed, `macarchy` copied to
`/usr/local/bin`, and a polkit rule so toggling doesn't ask for a password.

## Removing it

```bash
sudo ~/.config/omarchy/plugins/oniomarchy.macarchy/macarchy uninstall
omarchy plugin remove oniomarchy.macarchy
```

`uninstall` restores every interface to its permanent MAC first, then
removes the polkit rule and the installed binary. Add `--purge` to also
remove the `macchanger` package.

## Panel

Click the icon to open the panel: one row per real network interface,
showing its current MAC (and the permanent one, once randomized), with a
Randomize/Restore button. "Restore All" appears once anything is
randomized — the escape hatch if you lose track of which interfaces you
touched.

## Commands

| | |
|---|---|
| `macarchy status [--json]` | Current state of every real interface. |
| `macarchy randomize <iface>` | Randomize one interface's MAC. |
| `macarchy restore <iface>` | Restore one interface's permanent MAC. |
| `macarchy toggle <iface>` | Flip based on current state. |
| `macarchy panic` | Restore every interface at once. |
| `macarchy setup` / `uninstall [--purge]` | Install or remove the system side. Terminal + sudo only. |

## What it costs

Changing a MAC address bounces the link: if NetworkManager manages the
interface, it's disconnected and reconnected around the change, which
means a brief drop in connectivity on that interface.

A randomized MAC doesn't survive every driver/firmware combination
through a real reassociation — confirmed on an Intel `iwlwifi` card,
where the permanent MAC comes back the moment the interface actually
re-associates with the AP. This isn't something NetworkManager's own
`cloned-mac-address` setting can override (tested: setting it to
`preserve` made no difference), which means the reset happens in the
driver/firmware during association itself, below anything userspace
configures. `macarchy status` always reports the truth, so this shows up
rather than silently failing.

## Not yet built

- Randomize-on-connect (a persistent per-interface setting, rather than a
  manual click every time).
- Vendor/OUI display for the current MAC.
- Keyboard row-navigation inside the panel (mouse-only for now).

## License

MIT
