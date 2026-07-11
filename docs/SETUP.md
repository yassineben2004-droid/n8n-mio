# Setup — Sistema AI per Web Agency Locale

Guida per mettere in produzione l'intero sistema su n8n (deployato su Render con il `render.yaml` di questo repo).

## Panoramica del sistema

```
Outscraper (Google Maps)          I TUOI CLIENTI ACQUISITI
        │                                  │
        ▼                                  ▼
[01 Qualificazione Lead]          [04 Risposte Recensioni]  ← ogni giorno
        │                         [05 Post Settimanali GBP] ← ogni lunedì
        ▼
[02 Audit + Bozze Email]  ← ogni giorno, max 15 bozze
        │
   (tu rivedi e invii da Gmail)
        │ risposta interessata
        ▼
[03 Brief Sito Web] → Framer/Lovable/Webflow → anteprima → vendita
```

| Workflow | Fase | Trigger |
|---|---|---|
| `01-qualificazione-lead` | Trovare clienti | Form (upload CSV) |
| `02-audit-e-outreach` | Contattarli | Ogni giorno 9:00 |
| `03-brief-sito-web` | Vendere il sito | Form |
| `04-risposte-recensioni` | Servizio ricorrente | Ogni giorno 8:00 |
| `05-post-settimanali-gbp` | Servizio ricorrente | Ogni lunedì 10:00 |

## 1. Deploy di n8n su Render

1. Usa il pulsante **Use this template** / collega questo repo a Render come Blueprint (`render.yaml` è già pronto: web service n8n + database Postgres, entrambi su piano free).
2. Al primo avvio, crea l'account owner di n8n.
3. **Nota piano free:** il servizio va in sleep dopo inattività e gli schedule potrebbero non scattare. Per i workflow schedulati (02, 04, 05) conviene il piano Starter (~7$/mese), oppure un ping esterno (es. cron-job.org) che tiene sveglio il servizio.

## 2. Credenziali da creare in n8n

### Anthropic (Claude) — obbligatoria
1. Prendi una API key su https://platform.claude.com → API Keys
2. In n8n: **Credentials → New → Header Auth**
   - Name: `Anthropic API`
   - Header Name: `x-api-key`
   - Header Value: `sk-ant-...`
3. Nei nodi HTTP "Claude: ..." di ogni workflow seleziona questa credenziale.

I workflow usano `claude-opus-4-8`. Per i task ad alto volume (risposte recensioni, post) puoi ridurre i costi cambiando il modello in `claude-haiku-4-5` nel campo `model` dei nodi Code.

**Nota API (luglio 2026):** l'header `anthropic-version: 2023-06-01` è obbligatorio; non aggiungere `temperature`/`top_p` alle richieste — su Opus 4.7+ restituiscono errore 400.

### Google Sheets + Gmail — obbligatorie
1. Google Cloud Console → crea progetto → abilita **Google Sheets API** e **Gmail API**
2. Crea credenziali OAuth2 (tipo Web) con redirect URI di n8n (lo mostra n8n quando crei la credenziale)
3. In n8n: **Credentials → New → Google Sheets OAuth2** e **Gmail OAuth2**

### Google Business Profile API — per i workflow 04 e 05
Serve solo quando hai clienti attivi in gestione GBP.
1. Richiedi l'accesso all'API GBP (Google la concede su richiesta: https://developers.google.com/my-business)
2. Abilita **My Business API** nel progetto Google Cloud
3. In n8n crea una credenziale **OAuth2 API** generica:
   - Auth URL: `https://accounts.google.com/o/oauth2/v2/auth`
   - Token URL: `https://oauth2.googleapis.com/token`
   - Scope: `https://www.googleapis.com/auth/business.manage`
4. Autenticati con l'account Google che è **gestore** del profilo del cliente (fatti aggiungere come gestore dal cliente — è parte dell'onboarding).
5. Recupera `ACCOUNT_ID` e `LOCATION_ID` con una chiamata GET a `https://mybusinessaccountmanagement.googleapis.com/v1/accounts` e `https://mybusinessbusinessinformation.googleapis.com/v1/accounts/{account}/locations`.

## 3. Google Sheet di lavoro

Crea un foglio Google con 3 tab:

- **Leads**: `name, category, city, address, phone, email, site, rating, reviews, score, reasons, status, created_at, email_oggetto, audit`
- **Clienti**: `nome_cliente, settore, citta, servizi, account_id, location_id, attivo`
- **Post_Log**: `data, cliente, post`

Sostituisci `YOUR_SPREADSHEET_ID` nei workflow con l'ID del foglio (dall'URL).

## 4. Import dei workflow

In n8n: **Workflows → Import from File** → importa i 5 file della cartella `workflows/`. Poi per ciascuno:
1. Apri ogni nodo con credenziale mancante e selezionala
2. Sostituisci i segnaposto (`YOUR_SPREADSHEET_ID`, `ACCOUNT_ID`, `LOCATION_ID`, `IL_TUO_NOME`, `LA_TUA_ATTIVITA`)
3. Attiva il workflow (interruttore in alto)

## 5. Outscraper (fonte dei lead)

1. Account su https://outscraper.com (i primi export sono gratuiti)
2. Google Maps Scraper → query tipo `idraulico Milano`, `roofing contractor Atlanta`, `disinfestazione Roma`
3. Esporta il CSV con email arricchite → caricalo nel form del workflow 01

Settori consigliati (margini alti, siti pessimi): coperture/tetti, HVAC, idraulici, elettricisti, dentisti, disinfestazione, autofficine.

## 6. Ciclo operativo quotidiano

1. **Mattina (10 min):** apri Gmail → cartella Bozze → rivedi le bozze create dal workflow 02 → invia quelle buone, cestina le altre
2. **Quando qualcuno risponde:** compila il form del workflow 03 → ricevi il brief → incollalo in Framer/Lovable → anteprima pronta → mostrala al lead
3. **Chiusura:** sito base 500-800 €, sito+prenotazioni 1.500 €, oppure 1.200 € + 200 €/mese con manutenzione
4. **Upsell ricorrente:** gestione GBP 300-800 €/mese → aggiungi il cliente al tab `Clienti` → i workflow 04 e 05 lavorano da soli
5. **Recensioni negative:** arrivano come bozza Gmail → rivedi e pubblica a mano

## 7. Conformità (leggi prima di inviare la prima email)

Questo sistema crea **bozze** e limita i volumi (15/giorno) di proposito:

- **UE/Italia (GDPR + ePrivacy):** il B2B verso email aziendali pubbliche è generalmente difendibile come legittimo interesse, MA devi: identificarti chiaramente, offrire opt-out in ogni email (già incluso nel prompt), onorare gli opt-out subito (segna `status = opt_out` nel foglio), e cancellare i dati su richiesta.
- **USA (CAN-SPAM):** identificazione reale, indirizzo fisico nel footer, opt-out funzionante.
- **Mai** invio automatico di massa: oltre a essere illegale, brucia il dominio email (finisci in spam e il business muore).
- Le risposte alle recensioni sono pubblicate **per conto del cliente**: fatti autorizzare per iscritto nel contratto di gestione GBP.

## Costi di esercizio stimati

| Voce | Costo |
|---|---|
| Render (n8n + Postgres) | 0–14 $/mese |
| API Anthropic (15 audit+email/giorno + 2 clienti GBP) | ~20–60 $/mese con Opus; molto meno con Haiku sui task semplici |
| Outscraper | ~10–30 $/mese |
| Gmail/Sheets/GBP API | gratis |

Un solo cliente GBP a 300 €/mese copre tutti i costi.
