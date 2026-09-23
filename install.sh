#!/bin/bash
# =============================================================================
#  Kopierer Lehrerzimmer (Kyocera TASKalfa 6054ci) auf dem Mac einrichten
#
#  Aufruf im Terminal (eine Zeile):
#    bash -c "$(curl -fsSL https://marcolemke78-debug.github.io/kopierer-mac/install.sh)"
#
#  Was das Skript macht:
#    1. Konto-ID abfragen
#    2. Kyocera-Treiber installieren (falls noch nicht vorhanden)
#    3. Druckerbeschreibung (PPD) mit der Konto-ID erzeugen
#    4. Drucker „Kopierer Lehrerzimmer“ anlegen, Heften + Lochen freischalten
#    5. Voreinstellungen „Heften + Lochen“ und „Nur lochen“ anlegen
#    6. Alles prüfen
#
#  Hintergrund: Der Kopierer vergleicht die Konto-ID als Zeichenkette.
#  „123“ wird angenommen, „00000123“ (Kyoceras Kodierung aus dem Druckdialog)
#  wird als „falsche ID“ abgelehnt. Deshalb schreibt das Skript die ID direkt
#  in die Druckerbeschreibung – und zwar in beide Auswahlmöglichkeiten, damit
#  auch ein versehentlich geöffnetes Kyocera-Fenster nichts kaputt macht.
#  Das Kyocera-Fenster selbst wird aus dem Druckdialog entfernt.
# =============================================================================
set -u
set -o pipefail

QUEUE="Kopierer_Lehrerzimmer"
ANZEIGE="Kopierer Lehrerzimmer"
STANDORT="Lehrerzimmer"
GERAET="socket://10.31.220.253"
TREIBER_URL="https://www.kyoceradocumentsolutions.us/content/dam/download-center-americas-cf/us/drivers/drivers/Mac56_2024_05_16_KDC_en_zip.download.dmg"
TREIBER_DMG="$HOME/Downloads/Kyocera_Mac_Driver.dmg"
TREIBER_PPD="/Library/Printers/PPDs/Contents/Resources/Kyocera TASKalfa 6054ci.PPD"
TREIBER_FILTER="/usr/libexec/cups/filter/kyofilter_F"
TREIBER_SIGNATUR="Developer ID Installer: Kyocera Document Solutions Inc."
PRESET_DOMAIN="com.apple.print.custompresets.forprinter.$QUEUE"

# Farben nur, wenn die Ausgabe in ein Terminal geht
if [ -t 1 ]; then
  FETT=$'\033[1m'; GRUEN=$'\033[32m'; ROT=$'\033[31m'; NORMAL=$'\033[0m'
else
  FETT=""; GRUEN=""; ROT=""; NORMAL=""
fi

schritt() { printf '\n%s▶ %s%s\n' "$FETT" "$1" "$NORMAL"; }
ok()      { printf '%s  ✔ %s%s\n' "$GRUEN" "$1" "$NORMAL"; }
info()    { printf '  %s\n' "$1"; }
fehler()  {
  printf '\n%s✖ %s%s\n' "$ROT" "$1" "$NORMAL" >&2
  printf '  Schick Marco am besten ein Foto dieser Meldung.\n\n' >&2
  exit 1
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/kopierer.XXXXXX") || exit 1
MNT=""
aufraeumen() {
  [ -n "$MNT" ] && hdiutil detach "$MNT" -quiet 2>/dev/null
  rm -rf "$TMP"
}
trap aufraeumen EXIT

[ "$(uname)" = "Darwin" ] || fehler "Dieses Skript läuft nur auf einem Mac."
[ "$(id -u)" -ne 0 ] || fehler "Bitte ohne sudo starten – das Skript fragt selbst nach dem Passwort."

printf '\n%s══ Kopierer Lehrerzimmer auf dem Mac einrichten ══%s\n' "$FETT" "$NORMAL"
cat <<'TXT'

  Das Skript richtet den Kopierer im Lehrerzimmer ein:
    1. Kyocera-Treiber installieren (falls noch nicht da)
    2. Drucker „Kopierer Lehrerzimmer“ mit deiner Konto-ID anlegen
    3. Voreinstellungen „Heften + Lochen“ und „Nur lochen“
    4. Alles prüfen

  Du brauchst: deine Konto-ID vom Kopierer und dein Mac-Passwort.
TXT

# --- 1. Konto-ID -------------------------------------------------------------
schritt "Konto-ID"
while :; do
  read -r -p "  Deine Konto-ID am Kopierer (nur Ziffern): " KONTO_ID < /dev/tty \
    || fehler "Keine Tastatureingabe möglich. Bitte die Zeile direkt im Terminal ausführen."
  KONTO_ID="${KONTO_ID//[^0-9]/}"                  # alles außer Ziffern weg
  KONTO_ID="$(printf '%s' "$KONTO_ID" | sed 's/^0*//')"   # führende Nullen weg
  if [ -z "$KONTO_ID" ] || [ "${#KONTO_ID}" -gt 8 ]; then
    info "Bitte nur Ziffern eingeben, zum Beispiel 123."
    continue
  fi
  read -r -p "  Konto-ID $KONTO_ID – stimmt das? [J/n] " antwort < /dev/tty \
    || fehler "Keine Tastatureingabe möglich. Bitte die Zeile direkt im Terminal ausführen."
  case "$antwort" in
    [nN]*) ;;
    *) break ;;
  esac
