# snooze — Referenz

**[README](README_de.md) · [Full reference](REFERENCE.md)**

Die vollständige Kommandoreferenz für `snooze`. Für Installation und Grundkonfiguration
siehe [README_de.md](README_de.md) — dieses Dokument deckt den Rest ab.

- [Sprache](#sprache)
- [Optionen](#optionen)
- [Geplanter Start (`snooze plan`)](#geplanter-start-snooze-plan)
- [Dauer](#dauer)
- [Ziele](#ziele)
- [Beispiele](#beispiele)
- [Statusanzeige (`list active`, `list plans`)](#statusanzeige-list-active-list-plans)
- [Unterdrückte Probleme (`list suppressed`)](#unterdrückte-probleme-list-suppressed)
- [Funktionsweise](#funktionsweise)
- [Exit-Codes](#exit-codes)
- [Hinweise und Stolpersteine](#hinweise-und-stolpersteine)
- [Sicherheit](#sicherheit)
- [Installationsdetails](#installationsdetails)
- [Packaging](#packaging)

## Sprache

Alle Ausgaben (`OK`/`FEHLER`-Zeilen, Fehlermeldungen, `snooze help`) gibt es auf Deutsch und
Englisch. Gewählt wird beim Start anhand der System-Locale, geprüft in der Reihenfolge
`LC_ALL` → `LC_MESSAGES` → `LANG`: Deutsch, wenn der erste gesetzte Wert mit `de` beginnt
(`de_DE`, `de_CH`, `de_AT`, `de_LI`, `de_LU`, `de_BE`, `de_IT`, … — jede deutschsprachige
Region, keine feste Länderliste), sonst Englisch — auch wenn gar keine Locale gesetzt ist.

```bash
LC_ALL=de_DE.UTF-8 snooze help     # Deutsch
LC_ALL=en_US.UTF-8 snooze help     # Englisch
LC_ALL=fr_FR.UTF-8 snooze help     # Englisch (Standard, da nicht Deutsch)
```

Per `lang` in der Config (oder `SNOOZE_LANG`) lässt sich das fest auf `de` oder `en` setzen,
unabhängig von der System-Locale — z. B. wenn auf dem Admin-Host `LC_ALL=de_DE.UTF-8` gesetzt
ist, `snooze` dort aber trotzdem englische Ausgaben liefern soll. Leer (Standard) lässt die
automatische Erkennung über `LC_ALL`/`LC_MESSAGES`/`LANG` ziehen.

```ini
[snooze]
lang = en    # erzwingt Englisch, unabhängig von der System-Locale
lang =       # Standard: automatisch anhand der System-Locale
```

## Optionen

| Option              | Wirkung                                                                 |
|---------------------|-------------------------------------------------------------------------|
| `-F`, `--file DATEI`| Ziele aus DATEI lesen (ein Token je Zeile, `#` = Kommentar; `-` = stdin) |
| `-Y`, `--yes`       | Sicherheitsabfrage bei vielen Zielen überspringen                       |
| `--reason TEXT`     | Grund setzen (überschreibt Config; `{user}`/`{host}` erlaubt)           |

Alles nach `--` wird als Ziel behandelt, auch wenn es mit `-` beginnt.

Gepipte/umgeleitete Eingabe wird automatisch gelesen, auch ohne `-F -`: Sobald stdin
kein Terminal ist, liest `snooze` sie genauso wie `-F -` und ergänzt die gefundenen
Ziele um das, was auf der Kommandozeile übergeben wurde. Ein interaktives Terminal
(kein Pipe) bleibt unangetastet, ein blankes `snooze` wartet also nie auf Eingaben,
die gar nicht gemeint waren.

```bash
echo host1 host2 host3 | snooze          # alle drei für die Standard-Dauer muten
echo host1 host2 host3 | snooze 2h       # ... für 2h
zabbix-get-my-broken-hosts | snooze unmute
```

## Geplanter Start (`snooze plan`)

Statt sofort zu muten, kann ein Wartungsfenster für einen späteren Zeitpunkt geplant
werden: `snooze plan ZEIT [DAUER] [ZIELE…]`. `ZEIT` steht immer als erstes — danach
gelten dieselben Regeln wie bei `mute` (DAUER optional, sonst Standard aus der Config;
kein Ziel = lokaler Host).

Zwei Formate für `ZEIT`:

| Format               | Bedeutung                                                                 |
|-----------------------|---------------------------------------------------------------------------|
| `HH:MM`               | Heutiges Datum, ein Token. Liegt die Uhrzeit heute schon in der Vergangenheit, bricht `snooze` mit Fehler ab (kein automatisches Verschieben auf morgen) — dann das Datum explizit angeben. |
| `TT.MM.JJJJ HH:MM`    | Fester Tag und Uhrzeit. Unquotiert zwei Tokens (`22.5.2026 14:00` → `22.5.2026` und `14:00` getrennt), quotiert als ein Token genauso gültig. Führende Nullen bei Tag/Monat sind optional (`2.5.2026` und `02.05.2026` funktionieren beide). |

Ein Zeitpunkt in der Vergangenheit ist in beiden Formen ein Fehler (Exit-Code `2`).

```bash
# Heute Abend um 22:00 für 2h muten
snooze plan 22:00 2h host1

# Für einen bestimmten Tag planen (führende Null optional, unquotiert)
snooze plan 22.5.2026 14:00 4h "@Servers/Linux"
snooze plan 02.05.2026 14:00 4h "@Servers/Linux"

# Geplante (noch nicht gestartete) Fenster anzeigen
snooze list plans
```

Ein geplantes Fenster erscheint erst nach seinem Start in `snooze list active` —
vorher steht es unter `snooze list plans`. Intern wird lediglich `active_since` auf
den geplanten Zeitpunkt statt auf „jetzt" gesetzt; `extend`/`unmute` funktionieren
auf einem noch nicht gestarteten Fenster genauso wie auf einem laufenden.

## Dauer

Format: `<Zahl><Suffix>`.

| Suffix      | Bedeutung           |
|-------------|---------------------|
| `m`, `min`  | Minuten             |
| `h`         | Stunden             |
| `d`         | Tage                |
| `w`         | Wochen (7 Tage)     |
| `M`         | Monate (30 Tage)    |

Beispiele: `30m`, `30min`, `4h`, `2d`, `1w`, `1M`. Wird keine Dauer angegeben, gilt `3h`.

> **Achtung:** kleines `m` (und `min`) sind Minuten, großes `M` ist ein Monat.

## Ziele

- **Hosts**: Namen ohne Punkt werden automatisch um `.domain.tld` ergänzt
  (z. B. `prd-mail-5` wird zu `prd-mail-5.domain.tld`). Namen mit Punkt bleiben unverändert.
- **Glob**: Hostnamen dürfen `*`, `?` und `[…]` enthalten und werden gegen die
  Zabbix-Hostliste aufgelöst, z. B. `prd-mail-*` oder `tst-foo-?`.
- **Regex**: mit `~`-Präfix, z. B. `~^prd-mail-\d+$`. Matcht gegen den technischen Hostnamen.
- **Hostgruppen**: mit `@` voranstellen. Da Gruppennamen Schrägstriche und Leerzeichen
  enthalten können (z. B. `Servers/Linux`, `Discovered hosts`), in Anführungszeichen
  setzen: `"@Servers/Linux"`. (Glob/Regex gilt nur für Hosts, nicht für Gruppen.)
- Hosts, Muster und Gruppen lassen sich in einem Aufruf mischen.
- Die gültigen Namen findest du mit `snooze list hosts` bzw. `snooze list groups`.

Treffen Glob/Regex viele Hosts oder werden viele Ziele übergeben, fragt `snooze` ab
`confirm_threshold` Zielen nach. `-Y`/`--yes` überspringt die Abfrage; ohne TTY
(z. B. in Skripten) ist `-Y` dann zwingend.

## Beispiele

```bash
# Lokalen Host für die Standard-Dauer (3h) muten
snooze

# Lokalen Host für 4h muten
snooze 4h

# Einen Host ohne Dauer muten -> 3h
snooze mute prd-mail-5

# Mehrere Hosts für 2 Tage muten
snooze 2d prd-mail-5 prd-mail-mx-1

# Alle prd-mail-Hosts per Glob für 2h muten
snooze 2h 'prd-mail-*'

# Per Regex muten
snooze 1h '~^tst-.*-mx-\d+$'

# Eine ganze Hostgruppe für 2h muten
snooze 2h "@Servers/Linux"

# Hosts und Gruppe gemischt, ohne Rückfrage
snooze mute 2h -Y "@Servers/Linux" prd-mail-5

# Ziele aus Datei (eine je Zeile) oder per Pipe (auch -F - geht, ist aber nicht noetig)
snooze 1d -F /tmp/hosts.txt
echo prd-mail-5 | snooze 1d

# Laufende Stummschaltung um weitere 2h verlängern
snooze extend 2h prd-mail-5

# Mit explizitem Grund muten
snooze 2h prd-mail-5 --reason "Wartung Storage, Ticket #4711"

# Stummschaltung wieder aufheben
snooze unmute "@Servers/Linux"
snooze unmute prd-mail-5

# Übersichten und Aufräumen
snooze list hosts
snooze list groups
snooze list active     # bzw. snooze status
snooze list plans      # geplante, noch nicht gestartete Fenster (snooze plan)
snooze cleanup         # abgelaufene Fenster löschen

# Was würde beim Aufwecken sofort wieder alarmieren?
snooze list suppressed prd-mail-5
snooze list suppressed "@Servers/Linux"
snooze list suppressed         # alle aktuell von snooze verwalteten Fenster
```

## Statusanzeige (`list active`, `list plans`)

`snooze list active` zeigt alle bereits **gestarteten** snooze-Wartungsfenster mit
Restlaufzeit, Endzeitpunkt und (falls gesetzt) Grund:

```
@Servers/Linux                noch 1h 47m     (bis 2026-06-01 15:30)  [ansible@desktop]
prd-mail-5.domain.tld         noch 42m        (bis 2026-06-01 14:25)  [Wartung Storage, Ticket #4711]
tst-foo.domain.tld            abgelaufen      (bis 2026-06-01 12:00)  [sysadm@blackbox]
```

„abgelaufen" erscheint, weil Zabbix abgelaufene Wartungsfenster nicht selbst entfernt.
Solche Einträge bleiben sichtbar, bis sie per `unmute` oder `cleanup` gelöscht werden.

Per `snooze plan` geplante, aber noch nicht gestartete Fenster tauchen hier **nicht** auf,
sondern unter `snooze list plans`:

```
prd-mail-5.domain.tld         startet 2026-08-16 22:00  bis 2026-08-17 02:00  [ansible@desktop]
```

## Unterdrückte Probleme (`list suppressed`)

Ein Host in Maintenance erzeugt in Zabbix weiterhin Probleme, sie werden nur als
`suppressed` markiert und nicht alarmiert/angezeigt. `snooze list suppressed` fragt genau
diese unterdrückten Probleme ab und zeigt nur die, die **durch das jeweilige snooze-Fenster**
unterdrückt werden (Abgleich über die `maintenanceid`, nicht über fremde Zabbix-Maintenances).
Das beantwortet: „Was würde sofort wieder alarmieren, wenn ich jetzt `unmute` mache?"

```bash
snooze list suppressed prd-mail-5    # nur für dieses Ziel
snooze list suppressed               # für alle aktuell von snooze verwalteten Fenster
```

```
prd-mail-5.domain.tld  [Hoch]              Disk space is low on /var  seit 2026-06-01 12:03
prd-mail-5.domain.tld  [Durchschnittlich]  CPU load high              seit 2026-06-01 13:10
tst-foo.domain.tld     keine unterdrückten Probleme
```

Ein bereits abgelaufenes snooze-Fenster zeigt automatisch keine unterdrückten Probleme mehr
(Zabbix unterdrückt dann nichts mehr darüber) — dafür ist kein separater Status nötig.

## Funktionsweise

- Jedes Ziel erhält ein eigenes Wartungsfenster mit eindeutigem Namen:
  Hosts heißen `snooze:<host>`, Gruppen `snooze:@<gruppe>`.
- Beim Muten wird ein bereits bestehendes, gleichnamiges Fenster per
  `maintenance.update` aktualisiert (kein Löschen+Neuanlegen, damit das Ziel nie
  kurzzeitig ungemutet ist). Ein erneutes `mute` verlängert/aktualisiert die
  Stummschaltung damit idempotent.
- `extend` verlängert ein bestehendes Fenster um die angegebene Dauer ab seinem
  aktuellen Ende (bzw. ab jetzt, falls bereits abgelaufen).
- `unmute` sucht das Fenster anhand seines Namens und löscht es.
- `cleanup` löscht alle `snooze:`-Fenster, deren Ende in der Vergangenheit liegt.
- Es wird `maintenance_type = 0` (Wartung mit Datenerfassung) und genau ein Zeitraum
  über die gewünschte Dauer angelegt; der `reason` landet im `description`-Feld.

## Exit-Codes

| Code | Bedeutung                                                          |
|------|--------------------------------------------------------------------|
| `0`  | Alles erfolgreich                                                  |
| `1`  | Mindestens ein Ziel nicht gefunden oder fehlgeschlagen             |
| `2`  | Bedienfehler (z. B. `list` ohne Unterbefehl, abgebrochene Abfrage) |
| `130`| Abbruch per Strg-C                                                 |

## Hinweise und Stolpersteine

- Hostgruppen-Aktionen wirken auf alle Mitglieder der Gruppe zum Zeitpunkt des Anlegens.
- In Zabbix können mehrere getrennte "Hosts" mit Leerzeichen im Namen existieren
  (z. B. `prd-zabbix-1.domain.tld Zabbix server`). `snooze list hosts` zeigt diese so an,
  wie Zabbix sie führt.
- Abgelaufene Wartungsfenster gelegentlich mit `snooze cleanup` aufräumen.

## Sicherheit

Der `token` steht aktuell im Klartext in `/etc/snooze.conf`. Wer die Datei lesen kann,
kann den Token einsehen. Der Zugriff wird daher über Dateirechte geregelt: `0640`,
Eigentümer `root`, Leserecht nur für `admin_users` (per ACL) im eigenen
Ansible-Deployment dieses Projekts — siehe „Installationsdetails" unten, was das für
andere Install-Wege bedeutet.

Geplant ist, den Token über Ansible-Vault einzuspeisen (`vault_zabbix_token`) und dabei
zu rotieren. Da das Skript `SNOOZE_TOKEN`/`ZABBIX_TOKEN` aus der Umgebung liest, kann der
Token künftig auch ganz ohne Datei (z. B. via `EnvironmentFile`) bereitgestellt werden.

## Installationsdetails

Das Ansible-Play in `main.yml` ist der Weg, wie die eigenen Admin-Hosts dieses Projekts
`snooze` bekommen: nach `/usr/local/sbin/snooze` kopiert und per POSIX-ACL auf
`admin_users` beschränkt statt world-executable. Die Wege `.deb`, Homebrew und
`make install` aus [README_de.md](README_de.md) sind alle normale, unbeschränkte Installs
(normal `0755`, world-executable) — ACL bei Bedarf selbst einrichten, außerhalb der
Ansible-verwalteten Flotte.

**Aus dem Quellcode (jede Plattform mit Python 3):**

```bash
sudo make install    # installiert nach /usr/local/sbin/snooze + Man-Page + Bash-Completion
                      # + /etc/snooze.conf.example
```

**Das `.deb` selbst bauen:**

```bash
packaging/build-deb.sh      # -> dist/snooze_<version>_all.deb
packaging/test-install.sh   # installiert es in einem frischen Container je Zieldistro
```

Wie das genau funktioniert und was dabei geprüft wird, steht unter „Packaging" unten.

## Packaging

Zwei Dinge werden aus diesem Repo paketiert: ein `.deb` für Debian/Ubuntu und eine
Homebrew-Formula für Linux/macOS. Beide verpacken dasselbe einzelne Skript — es gibt keine
kompilierte/native Abhängigkeit zu bauen, Packaging bedeutet hier nur, Dateien korrekt
abzulegen und `python3` als Laufzeit-Abhängigkeit zu deklarieren.

**`.deb` (Debian/Ubuntu):**

```bash
packaging/build-deb.sh      # -> dist/snooze_<version>_all.deb
packaging/test-install.sh   # installiert das .deb in einem frischen Container je
                             # Zieldistro (apt-get install, nicht dpkg -i, damit
                             # deklarierte Depends: wirklich aufgelöst werden müssen)
                             # und fährt einen funktionalen Smoke-Test
```

Ein `all`-Architektur-Paket installiert überall — anders als bei einem kompilierten Tool
gibt es keinen Versions-Skew zwischen Distros (siehe `rtulke/cryptc`s
`packaging/build-deb.sh` dafür, wie dieses Problem aussieht und warum es dort separate
Builds erzwingt). Geprüft auf Debian 12/13 und Ubuntu 24.04/26.04. `.github/workflows/release.yml`
fährt dieselben Build-/Verify-Schritte in CI bei jedem Push und veröffentlicht bei einem
`vX.Y`-Tag auf GitHub Releases (plus ein rollierendes `latest`-Prerelease auf `main`).

Das Paket installiert das Skript nach `/usr/sbin/snooze`, die `snooze(1)`-Man-Page,
Bash-Completion und `/etc/snooze.conf.example`; ein `postinst`-Skript sät `/etc/snooze.conf`
beim ersten Install aus dieser Vorlage (überschreibt nie eine bestehende Datei, dieselbe
`force: false`-Philosophie wie die eigene Ansible-Deployment dieses Repos), `postrm purge`
entfernt sie wieder.

**Homebrew (Linux, macOS):**

`Formula/snooze.rb` hier ist die Quelle der Wahrheit (gleiche Struktur wie
`rtulke/airsnare`s `Formula/airsnare.rb`); [rtulke/homebrew-snooze](https://github.com/rtulke/homebrew-snooze)
ist der eigentliche Tap — ein separates `homebrew-<name>`-Repo ist zwingend nötig, damit
`rtulke/snooze` für Homebrew überhaupt ein auflösbarer Tap ist. `url`/`sha256` in beiden
Kopien bei jedem Release aktualisieren: `git tag vX.Y && git push origin vX.Y`, dann
`curl -sL .../archive/refs/tags/vX.Y.tar.gz | shasum -a 256`.

Der Formula-Name kollidiert mit dem `snooze` aus homebrew-core
([leahneukirchen/snooze](https://github.com/leahneukirchen/snooze), ein völlig anderer
cron-Ersatz). Bei einem bloßen Formula-Namen hat Core Vorrang vor jedem Tap — die
Installationsanweisung muss deshalb immer den vollqualifizierten Namen
`rtulke/snooze/snooze` verwenden. `brew tap` ändert nichts daran, worauf ein bloßes
`snooze` auflöst. Beide Formulae installieren ein Binary namens `snooze` und können
darum nicht gleichzeitig verlinkt sein; erzwingen ginge nur mit `brew link --overwrite`.
Auch CI-Jobs und Skripte, die aus diesem Tap installieren, brauchen den qualifizierten
Namen.
