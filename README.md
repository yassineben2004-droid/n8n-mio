# n8n su Render + Sistema AI per Web Agency Locale

Questo repo contiene:

1. **Il deploy di n8n su Render** (`render.yaml`) — vedi le [istruzioni ufficiali Render](https://render.com/docs/deploy-n8n)
2. **Un sistema completo di workflow n8n** che automatizza con l'AI (Claude) il business "siti web + gestione Google Business Profile per attività locali"

## Il business in breve

Attività locali di servizi (idraulici, HVAC, coperture, elettricisti, dentisti...) hanno margini alti ma presenza digitale pessima. Il sistema:

1. **Trova i lead** su Google Maps (rating 4+, 20+ recensioni, sito assente o debole)
2. **Genera audit + email personalizzate** con Claude (bozze Gmail, revisione umana)
3. **Genera il brief del sito** da incollare in un AI website builder (Framer, Lovable, Webflow)
4. **Gestisce i clienti acquisiti**: risposte automatiche alle recensioni e post settimanali sul profilo Google — il servizio ricorrente da 300-800 €/mese per cliente

## Struttura del repo

| Percorso | Contenuto |
|---|---|
| `render.yaml` | Blueprint Render (n8n + Postgres) |
| `workflows/01-qualificazione-lead.json` | Import CSV Outscraper → filtro + punteggio → Google Sheets |
| `workflows/02-audit-e-outreach.json` | Audit GBP con Claude + bozze email personalizzate (max 15/giorno) |
| `workflows/03-brief-sito-web.json` | Brief professionale per AI website builder |
| `workflows/04-risposte-recensioni.json` | Risposte AI alle recensioni dei clienti (auto per 4-5★, revisione per 1-3★) |
| `workflows/05-post-settimanali-gbp.json` | Post settimanali automatici sul Google Business Profile |
| `prompts/PROMPTS.md` | Libreria dei prompt Claude riutilizzabili |
| `docs/SETUP.md` | **Guida completa di setup (parti da qui)** |

## Quick start

1. Deploya n8n su Render con questo repo (Blueprint)
2. Segui [docs/SETUP.md](docs/SETUP.md): credenziali (Anthropic, Google Sheets, Gmail, GBP API), foglio Google, import dei 5 workflow
3. Esporta un CSV da Outscraper e caricalo nel form del workflow 01

> ⚠️ Il sistema crea **bozze** email con limite giornaliero e prevede revisione umana: è una scelta deliberata per deliverability e conformità GDPR/CAN-SPAM. Non trasformarlo in un cannone spara-spam.
