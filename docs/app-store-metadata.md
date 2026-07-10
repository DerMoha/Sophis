# App Store Metadata Draft

## English

**Subtitle:** Fast, private nutrition tracking

**Keywords:** calories,nutrition,macros,food diary,barcode,meal tracker,water

**Description:**

Sophis makes daily food tracking quick and understandable. Log food by search,
barcode, nutrition label, or manual entry; see today's calories and macros at a
glance; and review your diary over time. Optional planning, water, weight,
workout, supplement, and progress-photo tools stay available without crowding
the daily flow.

Your core history is stored locally. AI photo analysis is optional, uses your
own Gemini API key, and clearly identifies when selected content is sent for
cloud processing. AI nutrition estimates should always be reviewed.

## Deutsch

**Untertitel:** Schnelles, privates Ernährungstracking

**Keywords:** Kalorien,Ernährung,Makros,Tagebuch,Barcode,Mahlzeiten,Wasser

**Beschreibung:**

Mit Sophis erfasst du Lebensmittel schnell per Suche, Barcode,
Nährwerttabelle oder manueller Eingabe. Behalte Kalorien und Makros für heute
im Blick und prüfe deinen Verlauf im Ernährungstagebuch. Planung, Wasser,
Gewicht, Training, Supplemente und Fortschrittsfotos bleiben verfügbar, ohne
den täglichen Ablauf zu überladen.

Deine wichtigsten Daten werden lokal gespeichert. Die KI-Fotoanalyse ist
optional, verwendet deinen eigenen Gemini-API-Schlüssel und weist darauf hin,
wenn ausgewählte Inhalte zur Cloud-Verarbeitung gesendet werden. Prüfe
KI-Schätzungen immer vor dem Speichern.

## Review notes

- No account is required.
- Manual entry and food search work without Gemini.
- Barcode and nutrition-label flows request camera access only after a user
  selects the relevant action.
- HealthKit, notifications, biometrics, and AI are optional.
- Provide the reviewer with a test API key only if AI review is required; never
  commit it to the repository or metadata file.