done

# --- 2. Treiber --------------------------------------------------------------
schritt "Kyocera-Treiber"
if [ -x "$TREIBER_FILTER" ] && [ -f "$TREIBER_PPD" ]; then
  ok "Treiber ist schon installiert."
else
  if [ -f "$TREIBER_DMG" ]; then
    ok "Treiber-Datei liegt schon in Downloads."
  else
    info "Lade den Treiber von Kyocera (ca. 100 MB, dauert je nach WLAN ein paar Minuten) …"
    curl -fL --progress-bar -o "$TREIBER_DMG.teil" "$TREIBER_URL" \
      || fehler "Download fehlgeschlagen. Internet prüfen und die Zeile noch einmal ausführen."
    mv "$TREIBER_DMG.teil" "$TREIBER_DMG"
    ok "Treiber heruntergeladen."
  fi
  MNT="$TMP/dmg"; mkdir -p "$MNT"
  hdiutil attach "$TREIBER_DMG" -nobrowse -quiet -readonly -mountpoint "$MNT" \
    || fehler "Die Treiber-Datei lässt sich nicht öffnen. Lösche sie ($TREIBER_DMG) und starte die Zeile erneut."
  ANZAHL_PKG=$(find "$MNT" -maxdepth 2 -name "*.pkg" | wc -l | tr -d ' ')
  [ "$ANZAHL_PKG" -eq 1 ] || fehler "Im Treiber-Image wurde nicht genau ein Installationspaket gefunden ($ANZAHL_PKG)."
  PKG=$(find "$MNT" -maxdepth 2 -name "*.pkg" -print -quit)
  # Gatekeeper-Bewertung: Paket muss von macOS akzeptiert UND von Kyocera signiert sein
  BEWERTUNG=$(spctl -a -vv -t install "$PKG" 2>&1) \
    || fehler "macOS stuft das Treiber-Paket als nicht vertrauenswürdig ein – wird sicherheitshalber nicht installiert."
  printf '%s\n' "$BEWERTUNG" | grep -q "origin=$TREIBER_SIGNATUR" \
    || fehler "Das Treiber-Paket ist nicht von Kyocera signiert – wird sicherheitshalber nicht installiert."
  info "Installiere „$(basename "$PKG")“ …"
  info "Jetzt fragt der Mac nach deinem Passwort. Beim Tippen erscheint nichts – einfach eingeben und Enter."
  sudo installer -pkg "$PKG" -target / >"$TMP/installer.log" 2>&1 \
    || { cat "$TMP/installer.log" >&2; fehler "Treiber-Installation fehlgeschlagen."; }
  hdiutil detach "$MNT" -quiet 2>/dev/null; MNT=""
  { [ -x "$TREIBER_FILTER" ] && [ -f "$TREIBER_PPD" ]; } \
    || fehler "Treiber installiert, aber die erwarteten Dateien fehlen."
  rm -f "$TREIBER_DMG"
  ok "Treiber installiert."
fi

# --- 3. Druckerbeschreibung (PPD) mit Konto-ID bauen -------------------------
# Änderungen gegenüber der Kyocera-PPD:
#   - Kyocera-Fenster („Druckbedienung“) aus dem Druckdialog entfernen
#   - Konto-ID als Standard setzen und in BEIDE Auswahlmöglichkeiten schreiben
schritt "Druckerbeschreibung mit Konto-ID $KONTO_ID"
PPD="$TMP/$QUEUE.ppd"
awk -v id="$KONTO_ID" '
  /^\*APDialogExtension:/            { next }
  /^\*DefaultKmManagment: Default$/  { print "*DefaultKmManagment: MG" id; next }
  /^\*KmManagment Default\/Off: ""$/ { print "*KmManagment Default/Off: \"(" id ") statusdict /setmanagementnumber get exec\""; next }
  /^\*CloseUI: \*KmManagment$/       { print "*KmManagment MG" id "/" id ": \"(" id ") statusdict /setmanagementnumber get exec\"" }
  { print }
' "$TREIBER_PPD" > "$PPD" || fehler "Druckerbeschreibung konnte nicht erzeugt werden."
n=$(grep -c "(${KONTO_ID}) statusdict /setmanagementnumber get exec" "$PPD")
[ "${n:-0}" -eq 2 ] || fehler "Konto-ID wurde nicht korrekt eingetragen ($n statt 2 Stellen). Die Treiberversion passt evtl. nicht."
grep -q "^\*DefaultKmManagment: MG${KONTO_ID}$" "$PPD" || fehler "Standardwert für die Konto-ID fehlt."
grep -q "^\*APDialogExtension" "$PPD" && fehler "Kyocera-Fenster konnte nicht entfernt werden."
ok "Druckerbeschreibung erzeugt."

