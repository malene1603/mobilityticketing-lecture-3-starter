# Asynchronous workshop: Trace the hidden write

## Format

Fully asynchronous Moodle Workshop. Each student or established project group submits a comparison of the reporting mechanisms and one captured disagreement. Moodle releases peer submissions after the deadline. Students review two submissions and then revise their responsibility decision. No plenary or shared execution window is required.

## Expected student time

80 minutes.

## Preparation

Each student or established project group must have all four reporting approaches running and one case where their results differ before submitting.

## Phase 1: One payment, all consequences, 15 minutes

Draw a sequence beginning with one `INSERT INTO payments`. Include:

- constraints checked;
- trigger execution;
- summary-table writes;
- locks or rows touched, where observable;
- commit or rollback;
- a later materialised-view refresh;
- application-visible results.

## Phase 2: Failure cards, 20 minutes

Assign one card per group:

1. The trigger raises an error after the payment row is inserted.
2. A captured payment is later refunded.
3. The same external gateway notification is processed twice.
4. A route is transferred to another operator after historical payments exist.
5. The materialised-view refresh fails during the reporting job.

For the assigned case, explain the state of the base data and every derived representation.

## Phase 3: Implementation correction, 20 minutes

Make one targeted change that improves the assigned case. Examples include a uniqueness rule, a correction-aware trigger, an explicit refresh transaction, or a rebuild script. Do not attempt to solve every case.

## Phase 4: Architecture hearing, 20 minutes

Each group presents a two-minute recommendation. Peers score 0 to 2 on:

- source of truth is explicit;
- correction behaviour is covered;
- freshness matches the workload;
- write-path cost is acknowledged;
- the derived result can be verified or rebuilt.

## Phase 5: Individual exit note, 5 minutes

Complete this sentence:

> Database-side logic is justified here when ..., but I would avoid it when ...

## Moodle completion

One group sequence diagram, one corrected experiment, one peer score sheet, and one individual exit note.
