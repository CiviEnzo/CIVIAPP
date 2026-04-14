# Archivio fotografico - nuove funzionalita

## Set fotografici predefiniti

- Obiettivo: organizzare gli scatti di ogni visita in quattro set standard (Frontale, Dietro, Destra, Sinistra) per una consultazione piu rapida.
- Creazione automatica: alla creazione di un nuovo archivio cliente generare i quattro slot vuoti, ciascuno con anteprima, data ultimo aggiornamento e contatore delle versioni salvate.
- Caricamento: consentire l upload diretto nel set scelto (drag and drop o selezione da galleria), con validazioni su formato, dimensione e meta-dati (es. data scatto).
- Versioning: mantenere la cronologia degli scatti per set; mostrare l anteprima della versione attiva e permettere il rollback rapido alle versioni precedenti.
- Stato di completamento: evidenziare i set mancanti (badge grigio) e quelli completati (badge verde) per aiutare il personale a capire se servono foto aggiuntive.

## Funzione "Crea Collage"

- Accesso: pulsante "Crea Collage" visibile nell archivio cliente; apre un editor full width con elenco delle foto disponibili organizzate per set.
- Selezione foto: permettere la scelta di due immagini anche dallo stesso set; evidenziare quali sono gia selezionate e prevedere un filtro rapido per data/set.
- Orientamento collage: toggle per passare da layout verticale (foto affiancate in colonna) a layout orizzontale (affiancate in riga); salvare l impostazione insieme al collage.
- Strumenti di posizionamento: per ogni foto abilitare pan, zoom continuo con step predefiniti e rotazione libera (con snap a 0, 90, 180, 270 per riallineare velocemente).
- Sovrapposizioni: mostrare griglie e linee guida attivabili per allineare i punti di riferimento tra le due immagini.
- Salvataggio: consentire di salvare il collage come nuovo asset (thumbnail + meta informazioni) e collegarlo al cliente; registrare autore, data e foto di origine.
- Condivisione: prevedere download in formato immagine o PDF con entrambi i layout, e integrazione con eventuali report clinici esportati.

## Considerazioni UX e tecniche

- Ottimizzare le prestazioni caricando in lazy le anteprime e sfruttando cache locale per switch rapidi tra set e collage.
- L editor collage deve essere responsive: su tablet usare layout split, su desktop due pannelli con anteprima grande; su mobile limitarsi a funzioni base e rimandare all app desktop.
- Loggare tutte le operazioni di upload, modifica e salvataggio per audit trail e per ripristino in caso di errori.
