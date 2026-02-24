# Notifiche push + locali

## Architettura attuale
- `lib/services/notifications/notification_service.dart` incapsula l'unica istanza di `FlutterLocalNotificationsPlugin`, crea il canale Android `civiapp_push` (importance max, suono e vibrazione attivi) e inizializza le opzioni Darwin senza richiedere permessi aggiuntivi.  
- `NotificationService.show(...)` costruisce il `NotificationDetails` predefinito (Android, iOS, macOS) e accetta un `payload` serializzato in JSON per replicare i dati FCM nelle notifiche locali in foreground.  
- `handleNotificationResponse` inoltra i tap all'app tramite il `Stream<NotificationTap>` esposto da `onNotificationTap`, cosi' la navigazione puo' reagire centralizzando la logica.  
- `updateBadgeCount` sfrutta `flutter_app_badger` per sincronizzare il badge su iOS/macOS e sui launcher Android compatibili; sugli altri target la chiamata viene ignorata.
- `FirebaseInAppMessaging.instance` viene configurato all'avvio (solo Android/iOS) per consentire la visualizzazione automatica delle campagne create in console.

## Bootstrap e provider
- In `lib/main.dart` inizializziamo `WidgetsFlutterBinding`, creiamo il `NotificationService` e invochiamo `Firebase.initializeApp()` (usando la configurazione auto-caricata dai file `google-services.json` / `GoogleService-Info.plist`). Se dovesse servire una configurazione esplicita, possiamo importare `lib/firebase_options.dart` e passare `DefaultFirebaseOptions.currentPlatform`.  
- Dopo l'inizializzazione Firebase attiviamo `FirebaseMessaging` (`setAutoInitEnabled`, opzioni di presentazione iOS e handler background `_firebaseMessagingBackgroundHandler`) e solo successivamente `await notificationService.init()`, cosi' i canali sono pronti prima del `runApp`. Registriamo anche l'observer per `FirebaseMessaging.onMessageOpenedApp` e, alla prima frame utile, pubblichiamo l'eventuale `getInitialMessage()` per non perdere i tap arrivati con app chiusa.  
- In `ProviderScope` overrideiamo `notificationServiceProvider` definito in `lib/app/providers.dart`, che altrimenti lancia intenzionalmente un `UnimplementedError` per evitare l'uso senza inizializzazione.  
- Il provider espone anche `notificationTapStreamProvider` e `clientDashboardIntentProvider` per propagare gli eventi di tap e puntare la tab corretta nell'UI.
- `firebaseInAppMessagingProvider` espone l'istanza condivisa di `FirebaseInAppMessaging`, utile per sopprimere o riattivare i messaggi in base allo stato dell'app.

## Navigazione e gestione tap
- `lib/presentation/branding/widgets/branded_app_shell.dart` ascolta `notificationTapStreamProvider`: quando l'utente loggato e' un cliente, pubblichiamo un `ClientDashboardIntent` con `tabIndex = 4` (tab Notifiche) e navighiamo verso `/client`.  
- `NotificationService.handleMessageInteraction(RemoteMessage)` normalizza badge/count e inoltra il payload nel medesimo stream dei tap locali, cosi' l'app reagisce in modo uniforme a foreground/backgound/terminated.
- I dati presenti nel `payload` (es. `type`, `messageId`, `appointmentId`) vengono mantenuti e possono essere usati nel tab notifiche per deep-link o azioni contestuali.

## Foreground messaging
- `_listenForegroundMessages` in `lib/presentation/screens/client/client_dashboard_screen.dart` e' registrato al primo `initState`: ascolta `FirebaseMessaging.onMessage`, costruisce titolo/corpo a partire da `RemoteNotification` o `message.data` e genera un `payload` unendo tutti i campi `data` con l'eventuale `messageId`.  
- Se il backend invia il conteggio non letti (`badge` o `unreadCount`) lo convertiamo in intero e chiamiamo `notificationService.updateBadgeCount(...)`.  
- Generiamo un `id` numerico a 31 bit e invochiamo `notificationService.show(...)` per riflettere in locale la stessa notifica ricevuta in foreground; in caso d'errore facciamo fallback a uno `SnackBar` per non perdere l'informazione.

