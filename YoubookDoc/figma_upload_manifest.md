# Figma Upload Manifest (Current)

Versione: 2026-03-03  
Policy: set completo, legacy esclusi, fonte di verita = branch locale corrente.
Nota operativa: `YoubookDoc/flowchart.rtf` escluso dall'upload Figma Make per limite formato in upload.

## Ordine di caricamento consigliato
1. Core
2. Admin
3. Staff
4. Client
5. Cross-cutting
6. Asset

## Manifest file (stabile e versionabile)

| # | Path | Motivo di upload | Owner aggiornamento | Stato allineamento |
|---|---|---|---|---|
| 1 | `YoubookDoc/ui_app.md` | Prompt master e contratto Figma/MCP | Product + UX | Allineato |
| 2 | `YoubookDoc/login/login_admin.md` | Auth login admin | Auth owner | Allineato |
| 3 | `YoubookDoc/login/login_creazione_client.md` | Auth registrazione cliente | Auth owner | Allineato |
| 4 | `YoubookDoc/cliente/creazione_cliente.md` | Onboarding/creazione profilo cliente | Client owner | Allineato |
| 5 | `YoubookDoc/admin/UI/admin_ui_mobile.md` | UX admin mobile | Admin owner | Allineato |
| 6 | `YoubookDoc/admin/UI/UI MODULO SALONE.md` | Regole modulo salone | Admin owner | Allineato |
| 7 | `YoubookDoc/modulo/overview.md` | IA modulo panoramica/admin base | Admin owner | Allineato |
| 8 | `YoubookDoc/appointments/control_Appointment.md` | Regole agenda e controllo appuntamenti | Admin owner | Allineato |
| 9 | `YoubookDoc/appointments/UI_appointments_calendar.txt` | Dettagli UI calendario | Admin owner | Allineato |
| 10 | `YoubookDoc/appointments/manage_appintments_admin_side.txt` | Gestione appuntamenti lato admin | Admin owner | Allineato |
| 11 | `YoubookDoc/appointments/manage_appointmets_admin_multiservice.md` | Flow multi-servizio admin | Admin owner | Allineato |
| 12 | `YoubookDoc/ricerca_avanzata/ricerca_avanzata.md` | Ricerca avanzata clienti | Admin owner | Allineato |
| 13 | `YoubookDoc/vendite_cassa/vendite_cassa.txt` | Vendite e cassa | Admin owner | Allineato |
| 14 | `YoubookDoc/vendite_cassa/FATTURAZIONE` | Fatturazione | Admin owner | Allineato |
| 15 | `YoubookDoc/report/report.md` | Reportistica | Admin owner | Allineato |
| 16 | `YoubookDoc/staff/app_staff.md` | IA app staff | Staff owner | Allineato |
| 17 | `YoubookDoc/staff/staff.txt` | Regole operative staff | Staff owner | Allineato |
| 18 | `YoubookDoc/staff/creazione_turni.txt` | Pianificazione turni/permessi | Staff owner | Allineato |
| 19 | `YoubookDoc/cliente/cliente UI.md` | UI client principale | Client owner | Allineato |
| 20 | `YoubookDoc/cliente/prenotazione_cliente.txt` | Flow prenotazione client | Client owner | Allineato |
| 21 | `YoubookDoc/appointments/NUOVO SISTEMA DI PRENOTAZIONE LATO CLIEN.txt` | Nuovo booking lato client | Client owner | Allineato |
| 22 | `YoubookDoc/foto_cliente/archivio_fotografico.md` | Archivio foto cliente | Client owner | Allineato |
| 23 | `YoubookDoc/cliente/Anamnesi.md` | Anamnesi/questionari | Client owner | Allineato |
| 24 | `YoubookDoc/modulo/stripe.md` | Pagamenti Stripe e quote | Payments owner | Allineato |
| 25 | `YoubookDoc/modulo/whatsapp.md` | WhatsApp operativo | Messaging owner | Allineato |
| 26 | `YoubookDoc/modulo/whatsapp_reminder.md` | Reminder WhatsApp | Messaging owner | Allineato |
| 27 | `YoubookDoc/messaggi/CIVIAPP_MESSAGGI_GUIDA_Codex.md` | Messaggi/campagne/template | Messaging owner | Allineato |
| 28 | `YoubookDoc/notifications/notifications.md` | Notifiche e stati badge | Notifications owner | Allineato |
| 29 | `YoubookDoc/promozioni/new_promo.md` | Promozioni/last-minute | Marketing owner | Allineato |
| 30 | `YoubookDoc/PREVENTIVO.md` | Preventivi/quote client | Payments owner | Allineato |

## Legacy Excluded

| Path legacy | Stato | Motivo esclusione |
|---|---|---|
| `YoubookDoc/CIVIAPPTOSHARE.txt` | Rimosso (`git D`) | Documento legacy non piu fonte di verita |
| `YoubookDoc/admin/UI/UI` | Rimosso (`git D`) | File legacy eliminato dal progetto |
| `YoubookDoc/admin/UI/UI MODULO APPUNTAMENTI` | Rimosso (`git D`) | Sostituito da documentazione corrente appointments |

## Upload Excluded (Tool Constraints)

| Path | Stato | Motivo esclusione upload |
|---|---|---|
| `YoubookDoc/flowchart.rtf` | Presente | Formato non caricabile nel flusso Figma Make corrente |
| `YoubookDoc/punti fedeltà/punti fedelta.ini` | Presente | Escluso su richiesta operativa utente dal pacchetto upload |
| `YoubookDoc/assets/segna_viso.png` | Presente | Escluso su richiesta operativa utente dal pacchetto upload |
| `YoubookDoc/assets/segna_corpo.png` | Presente | Escluso su richiesta operativa utente dal pacchetto upload |

## Refresh cadence
Aggiornare questo file quando:
1. viene aggiunto/rimosso/rinominato un file UX/UI in `YoubookDoc`;
2. cambia la IA di route/moduli/ruoli;
3. prima di un nuovo ciclo di generazione Figma end-to-end;
4. cambia la policy MCP Code Connect o naming componenti.
