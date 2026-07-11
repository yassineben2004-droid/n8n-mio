# Libreria Prompt — Web Agency Locale con AI

Prompt riutilizzabili per il business "AI + Google Maps per attività locali".
Sono gli stessi prompt integrati nei workflow n8n (cartella `workflows/`), utilizzabili anche a mano in Claude.

Sostituisci i segnaposto `[TRA PARENTESI]` prima dell'uso.

---

## 1. Ricerca dei settori target

> Quali tipi di attività locali hanno di solito i siti web peggiori ma i margini di profitto più alti? Considera il mio mercato: [CITTÀ/REGIONE].

Settori tipici: coperture/tetti (margine 20-35%), HVAC/climatizzazione (15-30%), idraulici (25-40%), elettricisti (20-35%), dentisti, disinfestazione, autofficine, tatuatori.

---

## 2. Qualificazione lead (con CSV Outscraper)

> Ti allego un CSV esportato da Outscraper con attività locali da Google Maps. Trova i target con: rating 4+ stelle, almeno 20 recensioni, e un profilo Google Business non ottimizzato (niente sito web, o sito che è una pagina Facebook/builder gratuito). Ordina per opportunità e spiega perché ciascuno è un buon target.

Nel workflow n8n `01-qualificazione-lead` questo filtro è fatto in codice (più veloce ed economico): rating ≥ 4.0, recensioni ≥ 20, punteggio per assenza/debolezza del sito.

---

## 3. Audit del Google Business Profile (delivery + vendita)

> Fai un audit completo del profilo Google Business di [NOME ATTIVITÀ]. Analizza: ottimizzazione della categoria, qualità delle foto, descrizione dell'attività, recensioni (risposte, velocità, keyword) e keyword locali. Stima quanti clienti al mese perde verso competitor meglio posizionati (i primi 5 su Maps prendono ~70% dei click). Fornisci un piano di miglioramento passo-passo in ordine di impatto.

---

## 4. Email a freddo personalizzata

> Scrivi una email a freddo per [NOME ATTIVITÀ], un'azienda [SETTORE] a [CITTÀ] con rating [X] stelle e [N] recensioni Google ma senza sito web.
>
> L'email deve: citare rating e numero di recensioni reali, stimare quanti clienti stanno perdendo verso competitor con presenza online migliore, offrire un'anteprima gratuita del sito già costruita per loro, e suonare come scritta da una persona vera, non da un'agenzia di marketing. Massimo 150 parole con UNA sola call-to-action.

**Regole di conformità (obbligatorie in UE):** identificati con nome e attività reali, includi sempre una riga di opt-out ("Se preferisci non ricevere altre email, rispondi 'no grazie'"), volumi contenuti (il workflow limita a 15 bozze/giorno), invio manuale dopo revisione. Le email personalizzate convertono 3-8 volte meglio dei template generici — la qualità batte la quantità.

---

## 5. Brief per AI website builder

> Sto costruendo un sito web ad alta conversione per [NOME ATTIVITÀ]. In base ai loro servizi e alle recensioni positive dei clienti, scrivi un prompt professionale e dettagliato per un AI website builder.
>
> Includi sezioni per:
> - Hero header con il servizio principale e gli anni di esperienza
> - Sezione prenotazione con tutti i servizi elencati
> - Sezione testimonianze usando le loro recensioni Google reali
> - Sezione Chi Siamo che enfatizza esperienza e segnali di fiducia
> - Pulsanti call-to-action chiari e ripetuti
>
> I loro servizi: [INCOLLA DA GOOGLE MAPS]
> Le loro recensioni migliori: [INCOLLA 3-5 RECENSIONI]

Il brief va incollato in Framer, Webflow, Wix AI o Lovable → sito completo in meno di un'ora.

---

## 6. Risposte alle recensioni (servizio ricorrente)

> Genera risposte professionali e personalizzate alle recensioni dei clienti per un [TIPO ATTIVITÀ]. Crea template per recensioni a 5, 4, 3 stelle e negative, che incoraggino nuove prenotazioni affrontando le criticità. Suona umano, non aziendale. Inserisci in modo naturale keyword locali (es. "[SETTORE] a [CITTÀ]") dove non risulta forzato.

Nel workflow `04-risposte-recensioni`: le risposte a 4-5 stelle vengono pubblicate in automatico, quelle a 1-3 stelle passano da revisione umana.

---

## 7. Post settimanale GBP (servizio ricorrente)

> Scrivi il post settimanale per il profilo Google di [NOME], [SETTORE] a [CITTÀ]. 100-200 parole, un consiglio stagionale utile per i clienti finali (siamo a [MESE]), keyword locale naturale, call-to-action finale (chiamata o preventivo). Niente hashtag.

---

## Listino di riferimento (dal modello di business)

| Servizio | Prezzo |
|---|---|
| Sito base (5 pagine) | 500–800 € |
| Sito completo + sistema di prenotazione | 1.500 € |
| Sito + manutenzione mensile | 1.200 € iniziali + 200 €/mese |
| Gestione Google Business Profile | 300–800 €/mese per cliente |

Con 4 clienti/mese a 800 € di media + manutenzioni ricorrenti si arriva a 5.000–8.000 €/mese di ricavi ricorrenti entro 6 mesi. La gestione GBP è il servizio più scalabile: 10 clienti a 500 €/mese = 5.000 €/mese quasi passivi (i workflow 04 e 05 fanno il 90% del lavoro).
