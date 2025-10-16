# CLIENTE – NUOVA UI

## Obiettivo

Aggiornare completamente l’interfaccia lato **cliente** dell’app CiviApp, rendendola piu' intuitiva, moderna e coerente con la logica di navigazione principale (Bottom Navigation Bar).  
L’obiettivo e' permettere all’utente finale di gestire in autonomia i propri appuntamenti, le prenotazioni, il carrello e le notifiche, con un accesso rapido ai contenuti promozionali e ai pacchetti.

---

## 1️⃣ Bottom Navigation Bar

La barra inferiore deve includere le seguenti sezioni, in ordine:

1. **Home**  
2. **Appuntamenti**  
3. **Prenota**  
4. **Carrello**  
5. **Saloni**

Ogni tab deve essere rappresentata da un’icona coerente con il design system del progetto (Material Icons o Cupertino Icons, in base alla piattaforma).

---

## 2️⃣ Home

La **Home Page** deve fungere da dashboard principale per il cliente, con i seguenti elementi:

- **Appuntamento imminente:** mostra data, ora, servizio e operatore del prossimo appuntamento confermato.  
  - Se non ci sono appuntamenti imminenti, mostra un messaggio tipo “Nessun appuntamento in programma” e un pulsante “Prenota ora” *disattivo/placeholder* (non FAB).  

- **Last Minute:** mostra una sezione con eventuali offerte last minute (recuperate da Firestore → `salonId/lastminute`).  

- **Promozioni:** mostra card orizzontali con titolo, descrizione breve, e pulsante “Scopri di piu'”.  

- **Pacchetti:** visualizza i pacchetti acquistabili.  

🔹 **Nota:** eliminare completamente il **FloatingActionButton “Prenota ora”** attualmente presente nella home.

---

## 3️⃣ Appuntamenti

La sezione **Appuntamenti** deve includere due tab:

- **Prossimi Appuntamenti**  
  Elenco cronologico degli appuntamenti futuri con stato (confermato, in attesa, annullato).  
  Ogni card mostra:  
  - Data e ora  
  - Nome del servizio  
  - Nome operatore  
  - Pulsanti “Modifica” e “Annulla” se applicabili  

- **Storico Appuntamenti**  
  Elenco appuntamenti passati, con possibilita' di rivedere dettagli.  

🔹 **Da rimuovere:**  
- Bottone “Prenota Appuntamenti”  
- FAB “Prenota ora”

---

## 4️⃣ Prenota

Aggiornare completamente il **flow di prenotazione** per renderlo lineare e visivamente coerente con il design lato admin.

**Flow aggiornato:**
1. Scelta della categoria
2. Scelta del servizio  
3. Scelta dell’operatore (solo quelli disponibili)  
4. Scelta dello slot orario (solo slot liberi, escludendo ferie, permessi, malattie, pause pranzo — vedi vincoli in `prenotazione_cliente.txt`)  
5. Riepilogo finale → Conferma prenotazione  

**UI suggerita:**
- Stepper orizzontale (tipo Material Stepper o Custom Step Progress Bar)
- Card per i servizi e operatori con immagini, nomi e durata
- Calendar picker o list view per gli slot disponibili

---

## 5️⃣ Carrello

La sezione **Carrello** mostra tutti i servizi e pacchetti selezionati non ancora confermati.

**Contenuti:**
- Lista prodotti/servizi con nome, quantita' e prezzo  
- Totale aggiornato dinamicamente  
- Pulsante “Procedi al pagamento” → checkout nativo o Stripe  
- Pulsante “Svuota carrello”  

**Design:**  
- Stile coerente con l’e-commerce moderno  
- Nessun FAB  
- Eventuale animazione e badge numerico sulla tab "Carrello" quando ci sono elementi.
- Eventuale animazione e badge numerico sulla tab "Notifiche" quando ci sono elementi.

---

## 6️⃣ Saloni

La tab **Saloni** mostra la scheda del salone attivo con carte dedicate a descrizione, contatti, posizione, orari e canali social. Tutti i link sono tappabili e aprono le app esterne (telefono, email, mappe, browser) con il contenuto configurato dall'amministratore.

Gestione contenuti lato admin:
- In `Saloni → Modifica salone` è possibile compilare descrizione, contatti e coordinate.
- La stessa schermata consente di aggiungere uno o più canali social indicando nome e URL (es. Instagram, Facebook, TikTok).
- L'indirizzo e le coordinate alimentano il link rapido a Google Maps nella scheda cliente.
- I social configurati vengono mostrati nella tab cliente con l'icona appropriata e apertura in app/browser.

---

## 7️⃣ Barra Laterale (Drawer)

Aggiornare la **barra laterale cliente** come segue:

- Rimuovere voce “Notifiche” (spostata nella Bottom Bar)  
- Aggiungere:
  - **Punti Fedelta':** visualizza i punti accumulati e lo storico utilizzi.  
  - **Pacchetti:** accesso rapido ai pacchetti acquistati o attivi.  
  - **Logout** (in fondo al drawer)

---

## 8️⃣ Considerazioni Tecniche

- Framework: Flutter (Material 3)
- State Management: Riverpod
- Routing: GoRouter
- Database: Firebase Firestore  
- Notifiche: Firebase Messaging + Local Notifications  
- Target SDK: Android 35 / iOS 16  
- Mantenere stile visivo coerente con il lato admin

---

## 9️⃣ Prossimi Step (per Codex)

1. Aggiornare la `BottomNavigationBar` con le nuove pagine.  
2. Implementare i nuovi widget `HomeClientePage`, `AppuntamentiClientePage`, `PrenotaClientePage`, `CarrelloPage`, `NotifichePage`.  
3. Eliminare i FAB non piu' previsti.  
4. Aggiornare la grafica e logica del flusso di prenotazione.  
5. Integrare i nuovi moduli nel `drawer_cliente`.  
