# Changelog

Alle noemenswaardige wijzigingen in QLab Cleaner.

## 1.18.3 — 2026-09-12

Kleine correctie (patch).

- Duplicaten op bestandsnaam, niet op video-inhoud. De app leest media niet meer in; nodig is wat in de `.qlab5` staat.

## 1.18.2 — 2026-09-12

Kleine correctie (patch).

- Grote shows blijven bruikbaar: de app leest video’s in stukken en hasht alleen bestanden die even groot zijn, in plaats van tientallen GB in één keer.

## 1.18.1 — 2026-09-10

Kleine correctie (patch).

- App-icoon update

## 1.18.0 — 2026-09-10
als 
Nieuwe functie (minor).

- Eigen app-icoon in Dock en Finder.

## 1.17.0 — 2026-09-10

Nieuwe functie (minor).

- Optioneel backups meelezen: `.qlab5backup` naast de show, met een lijst van bestanden die alleen in een backup voorkomen. Relinken blijft in QLab.

## 1.16.1 — 2026-09-10

Kleine correctie (patch).

- Taalkeuze als compacte EN/NL/DE/FR-schakelaar. Kaarten, knoppen en header strakker.

## 1.16.0 — 2026-09-10

Nieuwe functie (minor).

- Klik op het logo voor een grotere weergave en een Buy me a coffee-link.

## 1.15.0 — 2026-09-10

Nieuwe functie (minor).

- Duplicaten herkennen op inhoud, ook als de bestandsnaam anders is.

## 1.14.0 — 2026-09-10

Nieuwe functie (minor).

- Bij grote scans zie je live hoeveel bestanden al zijn gelezen, in plaats van alleen te wachten.

## 1.13.0 — 2026-09-10

Nieuwe functie (minor).

- Recente workspaces op het startscherm, met de laatst gebruikte modus en contentmappen.

## 1.12.0 — 2026-09-10

Nieuwe functie (minor).

- Interface standaard in het Engels. Taal wisselen naar Nederlands, Deutsch of Français rechtsboven.

## 1.11.0 — 2026-09-10

Nieuwe functie (minor).

- Pad van een bestand kopiëren via het contextmenu; alle unused paden in één keer vanuit de kolom Niet in gebruik.

## 1.10.0 — 2026-09-10

Nieuwe functie (minor).

- Klik een bestand in de lijst en druk op spatie voor Quick Look, zonder het in Finder te openen.

## 1.9.2 — 2026-09-10

Kleine correctie (patch).

- Bij ‘bestanden in projectmap’ kun je de projectmap kiezen, niet alleen de .qlab5. De workspace en contentmappen worden daarin gevonden.

## 1.9.1 — 2026-09-10

Bugfix (patch).

- De melding ‘QLab draait’ verscheen altijd, omdat QLab Cleaner zichzelf herkende. Alleen Figure 53 QLab telt nog.

## 1.9.0 — 2026-09-10

Nieuwe functie (minor).

- Lijsten sorteren op naam, type, datum of grootte.

## 1.8.0 — 2026-09-10

Nieuwe functie (minor).

- Zoeken werkt ook op cue-nummer en cue-naam, niet alleen op bestandsnaam.

## 1.7.0 — 2026-09-10

Nieuwe functie (minor).

- Alleen media uit de speellijst telt als in gebruik. Cue templates in de workspace worden overgeslagen.

## 1.6.0 — 2026-09-10

Nieuwe functie (minor).

- Optioneel gedisarmde cues negeren: media die alleen in gedisarmde cues zit telt dan niet als in gebruik.

## 1.5.0 — 2026-09-10

Nieuwe functie (minor).

- Mappen kunnen op slot; ongebruikte files daarin (en optioneel bepaalde extensies) tellen niet als opruimbaar.

## 1.4.0 — 2026-09-10

Nieuwe functie (minor).

- Waarschuwing als QLab draait; verwijderen is geblokkeerd als deze workspace in QLab openstaat.

## 1.3.2 — 2026-09-10

Bugfix (patch).

- UID-verwijzingen in de QLab-file werden soms als array gelezen. Daardoor bleef het projecttype-voorstel op ‘onbekend’ staan.

## 1.3.1 — 2026-09-10

Bugfix (patch).

- De QLab-instelling ‘Copy files into project folder’ wordt nu wel uit de workspace gelezen, zodat het type-voorstel klopt.

## 1.3.0 — 2026-09-10

Nieuwe functie (minor).

- Na het openen van een workspace stelt de app het projecttype voor op basis van de QLab-instelling ‘Copy files into project folder’. Je bevestigt of wijzigt zelf.

## 1.2.0 — 2026-09-10

Nieuwe functie (minor).

- Als een map meerdere `.qlab5`-files bevat, kies je zelf welke workspace je controleert in plaats van de eerste.

## 1.1.0 — 2026-09-10

Nieuwe functies (minor).

- Lijsten groeperen op audio, video, images en MIDI
- Per gebruikt bestand: hoe vaak QLab het aanroept
- Totalen in MB/GB: alles in de mappen, in gebruik, mag weg
- MIDI, map-achtergronden en masks meenemen als QLab-targets
- Ontbrekende verwijzingen als eigen lijst
- Waarschuwing bij een te grote of “verkeerde” contentmap
- Ongebruikte bestanden naar de macOS-prullenmand, met bevestiging van aantal en omvang

## 1.0.1 — 2026-09-10

- Map kiezen staat bij losse verwijzingen (contentmappen). Bij een projectmap kies je alleen de `.qlab5`; de audio- en videomappen vindt de app zelf.

## 1.0.0 — 2026-09-10

Eerste versie.

- QLab 5 `.qlab5`-workspaces inlezen en gebruikte mediabestanden herkennen
- Twee projectmodi: bestanden verzameld in de projectmap, of losse verwijzingen
- Overzicht in twee lijsten: in gebruik en niet in gebruik
- Logo en versienummer altijd rechtsboven
- Backlog voor later werk, plus een suggestion log voor losse verbeterideeën
