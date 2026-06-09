# Privacy clienti salone

## Obiettivo

Preparare YouBook a gestire dati cliente, foto e campi aggiuntivi con una separazione chiara dei ruoli:

- il salone decide quali dati raccogliere, per quali finalita e con quale base giuridica;
- YouBook fornisce strumenti tecnici, conservazione, audit e cancellazione per conto del salone;
- l'app deve tracciare le conferme operative dello staff senza presentarle come consenso raccolto da YouBook.

Questa impostazione richiede comunque termini SaaS e DPA art. 28 GDPR separati, da validare legalmente prima del rilascio commerciale.

## Ruoli privacy

- Salone: titolare del trattamento per i dati dei propri clienti.
- YouBook: responsabile del trattamento per hosting, storage, backup, sicurezza, sincronizzazione, supporto e manutenzione.
- Staff/admin del salone: utenti autorizzati dal salone, con accesso limitato al salone di appartenenza.
- Cliente finale: interessato, con diritto di accesso, rettifica, cancellazione, opposizione e revoca dei consensi ove applicabile.

## Foto clienti

Le foto cliente sono dati personali. Vanno trattate come potenzialmente sensibili quando mostrano corpo, pelle, trattamenti, condizioni fisiche o risultati prima/dopo. Non vanno trattate come dati biometrici salvo uso per identificazione automatica, riconoscimento facciale o template biometrici.

### Regola prodotto

Ogni upload foto da admin/staff deve salvare:

- `privacy.purpose`: finalita dichiarata;
- `privacy.legalBasis`: base giuridica dichiarata dal salone;
- `privacy.confirmedAt`: data/ora conferma;
- `privacy.confirmedBy`: utente staff/admin che conferma;
- `privacy.confirmationVersion`: versione del testo di conferma;
- `privacy.specialCategoryRisk`: flag prudenziale per foto potenzialmente sensibili;
- `privacy.biometricProcessing`: deve restare `false` finche non esiste una feature biometrica esplicita.

Valori iniziali:

- finalita: `treatmentDocumentation`, `beforeAfterComparison`, `clientAppSharing`, `marketingPublication`;
- basi giuridiche: `contractOrPrecontract`, `explicitConsent`, `legalObligation`, `legitimateInterest`.

Per `marketingPublication` usare solo `explicitConsent` e conservare un riferimento al consenso quando verra introdotta la tabella consensi granulare.

### Conferma staff

La UI chiede la conferma una volta per sessione di lavoro sull'archivio foto del cliente, non per ogni singola foto. La conferma viene poi salvata come metadato su ogni foto caricata in quella sessione.

Lo staff deve confermare che:

- il cliente ha ricevuto l'informativa del salone;
- il salone dispone della base giuridica indicata;
- eventuali consensi necessari sono stati raccolti dal salone;
- la foto non sara usata per riconoscimento biometrico automatico o training AI.

Questa conferma non sostituisce il consenso del cliente: e un audit operativo della responsabilita del salone.

### Retention e cancellazione

Fase iniziale:

- supportare cancellazione manuale da archivio e Storage;
- supportare cancellazione di singola foto, collage e intero set fotografico;
- mantenere audit minimo su upload e autore nel documento foto;
- preparare il campo opzionale `privacy.deleteAfter` per retention futura.

Fase successiva:

- configurazione retention per salone/finalita;
- job schedulato di scadenza;
- log cancellazioni;
- export dati cliente.

## Campi aggiuntivi cliente

I campi standard gia presenti includono sesso/genere e professione. Sono dati personali ordinari nella maggior parte dei casi, ma devono rispettare minimizzazione e finalita.

Regola prodotto:

- sesso/genere: facoltativo salvo necessita documentata dal salone;
- professione: facoltativa, utile solo se collegata a finalita chiara;
- note libere: avvisare lo staff di non inserire dati sanitari o particolari se non necessari.

### Campi custom futuri

Ogni campo custom definito dal salone deve avere una configurazione:

```text
salon_client_fields/{fieldId}
  salonId
  label
  type
  purpose
  legalBasis
  required
  sensitiveFlag
  visibleToRoles
  retentionDays
  createdAt
  updatedAt
```

I valori cliente devono stare separati dalla definizione:

```text
client_custom_field_values/{valueId}
  salonId
  clientId
  fieldId
  value
  updatedAt
  updatedBy
```

Guardrail UI:

- mostrare finalita e obbligatorieta quando il salone crea un campo;
- impedire campi obbligatori senza finalita;
- chiedere conferma aggiuntiva per `sensitiveFlag`;
- evitare default invasivi;
- registrare chi modifica definizioni e valori.

## Consensi granulari

Il modello `ClientConsent` attuale copre `privacy`, `marketing`, `profilazione`. Per foto, WhatsApp marketing, pubblicazione social e profilazione avanzata serve un modello granulare:

```text
client_consents/{consentId}
  salonId
  clientId
  purpose
  legalTextVersion
  granted
  grantedAt
  revokedAt
  source
  collectedBy
  evidence
```

Fino a quando questo modello non e implementato, gli upload foto salvano solo la conferma staff nel blocco `privacy`.

## Checklist rilascio

- Aggiornare termini salone e DPA con ruolo YouBook come responsabile del trattamento.
- Aggiornare informativa privacy pubblica YouBook distinguendo utenti app e dati trattati per conto dei saloni.
- Preparare template informativa/consenso che il salone puo adattare.
- Collegare i consensi granulari a foto marketing, WhatsApp e profilazione.
- Aggiungere export/cancellazione dati cliente per salone.
- Aggiungere retention configurabile per foto e campi custom.
