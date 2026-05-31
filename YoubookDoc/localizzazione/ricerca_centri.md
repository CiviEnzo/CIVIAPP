# Ricerca centri lato cliente

## Obiettivo
Nella schermata cliente di scelta salone la lista deve mostrare prima i centri vicini al dispositivo, chiedendo il permesso di posizione quando serve. La ricerca manuale deve restare disponibile e deve permettere di trovare un centro solo per nome o numero di telefono anche quando la posizione non e' disponibile, negata o non ancora concessa.

## Analisi stato attuale
- La schermata interessata e' `lib/presentation/screens/client/client_salon_discovery_screen.dart`.
- Oggi `_searchController` aggiorna `_searchQuery` e `_matchesQuery()` filtra per nome, citta, indirizzo, email e telefono. Questo va ristretto: la ricerca cliente deve cercare solo per nome salone o numero di telefono.
- La lista viene presa da `data.discoverableSalons`; se vuota usa fallback su `data.salons.where((salon) => salon.isPublished).map(PublicSalon.fromSalon)`.
- I risultati vengono filtrati escludendo `SalonStatus.archived` e ordinati alfabeticamente per nome.
- I modelli sono gia' predisposti per la posizione:
  - `Salon` espone `latitude` e `longitude`.
  - `PublicSalon` espone `latitude` e `longitude`.
  - `firestore_mappers.dart` legge/scrive `latitude` e `longitude`.
  - i form admin `salon_form_sheet.dart` e `salon_profile_sheet.dart` permettono gia' di inserire coordinate manuali.
- La collection pubblica `public_salons` viene ascoltata in `AppDataStore` anche per il ruolo cliente, quindi la discovery puo' usare dati pubblici senza accedere a tutti i documenti `salons`.
- Non risultano dipendenze per geolocalizzazione nel `pubspec.yaml`.
- Mancano i permessi nativi:
  - Android: `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` non sono presenti in `android/app/src/main/AndroidManifest.xml`.
  - iOS: `NSLocationWhenInUseUsageDescription` non e' presente in `ios/Runner/Info.plist`.
- Non esiste ancora una logica di distanza, ordinamento per prossimita', stato permesso, CTA per usare la posizione o fallback quando le coordinate/indirizzo del salone sono assenti.
- I campi latitudine/longitudine sono oggi input manuali in `salon_form_sheet.dart` e `salon_profile_sheet.dart`; questo e' fragile per l'admin e va sostituito con geocoding automatico dall'indirizzo.

## Comportamento atteso
- All'apertura della schermata cliente:
  - se la ricerca manuale e' vuota, provare a ottenere la posizione utente dopo aver chiesto il permesso in modo contestuale;
  - mostrare solo i saloni pubblicati con indirizzo utile e coordinate valide, ordinati per distanza crescente;
  - mostrare distanza indicativa nella card/list item, per esempio `1,8 km`;
  - non mostrare nella lista iniziale/vicina i centri senza indirizzo o senza coordinate.
- Con ricerca manuale:
  - filtrare solo per nome salone o numero di telefono;
  - i centri senza indirizzo non devono apparire nella lista di prossimita', ma devono essere ricercabili tramite nome o telefono;
  - se la query non e' vuota, il criterio principale diventa la pertinenza testuale, non la sola distanza;
  - se piu' risultati matchano la query, ordinare prima per match sul nome, poi telefono, poi distanza quando disponibile, poi nome.
- Se il permesso posizione e' negato:
  - non bloccare la schermata;
  - mostrare una CTA discreta per abilitare la posizione dalle impostazioni o riprovare;
  - lasciare funzionante la ricerca per nome.
- Se il servizio di localizzazione del dispositivo e' spento:
  - mostrare stato informativo e CTA per attivarlo;
  - usare comunque ricerca manuale e ordinamento alfabetico.

## Regole di visibilita'
- Lista automatica "vicini a te":
  - include solo saloni pubblicati, non archiviati, con `address` non vuoto e coordinate valide;
  - esclude saloni senza indirizzo o senza coordinate, per evitare risultati non ordinabili o fuorvianti.
- Ricerca manuale:
  - include saloni pubblicati e non archiviati anche se senza indirizzo/coordinate;
  - cerca solo in `name` e `phone`;
  - non cerca per citta, indirizzo, email o altri contatti.
- Card risultato:
  - se il salone ha distanza disponibile, mostra la distanza;
  - se viene trovato via ricerca ma non ha indirizzo/coordinate, mostra un fallback tipo "Indirizzo non disponibile" senza distanza.

