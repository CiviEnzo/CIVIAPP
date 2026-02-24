# Preventivi

## Obiettivo
- Consentire al salone di costruire proposte economiche strutturate per ogni cliente partendo dal catalogo servizi e pacchetti gia presente in piattaforma.
- Collegare automaticamente il preventivo accettato con il flusso amministrativo (vendita, ticket di pagamento e successivo incasso).

## Attori e permessi
- Ruoli `admin` e `staff`: possono creare, modificare, inviare, accettare, rifiutare ed eliminare preventivi dal dettaglio cliente nella console amministrativa.
- Ruolo `client`: riceve il PDF tramite i canali scelti, trova lo storico dei preventivi nella propria app (dashboard cliente) e puo accettare l'offerta avviando un pagamento Stripe.

## Modello dati

### Quote
- `id`: identificativo del documento su Firestore (`quotes/<id>`).
- `salonId` / `clientId`: collegamenti forti al salone e al cliente.
- `number`: numerazione progressiva con prefisso `PR-<anno>-NNN` generata da `nextQuoteNumber`.
- `title`: intestazione opzionale mostrata nelle card e nel PDF.
- `notes`: note interne/esterne riportate nel PDF e nella vista cliente.
- `status`: `draft`, `sent`, `accepted`, `declined`, `expired`.
- `items`: elenco immutabile di `QuoteItem`.
- `total`: somma arrotondata a due decimali delle righe (calcolata a runtime, salvata a supporto dei report).
- Timestamps: `createdAt`, `updatedAt`, `sentAt`, `acceptedAt`, `declinedAt`.
- `validUntil`: data di scadenza opzionale utilizzata per evidenziare la scadenza lato UI.
- `ticketId`: eventuale riferimento a un `PaymentTicket` generato dopo l'accettazione.
- `sentChannels`: canali scelti per l'invio (valori di `MessageChannel`).
- `pdfStoragePath`: percorso del PDF in Firebase Storage per l'ultimo invio.
- `saleId`: identificativo della vendita generata (presente dopo accettazione manuale o via Stripe).
- `stripePaymentIntentId`: riferimento all'ultimo PaymentIntent Stripe associato (utile per audit e riconciliazione).

### Stati di un preventivo
- `draft`: bozza modificabile, mai inviata.
- `sent`: condiviso con il cliente; resta modificabile finche non viene accettato o rifiutato.
- `accepted`: accettato dal salone (con successiva creazione vendita). Le modifiche sono bloccate.
- `declined`: segnato come rifiutato; eventuali accettazioni future richiedono una nuova bozza.
- `expired`: stato virtuale usato solo in UI quando la data `validUntil` e passata senza decisione (il campo `status` su Firestore non viene aggiornato automaticamente).

### QuoteItem
- `id`: identificativo interno della riga.
- `description`: testo visualizzato nel PDF e nell'app.
- `quantity`: numero decimale (due decimali) per gestire percorsi o prodotti frazionati.
- `unitPrice`: prezzo unitario (two decimals).
- `serviceId` / `packageId`: riferimento facoltativo al servizio o al pacchetto selezionato; se assenti la riga e trattata come voce libera (es. prodotto extra).
- Valori derivati: `total` = `quantity * unitPrice` arrotondato a due decimali.

### Canali di invio supportati
- Email, WhatsApp, SMS: gestiti tramite condivisione manuale del PDF (Share XFiles).
- Push: presenza nel modello ma non ancora automatizzata; viene segnalato all'operatore se selezionato.

## Flussi backoffice

### Creazione e modifica
1. Dal dettaglio cliente (`Nuovo preventivo`) si apre il foglio `QuoteFormSheet`.
2. Il form precarica servizi e pacchetti del salone per suggerire righe collegate; e comunque possibile inserire voci manuali.
3. Il numero viene proposto automaticamente con il prossimo progressivo annuale; l'utente puo sovrascriverlo.
4. Si possono impostare titolo, scadenza (`validUntil`), note e quantita/prezzi delle righe.
5. Il salvataggio crea/aggiorna il documento su Firestore in stato `draft`. Le modifiche restano possibili finche lo stato e `draft` o `sent`.

