# Quiz answer key

## Question 1

Correct answer: B.

The volatility declaration is a contract with the optimiser. A function that reads changing database state should not be marked `IMMUTABLE`.

## Question 2

Correct answer: B.

A row-level trigger executes once for every affected row after that row operation. A statement-level trigger has different semantics.

## Question 3

Correct answer: False.

A materialised view changes when it is refreshed, not automatically after every base-table write.

## Question 4

Correct answers: A, B, C, and E.

A trigger participates in the surrounding database transaction, so D is false. The other risks remain important.

## Question 5

Correct answer: B.

The supplied trigger runs only on insert and never subtracts the previous contribution.

## Question 6

Correct answer: B.

Database programmability is useful when it establishes a real consistency, permission, or domain boundary. A thin wrapper may otherwise add another interface without reducing risk.

## Question 7

Correct answer: B.

A derived read model is trustworthy when its source, derivation, refresh state, and rebuild path are explicit.

## Question 8

Expected answer: Other components or reports rely on the trigger's side effects, correctness, or timing. Evidence may include callers that do not perform the summary write, tests that depend on the trigger, or reports that read the trigger-maintained table.

Full credit requires both reliance by another part of the system and concrete evidence of that reliance.