## Analisi inserimento automatico coordinate
Oggi l'admin deve compilare manualmente latitudine e longitudine. Per migliorare il flusso bisogna spostare il dato tecnico dietro un'azione automatica basata sull'indirizzo.

### Opzione consigliata: geocoding server-side
- Creare una Cloud Function callable/HTTPS, per esempio `geocodeSalonAddress`.
- Input: `salonId` oppure payload con `address`, `city`, `postalCode`, paese default `Italia`.
- La function chiama un provider geocoding esterno, ad esempio Google Maps Geocoding API o Google Places API.
- Output: `latitude`, `longitude`, `formattedAddress`, eventuale `placeId`, qualita' del match.
- Il client Flutter non espone API key sensibili: chiama solo la function.
- La function puo' applicare rate limit, logging, validazione e restrizioni per ruolo admin/staff autorizzato.
- Dopo conferma admin, salvare su `salons/{salonId}` e propagare il mirror `public_salons`.

Vantaggi:
- API key protetta;
- comportamento uniforme su iOS, Android e web;
- piu' facile gestire quote, errori e audit;
- possibile backfill automatico dei saloni gia' esistenti.

Svantaggi:
- richiede backend/function e configurazione provider;
- serve gestire costi/quote del servizio geocoding.

### Opzione alternativa: geocoding client-side
- Usare un package Flutter di geocoding oppure chiamare direttamente un endpoint provider dal client.
- Compilare latitudine/longitudine quando l'admin inserisce/modifica indirizzo.

Sconsigliata come prima scelta se richiede API key nel client. Accettabile solo se il provider e le restrizioni della chiave sono solide e se il backend non e' disponibile.

### UX admin proposta
- Nei form `salon_form_sheet.dart` e `salon_profile_sheet.dart`:
  - rendere latitudine/longitudine campi secondari o nascosti dietro "Dettagli tecnici";
  - aggiungere pulsante "Trova coordinate" vicino a indirizzo/citta/CAP;
  - quando indirizzo, citta o CAP cambiano, mostrare stato "Coordinate da aggiornare";
  - dopo il geocoding mostrare indirizzo normalizzato e coordinate in sola lettura;
  - permettere override manuale solo come azione avanzata, utile per correzioni puntuali.
- Se il provider restituisce piu' risultati:
  - mostrare una lista di candidati con indirizzo completo;
  - l'admin seleziona quello corretto;
  - salvare anche `googlePlaceId`/`placeId` quando disponibile.
- Se il geocoding fallisce:
  - non bloccare il salvataggio del salone;
  - mostrare warning "Coordinate non trovate: il centro non apparira' nella lista vicini finche' non vengono completate";
  - il salone resta ricercabile per nome o telefono se pubblicato.

### Dati consigliati
- Mantenere i campi esistenti `latitude` e `longitude`.
- Usare `googlePlaceId` come identificativo luogo quando il provider e' Google; oggi il campo esiste gia', ma la label "Link recensioni" lo rende ambiguo.
- Valutare di separare:
  - `googlePlaceId` per il luogo geocodificato;
  - `reviewLink` per il link recensioni, se serve davvero.
- Aggiungere opzionalmente metadata tecnici:
  - `geocodingStatus`: `missing`, `resolved`, `failed`, `manual`;
  - `geocodedAt`;
  - `formattedAddress`;
  - `geocodingProvider`.

## Checklist implementativa
- [ ] Aggiungere dipendenza Flutter per la posizione, preferibilmente `geolocator`, evitando una dipendenza separata per i permessi se il package copre richiesta e stato permesso.
- [ ] Aggiornare `android/app/src/main/AndroidManifest.xml` con `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`.
- [ ] Aggiornare `ios/Runner/Info.plist` con `NSLocationWhenInUseUsageDescription` usando un testo chiaro, es. "Usiamo la tua posizione per mostrarti i saloni piu' vicini.".
- [ ] Valutare se serve anche configurazione iOS in `Podfile`/permessi del package scelto dopo l'aggiunta della dipendenza.
- [ ] Creare un piccolo servizio/provider di localizzazione cliente, separato dalla UI, con:
  - stato `unknown/loading/granted/denied/deniedForever/serviceDisabled/error`;
  - posizione corrente nullable;
  - metodo `requestCurrentPosition()`;
  - metodo `openSettings()` o `openLocationSettings()` se supportato dal package.
- [ ] Inserire nella discovery cliente una richiesta permesso contestuale:
  - evitare richiesta aggressiva prima che la schermata sia pronta;
  - mostrare una riga/banner "Usa la tua posizione" se il permesso non e' ancora concesso;
  - chiedere il permesso al tap oppure dopo una breve spiegazione in schermata.
