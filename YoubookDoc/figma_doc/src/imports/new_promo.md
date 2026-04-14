# Creazione promozione

## Schema dati

### Modello promo (`salons/{salonId}/promotions/{promoId}`)
- `id` (string, generata server-side)  
- `salonId` (string, FK verso salone)  
- `title` (string, obbligatoria)  
- `subtitle` (string, opzionale per card)  
- `coverImagePath` (string, path Cloud Storage `salons/{salonId}/promotions/{promoId}/cover.jpg`)  
- `coverImageUrl` (string, URL firmato/scadenza breve cache)  
- `status` (enum: `draft`, `scheduled`, `published`, `expired`)  
- `startsAt` / `endsAt` (timestamp)  
- `cta` (oggetto CallToAction, vedi sotto)  
- `sections` (array di `PromoSection`, ordinata)  
- `createdAt` / `updatedAt` (timestamp server)  
- `createdBy` / `updatedBy` (uid admin)  
- `priority` (int per ordinamento card, opzionale)  
- `analytics` (oggetto aggregati: `viewCount`, `ctaClickCount`, aggiornato via Cloud Function)

### Sezione promo (`PromoSection`)
- `id` (string locale, usata per diff UI)  
- `type` (enum `text`, `image`)  
- `content`  
  - Per `text`: `richText` (HTML semplificato o delta Quill) + `style` opzionale (align, highlight)  
  - Per `image`: `imagePath`, `imageUrl`, `altText`, `caption` opzionale  
- `order` (int, ridondante per query diretta)  
- `layout` (enum opzionale per future varianti: full, split, quote)  
- `visibility` (bool, es. per nascondere senza cancellare)

### CallToAction (`cta`)
- `type` (enum: `whatsapp`, `phone`, `link`, `booking`, `custom`)  
- `label` (string, default “Contatta”)  
- `payload` (object)  
  - `whatsapp`: `phoneNumber`, `messageTemplateId` o `messageText`  
  - `phone`: `phoneNumber`  
  - `link`: `url`  
  - `booking`: `bookingUrl`, `serviceId`  
  - `custom`: `intent` + `data`  
- `enabled` (bool)  
- `metadata` (versione template, tracking params UTM)

### Storage
- Cloud Storage bucket con cartelle per salone: `salons/{salonId}/promotions/{promoId}/`  
- File supportati: `cover`, immagini sezione (`section_{sectionId}.jpg/png`)  
- Metadati blob: `salonId`, `promotionId`, `sectionId`, `uploadedBy` per audit trail  
- Regole Storage: scrittura permessa solo ad admin salone; lettura pubblica con URL firmato a scadenza.

### API
- **POST** `/promotions` (Cloud Function HTTPS o Firestore callable)  
  - Richiede `salonId`, dati promo; crea record, restituisce `promoId` e URL upload firmati.  
- **PATCH** `/promotions/{promoId}` aggiornamento parziale; convalida stato e range date.  
- **GET** `/promotions?salonId=...&status=published` per dashboard e app cliente.  
- **POST** `/promotions/{promoId}/images:uploadUrl` per ottenere URL firmato.  
- **POST** `/promotions/{promoId}/cta:track` aggiorna `ctaClickCount` (funzione server per evitare manipolazioni).  
- Trigger Firestore `onWrite` per aggiornare `status` (es. passare a `expired` se `endsAt` < now) e sincronizzare analytics aggregati.

---

## Builder e anteprima (UI/UX)

### Flusso creazione/edizione
- **Selezione salone** o pre-compilato se admin single-salon.  
- **Step 1 – Impostazioni base:** titolo, sottotitolo, date, stato (`draft/published`).  
- **Step 2 – Copertina:** upload immagine (drag & drop), crop 16:9/4:5, compressione client, indicatori di caricamento.  
- **Step 3 – Contenuto:** builder sezioni con lista ordinabile; pulsanti “Aggiungi testo/immagine”; preview inline; validazioni (min 1 sezione).  
- **Step 4 – Call to action:** selettore tipo, form dinamica, anteprima messaggio (es. WhatsApp template).  
- **Step 5 – Anteprima card & pagina:** toggle vista card (come in lista clienti) e pagina completa (scroll).  
- **Review e Pubblica:** riepilogo, stato attuale, pulsante Pubblica/Sospendi.

### Componenti UI
- **SectionListWidget:** gestisce drag & drop, pulsanti duplica/elimina, toggle espandi/comprimi e warn se sezione vuota.  
- **TextSectionEditor:** editor rich text semplificato (titolo, testo, bullet, enfasi) con scelta layout (`Semplice`, `Card`, `Citazione`).  
- **ImageSectionEditor:** uploader con progress, anteprima, alt text obbligatorio per accessibility.  
- **PreviewPane:** render condiviso (usa gli stessi widget di visualizzazione client per coerenza).  
- **CTAConfigurator:** form dinamica, anteprima link, validazione numeri/URL.  
- **StatusBanner:** indica bozza/pubblicata/scaduta; mostra countdown scadenza.

### UX Considerazioni
- Autosave bozza ogni X secondi (Firestore `draft`).  
- Indicatori di errore centralizzati; highlight campo invalido.  
- Cronologia versioni (facoltativa) salvando snapshot sezioni.  
- Accessibilità: contrasti, testi alternativi, navigazione tastiera.  
- Mobile responsive per admin che usa tablet.

---

# Visualizzazione promo lato clienti

## Lista promo
- Query Firestore `promotions` filtrata per `status=published` e `startsAt <= now < endsAt`.  
- Ordinamento per `priority` decrescente, poi `endsAt` più vicino.  
- Widget carousel con autoplay (5s default), indicatori tappabili, pausa onHover/onDrag.  
- Card layout: immagine background (fallback colore brand), overlay gradient, titolo, scadenza formattata (“Fino al 12 mag”).  
- Lazy loading immagini con cache; shimmer placeholder.

## Pagina dettaglio
- Navigazione: tap card → `PromoDetailPage(promoId)`.  
- `CustomScrollView` con `SliverAppBar` espandibile (immagine + titolo + CTA ancorata).  
- Corpo: iterazione `sections`;  
  - TextSectionWidget (layout `Semplice`, `Card`, `Citazione` con styling coerente lato client)  
  - ImageSectionWidget (hero animation dalla card, caption, titolo opzionale)  
- CTA persistente (pulsante `Contatta`) docked in bottom sheet su mobile; su web/desktop sticky a destra.  
- Gestione link CTA:
  - `whatsapp`: `launchUrl(Uri.parse("https://wa.me/$phone?text=$encodedTemplate"))`  
  - `phone`: `tel:`  
  - `link/booking`: `launchUrl` in webview/scheda esterna.  
  - Tracking: invoca Cloud Function `cta:track` prima di lanciare.

## Tracking & Analytics
- Eventi Firebase Analytics: `promo_view`, `promo_section_view`, `promo_cta_click`.  
- Parametri: `promoId`, `salonId`, `ctaType`, `position`.  
- Incremento aggregati in Firestore (`analytics.viewCount++`, `analytics.ctaClickCount++`).  
- Possibile heatmap sezione: salvare `lastViewedSectionId`.  
- Monitor scadenze: scheduler (Cloud Function cron) per disattivare promo scadute e inviare notifiche promemoria admin.