# --- 4. Drucker anlegen ------------------------------------------------------
# Zubehör: Option19=One (Kassetten 3+4), Option17=DF770 (Finisher DF-7140, Heften),
# Option21=True (Locheinheit), Option26=False (Job-Separator, kollidiert mit Finisher)
schritt "Drucker „$ANZEIGE“ anlegen"
if lpstat -p "$QUEUE" >/dev/null 2>&1; then
  info "Es gibt schon einen Drucker „$ANZEIGE“ – er wird mit den neuen Einstellungen ersetzt."
fi
info "Falls der Mac (noch einmal) nach deinem Passwort fragt: eingeben und Enter."
sudo lpadmin -p "$QUEUE" -E -v "$GERAET" -P "$PPD" -D "$ANZEIGE" -L "$STANDORT" \
  -o Option19=One -o Option17=DF770 -o Option21=True -o Option26=False \
  -o PageSize=A4 -o printer-is-shared=false >"$TMP/lpadmin.log" 2>&1 \
  || { cat "$TMP/lpadmin.log" >&2; fehler "Drucker konnte nicht angelegt werden."; }
INSTALLIERT="/etc/cups/ppd/$QUEUE.ppd"
n=$(grep -c "(${KONTO_ID}) statusdict /setmanagementnumber get exec" "$INSTALLIERT" 2>/dev/null)
[ "${n:-0}" -eq 2 ] || fehler "Drucker angelegt, aber die Konto-ID steckt nicht in der installierten Beschreibung."
grep -q "^\*DefaultOption21: True$" "$INSTALLIERT" || fehler "Locheinheit ist nicht aktiviert."
grep -q "^\*DefaultOption17: DF770$" "$INSTALLIERT" || fehler "Finisher (Heften) ist nicht aktiviert."
grep -q "^\*DefaultPageSize: A4$" "$INSTALLIERT" || fehler "Papierformat steht nicht auf A4."
ok "Drucker angelegt: Konto-ID $KONTO_ID, A4, Heften + Lochen freigeschaltet."

# --- 5. Voreinstellungen -----------------------------------------------------
# Die Presets hängen am Drucker-Namen und gelten für den angemeldeten Benutzer.
# Konto-ID bewusst NICHT im Preset – die kommt aus der Druckerbeschreibung.
schritt "Voreinstellungen „Heften + Lochen“ und „Nur lochen“"
defaults write "$PRESET_DOMAIN" "Heften + Lochen" '<dict>
  <key>com.apple.print.preset.behavior</key><integer>0</integer>
  <key>com.apple.print.preset.id</key><string>Heften + Lochen</string>
  <key>com.apple.print.preset.settings</key><dict>
    <key>KCStaple</key><string>Upperleft</string>
    <key>StapleCount</key><string>None</string>
    <key>KCPunch</key><string>2HoleEUR</string>
  </dict>
</dict>' || fehler "Voreinstellung „Heften + Lochen“ konnte nicht angelegt werden."
defaults write "$PRESET_DOMAIN" "Nur lochen" '<dict>
  <key>com.apple.print.preset.behavior</key><integer>0</integer>
  <key>com.apple.print.preset.id</key><string>Nur lochen</string>
  <key>com.apple.print.preset.settings</key><dict>
    <key>KCStaple</key><string>None</string>
    <key>KCPunch</key><string>2HoleEUR</string>
  </dict>
</dict>' || fehler "Voreinstellung „Nur lochen“ konnte nicht angelegt werden."
defaults write "$PRESET_DOMAIN" com.apple.print.customPresetsInfo '<array>
  <dict><key>PresetBehavior</key><integer>0</integer><key>PresetName</key><string>Heften + Lochen</string></dict>
  <dict><key>PresetBehavior</key><integer>0</integer><key>PresetName</key><string>Nur lochen</string></dict>
</array>' || fehler "Liste der Voreinstellungen konnte nicht angelegt werden."
defaults delete "$PRESET_DOMAIN" com.apple.print.customPresetNames >/dev/null 2>&1
n=$(defaults read "$PRESET_DOMAIN" com.apple.print.customPresetsInfo 2>/dev/null | grep -c "PresetName")
[ "${n:-0}" -eq 2 ] || fehler "Voreinstellungen wurden nicht gespeichert."
ok "Voreinstellungen angelegt."

# --- 6. Fertig ---------------------------------------------------------------
schritt "Fertig"
ok "„$ANZEIGE“ ist eingerichtet (Konto-ID $KONTO_ID)."
cat <<'TXT'

  So druckst du ab jetzt:
    Cmd + P  →  Drucker „Kopierer Lehrerzimmer“ wählen
             →  Menü „Voreinstellungen“: „Heften + Lochen“ oder „Nur lochen“
             →  Drucken

  Für normale Ausdrucke die Voreinstellung wieder auf „Standardeinstellungen“
  stellen, sonst wird weiter geheftet.
  Der Kopierer ist nur im Schul-WLAN erreichbar.

  Dieses Fenster kannst du jetzt schließen.

TXT
