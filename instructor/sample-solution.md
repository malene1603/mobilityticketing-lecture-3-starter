# Sample solution and self-assessment

Release after the first implementation submission deadline.

## Reference experiment

The experiment starts with one captured payment of 36 DKK, then applies a captured insert, a failed insert, a failed-to-captured correction, a captured-to-refunded correction, a delete, and a duplicate external reference. The materialised view is intentionally not refreshed until the refresh checkpoint.

| Mechanism | After captured insert | After refund correction | Recovery or rebuild |
| --- | --- | --- | --- |
| Direct aggregate query | Immediately shows the new amount | Immediately removes the refunded amount | Recomputed from authoritative rows on every read |
| SQL function over base tables | Same result as the direct query | Same corrected result | Recomputed; the function stores no copy |
| Materialised view | Stale until refresh | Still stale until refresh | `REFRESH MATERIALIZED VIEW`; freshness needs a schedule and monitoring |
| Insert-only trigger summary | Immediately adds the new amount | Incorrectly retains the contribution | Needs transition and delete logic, or a deterministic rebuild |

The verification script also shows that a duplicate external reference is accepted by the weak starter schema. Both the direct aggregate and the trigger count the duplicate. That is an integrity and workflow decision, not something to hide behind the reporting mechanism.

## Recommendation

For the stated delayed-reporting workload:

- keep `payments` as the authority;
- expose the direct aggregate through `captured_revenue_for_day` for low-volume, correctness-oriented reads;
- use `daily_captured_revenue` for delayed reporting when measured report cost justifies a stored result;
- refresh the materialised view through one observable scheduled job;
- do not treat the supplied insert-only trigger table as authoritative;
- if the trigger table is retained as an experiment, provide a deterministic rebuild and compare it regularly with the base aggregate.

This design keeps report maintenance out of the payment write path. The derived result can be rebuilt from PostgreSQL, and its freshness can be stated as a service-level expectation.

## Consistency check

After the declared refresh target, the following query should return no rows. Differences before refresh are expected.

```sql
with authoritative as (
    select
        r.operator_id,
        p.created_utc::date as revenue_date,
        sum(p.amount) as captured_amount,
        count(*) as captured_payments
    from payments p
    join tickets t on t.id = p.ticket_id
    join trips tr on tr.id = t.trip_id
    join routes r on r.id = tr.route_id
    where p.status = 'Captured'
    group by r.operator_id, p.created_utc::date
)
select
    coalesce(a.operator_id, m.operator_id) as operator_id,
    coalesce(a.revenue_date, m.revenue_date) as revenue_date,
    a.captured_amount as authoritative_amount,
    m.captured_amount as materialised_amount,
    a.captured_payments as authoritative_payments,
    m.captured_payments as materialised_payments
from authoritative a
full join daily_captured_revenue m
    using (operator_id, revenue_date)
where a.captured_amount is distinct from m.captured_amount
   or a.captured_payments is distinct from m.captured_payments;
```

## Why the stored procedure is optional

A procedure that merely wraps one insert may add another interface without establishing a meaningful responsibility. It becomes more defensible when it defines a permission boundary, a domain transaction, or a consistency boundary that callers should not reproduce.

## Example responsibility decision

**Decision:** Use a scheduled materialised view for monthly reporting and keep the base SQL aggregate as the correctness reference.

**Reason:** Reports may be delayed, while payment writes are correctness-critical. A scheduled refresh makes staleness explicit and keeps report maintenance out of the payment transaction.

**Rejected alternative:** The supplied insert-only trigger is immediately fresh for new captured rows, but it drifts on refunds and status corrections and adds hidden work to every payment insert.

**Operational requirement:** Record the last successful refresh and alert when it exceeds the reporting freshness target.

## Expected evidence

- all four mechanisms agree after initial backfill;
- the materialised view becomes stale after a source change and correct after refresh;
- the insert-only trigger diverges after at least one correction or delete;
- the chosen mechanism has a named authority, freshness rule, and rebuild path.

## Common mistakes

- Calling a function stored data. A SQL function over base rows stores logic, not the aggregate result.
- Claiming a materialised view is current without refreshing it.
- Testing only inserts and skipping status transitions or refunds.
- Adding trigger branches without explaining how a damaged summary is repaired.
- Choosing only by speed and ignoring coupling, corrections, observability, and recovery.

## Self-assessment

Score 0 to 2 for each:

1. The experiment reproduces at least one disagreement between mechanisms.
2. The recommendation identifies authority, freshness, and rebuild behaviour.
3. Corrections, refunds, and duplicate gateway references are tested.
4. The selected mechanism is justified from the reporting workload rather than feature preference.

Request lecturer feedback only when two mechanisms remain equally defensible after a concrete workload assumption and failure comparison have been supplied.
