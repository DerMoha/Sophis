"""Build the static English/German GitHub Pages site without dependencies."""
from html import escape
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'website'
BASE = 'https://dermoha.github.io/Sophis/'
EMAIL = 'sophis@brokenmoha.de'
TEXT = {
'en': {
 'nav': ['Overview', 'Support', 'Privacy', 'Beta terms'], 'skip': 'Skip to content',
 'intro': 'Sophis is an iOS app for tracking meals, nutrition and water.',
 'email_label': 'Email support', 'issue_label': 'Report an issue', 'issue_body': 'GitHub Issues is public and requires a GitHub account. Include your app version, iOS version and steps to reproduce a bug. Keep API keys, passwords, health records and private photos out of public reports.',
 'delete_title': 'Account & data deletion', 'delete_body': 'Delete your optional partner account within the app. Local tracking data can be removed separately in Settings. For a private support or privacy request, email us.',
 'privacy_title': 'Privacy policy', 'privacy_intro': 'What stays on your device, and what happens when you choose an external feature.',
 'terms_title': 'Beta terms', 'terms_intro': 'A few things to know before testing Sophis.',
 'updated': 'Updated 3 November 2026', 'operator': 'Provided by Mohammed Hamid', 'contents': 'On this page',
 'privacy': [
 ('The essentials', ['Sophis is a nutrition tracking app provided by Mohammed Hamid. Core tracking requires no account. Optional partner sharing uses Firebase Authentication and Cloud Firestore. Sophis does not use advertising, cross-app tracking or third-party analytics.', f'For support and privacy requests, contact <a href="mailto:{EMAIL}">{EMAIL}</a>.']),
 ('Information on your device', ['Nutrition goals and logs, water and weight entries, workouts, meal plans, recipes, supplements, preferences, cached barcode results and progress photos are stored locally using SQLite, app files and preferences. User-provided AI keys and optional Open Food Facts credentials use the operating system’s secure credential storage.', 'Nutrition-label scanning begins with local text recognition and parsing. The original image is not uploaded during this local pass. Captured label images may also be saved to the system Photos library; those copies can be managed there.', 'Apple Health data is read or written only with the relevant permission. Notifications and biometric protection for progress photos are handled locally by the operating system.']),
 ('Optional partner sharing', ['Creating an account sends your email and authentication credentials to Firebase Authentication. Your profile contains a display name and account identifier. Connecting a partner shares diary days, including food entries, nutrition goals and burned calories, through Cloud Firestore. The app synchronizes the most recent seven diary days. Your connected partner can access shared information.', 'Disconnecting removes the shared day documents and connection. Deleting the partner account within the app also removes your profile, invitations and Firebase account. Removing local app data alone does not delete the remote account or copies another person has retained. Google controls Firebase processing under its terms and privacy policy.']),
 ('Optional external features', ['<ul><li>Food search sends search terms to Open Food Facts. Barcode lookup sends barcodes to Open Food Facts and, if needed, Brocade. Results may be cached locally.</li><li>AI food, recipe and image features send selected images or text directly to the provider you choose: Gemini, OpenAI, OpenRouter, Anthropic or a custom compatible endpoint, using your own key.</li><li>If cloud help for labels is enabled, unclear label images and/or OCR text may be sent to the selected provider. Review AI estimates before saving.</li><li>Submitting a product to Open Food Facts sends the product data and any entered credentials to that service.</li></ul>', 'AI and food lookup requests go directly to the selected services. Partner sharing separately uses Firebase. External providers control their own processing and retention. Sophis does not use health, fitness or photo data for advertising, marketing or tracking.']),
 ('Photos, sharing & backups', ['Camera and photo-library permissions support barcode, label, meal and progress-photo features. Progress photos stay local unless you choose to export or share them. The operating system’s share sheet sends selected content to the app or recipient you choose.', 'You can export a backup containing nutrition records and progress-photo files. You control exported files after they leave Sophis.']),
 ('Deletion, retention & security', ['Delete All Local Data removes Sophis records, app-owned progress photos, settings, reminders and saved credentials from the app. It does not remove exported or shared copies, label images in Photos, or the remote partner account. You can remove saved API keys and Open Food Facts credentials in Settings.', 'Operating-system backups follow the platform’s retention rules. Requests to external providers may be retained according to their policies. Shared partner data remains in Firebase until it is removed through the partner/account deletion flows. Credentials use secure operating-system storage and remote connections are encrypted.']),
 ('Your choices & contact', ['The beta is intended for adults and provides general nutrition tracking, not medical advice. Consult a qualified professional for medical or dietary decisions.', 'Depending on your location, you may have rights to access, correct, export or delete information and complain to your data protection authority. Email the maintainer for privacy requests; do not post sensitive details in public issues. Policy changes are published here with an updated date.'])
 ],
 'terms': [
 ('About the beta', ['Sophis is an experimental nutrition tracking app provided by Mohammed Hamid. Beta versions may contain errors, change or become unavailable. Keep backups of information you need.']),
 ('Review nutrition estimates', ['Nutrition values and AI estimates can be inaccurate. Review them before saving. Sophis is not a medical device or a substitute for professional medical advice.']),
 ('External services & sharing', ['Optional AI uses your own provider key. You are responsible for your provider account and any usage charges. Provider terms apply to their services.', 'Share only information you are authorized to share. Your connected partner can see shared diary data. You can disconnect and delete your partner account in the app.']),
 ('Your rights', ['Nothing here limits rights that applicable law does not allow to be excluded. Apple’s TestFlight terms also apply to beta distribution.', '<a href="support.html">Contact support</a> if you have questions.'])
 ]},
'de': {
 'nav': ['Übersicht', 'Hilfe', 'Datenschutz', 'Beta-Bedingungen'], 'skip': 'Zum Inhalt',
 'intro': 'Sophis ist eine iOS-App zum Erfassen von Mahlzeiten, Nährwerten und Wasser.',
 'email_label': 'Support per E-Mail', 'issue_label': 'Fehler melden', 'issue_body': 'GitHub Issues ist öffentlich und erfordert ein GitHub-Konto. Nenne App-Version, iOS-Version und die Schritte zum Fehler. API-Schlüssel, Passwörter, Gesundheitsdaten und private Fotos gehören nicht in öffentliche Berichte.',
 'delete_title': 'Konto & Daten löschen', 'delete_body': 'Dein optionales Partnerkonto kannst du in der App löschen. Lokale Trackingdaten entfernst du separat in den Einstellungen. Für vertrauliche Support- oder Datenschutzanfragen schreibe uns eine E-Mail.',
 'privacy_title': 'Datenschutzerklärung', 'privacy_intro': 'Was auf deinem Gerät bleibt und was bei optionalen externen Funktionen passiert.',
 'terms_title': 'Beta-Bedingungen', 'terms_intro': 'Was du vor dem Testen von Sophis wissen solltest.',
 'updated': 'Stand: 3. November 2026', 'operator': 'Herausgeber: Mohammed Hamid', 'contents': 'Auf dieser Seite',
 'privacy': [
 ('Das Wichtigste', ['Sophis ist eine App zum Ernährungstracking von Mohammed Hamid. Grundlegendes Tracking erfordert kein Konto. Optionales Partner-Sharing nutzt Firebase Authentication und Cloud Firestore. Sophis verwendet keine Werbung, kein appübergreifendes Tracking und keine Analyse-SDKs von Drittanbietern.', f'Für Support und Datenschutzanfragen erreichst du uns unter <a href="mailto:{EMAIL}">{EMAIL}</a>.']),
 ('Informationen auf deinem Gerät', ['Ernährungsziele und Tagebucheinträge, Wasser- und Gewichtseinträge, Training, Essenspläne, Rezepte, Supplemente, Einstellungen, zwischengespeicherte Barcode-Ergebnisse und Fortschrittsfotos werden lokal in SQLite, App-Dateien und Einstellungen gespeichert. Eigene KI-Schlüssel und optionale Zugangsdaten für Open Food Facts liegen im sicheren Zugangsdaten-Speicher des Betriebssystems.', 'Das Scannen von Nährwerttabellen beginnt mit lokaler Texterkennung und Auswertung. In diesem lokalen Schritt wird das Originalbild nicht hochgeladen. Aufgenommene Etikettenbilder können zusätzlich in der Fotos-Mediathek gespeichert werden; diese Kopien verwaltest du dort.', 'Daten aus Apple Health werden nur mit der jeweiligen Berechtigung gelesen oder geschrieben. Benachrichtigungen und biometrischer Schutz für Fortschrittsfotos werden lokal durch das Betriebssystem verarbeitet.']),
 ('Optionales Partner-Sharing', ['Beim Erstellen eines Kontos werden deine E-Mail-Adresse und Anmeldedaten an Firebase Authentication übermittelt. Dein Profil enthält einen Anzeigenamen und eine Nutzerkennung. Wenn du einen Partner verbindest, werden Tagebucheinträge einschließlich Lebensmitteln, Ernährungszielen und verbrannten Kalorien über Cloud Firestore geteilt. Die App synchronisiert die letzten sieben Tage. Dein verbundener Partner kann auf die geteilten Informationen zugreifen.', 'Das Trennen der Verbindung entfernt die geteilten Tagesdokumente und die Verbindung. Das Löschen des Partnerkontos in der App entfernt zusätzlich dein Profil, Einladungen und Firebase-Konto. Das bloße Löschen lokaler App-Daten entfernt weder das entfernte Konto noch bereits aufbewahrte Kopien anderer Personen. Google verarbeitet Firebase-Daten nach seinen Bedingungen und seiner Datenschutzerklärung.']),
 ('Optionale externe Funktionen', ['<ul><li>Die Lebensmittelsuche sendet Suchbegriffe an Open Food Facts. Die Barcode-Suche übermittelt Barcodes an Open Food Facts und bei Bedarf an Brocade. Ergebnisse können lokal zwischengespeichert werden.</li><li>KI-Funktionen für Lebensmittel, Rezepte und Bilder senden ausgewählte Bilder oder Texte direkt an deinen gewählten Anbieter: Gemini, OpenAI, OpenRouter, Anthropic oder einen eigenen kompatiblen Endpoint. Dafür wird dein eigener API-Schlüssel verwendet.</li><li>Bei aktivierter Cloud-Hilfe können schwer lesbare Etikettenbilder und/oder OCR-Texte an den gewählten Anbieter gesendet werden. Prüfe KI-Schätzungen vor dem Speichern.</li><li>Beim Einsenden eines Produkts an Open Food Facts werden die Produktdaten und gegebenenfalls eingegebene Zugangsdaten an diesen Dienst übertragen.</li></ul>', 'KI- und Lebensmittelanfragen gehen direkt an die gewählten Dienste. Partner-Sharing nutzt separat Firebase. Externe Anbieter bestimmen ihre eigene Verarbeitung und Aufbewahrung. Sophis verwendet Gesundheits-, Fitness- oder Fotodaten nicht für Werbung, Marketing oder Tracking.']),
 ('Fotos, Teilen & Backups', ['Kamera- und Fotoberechtigungen ermöglichen Barcode-, Etiketten-, Mahlzeiten- und Fortschrittsfoto-Funktionen. Fortschrittsfotos bleiben lokal, sofern du sie nicht exportierst oder teilst. Über die Teilen-Funktion des Betriebssystems werden ausgewählte Inhalte an die von dir gewählte App oder Person übermittelt.', 'Du kannst ein Backup mit Ernährungseinträgen und Fortschrittsfotos exportieren. Nach dem Export liegen diese Dateien unter deiner Kontrolle.']),
 ('Löschung, Aufbewahrung & Sicherheit', ['Alle lokalen Daten löschen entfernt Sophis-Einträge, App-eigene Fortschrittsfotos, Einstellungen, Erinnerungen und gespeicherte Zugangsdaten aus der App. Exportierte oder geteilte Kopien, Etikettenbilder in Fotos und das entfernte Partnerkonto werden dadurch nicht gelöscht. API-Schlüssel und Open-Food-Facts-Zugangsdaten kannst du in den Einstellungen entfernen.', 'Backups des Betriebssystems folgen den Aufbewahrungsregeln der Plattform. Externe Anbieter können Anfragen nach ihren eigenen Richtlinien aufbewahren. Geteilte Partnerdaten bleiben in Firebase, bis sie über die Partner- oder Kontolöschung entfernt werden. Zugangsdaten liegen im sicheren Speicher des Betriebssystems; externe Verbindungen sind verschlüsselt.']),
 ('Deine Möglichkeiten & Kontakt', ['Die Beta richtet sich an Erwachsene und dient dem allgemeinen Ernährungstracking, nicht der medizinischen Beratung. Wende dich bei medizinischen oder diätetischen Entscheidungen an qualifiziertes Fachpersonal.', 'Abhängig von deinem Aufenthaltsort können Rechte auf Auskunft, Berichtigung, Export oder Löschung sowie eine Beschwerde bei einer Datenschutzaufsichtsbehörde bestehen. Richte Datenschutzanfragen per E-Mail an den Herausgeber und veröffentliche keine vertraulichen Angaben in Issues. Änderungen dieser Erklärung werden hier mit aktualisiertem Datum veröffentlicht.'])
 ],
 'terms': [
 ('Über die Beta', ['Sophis ist eine experimentelle App zum Ernährungstracking von Mohammed Hamid. Beta-Versionen können Fehler enthalten, sich verändern oder nicht mehr verfügbar sein. Sichere Informationen, die du aufbewahren möchtest.']),
 ('Nährwertschätzungen prüfen', ['Nährwerte und KI-Schätzungen können ungenau sein. Prüfe sie vor dem Speichern. Sophis ist kein Medizinprodukt und ersetzt keine professionelle medizinische Beratung.']),
 ('Externe Dienste & Teilen', ['Optionale KI-Funktionen verwenden deinen eigenen API-Schlüssel. Du bist für dein Anbieterkonto und mögliche Nutzungskosten verantwortlich. Für externe Dienste gelten deren Bedingungen.', 'Teile nur Informationen, die du teilen darfst. Dein verbundener Partner kann geteilte Tagebuchdaten sehen. Du kannst die Verbindung trennen und dein Partnerkonto in der App löschen.']),
 ('Deine Rechte', ['Gesetzliche Rechte, die nicht ausgeschlossen werden dürfen, werden durch diese Hinweise nicht eingeschränkt. Für die Beta-Verteilung gelten außerdem die TestFlight-Bedingungen von Apple.', 'Bei Fragen hilft dir der <a href="support.html">Support</a>.'])
 ]}
}
PAGES = ['index.html', 'support.html', 'privacy.html', 'terms.html']

