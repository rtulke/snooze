# snooze — Reference

**[README](README.md) · [Vollständige Referenz](REFERENZ_de.md)**

The full command reference for `snooze`. Start with [README.md](README.md) for
installation and basic configuration — this document covers everything else.

- [Language](#language)
- [Options](#options)
- [Scheduled start (`snooze plan`)](#scheduled-start-snooze-plan)
- [Duration](#duration)
- [Targets](#targets)
- [Examples](#examples)
- [Status display (`list active`, `list plans`)](#status-display-list-active-list-plans)
- [Suppressed problems (`list suppressed`)](#suppressed-problems-list-suppressed)
- [How it works](#how-it-works)
- [Exit codes](#exit-codes)
- [Notes and gotchas](#notes-and-gotchas)
- [Security](#security)
- [Installation details](#installation-details)
- [Packaging](#packaging)

## Language

All output (`OK`/`ERROR` lines, error messages, `snooze help`) is available in German and
English. Chosen at startup from the system locale, checked in order
`LC_ALL` → `LC_MESSAGES` → `LANG`: German if the first value that's set starts with `de`
(`de_DE`, `de_CH`, `de_AT`, `de_LI`, `de_LU`, `de_BE`, `de_IT`, … — any German-speaking
region, not a fixed country list), otherwise English — including when no locale is set at all.

```bash
LC_ALL=de_DE.UTF-8 snooze help     # German
LC_ALL=en_US.UTF-8 snooze help     # English
LC_ALL=fr_FR.UTF-8 snooze help     # English (default, since it's not German)
```

`lang` in the config (or `SNOOZE_LANG`) can pin this to `de` or `en` regardless of the
system locale — e.g. if the admin host has `LC_ALL=de_DE.UTF-8` set but `snooze` should
still produce English output there. Empty (the default) leaves automatic detection via
`LC_ALL`/`LC_MESSAGES`/`LANG` in charge.

```ini
[snooze]
lang = en    # forces English, regardless of the system locale
lang =       # default: automatic based on the system locale
```

## Options

| Option              | Effect                                                                    |
|---------------------|-----------------------------------------------------------------------------|
| `-F`, `--file FILE` | Read targets from FILE (one token per line, `#` = comment; `-` = stdin)     |
| `-Y`, `--yes`       | Skip the confirmation prompt for many targets                                |
| `--reason TEXT`     | Set the reason (overrides config; `{user}`/`{host}` allowed)                 |

Everything after `--` is treated as a target, even if it starts with `-`.

Piped/redirected input is read automatically, even without `-F -`: whenever stdin isn't
a TTY, `snooze` reads it the same way `-F -` would and adds whatever targets it finds to
whatever was given on the command line. An interactive terminal (no pipe) is left alone,
so a bare `snooze` never blocks waiting for input you didn't intend to send.

```bash
echo host1 host2 host3 | snooze          # mute all three for the default duration
echo host1 host2 host3 | snooze 2h       # ... for 2h
zabbix-get-my-broken-hosts | snooze unmute
```

## Scheduled start (`snooze plan`)

Instead of muting immediately, a maintenance window can be scheduled for a later time:
`snooze plan TIME [DURATION] [TARGETS…]`. `TIME` always comes first — after that, the
same rules as `mute` apply (DURATION optional, otherwise the config default; no target =
local host).

Two formats for `TIME`:

| Format                | Meaning                                                                    |
|------------------------|------------------------------------------------------------------------------|
| `HH:MM`                | Today's date, one token. If that time has already passed today, `snooze` errors out (no automatic roll-over to tomorrow) — give the date explicitly instead. |
| `DD.MM.YYYY HH:MM`     | Fixed day and time. Unquoted, two tokens (`22.5.2026 14:00` → `22.5.2026` and `14:00` separately); quoted as one token works just as well. Leading zeros on day/month are optional (both `2.5.2026` and `02.05.2026` work). |

A time in the past is an error in either form (exit code `2`).

```bash
# Mute for 2h starting tonight at 22:00
snooze plan 22:00 2h host1

# Schedule a specific day (leading zero optional, unquoted)
snooze plan 22.5.2026 14:00 4h "@Servers/Linux"
snooze plan 02.05.2026 14:00 4h "@Servers/Linux"

# Show planned (not-yet-started) windows
snooze list plans
```

A planned window only shows up in `snooze list active` once it has started — before
that, it's under `snooze list plans`. Internally, `active_since` is simply set to the
planned time instead of "now"; `extend`/`unmute` work the same on a not-yet-started
window as on a running one.

## Duration

Format: `<number><suffix>`.

| Suffix      | Meaning              |
|-------------|----------------------|
| `m`, `min`  | Minutes              |
| `h`         | Hours                |
| `d`         | Days                 |
| `w`         | Weeks (7 days)       |
| `M`         | Months (30 days)     |

Examples: `30m`, `30min`, `4h`, `2d`, `1w`, `1M`. If no duration is given, `3h` applies.

> **Note:** lowercase `m` (and `min`) are minutes, uppercase `M` is a month.

## Targets

- **Hosts**: names without a dot automatically get `.domain.tld` appended
  (e.g. `prd-mail-5` becomes `prd-mail-5.domain.tld`). Names with a dot are left unchanged.
- **Glob**: hostnames may contain `*`, `?` and `[…]` and are resolved against the
  Zabbix host list, e.g. `prd-mail-*` or `tst-foo-?`.
- **Regex**: with a `~` prefix, e.g. `~^prd-mail-\d+$`. Matches against the technical hostname.
- **Hostgroups**: prefix with `@`. Since group names can contain slashes and spaces
  (e.g. `Servers/Linux`, `Discovered hosts`), quote them:
  `"@Servers/Linux"`. (Glob/regex only apply to hosts, not groups.)
- Hosts, patterns, and groups can be mixed in a single call.
- Find valid names with `snooze list hosts` or `snooze list groups`.

If a glob/regex matches many hosts, or many targets are passed, `snooze` asks for
confirmation above `confirm_threshold` targets. `-Y`/`--yes` skips the prompt; without
a TTY (e.g. in scripts), `-Y` is then mandatory.

## Examples

```bash
# Mute the local host for the default duration (3h)
snooze

# Mute the local host for 4h
snooze 4h

# Mute a host without a duration -> 3h
snooze mute prd-mail-5

# Mute multiple hosts for 2 days
snooze 2d prd-mail-5 prd-mail-mx-1

# Mute all prd-mail hosts via glob for 2h
snooze 2h 'prd-mail-*'

# Mute via regex
snooze 1h '~^tst-.*-mx-\d+$'

# Mute an entire hostgroup for 2h
snooze 2h "@Servers/Linux"

# Mix hosts and a group, without confirmation
snooze mute 2h -Y "@Servers/Linux" prd-mail-5

# Targets from a file (one per line), or piped stdin (-F - works too, but isn't required)
snooze 1d -F /tmp/hosts.txt
echo prd-mail-5 | snooze 1d

# Extend a running mute by another 2h
snooze extend 2h prd-mail-5

# Mute with an explicit reason
snooze 2h prd-mail-5 --reason "Storage maintenance, ticket #4711"

# Remove a mute
snooze unmute "@Servers/Linux"
snooze unmute prd-mail-5

# Overviews and cleanup
snooze list hosts
snooze list groups
snooze list active     # or snooze status
snooze list plans      # planned, not-yet-started windows (snooze plan)
snooze cleanup         # delete expired windows

# What would alert immediately on wake-up?
snooze list suppressed prd-mail-5
snooze list suppressed "@Servers/Linux"
snooze list suppressed         # all windows currently managed by snooze
```

## Status display (`list active`, `list plans`)

`snooze list active` shows all already-**started** snooze maintenance windows with
remaining time, end time, and (if set) the reason:

```
@Servers/Linux                1h 47m left     (until 2026-06-01 15:30)  [ansible@desktop]
prd-mail-5.domain.tld         42m left        (until 2026-06-01 14:25)  [Storage maintenance, ticket #4711]
tst-foo.domain.tld            expired         (until 2026-06-01 12:00)  [sysadm@blackbox]
```

"expired" shows up because Zabbix doesn't remove expired maintenance windows on its own.
Such entries stay visible until deleted via `unmute` or `cleanup`.

Windows scheduled via `snooze plan` but not yet started do **not** show up here —
they're under `snooze list plans` instead:

```
prd-mail-5.domain.tld         starts 2026-08-16 22:00  until 2026-08-17 02:00  [ansible@desktop]
```

## Suppressed problems (`list suppressed`)

A host in maintenance still generates problems in Zabbix; they're just marked
`suppressed` and not alerted/shown. `snooze list suppressed` queries exactly these
suppressed problems and shows only the ones **suppressed by that specific snooze
window** (matched via `maintenanceid`, not any unrelated Zabbix maintenance). That
answers: "what would alert immediately if I `unmute` right now?"

```bash
snooze list suppressed prd-mail-5    # only for this target
snooze list suppressed               # for all windows currently managed by snooze
```

```
prd-mail-5.domain.tld  [High]     Disk space is low on /var  since 2026-06-01 12:03
prd-mail-5.domain.tld  [Average]  CPU load high              since 2026-06-01 13:10
tst-foo.domain.tld     no suppressed problems
```

An already-expired snooze window automatically shows no more suppressed problems
(Zabbix no longer suppresses anything via it) — no separate status is needed for that.

## How it works

- Each target gets its own maintenance window with a unique name:
  hosts are named `snooze:<host>`, groups `snooze:@<group>`.
- When muting, an already-existing window of the same name is updated via
  `maintenance.update` (no delete+recreate, so the target is never briefly
  unmuted). Running `mute` again therefore extends/updates the mute idempotently.
- `extend` extends an existing window by the given duration from its current
  end (or from now, if it has already expired).
- `unmute` looks up the window by its name and deletes it.
- `cleanup` deletes all `snooze:` windows whose end lies in the past.
- Windows use `maintenance_type = 0` (maintenance with data collection) and
  exactly one time period spanning the requested duration; `reason` ends up
  in the `description` field.

## Exit codes

| Code  | Meaning                                                              |
|-------|------------------------------------------------------------------------|
| `0`   | Everything succeeded                                                   |
| `1`   | At least one target not found or failed                                |
| `2`   | Usage error (e.g. `list` without a subcommand, aborted confirmation)   |
| `130` | Aborted via Ctrl-C                                                     |

## Notes and gotchas

- Hostgroup actions apply to all group members at the time the window is created.
- Zabbix can have several distinct "hosts" with spaces in the name
  (e.g. `prd-zabbix-1.domain.tld Zabbix server`). `snooze list hosts` shows these
  exactly as Zabbix has them.
- Clean up expired maintenance windows occasionally with `snooze cleanup`.

## Security

The `token` currently sits in plaintext in `/etc/snooze.conf`. Anyone who can read the
file can see the token. Access is therefore controlled via file permissions: `0640`,
owner `root`, read access only for `admin_users` (via ACL) in this project's own
Ansible-managed deployment — see **Installation details** below for what that means for
other install methods.

The plan is to inject the token via Ansible Vault (`vault_zabbix_token`) and rotate it
from there. Since the script reads `SNOOZE_TOKEN`/`ZABBIX_TOKEN` from the environment,
the token can in the future also be supplied without any file at all (e.g. via
`EnvironmentFile`).

## Installation details

The Ansible play in `main.yml` is how this project's own admin hosts get `snooze`:
copied to `/usr/local/sbin/snooze` and restricted to `admin_users` via a POSIX ACL
rather than being world-executable. The `.deb`, Homebrew, and `make install` paths in
[README.md](README.md) are all plain, unrestricted installs (normal `0755`,
world-executable) — apply an ACL yourself if you want that restriction outside the
Ansible-managed fleet.

**From source (any platform with Python 3):**

```bash
sudo make install    # installs to /usr/local/sbin/snooze + man page + bash completion
                      # + /etc/snooze.conf.example
```

**Building the `.deb` yourself:**

```bash
packaging/build-deb.sh      # -> dist/snooze_<version>_all.deb
packaging/test-install.sh   # installs it into a fresh container of each target distro
```

See **Packaging** below for how these work and what they verify.

## Packaging

Two things are packaged from this repo: a `.deb` for Debian/Ubuntu and a Homebrew
formula for Linux/macOS. Both wrap the same single script — there's no compiled/native
dependency to build, so packaging is entirely about laying files out correctly and
declaring `python3` as a runtime dependency.

**`.deb` (Debian/Ubuntu):**

```bash
packaging/build-deb.sh      # -> dist/snooze_<version>_all.deb
packaging/test-install.sh   # installs the .deb into a fresh container of each
                             # target distro (apt-get install, not dpkg -i, so
                             # declared Depends: actually has to resolve) and
                             # runs a functional smoke test
```

One `all`-architecture package installs everywhere — unlike a compiled tool, there's no
per-distro library-version skew (see `rtulke/cryptc`'s `packaging/build-deb.sh` for what
that problem looks like and why it forces separate builds there). Verified on Debian
12/13 and Ubuntu 24.04/26.04. `.github/workflows/release.yml` runs the same build +
verify steps in CI on every push, and publishes to GitHub Releases on a `vX.Y` tag (plus
a rolling `latest` prerelease on `main`).

The package installs the script to `/usr/sbin/snooze`, the `snooze(1)` man page, bash
completion, and `/etc/snooze.conf.example`; a `postinst` script seeds `/etc/snooze.conf`
from that example on first install (never overwriting an existing file, same `force:
false` philosophy as this repo's own Ansible deployment) and `postrm purge` removes it
again.

**Homebrew (Linux, macOS):**

`Formula/snooze.rb` here is the source of truth (same layout as `rtulke/airsnare`'s
`Formula/airsnare.rb`); [rtulke/homebrew-snooze](https://github.com/rtulke/homebrew-snooze)
is the actual tap — a separate `homebrew-<name>` repo is what makes `rtulke/snooze` a tap
Homebrew can resolve at all. Bump `url`/`sha256` in both copies on each release:
`git tag vX.Y && git push origin vX.Y`, then `curl -sL
.../archive/refs/tags/vX.Y.tar.gz | shasum -a 256`.

The formula name collides with homebrew-core's own `snooze`
([leahneukirchen/snooze](https://github.com/leahneukirchen/snooze), an unrelated cron
replacement). Core takes precedence over any tap for a bare formula name, so the install
instructions must always use the fully qualified `rtulke/snooze/snooze` — `brew tap` does
not change which formula a bare `snooze` resolves to. Both formulae install a `snooze`
binary and therefore cannot be linked simultaneously; `brew link --overwrite` would be
needed to force it. Anything that installs from this tap in CI or scripts needs the
qualified name too.
