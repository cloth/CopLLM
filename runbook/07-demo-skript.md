# 07 — Demo-Skript fuer Kundengespraeche

## Vorbereitung (5 Min. vorher)

- Stack laeuft? `docker ps` pruefen
- Test-Frage stellen um Cold-Start zu vermeiden
- 2-3 Demo-Dokumente in Google Drive bereit

## Demo-Ablauf (20 Minuten)

### 1. Problem-Darstellung (3 Min.)

> "Stellen Sie sich vor, Ihre Mitarbeiter suchen taeglich in Hunderten PDFs,
> E-Mails und Dokumenten nach Informationen. Wie lange dauert das?"

### 2. Live-Demo: Frage stellen (5 Min.)

Open WebUI oeffnen und zeigen:
- Frage zu einem bekannten Firmendokument stellen
- Zeigen: Praezise Antwort MIT Quellenangabe
- Vergleich: "Das ist wie ChatGPT, aber auf EURE Dokumente trainiert — ohne dass eure Daten irgendwo hinfliessen."

### 3. Live-Demo: Dokument hinzufuegen (5 Min.)

- PDF live in Google Drive hochladen
- n8n Sync abwarten (oder manuell triggern fuer Demo)
- Frage zum neuen Dokument stellen
- Zeigen: "Das wurde gerade vor 2 Minuten hochgeladen und ist sofort verfuegbar."

### 4. Architektur (3 Min.)

- Einfaches Diagramm zeigen (aus CLAUDE.md)
- Betonen: "Deutsche Server, DSGVO-konform, kein Training auf euren Daten"
- Betonen: "Automatischer Sync — ihr pflegt eure Dokumente wie gewohnt in Drive"

### 5. Preise und naechste Schritte (4 Min.)

- Setup: 1.500 EUR (Basis) / 2.500 EUR (Business)
- Monatlich: ab 99 EUR/Monat
- Naechster Schritt: "Wir machen ein Pilotprojekt mit 10 eurer Dokumente. Kostenlos."

## Die entscheidende Frage

> "Was waeren eure drei haeufigsten Fragen, die eure Mitarbeiter taeglich stellen
> und fuer die sie gerade 5-10 Minuten suchen?"

Die Antwort darauf ist dein Projektauftrag.

## Haeufige Einwaende

**"Wir haben das schon mit Copilot probiert."**
→ Copilot sucht in eurer gesamten Microsoft-Infrastruktur — das macht es ungenau.
Wir definieren exakt, welche Dokumente relevant sind.

**"Unsere Daten sind sensibel."**
→ Genau deswegen. Deutsche Server, AVV vorhanden, kein Training auf euren Daten.
Optional: 100% lokal ohne Cloud-API moeglich.

**"Zu teuer."**
→ Rechnung: 5 Mitarbeiter x 30 Min/Tag Suche x 220 Arbeitstage = 550 Stunden/Jahr.
Bei 40 EUR/h = 22.000 EUR Opportunitaetskosten. Unser System: 3.000 EUR einmalig.

**"Koennen wir das selbst betreiben?"**
→ Ja, Weg C laeuft komplett auf eurem Server. Wir setzen auf, ihr betreibt.

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