## Notifiche manuali di debug
- In `MessagesModule` (dashboard admin) e' presente la card "Notifiche manuali": consente di cercare clienti del salone corrente, selezionarne piu' di uno e spedire un push ad-hoc indicando titolo e testo.  
- Il client invoca la callable `sendManualPushNotification` (Firebase Functions) che valida ruolo/salone, filtra i clienti senza preferenze push o token e invia direttamente via FCM, rimuovendo i token invalidi.  
- Il payload include `type = manual_notification`, `messageId`, `salonId`, `clientId`, `title`, `body` e `sentAt`, cosi' la UI lato client riesce a visualizzare i tap come per i reminder automatici.
- La card propone un messaggio di esempio e offre il pulsante "Anteprima in-app", che scatena l'evento `manual_notification_preview` su `FirebaseInAppMessaging`: basta collegare una campagna alla stessa key per visualizzare un messaggio di prova sul dispositivo (solo Android/iOS).
- Ogni invio manuale genera anche una riga in `message_outbox` con stato `sent`, così il tab Notifiche del cliente mostra lo storico completo delle comunicazioni manuali.

## Notifiche slot last-minute
- Durante la creazione o modifica di uno slot express (`ExpressSlotSheet`) l'admin può decidere se inviare subito una push ai clienti, scegliendo tra invio a tutto il salone oppure destinatari selezionati manualmente.  
- La preferenza predefinita per salone è configurabile dalla card `Promemoria appuntamenti` in `MessagesModule` (`ReminderSettings.lastMinuteNotificationAudience`).  
- Il client invoca la callable `notifyLastMinuteSlot` che valida ruolo/salone, carica lo slot, genera il titolo/body (`Last-minute: {servizio}` + orario/prezzo/posti) e spedisce la push via FCM con payload `type = last_minute_slot`, `slotId`, `startAt`, `priceNow`, `discountPct`, `availableSeats`.  
- Ogni invio registra l'esito in `/message_outbox` (`source = notify_last_minute_slot`, conteggio success/failure/invalid) e ripulisce i token non validi come per le notifiche manuali.

## Backend FCM
- `functions/src/messaging/channels/push.ts` attualmente invia `title`, `body`, `type` e un `dataPayload` con ID messaggio, salone, template e metadati (appointment, offset).  
- Manca ancora l'arricchimento con `android.notification.channelId`, badge/sound e un `data.deepLink` coerente con il protocollo app: possiamo estendere l'oggetto passato a `sendEachForMulticast` per includere questi campi e sfruttare appieno `NotificationService`.  
- Quando il backend iniziera' a inviare badge numerici, assicurarsi che siano stringhe o interi parsabili, cosi' il frontend aggiorna il contatore correttamente.

## Badge nell'UI cliente
- Nel drawer client le voci `Punti fedeltà`, `Pacchetti`, `Preventivi`, `Fatturazione` e `Le mie foto` mostrano un badge numerico ogni volta che arrivano nuovi contenuti; il contatore si azzera automaticamente appena l'utente apre la relativa scheda.  
- L'icona rapida per le notifiche si sposta nell'angolo in alto a destra della top bar, in modo da restare sempre visibile anche quando la bottom navigation è nascosta.  
- Lo slot precedentemente occupato dall'icona ora mostra un placeholder "Info salone" che aprirà la futura pagina con i dettagli del salone attivo; per il momento funge solo da indicatore statico.  
- Se nel drawer sono presenti badge attivi, l'icona hamburger sulla top bar espone un indicatore senza contatore per richiamare l'attenzione.  
- Le destinazioni `Agenda` e `Notifiche` della bottom navigation usano la stessa logica incrementale: il badge visualizza solo gli elementi non ancora aperti e sparisce quando la tab viene visitata.
- L'apertura della tab Notifiche segna automaticamente tutte le notifiche come lette lato client senza aggiornare il campo `readAt` in Firestore.

## Prossimi passi suggeriti
1. Tracciare con Analytics il funnel specifico delle notifiche last-minute (`tap`, apertura sheet, checkout completato) per misurare il tasso di conversione.
