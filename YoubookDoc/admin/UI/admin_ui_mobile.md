# Roadmap UI Admin (mobile-first)

## Obiettivi
- Ottimizzare l’admin per iPhone, iPad e Android con layout adattivi e touch-friendly.
- Ridurre la complessità della vista agenda a sola visione giornaliera, massimizzando lo spazio utile.
- Aggiornare tutti gli sheet (bottom sheet/modal) per garantire usabilità su mobile, con CTA sempre raggiungibili.
- Creare una libreria di widget ad hoc per velocizzare sviluppo e coerenza visuale.

## Principi guida
- Single-focus per schermata: una decisione per volta, no overload di informazioni.
- Gerarchie chiare: header compatti, contenuto principale in primo piano, azioni primarie fisse in basso.
- Gesture e tap target >44px; drag & drop solo se essenziale.
- Layout adattivi: breakpoint principali 360-480 (phone), 768-1024 (tablet); uso di colonne fluide su iPad/Android tablet.
- Performance: evitare liste annidate complesse; lazy loading su feed e agenda.

## Libreria widget ad hoc
- AppBar compatta con titolo + action primaria (icona) + filtro secondario in overflow.
- Card riassunto (stat/alert) con layout 2x2 su phone e 3x2 su tablet.
- Lista appuntamenti con pillole stato (confermato, in attesa, no-show) e azioni rapide a swipe.
- Timeline agenda giornaliera: slot da 15/30 minuti, righe alternate leggere, sticky header con data e controlli giorno ±.
- BottomSheet adattivo: altezze 60/75/90%, toolbar superiore con handle + chiudi, CTA primaria sticky in basso.
- Form controls mobile: input grandi, selettori orario a tappable chips, autocompletamento clienti/servizi.
- Banner di esito (success/warning/error) a comparsa in alto con auto-dismiss.

## Aggiornamenti per area
- Home admin: cards KPI, alert operativi (es. no-show oggi), quick actions per aggiungere appuntamento/cliente.
- Agenda (giornaliera): timeline verticale full height, cambio giorno con swipe/arrow, filtro collaboratore/servizio, indicatore “ora corrente”.
- Appuntamenti: elenco compatto con status, ricerca veloce per cliente, azioni rapide (chiama, messaggia, ripianifica).
- Clienti: scheda compatta con foto, note rapide, storico visite; bottom sheet per aggiunta rapida.
- Servizi/risorse: liste con tag durata e prezzo, toggle disponibilità; su tablet, doppia colonna lista+detail.
- Notifiche/alert: centro notifiche leggero con raggruppamento per giorno.

## Roadmap di lavoro
1) Fondamenta UI
   - Definire design tokens mobile (spaziature, radius, tipografia compatta) e palette scura/chiara coerente con il brand.
   - Creare layout grid e breakpoints per phone/tablet; verificare notch/safe area.
2) Widget library
   - Implementare i widget ad hoc elencati (AppBar compatta, card KPI, timeline agenda, bottom sheet, CTA sticky).
   - Documentare esempi d’uso e varianti per phone vs tablet.
3) Aggiornamento schermate
   - Agenda: migrare a vista giornaliera, integrare timeline e filtri; ottimizzare scroll e sticky header.
   - Appuntamenti/Clienti/Servizi: rimpiazzare componenti generici con i nuovi widget; semplificare i form per mobile.
   - Sheet/modal: uniformare altezza, handle, CTA sticky, gestione tastiera e scroll.
4) QA e ottimizzazioni
   - Test responsive su iPhone (small/large), iPad (portrait/landscape) e Android (phone/tablet).
   - Verifica accessibilità (contrast, focus, reader), performance di scroll e comportamenti offline/base.

## Decisioni aperte
- Selezionare la tipografia di sistema o custom (per coerenza con il brand) mantenendo leggibilità su phone.
- Definire soglia di densità per la timeline (15 vs 30 minuti) in base al carico medio del salone.
- Stabilire se introdurre quick actions persistenti (FAB/toolbar inferiore) o usare solo CTA sticky negli sheet.
