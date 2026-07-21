# Miglioramenti da feedback Tester Community

Fonte analizzata: `YoubookDoc/rateapp/com.cividevops.civiapp_feedback.pdf`

## Sintesi

Il report non evidenzia crash, bug critici o funzionalita rotte. I tester indicano che l'app ha funzionato bene sui dispositivi e SDK provati.

Le attivita richieste riguardano soprattutto:

- migliorare la visibilita su Google Play tramite ASO;
- aggiungere onboarding/walkthrough dinamico per i nuovi utenti;
- aggiungere un flusso corretto per lasciare recensioni;
- aumentare engagement, retention, notifiche, monitoraggio e raccolta feedback.

Nota importante: il PDF suggerisce anche incentivi per le recensioni. Questa parte non va implementata cosi com'e: Google Play vieta recensioni o rating incentivati. Eventuali sconti o reward devono essere scollegati dal lasciare una recensione o una valutazione.

## P0 - Compliance recensioni Google Play

- [ ] Non implementare incentivi in cambio di rating o recensioni.
- [ ] Non chiedere agli utenti se apprezzano l'app prima di mostrare il prompt di rating.
- [ ] Non chiedere valutazioni positive o "5 stelle".
- [x] Se viene aggiunto un pulsante manuale "Valuta l'app" nelle impostazioni, deve aprire direttamente la pagina Play Store dell'app, non forzare il dialog In-App Review.
- [ ] Se viene usato il dialog In-App Review, mostrarlo solo in momenti contestuali e non da un bottone diretto.

Criteri di accettazione:

- [ ] Nessun testo o flusso promette sconti, coupon, vantaggi o bonus in cambio di una recensione.
- [x] Il pulsante nelle impostazioni apre `market://details?id=com.cividevops.civiapp` con fallback web a `https://play.google.com/store/apps/details?id=com.cividevops.civiapp`.
- [ ] Il prompt automatico di review e limitato da logica interna di frequenza e non viene mostrato ripetutamente.

## P1 - ASO Play Store

Problema dal PDF: la descrizione attuale sarebbe troppo povera di testo e keyword rilevanti, riducendo la visibilita nelle ricerche.

Da fare:

- [ ] Raccogliere keyword reali per il posizionamento di You Book.
- [ ] Verificare il dominio corretto dell'app: nel PDF si parla di "beauty salons" e "salon management"; confermare che sia ancora il target reale prima di scrivere copy e keyword.
- [ ] Riscrivere la descrizione breve Play Store evidenziando il beneficio principale dell'app.
- [ ] Riscrivere la descrizione lunga Play Store con keyword organiche, senza keyword stuffing.
- [ ] Evidenziare benefici utente e funzionalita chiave: prenotazioni, gestione profilo, esperienza cliente, eventuali saloni/servizi se pertinenti.
- [ ] Aggiornare eventuali screenshot/caption Play Store per mostrare i flussi principali.
- [ ] Preparare varianti localizzate almeno per italiano e inglese, se l'app e distribuita in piu mercati.
- [ ] Definire metriche di verifica: impression, conversion rate listing -> install, keyword ranking, store listing visitors.

Criteri di accettazione:

- [ ] Nuova descrizione breve pronta per Play Console.
- [ ] Nuova descrizione lunga pronta per Play Console.
- [ ] Keyword principali documentate.
- [ ] Copy coerente con il prodotto reale, non solo con il testo generico del report.

## P1 - Walkthrough dinamico per nuovi utenti

Problema dal PDF: manca un tutorial/onboarding dinamico, con rischio di confusione e abbandono iniziale.

Da fare:

