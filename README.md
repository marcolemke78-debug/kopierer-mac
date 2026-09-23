# Kopierer Lehrerzimmer auf dem Mac

Einrichtung des Kyocera TASKalfa 6054ci im Lehrerzimmer auf einem Mac, inklusive Heften und Lochen aus dem Druckdialog.

**Für Kolleg:innen:** <https://marcolemke78-debug.github.io/kopierer-mac/> öffnen und den drei Schritten folgen.

## Was hier liegt

| Datei | Zweck |
|---|---|
| `install.sh` | Das Einrichtungs-Skript. Wird per `bash -c "$(curl -fsSL …/install.sh)"` im Terminal ausgeführt. |
| `index.html` | Die Anleitungsseite mit Kopieren-Button (GitHub Pages). |
| `fahrplan.html` → `Fahrplan_Kopierer_Mac.pdf` | Einseitiger Fahrplan zum Ausdrucken oder Mitschicken. |

## Was das Skript macht

1. Konto-ID abfragen (nur Ziffern, führende Nullen werden entfernt).
2. Kyocera Mac Driver installieren, falls er fehlt. Download direkt von Kyocera (US-Seite), Signatur wird vor der Installation geprüft.
3. Aus der Kyocera-PPD eine eigene Druckerbeschreibung erzeugen: Konto-ID als Standard und in beiden Auswahlmöglichkeiten, Kyocera-Fenster aus dem Druckdialog entfernt.
4. Drucker `Kopierer_Lehrerzimmer` anlegen (Socket, A4, Kassetten 3+4, Finisher DF-7140, Locheinheit). Ein vorhandener Drucker gleichen Namens wird ersetzt.
5. Voreinstellungen „Heften + Lochen" und „Nur lochen" für den angemeldeten Benutzer anlegen.
6. Jeden Schritt selbst prüfen und bei Problemen mit klarer Meldung abbrechen.

## Warum der Umweg über die PPD

Der Kopierer vergleicht die Konto-ID als Zeichenkette. `(123)` wird angenommen, `(00000123)` wird als „falsche ID" abgelehnt. Genau diese achtstellige Form erzeugt der Kyocera-Druckdialog, wenn man die ID dort einträgt. Deshalb steckt die ID direkt in der Druckerbeschreibung, und das Kyocera-Fenster ist abgeschaltet.

## Hinweise

- Im Repo liegen keine Kyocera-Dateien und keine Konto-IDs. Die ID gibt jede Person lokal ein.
- Die Kopierer-Adresse ist eine interne Schuladresse und außerhalb des Schulnetzes nicht erreichbar.
- PDF neu erzeugen: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf=Fahrplan_Kopierer_Mac.pdf file://$PWD/fahrplan.html`
