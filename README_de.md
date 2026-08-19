# snooze

*Leg den Zabbix-Alarm schlafen, nicht dich selbst.*

**[English](README.md) · [Vollständige Referenz](REFERENZ_de.md) · [Full reference](REFERENCE.md)**

`snooze` ist ein Single-File-Python-3-CLI, das Zabbix-Hosts und -Hostgruppen stummschaltet,
indem es zeitlich begrenzte Wartungsfenster über die JSON-RPC-API anlegt — damit ein
3-Uhr-morgens-Pager-Sturm, weil `/var` schon wieder bei 91 % steht, nicht sofort dein
Problem sein muss. Keine Abhängigkeiten, kein Build-Schritt, nur ein Skript und ein
API-Token. Spricht mit Zabbix ≥ 6.4, gibt je nach Locale Deutsch oder Englisch aus, und
kann neben dem normalen Muten auch ein laufendes Fenster `extend`en oder mit `plan` schon
im Voraus für ein bekanntes Wartungsfenster planen.

```bash
snooze 2h prd-mail-5              # Host für 2 Stunden muten
snooze 4h "@Servers/Linux"        # ganze Hostgruppe muten
snooze plan 22:00 2h host1        # heute Abend um 22:00 starten
snooze unmute prd-mail-5          # wieder aufheben
```

Die vollständige Kommandoreferenz, Ziel-Syntax (Globs/Regex/Hostgruppen), geplante
Starts, Exit-Codes, Packaging-Interna und Sicherheitshinweise stehen in
**[REFERENZ_de.md](REFERENZ_de.md)**.

## Voraussetzungen

- Python 3.8 oder neuer
- Netzwerkzugriff auf deine Zabbix-API
- Ein Zabbix-API-Token

## Installation

**Debian-basierte Distributionen (Ubuntu, Mint, Raspberry Pi OS, …):**

```bash
sudo apt-get install ./snooze_*_all.deb
```

Das `.deb` gibt's auf der [Releases-Seite](https://github.com/rtulke/snooze/releases).

**Homebrew (Linux, macOS):**

```bash
brew install rtulke/snooze/snooze
```