- [ ] Implementare una funzione pura per distanza tra coordinate, preferibilmente Haversine, se non si usa un helper del package:
  - input: lat/lng utente e lat/lng salone;
  - output: metri/km;
  - gestione `null` quando una coordinata manca.
- [ ] Creare un view model locale per la lista, es. `DiscoverableSalonResult`, con:
  - `PublicSalon salon`;
  - `double? distanceMeters`;
  - `bool matchesName`;
  - `bool matchesPhone`;
  - `bool hasAddressAndCoordinates`;
  - eventuale `sortRank`.
- [ ] Cambiare l'ordinamento attuale in `client_salon_discovery_screen.dart`:
  - senza query: prima distanza crescente, poi nome;
  - senza query: escludere saloni senza indirizzo o senza coordinate;
  - con query: includere anche saloni senza indirizzo/coordinate se matchano nome o telefono;
  - con query: match esatto/prefix/contains sul nome, poi match telefono, poi distanza, poi nome.
- [ ] Aggiornare `_matchesQuery()`:
  - cercare solo in `salon.name` e `salon.phone`;
  - rimuovere match su citta, indirizzo ed email;
  - normalizzare il telefono rimuovendo spazi, prefissi formattati e simboli non numerici per rendere la ricerca robusta.
- [ ] Aggiornare placeholder e microcopy del campo:
  - esempio: "Cerca per nome o telefono";
  - eventuale testo secondario per posizione: "Mostriamo prima i saloni piu' vicini quando la posizione e' attiva.".
- [ ] Aggiornare `_SalonCard` per mostrare distanza quando disponibile.
- [ ] Gestire empty state distinti:
  - nessun salone pubblicato;
  - nessun risultato per la query;
  - nessun salone vicino con indirizzo/coordinate, ma ricerca manuale disponibile;
  - posizione negata o disattivata.
- [ ] Nascondere dalla lista vicini i saloni senza indirizzo o senza coordinate, mantenendoli ricercabili per nome/telefono.
- [ ] Verificare che `public_salons` contenga sempre `latitude` e `longitude` quando un salone viene pubblicato o aggiornato.
- [ ] Introdurre geocoding automatico lato admin:
  - Cloud Function `geocodeSalonAddress` o servizio equivalente;
  - CTA "Trova coordinate" nei form salone;
  - salvataggio coordinate dopo conferma admin;
  - fallback/manual override avanzato.
- [ ] Chiarire il campo `googlePlaceId`: oggi viene usato con label "Link recensioni"; decidere se resta Place ID o se serve un campo separato per il link recensioni.
- [ ] Verificare le regole Firestore per lettura pubblica/cliente di `public_salons` e assicurarsi che non espongano dati non necessari.
- [ ] Valutare un backfill dati per i saloni gia' esistenti:
  - coordinate mancanti;
  - indirizzi mancanti;
  - `isPublished`;
  - documento mirror in `public_salons`.
- [ ] Per scala futura, valutare query geospaziali backend/Firestore:
  - per pochi centri va bene caricare `public_salons` e ordinare client-side;
  - per molti centri serve geohash/GeoFlutterFire o endpoint Cloud Function con bounding box/raggio.
- [ ] Aggiungere test unitari per:
  - calcolo distanza;
  - ordinamento senza query;
  - ordinamento con query per nome;
  - ricerca per telefono normalizzato;
  - saloni senza indirizzo/coordinate esclusi dalla lista vicini;
  - saloni senza indirizzo/coordinate inclusi se matchano ricerca;
  - permesso negato/service disabled.
- [ ] Aggiungere test/widget smoke per la schermata:
  - campo ricerca manuale;
  - CTA posizione;
  - distanza visibile quando disponibile;
  - fallback quando la posizione non e' disponibile.
- [ ] Verificare manualmente su Android e iOS:
  - primo avvio con permesso non richiesto;
  - permesso concesso;
  - permesso negato;
  - permesso negato definitivamente;
  - localizzazione dispositivo spenta;
  - ricerca per nome/telefono con e senza posizione attiva.

## Note tecniche
- Prima implementazione consigliata: calcolo e ordinamento client-side usando `public_salons`, perche' la struttura dati attuale e' gia' disponibile e riduce il rischio.
- Non salvare la posizione del cliente se serve solo per ordinare la lista: mantenerla in memoria nello stato della schermata/provider.
- Evitare di mostrare saloni archiviati; mantenere il filtro attuale su `SalonStatus.archived`.
- Se un salone e' pubblicato ma senza indirizzo/coordinate, non va mostrato nella lista vicini. Deve pero' restare raggiungibile dalla ricerca manuale per nome o telefono.
