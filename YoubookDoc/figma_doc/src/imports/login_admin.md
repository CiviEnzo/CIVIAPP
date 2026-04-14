# Login Admin - Creazione/Recupero Password e Registrazione Centro

Questo documento definisce le modifiche richieste al flusso di login admin, con particolare attenzione a recupero password e registrazione come centro.

## Modifiche richieste (sintesi)

- Recupero password: il tap su "Hai dimenticato la password?" deve cambiare pagina e guidare l'utente in un flusso dedicato di recupero.
- Sotto "Registrati come cliente" aggiungere il link "Registrati come centro".
- La registrazione come centro crea una richiesta di registrazione admin con stato non abilitato; la registrazione da sola non puo mai abilitare un admin.

## Recupero password (pagina dedicata)

### UX
- Da login admin, il link "Hai dimenticato la password?" apre una nuova pagina (route dedicata, non modal).
- La pagina di recupero contiene:
  - Titolo: "Recupera password"
  - Descrizione breve del flusso (es. invio link email).
  - Campo email.
  - CTA primaria: "Invia link di recupero".
  - CTA secondaria: "Torna al login".

### Flow
1. L'utente inserisce l'email.
2. Il sistema invia il link di recupero.
3. Mostrare conferma (toast o pagina di esito) e link per tornare al login.

### Note di business
- Il recupero password non abilita l'admin: se l'account e in stato non abilitato, dopo il reset non deve comunque poter accedere.

## Creazione password (primo accesso)

- Se l'admin viene creato da backoffice o dopo registrazione centro, usare un flusso "Imposta password" (link via email o schermata dedicata) per il primo accesso.
- Anche con password impostata, l'accesso e permesso solo se l'admin e abilitato.

## Registrati come centro

### Posizionamento UI
- Nella pagina di login admin, sotto "Registrati come cliente" aggiungere "Registrati come centro".

### Flow proposto
1. "Registrati come centro" apre la pagina di registrazione centro/admin.
2. L'utente completa i dati del centro e dell'admin (email, nome, ruolo, contatti).
3. Il sistema crea:
   - record centro
   - record admin con stato "pending" / `enabled: false`
4. L'utente vede una schermata di conferma: "Richiesta inviata. Il tuo account sara abilitato dopo verifica".

### Regole di abilitazione admin
- La registrazione non abilita mai l'admin.
- Solo un admin abilitato o backoffice puo settare `enabled: true`.
- In login, se `enabled: false`, mostrare messaggio: "Account in attesa di abilitazione" e bloccare l'accesso.

## Dati minimi consigliati (admin)

- `email`
- `displayName`
- `centerId`
- `centerId` viene generato dal backend alla creazione del centro e associato all'admin
- `enabled` (boolean)
- `status` (pending/active/rejected)
- `enabledBy`, `enabledAt` (audit)

## Accettazione

- Il recupero password apre una pagina dedicata e guida l'utente fino all'invio del link.
- In login admin compaiono i due link: "Registrati come cliente" e "Registrati come centro".
- Dopo registrazione centro, l'admin risulta non abilitato e non puo accedere finche non viene abilitato manualmente.
