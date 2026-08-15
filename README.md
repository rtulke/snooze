# snooze

*Give your alerts a break*

**[Deutsch](README_de.md) · [Full reference](REFERENCE.md) · [Vollständige Referenz](REFERENZ_de.md)**

`snooze` is a single-file Python 3 CLI that mutes Zabbix hosts and hostgroups by creating
time-boxed Maintenance windows over the JSON-RPC API — so a 3am pager storm because
`/var` hit 91% again doesn't have to be your problem until office hours. No dependencies,
no build step, just a script and an API token. Talks to Zabbix ≥ 6.4, prints its output
in German or English depending on your locale, and beyond a plain one-shot mute can
`extend` a running window or `plan` one ahead of a maintenance slot you already know is
coming.

```bash
snooze 2h prd-mail-5              # mute a host for 2 hours
snooze 4h "@Servers/Linux"        # mute a whole hostgroup
snooze plan 22:00 2h host1        # mute starting tonight at 22:00
snooze unmute prd-mail-5          # undo it
```

For the full command reference, target syntax (globs/regex/hostgroups), scheduled
starts, exit codes, packaging internals, and security notes, see
**[REFERENCE.md](REFERENCE.md)**.

## Requirements

- Python 3
- Network access to your Zabbix API
- A Zabbix API token

## Installation

**Debian-based distributions (Ubuntu, Mint, Raspberry Pi OS, …):**

```bash
sudo apt-get install ./snooze_*_all.deb
```

Grab the `.deb` from the [Releases page](https://github.com/rtulke/snooze/releases).

**Homebrew (Linux, macOS):**

```bash
brew install rtulke/snooze/snooze
```

Use the fully qualified name. Homebrew's core repository already ships an unrelated tool
also called [`snooze`](https://github.com/leahneukirchen/snooze) — a small cron
replacement — and core always wins over a tap for a bare formula name, so a plain
`brew install snooze` installs *that* one even after `brew tap rtulke/snooze`.

Symptom of having the wrong one: `snooze help` hangs instead of printing help (the other
tool reads `help` as a time spec and sleeps), and `file $(which snooze)` reports a
compiled executable rather than a Python script. To switch:

```bash
brew uninstall snooze               # removes homebrew-core's snooze
brew install rtulke/snooze/snooze
```

Both install a binary named `snooze`, so only one of them can be linked at a time.

Building from source, building the `.deb` yourself, and the ACL-restricted Ansible
deployment this project uses for its own admin hosts are all covered in
**[REFERENCE.md](REFERENCE.md)**.

Whichever path you use, `snooze` needs a Zabbix API token before it can do anything
beyond `--help`/`--version` — see **Configuration** below.

## Configuration

Settings live in an INI file. The **first readable** file from this list wins:

```
./snooze.conf
~/.snooze.conf
/etc/snooze.conf
```

Template: `/etc/snooze.conf.example`

| Key                 | Meaning                                                      | Default                                       |
|---------------------|----------------------------------------------------------------|-----------------------------------------------|
| `url`               | Endpoint of the Zabbix JSON-RPC API                            | `https://zabbix.domain.tld/api_jsonrpc.php`   |
| `token`             | API token (Bearer)                                              | empty                                          |
| `domain`            | Domain appended to hostnames without a dot                      | `domain.tld`                                  |
| `duration`          | Default duration when none is given                             | `3h`                                          |
| `prefix`            | Name prefix of the maintenance windows managed by `snooze`      | `snooze:`                                     |
| `timeout`           | Timeout for API calls (seconds)                                  | `15`                                          |
| `retries`           | Retries on network errors                                        | `2`                                           |
| `reason`            | Comment per window; `{user}`/`{host}` get substituted            | `{user}@{host}`                               |
| `confirm_threshold` | How many targets before confirming (`-Y` skips it)               | `10`                                          |
| `lang`              | Output language: `de`/`en`. Empty = system locale                | empty (automatic)                             |

Every value can additionally be overridden via environment variable:
`SNOOZE_URL`, `SNOOZE_TOKEN`, `SNOOZE_DOMAIN`, `SNOOZE_DURATION`, `SNOOZE_PREFIX`,
`SNOOZE_TIMEOUT`, `SNOOZE_RETRIES`, `SNOOZE_REASON`, `SNOOZE_CONFIRM_THRESHOLD`, `SNOOZE_LANG`.
`ZABBIX_TOKEN` / `ZABBIX_URL` are also accepted for token and URL (vault-friendly).

How the `de`/`en` auto-detection actually works (which `LC_*` wins, which locales count
as German) is in **[REFERENCE.md → Language](REFERENCE.md#language)**.

## Usage

| Command                                   | Effect                                                     |
|--------------------------------------------|-------------------------------------------------------------|
| `snooze`                                    | Mute the local host (where it's run) for 3h (shortcut)      |
| `snooze [DURATION] [TARGETS…]`              | Mute; `mute` is implied                                     |
| `snooze mute [DURATION] [TARGETS…]`         | Mute (explicit)                                              |
| `snooze plan TIME [DURATION] [TARGETS…]`    | Mute with a scheduled start instead of now                  |
| `snooze extend DURATION [TARGETS…]`         | Extend a running mute by DURATION                            |
| `snooze unmute [TARGETS…]`                  | Remove a mute                                                |
| `snooze list hosts`                         | List all hosts known to Zabbix                               |
| `snooze list groups`                        | List all hostgroups                                          |
| `snooze list active`                        | Show already-started snooze windows                          |
| `snooze status`                             | Alias for `snooze list active`                                |
| `snooze list plans`                         | Show planned, not-yet-started snooze windows                 |
| `snooze list suppressed [TARGETS…]`         | Show problems suppressed by snooze (no target = all)         |
| `snooze cleanup`                            | Remove expired snoozes (alias `prune`)                        |
| `snooze help`                               | Show help (also `-h`, `--help`)                                |
| `snooze version`                            | Show version and author (also `-V`, `--version`)               |

If the first token is a known command, that command runs; otherwise the entire input is
treated as arguments to `mute` — so `snooze 2h host1` and `snooze mute 2h host1` are the
same thing. Full option flags, target syntax, `snooze plan` time formats, worked
examples, and everything else live in **[REFERENCE.md](REFERENCE.md)**.
