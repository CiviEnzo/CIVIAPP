# Modulo Vendita

## Aggiornamento richiesto

### Card da rimuovere
- Eliminare la card **Ticket aperti** dal riepilogo superiore del modulo Vendita.

### Card Vendite
- Deve mostrare il **numero di scontrini del giorno selezionato**.
- Il conteggio deve aggiornarsi quando cambia la data selezionata nella sezione vendite concluse.

### Card Incasso
- Deve mostrare il **totale incasso del giorno selezionato**.
- Il valore deve essere calcolato sulle **entrate registrate** del giorno selezionato.
- Per i ticket, il totale deve seguire la **data del ticket / data del movimento** (non la data di chiusura del ticket).

### Card Pacchetti venduti
- Aggiungere una card **Pacchetti venduti** nel riepilogo superiore.
- Deve mostrare il **totale importo dei pacchetti venduti** nel giorno selezionato.
- Deve mostrare anche il **totale dei pacchetti venduti** (quantità) nel giorno selezionato.
- Il calcolo deve considerare solo le righe vendita di tipo **pacchetto**.

## Risultato atteso (Vendita)
- Le card riepilogative del modulo Vendita devono riflettere la data selezionata dall'utente: `Vendite` (scontrini del giorno), `Incasso` (totale incasso del giorno, con data ticket/movimento) e `Pacchetti venduti` (importo + quantità dei pacchetti del giorno). La card `Ticket aperti` deve essere rimossa dal riepilogo.
