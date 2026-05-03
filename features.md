# Sophis – Feature Ideas

## 🔥 High Impact

### 1. Intermittent Fasting Timer
Timer mit konfigurierbarem Fasten-/Essensfenster (z. B. 16:8, 18:6, OMAD).
- Live-Timer mit Fortschrittsanzeige
- Push-Benachrichtigung bei Fenster-Start/Ende
- Visualisierung des aktuellen Zyklus-Status
- Integration mit bestehendem NotificationService
- Dashboard-Card für schnellen Zugriff

### 2. Mikronährstoff-Tracking
Tracking von Vitaminen und Mineralien zusätzlich zu Makros.
- Erweiterung der FoodItem-Daten um Mikronährstoffe (Vit. A, C, D, Eisen, Calcium, etc.)
- Tägliche Mikronährstoff-Übersicht (Fortschrittsbalken pro Vitamin)
- Warnung bei Unter-/Überversorgung
- Barcode-Lookup um Mikronährstoffdaten erweitern (OpenFoodFacts liefert diese)

### 3. Quick-Calories / Schnell-Logging
Manchmal will man nur "~500 kcal Snack" eintragen, ohne ein Lebensmittel zu suchen.
- Free-Text-Feld mit Kalorien + optional Makros (P/C/F)
- Kein FoodItem notwendig – rein numerischer Eintrag
- Quick-Action Button auf dem Dashboard
- Kategorie/Mahlzeit zuweisbar

### 4. Progress Photos / Vorher-Nachher
Siehe detaillierten Plan unten (Progress Photos Plan).

## ⚡ Medium Impact

### 5. Körpermaße
Nicht nur Gewicht, sondern alle relevanten Körpermaße tracken.
- Konfigurierbare Messpunkte: Bauch, Hüfte, Brust, Arme, Oberschenkel, Waden, Nacken
- Verlaufsgrafik pro Messpunkt (fl_chart)
- Side-by-Side-Vergleich verschiedener Zeitpunkte
- Notizen pro Messung
- Schätzung Körperfettanteil (Navy-Methode)

### 6. Google Fit Integration
Aktuell nur Apple HealthKit. Schließt Android-Nutzer aus.
- Pendant zu HealthService für Google Fit
- Read: Schritte, verbrannte Kalorien, Gewicht
- Write: Ernährung, Gewicht
- Feature-Flag je Plattform

### 7. Custom Macro Goals per Meal
Makro-Ziele nicht nur für den ganzen Tag, sondern pro Mahlzeit.
- Einstellbar pro Mahlzeit-Typ (Frühstück, Mittag, Abend, Snack)
- Visuelle Anzeige im FoodDiary (z. B. "30/40g Protein erreicht")
- Hilft bei Meal-Prep und gezielter Ernährung

### 8. Ernährungstagebuch-Insights
Wöchentliche/Monatliche Zusammenfassung mit Trends.
- "Diese Woche: 15% mehr Protein als letzte Woche"
- "Du isst meistens um 19:30 zu Abend"
- Kalorien-Trend über Wochen/Monate
- Beste/Varianzreichste Mahlzeiten
- Widget mit Wochenübersicht

## 💡 Nice-to-Have

### 9. Ernährungs-Präferenzen als Filter
- Vegan, Vegetarisch, Keto, Low-Carb, Paleo, High-Protein, Laktosefrei, Glutenfrei
- Lebensmittelvorschläge und Rezepte entsprechend filtern
- Präferenz-Tag in den Einstellungen
- Suchfilter im FoodSearchScreen

### 10. Sprachlogging
"Ich habe einen Apfel und einen Proteinshake gegessen" per Spracheingabe.
- Speech-to-Text (platform channel)
- Text an bestehende Gemini-Integration senden
- Gemini parst in FoodEntry-Objekte
- Manuelle Korrektur vor dem Speichern

### 11. Mahlzeiten-Foto-Tagebuch
Visuelles Tagebuch aller Mahlzeiten als chronologischer Scroll-Feed.
- Foto optional bei jedem Food-Logging
- Grid/Liste der Mahlzeiten-Fotos
- Unabhängig von AI-Analyse (kamera button ohne AI)
- Teilen als Collage

### 12. Koffein-Tracking
- Koffein pro FoodItem/Getränk
- Tageslimit einstellbar
- Warnung bei Überschreitung
- Letzter Koffein-Zeitpunkt (Schlaf-Warnung)

### 13. Wasser-Erinnerungen
- Push-Benachrichtigungen in konfigurierbaren Intervallen
- "Du hast erst 500ml von 2000ml getrunken"
- Intelligente Reminder basierend auf aktuellem Fortschritt

### 14. Perioden-Tracking
Zyklus-Tracking (für weibliche Nutzer).
- Kalender-basierte Eingabe
- Phasen-Anzeige
- Korrelation mit Ernährung/Gewicht/Cravings
- Privatsphäre-first, nur lokal

### 15. Community Recipe Sharing
- Rezepte als sophis://share Deep Link teilen (bestehende Infrastruktur nutzen)
- Öffentliche Rezept-Bibliothek (optional)
- Bewertungen und Kommentare
- "Remixen" von Community-Rezepten

### 16. Dark Mode Schedule
- Automatischer Dark Mode nach Zeitplan (z. B. ab 20:00)
- Unabhängig vom System-Dark-Mode
- Optional: Sonnenuntergang-basiert

### 17. Apple Watch Companion App
- Schnelleingabe: Wasser, Kalorien, Supplement
- Komplikation mit Tagesfortschritt
- Heute-Übersicht (Makros, Wasser, Kalorien)
- Force Touch für Quick-Logging

### 18. Daten-Verschlüsselung
- Optionale Verschlüsselung der SQLite-Datenbank (sqflite_sqlcipher)
- FaceID/TouchID zum Entsperren
- Export mit Passwortschutz

### 19. Widget-Varianten
- Mehrere Widget-Größen (small, medium, large)
- Widget-Konfiguration (welche Werte anzeigen)
- Watch-Complication

### 20. Barcode-Scan History
- Verlauf aller gescannten Barcodes mit Datum
- "Zuletzt gescannt" als Filter
- Schnellzugriff auf häufige Produkte
- Statistiken: meistgescannte Produkte
