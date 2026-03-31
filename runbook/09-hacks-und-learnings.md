# 09 — Hacks und Learnings

Allgemeine Erfahrungen, Tricks und Workarounds aus eigenen Tests und Kunden-Setups.

---

## Embedding-Qualitaet

### Chunk-Groesse ist entscheidend

- Zu gross (>1000 Zeichen): KI bekommt zu viel Rauschen, Antworten werden unpraezise
- Zu klein (<100 Zeichen): Kein Kontext, schlechte Treffer
- Sweet Spot: 300-600 Zeichen mit 10-15% Ueberlappung
- Bei technischen Dokumenten: eher groessere Chunks (600-800)
- Bei FAQ/Kurztexten: eher kleinere Chunks (200-400)

### Similarity Threshold tunen

- 0.9+: Nur fast-exakte Treffer → zu restriktiv
- 0.75-0.85: Gute Balance fuer die meisten Faelle
- 0.6-0.75: Mehr Treffer, aber auch mehr Rauschen
- Bei schlechter OCR-Qualitaet: Threshold runtersetzen auf 0.65

---

## OCR-Tipps

- pdf-parse reicht fuer Text-PDFs, versagt bei Scans komplett
- Tesseract mit `-l deu` fuer deutsche Dokumente
- Google Document AI ist deutlich besser als Tesseract bei schlechten Scans
- Vor dem Embedding: OCR-Text bereinigen (doppelte Leerzeichen, Sonderzeichen)

---

## n8n auf Raspberry Pi

- RAM ist der Bottleneck, nicht CPU
- Bei vielen gleichzeitigen Workflows: n8n Execution Mode auf "queue" stellen
- Ollama + n8n auf dem gleichen Pi: Geht, aber nur ein Workflow gleichzeitig

---

## Demo-Tipps

- Immer vorher Cold-Start vermeiden (erste Anfrage ist langsam)
- 3 vorbereitete Fragen die garantiert funktionieren
- Eine Frage die garantiert "nicht in Dokumenten" sagt → zeigt Ehrlichkeit der KI

---

## Learnings & Hacks
<!-- Ergaenze hier nach jedem Setup was dir aufgefallen ist -->
