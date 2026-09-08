## Baseline – før ændringer
| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-BUS | 2026-04-29 | 36.00 | 1 |
| OP-METRO | 2026-04-29 | 36.00 | 1 |

## SQL function

Funktionen `captured_revenue_for_day` beregner den aktuelle captured revenue direkte fra betalingsdataene.

For OP-METRO på 2026-04-29:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---|---|
| OP-METRO | 2026-04-29 | 36.00 | 1 |

## Materialized view – før refresh

Materialized view'et blev oprettet med `WITH NO DATA`, så det indeholder endnu ingen data.

Da jeg forsøgte at læse fra view'et, fik jeg:

`ERROR: materialized view "daily_captured_revenue" has not been populated`

PostgreSQL anbefaler at bruge `REFRESH MATERIALIZED VIEW`.

Dette viser, at et materialized view ikke automatisk indeholder aktuelle data, når det oprettes med `WITH NO DATA`.

## Materialized view – efter refresh

Efter `REFRESH MATERIALIZED VIEW` indeholder view'et:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---|---|
| OP-BUS | 2026-04-29 | 36.00 | 1 |
| OP-METRO | 2026-04-29 | 36.00 | 1 |

View'et viser samme resultat som baseline. Dataene er dog et snapshot og bliver ikke automatisk opdateret, når data i de underliggende tabeller ændres.

## Trigger-maintained summary

Trigger-løsningen opretter tabellen `daily_revenue_by_operator` og en trigger på `payments`.

Triggeren reagerer på nye betalinger og tilføjer captured payments til den daglige opsummering.

Triggeren er dog med vilje ufuldstændig og håndterer kun `INSERT` af payments med status `Captured`.

### Trigger summary – før nye betalinger

Efter oprettelsen af triggeren indeholder `daily_revenue_by_operator` ingen rækker.

Det skyldes, at triggeren kun reagerer på nye `INSERT`-operationer. De eksisterende payments bliver ikke automatisk indlæst i summary-tabellen.

Dette viser, at trigger-løsningen kræver en separat backfill/rebuild, hvis summary-tabellen skal indeholde historiske data.

### Test 1 – Captured payment

Jeg indsatte en ny payment med status `Captured`:

- Payment: `PAY-CASE-CAPTURED`
- Operator: `OP-METRO`
- Beløb: 36 DKK
- Dato: 2026-04-29

Triggeren opdaterede automatisk `daily_revenue_by_operator`:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-METRO | 2026-04-29 | 36 | 1 |

Dette viser, at triggeren fungerer ved en ny `Captured` payment.

### Test 2 – Failed payment

Jeg indsatte en ny payment med status `Failed`:

- Payment: `PAY-CASE-FAILED`
- Beløb: 50 DKK
- Dato: 2026-04-29

`payments` accepterede indsættelsen, men triggeren opdaterede ikke summary-tabellen.

Summary-tabellen er fortsat:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-METRO | 2026-04-29 | 36 | 1 |

Dette er forventet, da triggeren kun reagerer på payments med status `Captured`.

### Test 3 – Failed → Captured

Jeg ændrede `PAY-CASE-FAILED` fra `Failed` til `Captured`.

`payments` viser nu betalingen som `Captured`, men `daily_revenue_by_operator` blev ikke opdateret.

Summary-tabellen er fortsat:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-METRO | 2026-04-29 | 36 | 1 |

Den korrekte værdi baseret på `payments` burde være 86 DKK og 2 captured payments.

Dette viser, at den leverede trigger er ufuldstændig, fordi den kun håndterer nye `INSERT`-operationer og ikke statusændringer fra `Failed` til `Captured`.

### Test 4 – Captured → Refunded

Jeg ændrede `PAY-CASE-CAPTURED` fra `Captured` til `Refunded`.

`payments` viser nu betalingen som `Refunded`, men `daily_revenue_by_operator` blev ikke opdateret.

Summary-tabellen er fortsat:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-METRO | 2026-04-29 | 36 | 1 |

Den korrekte captured revenue burde ikke længere inkludere den refunderede payment.

Dette viser endnu en begrænsning ved triggeren: Den håndterer ikke ændringer fra `Captured` til `Refunded`, og den afspejler derfor ikke længere den aktuelle tilstand i `payments`.

### Test 5 – DELETE payment

Jeg slettede `PAY-CASE-FAILED` fra `payments`.

`payments` blev ændret korrekt, men `daily_revenue_by_operator` blev ikke opdateret.

Summary-tabellen er fortsat:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-METRO | 2026-04-29 | 36 | 1 |

Dette viser, at triggeren ikke håndterer `DELETE`-operationer. Den lagrede summary kan derfor blive inkonsistent med de aktuelle data i `payments`.

### Test 6 – Duplicate payment

Jeg indsatte en ny `Captured` payment med samme `external_payment_reference` som en eksisterende payment:

- Original reference: `gateway-capture-0001`
- Duplicate payment: `PAY-CASE-DUPLICATE`
- Beløb: 36 DKK