def layout(lang, page, title, body):
 t = TEXT[lang]
 prefix = '../' if lang == 'de' else ''
 target = ('de/' if lang == 'en' else '../') + page
 nav = ' · '.join(f'<a href="{p}"' + (' aria-current="page"' if p == page else '') + f'>{label}</a>' for p, label in zip(PAGES, t['nav']))
 return f'''<!doctype html>
<html lang="{lang}">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{escape(title)} · Sophis</title>
<link rel="stylesheet" href="{prefix}site.css?v=2">
<link rel="alternate" hreflang="en" href="{BASE}{page}">
<link rel="alternate" hreflang="de" href="{BASE}de/{page}"></head>
<body><a class="skip" href="#main">{t['skip']}</a>
<header><a href="index.html" class="brand">Sophis</a><a href="{target}" lang="{'de' if lang == 'en' else 'en'}">{'Deutsch' if lang == 'en' else 'English'}</a></header>
<nav aria-label="{'Navigation' if lang == 'en' else 'Navigation'}">{nav}</nav>
<main id="main">{body}</main>
<footer>{t['operator']} · <a href="mailto:{EMAIL}">{EMAIL}</a></footer>
</body></html>'''

def document(t, kind):
 sections = ''.join('<section><h2>' + title + '</h2>' + ''.join(p if p.startswith('<ul>') else '<p>' + p + '</p>' for p in paragraphs) + '</section>' for title, paragraphs in t[kind])
 return f'<h1>{t[kind + "_title"]}</h1><p class="muted">{t["updated"]}</p>{sections}'

