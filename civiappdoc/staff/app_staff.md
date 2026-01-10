Dobbiamo creare l'app relativa allo staff. Quando faccio il login con un'utenza che ha come ruolo staff voglio vedere un'app con due sezioni principali:
- Dashboard (vediamo i prossimi appuntamenti e il cliente dell'appuntamento).
- Ferie e permessi: in questa pagina l'utente staff potra inviare una richiesta di ferie (permesso, malattia) che dovra essere approvata dall'admin.

Al momento non abbiamo questo processo di richiesta (lato staff) delle ferie e/o permessi, e accettazione da parte dell'admin. Quindi dobbiamo implementarlo.
Inoltre l'utente staff puo vedere la scheda cliente completamente ma non puo modificare o inserire niente.

Requisiti dettagliati

1) Ruoli e permessi
- Staff: accesso a Dashboard, Ferie e permessi, Scheda cliente in sola lettura.
- Admin: approva o rifiuta le richieste; puo aggiungere note o motivazioni.
- Clienti: nessun accesso all'app staff.

2) Navigazione e struttura
- Bottom navigation con 2 voci: Dashboard, Ferie e permessi.
- Accesso alla scheda cliente dalla lista appuntamenti (tap sull'appuntamento).

3) Dashboard
Obiettivo: mostrare rapidamente i prossimi appuntamenti.
- Lista dei prossimi appuntamenti (ordinati per data e ora).
- Ogni card mostra: data/ora, servizio, cliente (nome e cognome), stato appuntamento.
- Stati possibili: confermato, da confermare, annullato, completato.
- Filtri rapidi: oggi, domani, prossimi 7 giorni.
- Stato vuoto: messaggio chiaro e call to action "Nessun appuntamento in programma".

4) Scheda cliente (sola lettura)
Obiettivo: consultare tutte le informazioni senza modificarle, con una vista iniziale compatta.
- Primo blocco (subito visibile): dati essenziali (nome, telefono, email), pacchetti attivi, note.
- Secondo blocco: prossimi appuntamenti in lista compatta (data/ora, servizio, stato).
- Sezioni espandibili per storico e dettagli aggiuntivi.
- Nessun pulsante di modifica o creazione.


5) Ferie e permessi
Obiettivo: inviare richieste e monitorare lo stato.
- Lista richieste inviate con stato: in attesa, approvata, rifiutata, annullata.
- Pulsante "Nuova richiesta".
- Form richiesta:
  - Tipo: ferie, permesso, malattia.
  - Data inizio, data fine (obbligatorie).
  - Note/motivazione (opzionale, ma utile).
  - Allegato (opzionale, ad esempio certificato).
- Validazioni: data fine >= data inizio, campi obbligatori compilati.
- Invio: mostra conferma e stato "in attesa".

6) Flusso approvazione admin
- Dove approva: nel modulo staff, all'interno della card del membro staff compare una notifica "Richiesta in attesa".
- Dalla card l'admin apre il dettaglio richiesta e puo approvare o rifiutare con motivazione.
- Lo staff riceve notifica dell'esito.

7) Stati e feedback UI
- Loading: skeleton o spinner per liste e dettagli.
- Errori: messaggi chiari con retry.
- Successo: toast/alert con conferma operazione.

8) Dati minimi da modellare
- Richiesta ferie/permesso:
  - id, staffId, tipo, dataInizio, dataFine, note, allegatoUrl, stato, creatoIl, aggiornatoIl, motivazioneAdmin.
- Appuntamento:
  - id, dataOra, servizio, clienteId, stato, note.
- Cliente:
  - id, nome, cognome, telefono, email, note.

9) Requisiti UI/UX
- UI intuitiva e veloce, ottimizzata per mobile.
- Tipografia leggibile, card compatte, CTA ben visibile.
- Gestione offline base: mostra ultimo stato noto e avvisa se non connesso.

10) Scope MVP
- Dashboard con lista appuntamenti e accesso scheda cliente (read-only).
- Richiesta ferie/permessi con invio e lista stati.
- Workflow approvazione lato admin (minimo: approva/rifiuta).

11) Fuori scope per ora
- Modifica dei dati cliente da parte dello staff.
- Gestione turni o calendario avanzato.
- Chat interna o messaggistica con l'admin.