### Invio al cliente
1. Solo utenti `admin`/`staff` possono avviare l'invio.
2. Il sistema propone i canali in base alle preferenze del cliente (`ChannelPreferences`); l'operatore puo selezionare uno o piu canali supportati.
3. Generazione PDF lato device con layout A4, riepilogo salon/client, righe e totali.
4. Upload del PDF su Firebase Storage in `salon_media/<salonId>/quotes/<quoteId>/<file>.pdf`; il percorso viene salvato in `pdfStoragePath`.
5. Apertura della share sheet nativa (email/SMS/WhatsApp) con messaggio precompilato e link al download.
6. Aggiornamento del documento: `status` passa a `sent` (se non gia `accepted`), `sentAt`, `sentChannels` e `updatedAt` vengono registrati.

### Gestione decisione
- **Accetta (cliente via Stripe):** dal dettaglio preventivo nell'app cliente l'utente seleziona *Accetta e paga*. Si apre un checkout Stripe (Payment Link o Checkout Session). Al `payment_intent.succeeded` una Cloud Function validando l'evento richiama lo stesso flusso di backoffice (`acceptQuote`) che crea la `Sale`, chiude o genera il `PaymentTicket`, salva `acceptedAt`, `ticketId` e aggiorna lo stato a `accepted`.
- **Accetta (backoffice):** resta disponibile per `admin`/`staff` come fallback manuale (es. incassi offline). Crea una `Sale` con stato pagamento `deposit`, genera o riutilizza un `PaymentTicket` e lo chiude collegandolo alla vendita. Le note del preventivo vengono propagate alla vendita e al ticket, e il `status` diventa `accepted`.
- **Rifiuta:** richiede conferma; aggiorna `status` a `declined`, imposta `declinedAt` e azzera `acceptedAt`.
- **Scadenza:** non avviene un cambio di stato automatico; la UI mostra comunque il badge "Scaduto" quando `validUntil` e nel passato.
- **Elimina:** rimuove il documento dalla collezione `quotes`. Al momento non annulla automaticamente la vendita eventualmente generata in precedenza (operazione manuale nel modulo vendite).

## Esperienza cliente
- Nella dashboard cliente compare la sezione Preventivi con card ordinate dalla piu recente.
- Ogni card mostra titolo/numero, date di creazione e invio, scadenza, note, elenco righe con quantita e prezzi, totale, stato e canali utilizzati.
- Messaggi dedicati informano il cliente se il preventivo e stato accettato (con ticket gia registrato) o rifiutato. Quando scade viene evidenziato e suggerito di contattare il salone.

## Storage e integrazioni
- Firestore: collezione `quotes` con tutti i campi descritti sopra. Le regole di sicurezza richiedono coerenza del `salonId` e controllano i permessi per ruolo.
- Firebase Storage: cartella `salon_media/<salonId>/quotes/<quoteId>/` per archiviare gli invii PDF, con metadata (quoteId, salonId, clientId, quoteNumber).
- Stripe: il client-side genera la sessione di pagamento con i totali del preventivo. Una Cloud Function in ascolto sugli eventi Webhook Stripe (almeno `payment_intent.succeeded` e `payment_intent.payment_failed`) valida la signature, arricchisce i metadati con `quoteId`, quindi chiama i casi d'uso su App Data Store. Al successo viene invocato `acceptQuote`; in caso di fallimento si registrano log e notifiche interne.
- Accettazione: crea una vendita (`sales`), aggiorna/crea ticket (`paymentTickets`) e consente al modulo cassa di registrare in seguito incassi o acconti. I pacchetti inclusi vengono trasformati in `SaleItem` con sessioni e scadenze coerenti con la configurazione del pacchetto.

## Limitazioni note / TODO
- Non esiste ancora un flusso di retry/notify automatico per pagamenti Stripe falliti o abbandonati; il cliente deve ripetere l'operazione e lo staff monitorare i fallimenti dai log.
- La condivisione del PDF dipende dalla share sheet del dispositivo: non c'e invio automatico server-side.
- Il canale Push non ha implementazione; eventuali selezioni informano soltanto l'operatore.
- La scadenza non altera lo stato su Firestore: per statistiche o automazioni future serviranno job dedicati.
- I preventivi accettati non possono essere eliminati; per le bozze/inviati lo staff deve comunque riconciliare manualmente eventuali vendite o ticket gia generati.