for lang, t in TEXT.items():
 folder = ROOT / ('de' if lang == 'de' else '')
 folder.mkdir(parents=True, exist_ok=True)
 home = f'<h1>Sophis</h1><p>{t["intro"]}</p><p>' + ('The TestFlight beta is awaiting Apple’s review. <a href="https://testflight.apple.com/join/wf41vGqu">TestFlight invitation</a> (available after approval).' if lang == 'en' else 'Die TestFlight-Beta wartet auf Apples Prüfung. <a href="https://testflight.apple.com/join/wf41vGqu">TestFlight-Einladung</a> (nach der Freigabe nutzbar).') + '</p><p><a href="https://github.com/DerMoha/Sophis">GitHub</a></p>'
 support = f'<h1>{t["nav"][1]}</h1><p>' + ('Questions or problems? Email ' if lang == 'en' else 'Bei Fragen oder Problemen schreibe an ') + f'<a href="mailto:{EMAIL}">{EMAIL}</a>.</p><h2>{t["issue_label"]}</h2><p>{t["issue_body"]}</p><p><a href="https://github.com/DerMoha/Sophis/issues">GitHub Issues</a></p><h2>{t["delete_title"]}</h2><p>{t["delete_body"]}</p>'
 for page, title, body in [('index.html', t['nav'][0], home), ('support.html', t['nav'][1], support), ('privacy.html', t['privacy_title'], document(t, 'privacy')), ('terms.html', t['terms_title'], document(t, 'terms'))]:
  (folder / page).write_text(layout(lang, page, title, body))
(ROOT / '.nojekyll').touch()
