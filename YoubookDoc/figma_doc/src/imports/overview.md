# Modulo Overview (Panoramica)

## Aggiornamento richiesto

### Card Appuntamenti
- Deve mostrare **solo** gli appuntamenti con stato **Programmato**.
- Escludere dal conteggio gli appuntamenti con stati diversi (es. completato, annullato, no-show).

### Card Pacchetti
- Deve mostrare il **totale dei pacchetti attivi assegnati ai clienti**.
- Non deve mostrare il totale del catalogo pacchetti/servizi disponibili.

### Card Totale scontrini
- Deve mostrare il **totale degli scontrini dell'anno corrente**.
- Il conteggio va calcolato sugli scontrini/vendite registrati nel solo anno in corso.

### Card Incasso anno in corso
- Deve mostrare l'**incasso totale dell'anno corrente**.
- Il valore va calcolato come somma degli importi degli scontrini/vendite registrati nel solo anno in corso.
- Nella card devono essere visibili anche **2 righe di dettaglio**:
- **Totale servizi venduti**
- **Totale pacchetti venduti**
- Nei due subtotali (**servizi** e **pacchetti**) **non** devono essere considerati gli importi coperti da **punti fedeltà**.

### Card Incasso Posticipato
- Deve mostrare il totale dell'**incasso posticipato**.
- Il valore va calcolato come somma dei **residui da incassare** delle vendite con stato pagamento **Posticipato**.
- Deve includere anche le vendite con stato **Acconto** che hanno un **residuo da saldare**.
- **Al click** deve aprire una **modale** con la lista dei clienti che devono pagare.
- La modale deve aprirsi **centrata a schermo** (non come pannello dal basso).
- Nella modale, il **nome cliente** deve essere un **hyperlink** cliccabile verso la scheda cliente.
- L'hyperlink del nome cliente deve aprire direttamente il tab **Fatturazione** della scheda cliente.

### Card Punti
- Deve mostrare il **totale punti clienti**.
- Il valore rappresenta il **saldo punti fedeltà complessivo** dei clienti del salone.
- Deve **sempre distinguere** i **punti assegnati** dai **punti usati** (es. nel sottotitolo o dettaglio della card).

### Card da rimuovere
- **Card Staff**: eliminare dalla Panoramica.
- **Card Servizi**: eliminare dalla Panoramica.
- **Card Incasso oggi**: eliminare dalla Panoramica.

### Interazioni card (modali)
- **Card Pacchetti attivi clienti**: al click apre una **modale** con la lista dei clienti che hanno pacchetti attivi.
- La modale deve aprirsi **centrata a schermo** (non dal basso).
- Nella modale pacchetti, il **nome cliente** deve essere un **hyperlink** cliccabile verso la scheda cliente.

## Risultato atteso (Panoramica)
- La dashboard Overview deve riflettere solo le card necessarie, con metrica Appuntamenti filtrata su `Programmato`, metrica Pacchetti basata sui pacchetti attivi dei clienti (con modale lista clienti), card `Totale scontrini` e `Incasso anno in corso` calcolate sull'anno corrente, card `Incasso Posticipato` calcolata sui residui delle vendite **posticipate e in acconto** con saldo aperto (con modale lista clienti da saldare) e card `Punti` basata sul saldo punti fedeltà totale dei clienti con distinzione esplicita tra punti assegnati e usati.
