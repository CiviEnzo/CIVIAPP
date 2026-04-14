# UI Admin Mobile - Spec esecutiva

## Summary
- Obiettivo: correggere i layout mobile admin rotti senza cambiare IA, navigazione o logica dati.
- Tono dell'intervento: moderate refresh. Si puliscono spaziature, stacking, CTA e gerarchia, ma non si fa redesign del brand.
- Primo pass: shell admin, Saloni, Messaggi & Marketing, Vendite & Cassa, Magazzino.
- La remediation va estesa anche ai pattern identici trovati durante l'audit locale.

## Scope
- Correggere overflow, testi spezzati, row desktop-like, tabelle non adatte a phone, dialog con larghezza fissa.
- Mantenere invariati router, moduli disponibili, ordine sezioni, rail desktop, drawer mobile e modelli dati.
- Riutilizzare helper/layout condivisi nella presentation admin invece di duplicare fix locali.

## Non-scope
- Nessuna modifica a dominio, repository, provider o schema Firestore.
- Nessun redesign completo di Reports, Agenda o moduli fuori dai casi ad alto rischio, salvo piccoli adeguamenti dovuti a helper condivisi.
- Nessuna modifica a `adminTextScaleFactor`: i fix devono arrivare dal layout.

## Breakpoint e regole
- `phone < 600`: contenuto più denso, CTA principali full-width quando isolate, padding ridotti, header più compatti.
- `stacked header / toolbar < 720`: header di sezione, pill, controlli data, filtri e azioni devono scendere sotto il titolo.
- `2 colonne >= 920`: recupero di layout a due colonne per card o pannelli secondari.
- `rail desktop >= 1080`: comportamento desktop invariato.
- Regola generale: evitare `Row` rigide con testo lungo; preferire `LayoutBuilder`, `Wrap`, `Column` o `Expanded` con stacking esplicito.
- Regola generale: nessuna larghezza fissa nei dialog o nelle card che devono vivere su 390-430 px, salvo elementi clampati al viewport.

## Audit moduli ad alto rischio

### Shell admin
- Ridurre il padding orizzontale del contenitore modulo su phone per non comprimere il contenuto utile.
- Rendere il badge modulo in app bar più compatto su phone, con padding ridotto e sottotitolo nascosto quando manca spazio reale.
- Non cambiare drawer, rail, grouping dei moduli o intent navigation.

### Saloni
- `Saloni` header: CTA "Aggiungi Salone" full-width su layout compatti.
- `Operatività e risorse`: la pill di setup non può stare forzata sulla stessa riga del titolo se il width è stretto.
- Card con detail row a larghezza fissa: convertire a `Wrap` o griglie calcolate.
- Integrazione WhatsApp: le tile dettaglio non devono dipendere da `SizedBox(width: 220)` hardcoded senza fallback.

### Messaggi & Marketing
- Ridurre il padding esterno del modulo e dei pannelli su 390-430 px.
- La `TabBar` resta scrollabile, ma con padding più leggero su phone.
- `Promemoria appuntamenti`: combinazione `chips + switch`, dropdown e azioni finali deve collassare verticalmente senza overflow.
- `Dettagli promemoria`: il dialog va clampato al viewport, non fissato a 480 px.
- `ManualNotificationCard`: header selezione clienti, panel padding e azioni devono restare leggibili su phone.
- Le tile promozioni devono impilare switch e CTA se il titolo è lungo.

### Vendite & Cassa
- La CTA iniziale "Nuova vendita" non deve restare in una `Row` vuota con `Spacer` su phone: deve poter diventare full-width.
- `Ticket aperti`: header titolo + count deve supportare stacking.
- `Vendite concluse`: titolo e controlli data devono separarsi sotto `720 px`.
- Sotto `760 px`, mantenere il rendering a card e non regredire verso DataTable orizzontali.
- Le righe label/value mobile devono usare un helper condiviso per evitare testo spezzato lettera per lettera.

### Magazzino
- La CTA "Aggiungi Prodotto" deve poter occupare tutta la larghezza su phone.
- Le metriche non devono usare larghezza fissa 210.
- Ricerca e filtro devono poter andare in colonna.
- Sotto `760 px`, la tabella deve diventare una lista di card prodotto con stato e azioni leggibili.
- Sopra `760 px`, la tabella desktop attuale può rimanere.

## Pattern simili da intercettare
- `Row` con `Spacer` + unica CTA finale.
- `Row` con titolo lungo + `Switch` o pill a destra.
- Dialog con `SizedBox(width: ...)`.
- `Wrap` con tile a larghezza fissa dentro card strette.
- DataTable o pseudo-tabella che non ha una variante mobile a card.
- Label/value mobile implementati localmente con due `Expanded` rigidi.

## Checklist "trova strutture simili"
- Cercare `SizedBox(width:` e verificare se esiste fallback mobile.
- Cercare `Row(` nei moduli admin e verificare i casi con:
  `Expanded + Switch`
  `Expanded + Chip`
  `Expanded + IconButton`
  `Spacer + FilledButton`
- Cercare `DataTable` o header di tabella e verificare la presenza di una variante compact.
- Cercare `headlineMedium` nei moduli mobile e verificare se la gerarchia resta leggibile a 390 px.
- Cercare pannelli con padding `18-28` e verificare se su phone va alleggerito.

## Helper condivisi richiesti
- Header sezione responsive con trailing che scende sotto su width compatte.
- Toolbar responsive con primary control + secondary action che passa a colonna.
- Riga key/value mobile condivisa tra Vendite e Magazzino.

## Acceptance criteria
- Nessun titolo o label si spezza verticalmente carattere per carattere.
- Nessuna stripe rossa di overflow nei moduli target.
- Nessuno scroll orizzontale involontario, salvo `TabBar` dichiaratamente scrollabile.
- CTA, filtri, switch e controlli data sempre visibili e tappabili su `390x844` e `430x932`.
- Le tabelle desktop in `Vendite` e `Magazzino` restano attive sopra la soglia compact.
- Nessuna modifica a API, provider, repository, router o schema dati.

## QA matrix

| Viewport | Verifiche minime |
| --- | --- |
| `390x844` | app bar compatta, header stacked, nessun overflow, CTA full-width dove previste |
| `430x932` | tab messaggi leggibile, promemoria editabili, card inventory leggibili |
| `834x1194` | recupero layout tablet senza regressioni desktop |
| `1024x1366` | griglie e pannelli affiancati, nessun compact forzato inutile |

## Test plan
- Estendere i widget test admin shell con viewport phone reali.
- Estendere i widget test di `MessagesMarketingModule` con viewport `390x844` e `430x932`.
- Aggiungere test compact per `SalesModule` verificando la presenza della vista mobile a card.
- Aggiungere test compact per `InventoryModule` verificando la presenza della vista mobile a card.
- Quando si eseguono i test, considerare baseline già non verde:
  - `admin_dashboard_screen_test`: hover tooltip desktop
  - `reports_module_test`: sticky shortcuts analytics

## Nota operativa
- Questo documento sostituisce la roadmap generica precedente.
- La copia in `YoubookDoc/figma_doc/src/imports/admin_ui_mobile.md` deve restare identica, perché è usata come input documentale dal pacchetto Figma docs.
