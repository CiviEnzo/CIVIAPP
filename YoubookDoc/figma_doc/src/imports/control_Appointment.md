# Refactor controllo appuntamenti (agenda amministrazione)

## Problemi osservati
- Drag & drop intermittente: preview che scompare o rimane “bloccata”, card che non risponde al tap finché si esce/rientra dal modulo.
- Concorrenza di gesture: tap-per-creare, long-press-drag e hover condividono lo stesso `State`, con rischi di arena sporca (PointerCancel/Up non gestiti).
- Auto-scroll e setState frequenti causano flicker e state leak quando il `RenderBox` non è pronto.

## Obiettivi del refactor
- Isolare lo stato delle interazioni (hover/drag/auto-scroll) in un controller dedicato, ricreato a ogni ingresso nel modulo.
- Separare i layer: grid per creazione slot, card per appuntamenti, overlay preview indipendente dal rebuild della colonna.
- Definire una macchina a stati chiara (`idle`, `hover`, `dragging`, `conflict`, `accepting`, `cancelled`) con transizioni esplicite e cleanup garantito.
- Ridurre il lavoro di `setState` nelle colonne: la UI deve solo osservare il controller.

## Architettura proposta
1. **AppointmentInteractionController** (ChangeNotifier/Riverpod):
   - Stato: `hoverSlot`, `dragPayload`, `previewRange`, `hasConflict`, flag `isDragging`, `lastOffset`.
   - API: `startDrag(payload)`, `updateDrag(offset)`, `finishDrag()`, `cancelDrag()`, `setHover(slot)` e `clearHover()`.
   - Gestisce auto-scroll centralizzato con coda di richieste e cancellazione.
2. **GridBackground**:
   - Widget separato che calcola gli slot liberi e gestisce tap-per-creare via hit test logico, non via `GestureDetector` globale.
   - Non partecipa al drag.
3. **AppointmentLayer**:
   - Card appuntamenti con `LongPressDraggable` configurato (`maxSimultaneousDrags: 1`, `dragDevices` coerente).
   - Callback di drag delegati al controller; il widget non modifica direttamente lo stato locale.
4. **PreviewOverlay**:
   - Overlay sopra la colonna che osserva il controller e disegna il “fantasmino” e gli highlight di conflict.
   - Nessun `setState` nella colonna per aggiornare il preview.
5. **State lifecycle**:
   - Reset dello stato in `initState`/`dispose` del modulo agenda e su cambio settimana/scope/staff.
   - Listener globale per `PointerUp/Cancel` sul container della colonna che invoca `finishDrag/cancelDrag`.

## Sequenza di implementazione
1) Introdurre `AppointmentInteractionController` e relative classi di stato (hover/drag).  
2) Rifattorizzare `DragTarget` e `LongPressDraggable` per usare solo il controller (niente `setState` locale per preview).  
3) Estrarre `GridBackground` e rimuovere il `GestureDetector` che avvolge tutta la colonna; tap-per-creare usa hit test sugli slot liberi.  
4) Creare `PreviewOverlay` separato che si sottoscrive al controller.  
5) Introdurre state machine e logging (solo debug) per tracciare transizioni e individuare eventuali buchi.  
6) Cleanup: rimuovere throttle/guardie ridondanti, sostituire auto-scroll con servizio nel controller.

## Note operative
- Mantenere compatibilità con tap singolo per edit; il drag può restare long-press. Se serve, prevedere flag per richiedere un modificatore (es. Alt) per evitare avvii involontari.
- Aggiungere test widget mirati: drag con auto-scroll, drag con conflitto, tap-per-creare sopra area vuota, cambio settimana con stato drag attivo (deve resettare).  