Den vollqualifizierten Namen verwenden. In Homebrews Core-Repository gibt es bereits ein
völlig anderes Tool namens [`snooze`](https://github.com/leahneukirchen/snooze) — einen
kleinen cron-Ersatz — und bei einem bloßen Formula-Namen gewinnt Core immer gegen einen
Tap. Ein einfaches `brew install snooze` installiert also *dieses* Tool, selbst nach
`brew tap rtulke/snooze`.

Symptom für das falsche Tool: `snooze help` hängt, statt die Hilfe auszugeben (das andere
Tool liest `help` als Zeitangabe und legt sich schlafen), und `file $(which snooze)` zeigt
ein kompiliertes Executable statt eines Python-Skripts. Zum Wechseln:

```bash
brew uninstall snooze               # entfernt das snooze aus homebrew-core
brew install rtulke/snooze/snooze
```

Beide installieren ein Binary namens `snooze` — es kann immer nur eines verlinkt sein.

Bauen aus dem Quellcode, das `.deb` selbst bauen und das ACL-beschränkte Ansible-Deployment,
das dieses Projekt für die eigenen Admin-Hosts nutzt, stehen alle in
**[REFERENZ_de.md](REFERENZ_de.md)**.

Egal welcher Weg: `snooze` braucht einen Zabbix-API-Token, bevor es mehr als
`--help`/`--version` kann — siehe „Konfiguration" unten.

## Konfiguration

Die Einstellungen stehen in einer INI-Datei. Es gewinnt die **erste lesbare** Datei aus:

```
./snooze.conf
~/.snooze.conf
/etc/snooze.conf
```

Vorlage: `/etc/snooze.conf.example`

Es gewinnt die erste vorhandene Datei vollständig — Einstellungen werden nie über
mehrere Dateien hinweg gemischt. Eine Datei, die zwar existiert, aber nicht lesbar
ist (falscher Eigentümer, fehlende ACL), wird mit einer Warnung auf stderr
übersprungen; die Suche läuft weiter. Ein `/etc/snooze.conf` ohne Leserecht kann
also kein funktionierendes `~/.snooze.conf` verdecken.

| Schlüssel           | Bedeutung                                                     | Standard                                      |
|---------------------|-------------------------------------------------------------------|-----------------------------------------------|
| `url`               | Endpunkt der Zabbix-JSON-RPC-API                                  | `https://zabbix.domain.tld/api_jsonrpc.php`   |
| `token`             | API-Token (Bearer)                                                | leer                                          |
| `domain`            | Domain, die an Hostnamen ohne Punkt angehängt wird                | `domain.tld`                                  |
| `duration`          | Standard-Dauer, wenn keine angegeben ist                          | `3h`                                          |
| `prefix`            | Namenspräfix der von `snooze` verwalteten Wartungsfenster         | `snooze:`                                     |
| `timeout`           | Timeout für API-Aufrufe (Sekunden)                                | `15`                                          |
| `retries`           | Wiederholungen bei Netzfehlern                                    | `2`                                           |
| `reason`            | Kommentar je Fenster; `{user}`/`{host}` werden ersetzt            | `{user}@{host}`                               |
| `confirm_threshold` | Ab wie vielen Zielen nachgefragt wird (`-Y` überspringt)          | `10`                                          |
| `lang`              | Sprache der Ausgaben: `de`/`en`. Leer = System-Locale             | leer (automatisch)                            |
| `ssl_verify`        | TLS-Zertifikat des API-Endpunkts prüfen (siehe unten)             | `true`                                         |

Jeder Wert lässt sich zusätzlich per Umgebungsvariable überschreiben:
`SNOOZE_URL`, `SNOOZE_TOKEN`, `SNOOZE_DOMAIN`, `SNOOZE_DURATION`, `SNOOZE_PREFIX`,
`SNOOZE_TIMEOUT`, `SNOOZE_RETRIES`, `SNOOZE_REASON`, `SNOOZE_CONFIRM_THRESHOLD`, `SNOOZE_LANG`,
`SNOOZE_SSL_VERIFY`.
Für Token und URL werden auch `ZABBIX_TOKEN` / `ZABBIX_URL` akzeptiert (Vault-freundlich).

Wie die `de`/`en`-Erkennung genau funktioniert (welches `LC_*` gewinnt, welche Locales als
Deutsch zählen), steht in **[REFERENZ_de.md → Sprache](REFERENZ_de.md#sprache)**.

### TLS-Zertifikate

Nutzt dein Zabbix ein selbstsigniertes Zertifikat oder eine interne CA, bricht
`snooze` mit einer Meldung ab, die die Ursache benennt, statt eine Verbindung zu
wiederholen, die nie zustande kommen kann. Drei Auswege, der beste zuerst:

1. Die CA ins System-Trust-Store aufnehmen — davon profitiert alles auf dem Host.
2. `SSL_CERT_FILE` auf die CA-Datei zeigen lassen, nur für dieses Werkzeug.
3. `ssl_verify = false` in der Config setzen (oder `SNOOZE_SSL_VERIFY=false`), um
   die Prüfung ganz abzuschalten.

Variante 3 heißt: Der API-Token geht über eine Verbindung, die niemand
authentifiziert hat — wer sie abfangen kann, bekommt den Token. `snooze` warnt
deshalb bei jedem Lauf auf stderr, solange das aktiv ist. Für Laborumgebungen
geeignet, nicht für den Host, der produktive Wartungsfenster verwaltet.

## Verwendung

| Kommando                                  | Wirkung                                                     |
|---------------------------------------------|-----------------------------------------------------------|
| `snooze`                                     | Lokalen Host für 3h muten (Kurzform)                       |
| `snooze [DAUER] [ZIELE…]`                    | Muten; `mute` ist implizit                                 |
| `snooze mute [DAUER] [ZIELE…]`               | Muten (explizit)                                            |
| `snooze plan ZEIT [DAUER] [ZIELE…]`          | Muten mit geplantem Start statt sofort                     |
| `snooze extend DAUER [ZIELE…]`               | Laufende Stummschaltung um DAUER verlängern                |
| `snooze unmute [ZIELE…]`                     | Stummschaltung aufheben                                     |
| `snooze list hosts`                          | Alle in Zabbix bekannten Hosts auflisten                    |
| `snooze list groups`                         | Alle Hostgruppen auflisten                                  |
| `snooze list active`                         | Bereits gestartete snooze-Wartungsfenster anzeigen          |
| `snooze status`                              | Alias für `snooze list active`                              |
| `snooze list plans`                          | Geplante, noch nicht gestartete snooze-Fenster anzeigen     |
| `snooze list suppressed [ZIELE…]`            | Durch snooze unterdrückte Probleme (kein Ziel = alle)       |
| `snooze cleanup`                             | Abgelaufene snooze-Fenster entfernen (Alias `prune`)        |
| `snooze help`                                | Hilfe anzeigen (auch `-h`, `--help`)                        |
| `snooze version`                             | Version und Autor ausgeben (auch `-V`, `--version`)         |

Ist das erste Token ein bekanntes Kommando, wird dieses ausgeführt; andernfalls gilt die
gesamte Eingabe als Argumente für `mute` — `snooze 2h host1` und `snooze mute 2h host1`
sind also dasselbe. Alle Options-Flags, Ziel-Syntax, `snooze plan`-Zeitformate,
durchgerechnete Beispiele und der Rest stehen in **[REFERENZ_de.md](REFERENZ_de.md)**.

## Skripting

`--json` gibt statt Text ein einziges JSON-Dokument aus, mit sprachunabhängigen
Feldnamen — ein Skript bricht also nicht, wenn sich die Locale des Hosts ändert:

```bash
snooze --json 2h prd-mail-5
snooze --json list active | jq -r '.results[] | "\(.target) noch \(.remaining)s"'
```

Einzelheiten und die vollständige Feldreferenz stehen in
**[REFERENZ_de.md → JSON-Ausgabe](REFERENZ_de.md#json-ausgabe)**.

Ein fertiges Ansible-Playbook, das einen Host mutet, seine Pakete aktualisiert und ihn
anschließend wieder aufweckt — für Debian, RPM, SUSE, Arch und Alpine — liegt in
**[examples/ansible/](examples/ansible/)**.