Databasen accepterede den duplicate payment.

Trigger-summaryen blev:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-METRO | 2026-04-29 | 72 | 2 |

Dette viser, at duplicate payments bliver talt som separate payments. Der findes ingen `UNIQUE` constraint på `external_payment_reference`, og triggeren håndterer ikke duplicate delivery.

Det kan føre til overrapportering af revenue.

## Sammenligning med authority

Jeg kørte reference-queryen igen efter testene.

Reference-queryen læser direkte fra `payments`, som er authority for revenue-data.

Resultatet er:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-BUS | 2026-04-29 | 36.00 | 1 |
| OP-METRO | 2026-04-29 | 72.00 | 2 |

Trigger-summaryen viser også 72 DKK og 2 payments for OP-METRO, men dette betyder ikke nødvendigvis, at den er korrekt. Triggeren har tidligere vist sig ikke at håndtere statusændringer og deletes korrekt.

Den direkte query er derfor den aktuelle authority, mens trigger-summaryen er afledte data.

### Materialized view – stale data

Efter testene kørte jeg en SELECT på `daily_captured_revenue`.

Materialized view'et viser fortsat:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-BUS | 2026-04-29 | 36.00 | 1 |
| OP-METRO | 2026-04-29 | 36.00 | 1 |

Reference-queryen, som læser direkte fra `payments`, viser derimod:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-BUS | 2026-04-29 | 36.00 | 1 |
| OP-METRO | 2026-04-29 | 72.00 | 2 |

Materialized view'et er derfor stale. Det skal refreshes for at afspejle ændringer i de underliggende `payments`-data.

Dette viser forskellen mellem et live query-resultat og et materialized snapshot.

### Materialized view – efter ny refresh

Jeg refreshed materialized view'et efter testændringerne.

Efter refresh viser view'et:

| operator_id | revenue_date | captured_amount | captured_payments |
|---|---|---:|---:|
| OP-BUS | 2026-04-29 | 36.00 | 1 |
| OP-METRO | 2026-04-29 | 72.00 | 2 |

Resultatet matcher reference-queryen.

Materialized view'et kan derfor give hurtige læsninger af et forberegnet resultat, men dataene kan være stale mellem refreshes.

## Responsibility matrix

| Approach | Correctness | Freshness | Write cost | Read cost | Hidden side effects | Rebuildability | Operational complexity |
|---|---|---|---|---|---|---|---|
| Direct query | Høj – beregner direkte fra `payments` | Høj – altid aktuelle data | Lav – ingen ekstra writes | Højere – beregningen udføres ved hver læsning | Ingen | Høj – ingen afledt data at genopbygge | Lav |
| SQL function | Høj – beregner direkte fra `payments` | Høj – altid aktuelle data | Lav – ingen ekstra writes | Højere – funktionen udfører queryen ved hver læsning | Ingen | Høj – ingen afledt data at genopbygge | Lav |
| Materialized view | Høj efter refresh | Middel – kan være stale mellem refreshes | Lav ved almindelige writes, men refresh kræver ekstra arbejde | Lav – resultatet er forberegnet | Ingen ved payment writes | Høj – kan genopbygges med `REFRESH MATERIALIZED VIEW` | Middel – refresh skal planlægges og overvåges |
| Trigger summary | Lavere – den leverede trigger håndterer ikke updates/deletes | Høj ved de INSERTs, triggeren håndterer, men kan blive stale ved andre ændringer | Højere – hver relevant INSERT medfører ekstra arbejde og writes | Lav – resultatet er allerede beregnet | Ja – INSERT på `payments` medfører skjulte writes til summary-tabellen | Middel/lav – kræver backfill/rebuild-logik | Høj – ændringer i payment-logikken skal holdes synkroniseret med triggeren |

## Recommendation

På baggrund af testene vil jeg anbefale **SQL function** som den primære løsning til rapportering af captured revenue.

SQL function'en læser direkte fra `payments`, som er authority for betalingsdata. Derfor er resultatet altid baseret på den aktuelle tilstand i databasen. Den kræver heller ikke ekstra writes eller skjulte side effects, som trigger-løsningen gør.

Direct query har de samme fordele og er også en god løsning. SQL function'en har dog den fordel, at rapporteringslogikken er samlet ét sted og kan genbruges af flere kaldere.

Materialized view kan være en god løsning, hvis der senere bliver behov for meget hurtige reads og mange rapporteringskald. Testene viste dog, at materialized view'et kan være stale mellem refreshes. Det betyder, at man skal acceptere en bestemt grad af forsinkelse eller have en strategi for, hvornår view'et skal refreshes.

Jeg vil ikke anbefale den nuværende trigger-maintained summary som primær løsning. Testene viste, at triggeren ikke håndterer statusændringer fra `Failed` til `Captured`, ændringer fra `Captured` til `Refunded` eller `DELETE`. Den håndterer heller ikke duplicate payments. Det gør det muligt for summary-tabellen at blive forskellig fra de aktuelle data i `payments`.

Derfor er den samlede anbefaling:

**SQL function som standardløsning**, fordi den giver aktuelle resultater uden skjulte side effects og samtidig samler rapporteringslogikken ét sted.

Hvis systemet senere får et meget stort antal rapporteringskald, kan et materialized view overvejes som en optimering. I så fald skal freshness-kravet og refresh-strategien være tydeligt defineret.


## Side-effect trace

Jeg følger her en `INSERT` af en `Captured` payment for at se, hvilke side effects der opstår.

Eksempel:

```sql
INSERT INTO payments (
    id,
    user_id,
    ticket_id,
    external_payment_reference,
    amount,
    currency,
    status,
    created_utc
)
VALUES (
    'PAY-TRACE',
    'USER-1',
    'TICKET-1',
    'gateway-trace',
    36,
    'DKK',
    'Captured',
    '2026-04-29 11:00:00+00'
);
```

Flowet er:

```text
INSERT INTO payments
        |
        v
payments row inserted
        |
        v
AFTER INSERT trigger
        |
        v
add_inserted_payment_to_daily_revenue()
        |
        +--> finder operator via
        |    tickets -> trips -> routes
        |
        v
daily_revenue_by_operator
        |
        v
captured_amount og captured_payments opdateres
```

Selve `INSERT`-operationen ændrer altså ikke kun `payments`. Triggeren foretager også en ekstra ændring i `daily_revenue_by_operator`.

### Side effects

| Step | Handling                                  | Table affected                     |
| ---- | ----------------------------------------- | ---------------------------------- |
| 1    | Payment indsættes                         | `payments`                         |
| 2    | Trigger aktiveres                         | Ingen direkte ændring              |
| 3    | Operator findes via ticket, trip og route | `tickets`, `trips`, `routes` læses |
| 4    | Daily revenue opdateres                   | `daily_revenue_by_operator`        |

Det betyder, at en almindelig payment write har en skjult ekstra skriveoperation.

Det er en fordel, hvis man ønsker meget hurtige rapporteringskald, fordi revenue allerede er beregnet. Til gengæld øges kompleksiteten, fordi payment-logikken og summary-logikken skal holdes synkroniseret.

Testene viste også, at dette kan give problemer. Triggeren håndterede eksempelvis ikke `Failed → Captured`, `Captured → Refunded` eller `DELETE`. Derfor kan `daily_revenue_by_operator` komme ud af sync med `payments`.

Dette er en vigtig grund til, at jeg ikke vil placere den primære reporting responsibility i triggeren.

## Issue

### Duplicate payments kan føre til forkert revenue

Under testene blev der indsat en ny `Captured` payment med samme `external_payment_reference` som en eksisterende payment.

Databasen accepterede betalingen, fordi `external_payment_reference` ikke har en `UNIQUE` constraint.

Det medførte, at revenue blev beregnet som:

| operator_id | revenue_date | captured_amount | captured_payments |
| ----------- | ------------ | --------------: | ----------------: |
| OP-METRO    | 2026-04-29   |           72.00 |                 2 |

Hvis den anden payment var en duplicate delivery fra betalingssystemet og ikke en reel ny betaling, er revenue derfor blevet overrapporteret.

Problemet viser, at reporting ikke alene kan løse alle integrity-problemer. Payment-dataene skal også beskyttes mod duplicate delivery.

En mulig løsning er at gøre `external_payment_reference` unik, hvis domænet garanterer, at denne reference identificerer én bestemt payment.

## Decision record

### Beslutning

Vi vælger **SQL function** som den primære løsning til captured revenue reporting.

### Begrundelse

SQL function'en læser direkte fra `payments`, som er authority for payment-data. Resultatet er derfor aktuelt og kræver ikke en separat summary-tabel.

Vi vælger ikke trigger-maintained summary som primær løsning, fordi testene viste, at den leverede trigger ikke håndterer alle ændringer i payments. Det kan føre til, at summary-data bliver forskellig fra authority.

Materialized view er heller ikke valgt som standard, fordi det kræver en refresh-strategi og derfor kan indeholde stale data. Det kan dog senere bruges som performance-optimering, hvis systemet får et stort behov for hurtige reporting reads.

### Consequences

**Fordele:**

* Aktuelle resultater
* Ingen skjulte writes ved payment inserts
* Ingen separat summary-tabel, der kan komme out of sync
* Reporting-logikken kan genbruges gennem funktionen
* Simpelt at genberegne resultatet ud fra authority

**Ulemper:**

* Revenue skal beregnes ved hvert kald
* Mange eller tunge reporting queries kan give større read workload
* Hvis systemet vokser meget, kan en materialized view senere være nødvendig som optimering

### Opfølgende integrity-fix

Duplicate payment-problemet bør håndteres separat fra reporting-løsningen. Hvis `external_payment_reference` skal være unik i domænet, bør databasen håndhæve dette med en `UNIQUE` constraint.

Det er vigtigt, fordi en reporting-løsning ikke bør forsøge at kompensere for ugyldige eller duplicate payment-data.
