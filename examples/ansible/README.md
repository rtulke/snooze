# Ansible: upgrade with alerts muted

`upgrade.yml` upgrades packages on a host while its Zabbix alerts are muted, and
unmutes it afterwards. It handles Debian- and RPM-based systems in the same play,
plus zypper, pacman and apk.

```sh
ansible-playbook -i inventory.yml upgrade.yml            # everything, one host at a time
ansible-playbook -i inventory.yml upgrade.yml -l web01   # just one host
ansible-playbook -i inventory.yml upgrade.yml -e snooze_duration=4h
ansible-playbook -i inventory.yml upgrade.yml --check     # dry run, touches nothing
```

## Where snooze runs

By default on the **controller**, not on the target:

```yaml
snooze_delegate: localhost
```

That way the Zabbix API token lives in one place — `~/.snooze.conf` or
`$SNOOZE_TOKEN` on the machine running Ansible — instead of being distributed to
every server you upgrade. The targets don't need snooze installed at all.

To run it on each target instead (e.g. because only the hosts can reach the Zabbix
API), set `snooze_delegate: "{{ inventory_hostname }}"` and make sure snooze and a
token are present there.

## What happens when something breaks

| Situation | Behaviour |
|---|---|
| Token missing or API unreachable | Play aborts in preflight — nothing is muted, no package is touched |
| Host unknown to Zabbix | Mute fails, that host is skipped — it never upgrades while only *believed* to be muted |
| Upgrade fails | Host **stays muted**, play reports the manual unmute command |
| Mute expired during a long upgrade | Unmute exits 1, reported as a warning; the play still succeeds |
| Playbook killed mid-run | Mute expires on its own after `snooze_duration` — nothing stays silenced forever |

Leaving a failed host muted is deliberate: a half-upgraded machine would otherwise
alert on everything at once, right when someone is trying to look at it. Set
`-e snooze_unmute_on_failure=true` if you want the opposite.

## Variables

| Variable | Default | Meaning |
|---|---|---|
| `snooze_delegate` | `localhost` | Where snooze runs |
| `snooze_bin` | `snooze` | Path to the snooze executable |
| `snooze_target` | `{{ inventory_hostname }}` | Name Zabbix knows the host by |
| `snooze_duration` | `1h` | Mute length — must outlast upgrade *and* reboot |
| `snooze_reason` | `Package upgrade (Ansible, {user}@{host})` | Maintenance comment; `{user}`/`{host}` are substituted by snooze |
| `snooze_unmute_on_failure` | `false` | Unmute even when the upgrade failed |
| `upgrade_hosts` | `all` | Which hosts to run against |
| `upgrade_serial` | `1` | How many hosts at a time |
| `upgrade_max_fail_percentage` | `0` | Abort the rollout after the first failure |
| `upgrade_reboot` | `auto` | `auto` \| `always` \| `never` |
| `upgrade_autoremove` | `true` | Remove orphaned packages (apt) |
| `upgrade_reboot_timeout` | `600` | Seconds to wait for a host to come back |

## Host names

snooze passes `snooze_target` to Zabbix, appending the domain from `snooze.conf`
to names without a dot — so an inventory entry `web01` becomes
`web01.domain.tld`. If Zabbix knows a host under a different name, set
`snooze_target` for it in the inventory:

```yaml
db01:
  snooze_target: db01-prod.example.com
```

Getting this wrong is caught immediately: the mute fails and that host is skipped
rather than upgraded unmuted.

## Requirements

- Ansible on the controller, snooze plus a working token wherever `snooze_delegate`
  points
- `community.general` **only** for zypper/pacman/apk hosts —
  `ansible-galaxy collection install community.general`. Pure apt/dnf/yum fleets
  need nothing beyond ansible-core.
- Reboot detection on RPM systems uses `needs-restarting` from `dnf-utils` /
  `yum-utils`. Without it the play says so and skips the reboot instead of
  guessing; `-e upgrade_reboot=always` forces one.
