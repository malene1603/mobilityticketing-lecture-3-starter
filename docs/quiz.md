# Quiz: Functions, procedures, triggers, and materialised results

Use these questions as the Moodle quiz bank. The answer key is kept in `instructor/quiz-key.md` until the quiz has been released.

## Question 1

**Type:** Multiple choice

A PostgreSQL function is declared `IMMUTABLE`. What claim is being made?

A. It may write any table but commits immediately.
B. The same arguments always produce the same result, and the function does not depend on changing database state.
C. It is executed only once per database restart.
D. It may return only scalar values.

## Question 2

**Type:** Multiple choice

When does an `AFTER INSERT FOR EACH ROW` trigger execute?

A. Once when the database starts
B. Once per inserted row after the row operation
C. Once per transaction regardless of row count
D. Only when explicitly called by the application

## Question 3

**Type:** True or false

A materialised view always reflects the latest committed base-table data.

## Question 4

**Type:** Multiple select

Which are risks of trigger-maintained aggregates? Select all that apply.

A. Hidden writes that callers may not know about
B. Additional work and locking on the write path
C. Drift when update, delete, or correction cases are incomplete
D. Guaranteed inability to participate in the transaction
E. Harder replay and debugging if the derivation is not explicit

## Question 5

**Type:** Multiple choice

Why is the supplied payment trigger incorrect after a payment changes from `Captured` to `Refunded`?

A. PostgreSQL cannot update payment rows.
B. The trigger runs only on insert and never subtracts the previous contribution.
C. Materialised views block the update.
D. A foreign key deletes the summary.

## Question 6

**Type:** Multiple choice

What is the most important architectural question before wrapping an insert in a stored procedure?

A. Can the procedure name be shortened?
B. Does it create a meaningful consistency, permission, or domain boundary?
C. Does it avoid all network traffic?
D. Can it replace the table's primary key?

## Question 7

**Type:** Multiple choice

A report may be several minutes behind, but must be reproducible from authoritative data. Which property is most important for a stored summary?

A. It uses the same column names as the API.
B. It can be rebuilt deterministically and its refresh point is observable.
C. It is updated by the longest possible transaction.
D. It contains every operational column.

## Question 8

**Type:** Short answer

What evidence would show that a database trigger has become an architectural dependency rather than a local implementation detail?
