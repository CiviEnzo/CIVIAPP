# Modello Questionario Anamnesi (Import)

Questo file contiene il modello "Anamnesi estetica base" in formato JSON, pronto per essere importato
nell'applicazione tramite il pulsante **Importa modello** disponibile nel modulo amministrativo
"Questionari cliente".

## Come utilizzare il file

1. Copia il JSON sottostante (includendo parentesi graffe iniziali e finali).
2. Accedi al backoffice con un profilo `admin` o `staff` e seleziona il salone di destinazione.
3. Apri il modulo **Questionari cliente** dal menu laterale.
4. Fai clic su **Importa modello**, incolla il JSON e, se desideri, marca l'opzione "Imposta come modello predefinito".
5. Conferma l'import: il modello verrà salvato per il salone selezionato.

> Il campo `salonId` verrà sovrascritto automaticamente con l'identificativo del salone scelto durante
> l'import. Puoi mantenere il valore di esempio presente nel JSON.

## JSON del modello

```json
{
  "id": "tmpl-anamnesi-base",
  "salonId": "salon-placeholder",
  "name": "Anamnesi estetica base",
  "description": "Questionario standard per raccogliere anamnesi, stile di vita e consenso informato.",
  "isDefault": true,
  "groups": [
    {
      "id": "grp-cardiovascular",
      "title": "Condizioni cardiovascolari",
      "sortOrder": 10,
      "questions": [
        {
          "id": "q-cardiac-disease",
          "label": "Patologie cardiache (infarto, aritmie, insufficienza)?",
          "type": "boolean"
        },
        {
          "id": "q-blood-pressure",
          "label": "Pressione alta o bassa?",
          "type": "boolean"
        },
        {
          "id": "q-pacemaker",
          "label": "Portatore di pacemaker o defibrillatore?",
          "type": "boolean"
        },
        {
          "id": "q-heart-meds",
          "label": "Assunzione di farmaci cardiaci (anticoagulanti, beta-bloccanti)?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-pregnancy",
      "title": "Gravidanza e allattamento",
      "sortOrder": 20,
      "questions": [
        {
          "id": "q-pregnant",
          "label": "Attualmente incinta?",
          "type": "boolean"
        },
        {
          "id": "q-breastfeeding",
          "label": "Sta allattando?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-general-pathologies",
      "title": "Patologie generali",
      "sortOrder": 30,
      "questions": [
        {
          "id": "q-diabetes",
          "label": "Diabete diagnosticato?",
          "type": "boolean"
        },
        {
          "id": "q-diabetes-meds",
          "label": "Assunzione di farmaci per il diabete?",
          "type": "boolean"
        },
        {
          "id": "q-insulin-resistance",
          "label": "Insulino-resistenza confermata?",
          "type": "boolean"
        },
        {
          "id": "q-kidney-liver",
          "label": "Problemi renali o epatici?",
          "type": "boolean"
        },
        {
          "id": "q-autoimmune",
          "label": "Patologie autoimmuni o croniche?",
          "type": "boolean"
        },
        {
          "id": "q-general-notes",
          "label": "Dettagli o note aggiuntive",
          "type": "textarea",
          "helperText": "Specificare eventuali terapie in corso."
        }
      ]
    },
    {
      "id": "grp-hormonal",
      "title": "Storia ormonale",
      "sortOrder": 40,
      "questions": [
        {
          "id": "q-menstrual-irregularities",
          "label": "Irregolarità mestruali?",
          "type": "boolean"
        },
        {
          "id": "q-menopause",
          "label": "Menopausa in corso?",
          "type": "boolean"
        },
        {
          "id": "q-pcos",
          "label": "Problemi di ovaio policistico o simili?",
          "type": "boolean"
        },
        {
          "id": "q-thyroid",
          "label": "Patologie tiroidee o endocrine?",
          "type": "boolean"
        },
        {
          "id": "q-weight-history",
          "label": "Storia di sovrappeso o difficoltà nel controllo del peso?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-allergies",
      "title": "Allergie e reazioni",
      "sortOrder": 50,
      "questions": [
        {
          "id": "q-allergies",
          "label": "Allergie note (farmaci, cosmetici, lattice)?",
          "type": "boolean"
        },
        {
          "id": "q-adverse-reactions",
          "label": "Reazioni avverse a trattamenti estetici o farmaci?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-skin",
      "title": "Disturbi della pelle",
      "sortOrder": 60,
      "questions": [
        {
          "id": "q-skin-disorders",
          "label": "Dermatiti, eczema, psoriasi o ferite aperte?",
          "type": "boolean"
        },
        {
          "id": "q-topical-therapies",
          "label": "Terapie topiche o sistemiche in corso?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-surgery",
      "title": "Chirurgia e trattamenti recenti",
      "sortOrder": 70,
      "questions": [
        {
          "id": "q-surgery-last12",
          "label": "Interventi chirurgici negli ultimi 12 mesi?",
          "type": "boolean"
        },
        {
          "id": "q-recent-aesthetic",
          "label": "Trattamenti estetici recenti (laser, filler, peeling, Botox)?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-activity",
      "title": "Attività fisica",
      "sortOrder": 80,
      "questions": [
        {
          "id": "q-activity-regular",
          "label": "Pratica attività fisica regolare?",
          "type": "boolean"
        },
        {
          "id": "q-activity-type",
          "label": "Tipo di attività praticata",
          "type": "text"
        },
        {
          "id": "q-activity-frequency",
          "label": "Frequenza settimanale e durata",
          "type": "text"
        },
        {
          "id": "q-sedentary",
          "label": "Stile di vita sedentario?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-nutrition",
      "title": "Alimentazione",
      "sortOrder": 90,
      "questions": [
        {
          "id": "q-special-diet",
          "label": "Segue una dieta particolare o nutrizionista?",
          "type": "boolean"
        },
        {
          "id": "q-dietary-restrictions",
          "label": "Restrizioni o intolleranze alimentari?",
          "type": "boolean"
        },
        {
          "id": "q-fruit-veg-portions",
          "label": "Porzioni di frutta o verdura al giorno",
          "type": "number",
          "helperText": "Inserire il valore medio giornaliero."
        },
        {
          "id": "q-sugar-fat",
          "label": "Consumo frequente di zuccheri o grassi?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-hydration",
      "title": "Idratazione",
      "sortOrder": 100,
      "questions": [
        {
          "id": "q-water-intake",
          "label": "Quanta acqua beve mediamente al giorno?",
          "type": "singleChoice",
          "options": [
            { "id": "lt_less_1", "label": "Meno di 1 litro" },
            { "id": "lt_1_2", "label": "Tra 1 e 2 litri" },
            { "id": "lt_over_2", "label": "Oltre 2 litri" }
          ]
        },
        {
          "id": "q-sugary-drinks",
          "label": "Consumo di bevande zuccherate o alcoliche?",
          "type": "boolean"
        }
      ]
    },
    {
      "id": "grp-sleep-stress",
      "title": "Sonno e stress",
      "sortOrder": 110,
      "questions": [
        {
          "id": "q-sleep-hours",
          "label": "Ore di sonno medie per notte",
          "type": "number"
        },
        {
          "id": "q-insomnia",
          "label": "Problemi di insonnia?",
          "type": "boolean"
        },
        {
          "id": "q-stress-level",
          "label": "Livello di stress percepito",
          "type": "singleChoice",
          "options": [
            { "id": "low", "label": "Basso" },
            { "id": "medium", "label": "Medio" },
            { "id": "high", "label": "Alto" }
          ]
        }
      ]
    },
    {
      "id": "grp-skin-care",
      "title": "Cura della pelle",
      "sortOrder": 120,
      "questions": [
        {
          "id": "q-uses-cosmetics",
          "label": "Utilizza creme o cosmetici?",
          "type": "boolean"
        },
        {
          "id": "q-cosmetic-source",
          "label": "Dove acquista abitualmente i prodotti?",
          "type": "singleChoice",
          "options": [
            { "id": "pharmacy", "label": "Farmacia" },
            { "id": "supermarket", "label": "Supermercato" },
            { "id": "beauty_center", "label": "Centro estetico" },
            { "id": "other", "label": "Altro" }
          ]
        },
        {
          "id": "q-products-used",
          "label": "Prodotti utilizzati regolarmente",
          "type": "textarea"
        }
      ]
    },
    {
      "id": "grp-hair-removal",
      "title": "Depilazione",
      "sortOrder": 130,
      "questions": [
        {
          "id": "q-hair-removal-method",
          "label": "Metodo di depilazione utilizzato",
          "type": "singleChoice",
          "options": [
            { "id": "wax", "label": "Ceretta" },
            { "id": "razor", "label": "Rasoio" },
            { "id": "epilator", "label": "Epilatore" },
            { "id": "laser", "label": "Laser" },
            { "id": "other", "label": "Altro" }
          ]
        }
      ]
    },
    {
      "id": "grp-previous-treatments",
      "title": "Trattamenti estetici precedenti",
      "sortOrder": 140,
      "questions": [
        {
          "id": "q-previous-treatments",
          "label": "Ha effettuato trattamenti viso o corpo precedenti?",
          "type": "boolean"
        },
        {
          "id": "q-previous-treatments-notes",
          "label": "Specificare trattamenti precedenti",
          "type": "textarea",
          "helperText": "Inserire trattamenti, date e risultati."
        }
      ]
    },
    {
      "id": "grp-goals",
      "title": "Obiettivi personali",
      "sortOrder": 150,
      "questions": [
        {
          "id": "q-treatment-goals",
          "label": "Obiettivi personali del trattamento",
          "type": "textarea"
        }
      ]
    },
    {
      "id": "grp-consent",
      "title": "Consenso informato",
      "sortOrder": 160,
      "questions": [
        {
          "id": "q-consent-informed",
          "label": "Il cliente dichiara di aver ricevuto tutte le informazioni sul trattamento?",
          "type": "boolean",
          "isRequired": true
        },
        {
          "id": "q-client-signature",
          "label": "Firma cliente",
          "type": "text",
          "isRequired": true
        },
        {
          "id": "q-consent-date",
          "label": "Data compilazione",
          "type": "date",
          "isRequired": true
        }
      ]
    }
  ]
}
```

Buon lavoro con l'importazione!