- [ ] Progettare un onboarding al primo avvio, skippabile.
- [ ] Mostrare il walkthrough solo ai nuovi utenti o dopo update importanti, salvando lo stato di completamento.
- [ ] Guidare l'utente nei flussi principali: creazione/completamento profilo, prenotazione, uso delle funzioni chiave.
- [ ] Aggiungere tooltip o overlay highlight sulle azioni principali.
- [ ] Evitare testi lunghi: ogni step deve avere titolo breve, azione chiara e pulsanti `Avanti`, `Salta`, `Fine`.
- [ ] Gestire il caso utente gia registrato/login gia completato, evitando step inutili.
- [ ] Aggiungere tracking eventi: `onboarding_started`, `onboarding_step_viewed`, `onboarding_completed`, `onboarding_skipped`.
- [ ] Prevedere accesso manuale al walkthrough da impostazioni/help.

Criteri di accettazione:

- [ ] Nuovo utente vede il walkthrough una sola volta.
- [ ] Utente puo saltare il walkthrough senza blocchi.
- [ ] Gli step puntano a schermate/funzionalita reali.
- [ ] Lo stato resta persistito dopo chiusura e riapertura app.

## P1 - Help center / supporto utente

Problema dal PDF: il walkthrough dovrebbe essere affiancato da accesso facile a FAQ o tutorial.

Da fare:

- [ ] Aggiungere voce "Aiuto" o "Centro assistenza" nelle impostazioni/profilo.
- [ ] Inserire FAQ sui flussi principali: account, profilo, prenotazioni, notifiche, recensioni, contatto supporto.
- [ ] Valutare tutorial video o brevi guide visuali solo dove realmente utili.
- [ ] Collegare il centro assistenza anche dal walkthrough.
- [ ] Aggiungere contatto supporto o form interno per richieste.

Criteri di accettazione:

- [ ] L'utente trova l'aiuto in massimo 2 tap dalle impostazioni/profilo.
- [ ] Le FAQ coprono i problemi piu probabili del primo utilizzo.
- [ ] Esiste un modo chiaro per contattare il supporto.

## P1 - Pulsante "Valuta l'app"

Problema dal PDF: manca un pulsante per lasciare rating/recensione, occasione persa per feedback e reputazione Play Store.

Da fare:

- [x] Aggiungere in impostazioni una voce `Valuta l'app`.
- [x] Aprire la scheda Play Store dell'app con schema `market://` e fallback HTTPS.
- [x] Gestire errore se Play Store non e disponibile.
- [x] Aggiungere tracking evento `rate_app_tapped`.
- [ ] Per prompt automatici, usare In-App Review solo dopo interazioni positive, per esempio prenotazione completata o servizio concluso.
- [ ] Applicare throttle locale/remoto: non mostrare prompt troppo spesso, non mostrare su primo avvio, non mostrare dopo skip recente.
- [ ] Non collegare premi, sconti o vantaggi al lasciare una recensione.

Criteri di accettazione:

- [ ] Il pulsante manuale funziona su Android reale con Play Store installato.
- [x] Esiste fallback web.
- [ ] Il prompt automatico non appare in loop.
- [ ] Nessun incentivo e associato alla recensione.

## P2 - Client engagement e retention

Raccomandazione dal PDF: valutare funzioni di engagement come loyalty program o referral bonus.

Da fare:

- [ ] Definire se il modello di business supporta loyalty/referral.
- [ ] Disegnare regole antifrode per referral e reward.
- [ ] Valutare una raccolta punti o vantaggi legati ad azioni reali nell'app, non alle recensioni.
- [ ] Aggiungere storico reward/benefici per l'utente, se il programma viene implementato.
- [ ] Tracciare metriche: utenti invitati, conversioni referral, retention D7/D30, uso reward.

Criteri di accettazione:

- [ ] Regole reward documentate prima dello sviluppo.
- [ ] Nessun reward viola policy recensioni o store.
- [ ] Eventi analytics disponibili per misurare l'effetto sulla retention.

## P2 - Monitoraggio performance e funnel

Raccomandazione dal PDF: analizzare regolarmente metriche di engagement per capire dove gli utenti abbandonano.

Da fare:

- [x] Verificare strumenti gia presenti: Firebase Analytics, Crashlytics, Performance Monitoring o alternative.
- [ ] Definire funnel minimo: installazione, primo avvio, login/registrazione, completamento profilo, inizio prenotazione, prenotazione completata, onboarding completato, apertura notifiche.
- [x] Aggiungere eventi analytics base per `rate_app_tapped`, `app_feedback_started`, `app_feedback_submitted` e screen tracking.
- [ ] Creare dashboard per drop-off onboarding e prenotazione.
- [ ] Monitorare crash-free users, tempi di avvio, errori API, schermate lente. Crashlytics e stato aggiunto; Performance Monitoring non ancora.
- [ ] Definire un controllo periodico dei dati, almeno settimanale nelle prime release dopo le modifiche.

Criteri di accettazione:

- [ ] Funnel principale visibile in analytics.
- [ ] Drop-off onboarding/prenotazione misurabile.
- [ ] Crash e performance sono consultabili per versione app.

## P2 - Notifiche push piu rilevanti

Raccomandazione dal PDF: rendere le notifiche personalizzate e utili.

Da fare:

- [ ] Mappare tutte le notifiche attuali e il loro scopo.
- [ ] Segmentare le notifiche per stato utente e comportamento, evitando messaggi generici.
- [ ] Aggiungere deep link alla schermata corretta quando una notifica viene aperta.
- [ ] Aggiungere preferenze notifiche, se non presenti.
- [ ] Evitare frequenza eccessiva e notifiche non azionabili.
- [ ] Tracciare delivery, open rate e conversione post-click.

Criteri di accettazione:

- [ ] Ogni notifica ha uno scopo chiaro.
- [ ] Tap sulla notifica apre il contesto corretto.
- [ ] L'utente puo gestire almeno le categorie principali di notifica.

## P2 - Feedback loop interno

Raccomandazione dal PDF: aggiungere un meccanismo per segnalare bug o suggerire feature direttamente dall'app.

Da fare:

- [x] Aggiungere voce `Segnala un problema` o `Invia feedback`.
- [x] Consentire categorie app: bug, suggerimento, usabilita, performance, account, altro.
- [x] Allegare automaticamente dati tecnici minimi: versione app, piattaforma, user id se disponibile, timestamp.
- [ ] Valutare allegato screenshot opzionale con consenso utente.
- [x] Salvare/inviare feedback verso canale gestibile dal team: Firestore, backend, email support, ticketing.
- [ ] Aggiungere stato interno per triage: nuovo, in analisi, risolto, scartato. Oggi viene creato lo stato iniziale `new`.

Criteri di accettazione:

- [x] Utente puo inviare feedback senza uscire dall'app.
- [x] Il team riceve dati sufficienti per riprodurre il problema.
- [x] Il flusso rispetta privacy e consenso per eventuali allegati.

## P3 - Integrazione social sharing

Raccomandazione dal PDF: permettere agli utenti di condividere esperienze o promuovere saloni/servizi preferiti.

Da fare:

- [ ] Verificare quali contenuti sono davvero condivisibili: profilo salone, servizio, prenotazione completata, esperienza.
- [ ] Implementare share sheet nativo, evitando permessi social non necessari.
- [ ] Preparare testo condiviso e link pubblico/deep link.
- [ ] Evitare condivisione automatica di dati personali o dettagli prenotazione.
- [ ] Tracciare evento `share_started` e, se possibile, `share_completed`.

Criteri di accettazione:

- [ ] L'utente sceglie volontariamente cosa condividere.
- [ ] Nessun dato sensibile viene incluso nel testo di default.
- [ ] Il link condiviso porta a una destinazione utile.

## Ordine consigliato di lavoro

1. Compliance recensioni e pulsante `Valuta l'app`.
2. ASO Play Store.
3. Walkthrough dinamico e help center.
4. Analytics/funnel per misurare onboarding, prenotazioni e retention.
5. Feedback loop interno.
6. Notifiche personalizzate.
7. Loyalty/referral.
8. Social sharing.

## Riferimenti utili

- Google Play policy rating/review/install: https://support.google.com/googleplay/android-developer/answer/9898684
- Google Play In-App Review API: https://developer.android.com/guide/playcore/in-app-review
