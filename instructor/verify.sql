\set ON_ERROR_STOP on
set timezone = 'UTC';

create function pg_temp.assert_reporting_snapshot(
    case_name text,
    requested_operator_id text,
    requested_date date,
    expected_amount numeric,
    expected_count bigint,
    expected_materialized_amount numeric,
    expected_materialized_count bigint,
    expected_trigger_amount numeric,
    expected_trigger_count bigint
)
returns void
language plpgsql
as $$
declare
    direct_amount numeric;
    direct_count bigint;
    function_amount numeric;
    function_count bigint;
    materialized_amount numeric;
    materialized_count bigint;
    trigger_amount numeric;
    trigger_count bigint;
begin
    select coalesce(sum(p.amount), 0), count(*)
    into direct_amount, direct_count
    from payments p
    join tickets t on t.id = p.ticket_id
    join trips tr on tr.id = t.trip_id
    join routes r on r.id = tr.route_id
    where r.operator_id = requested_operator_id
      and p.created_utc::date = requested_date
      and p.status = 'Captured';

    select captured_amount, captured_payments
    into function_amount, function_count
    from captured_revenue_for_day(requested_operator_id, requested_date);

    select coalesce(max(m.captured_amount), 0), coalesce(max(m.captured_payments), 0)::bigint
    into materialized_amount, materialized_count
    from daily_captured_revenue m
    where m.operator_id = requested_operator_id
      and m.revenue_date = requested_date;

    select coalesce(max(d.captured_amount), 0), coalesce(max(d.captured_payments), 0)::bigint
    into trigger_amount, trigger_count
    from daily_revenue_by_operator d
    where d.operator_id = requested_operator_id
      and d.revenue_date = requested_date;

    if direct_amount is distinct from expected_amount
       or direct_count is distinct from expected_count
       or function_amount is distinct from direct_amount
       or function_count is distinct from direct_count
       or materialized_amount is distinct from expected_materialized_amount
       or materialized_count is distinct from expected_materialized_count
       or trigger_amount is distinct from expected_trigger_amount
       or trigger_count is distinct from expected_trigger_count then
        raise exception 'FAIL %: direct=(%, %), function=(%, %), materialized=(%, %), trigger=(%, %)',
            case_name,
            direct_amount, direct_count,
            function_amount, function_count,
            materialized_amount, materialized_count,
            trigger_amount, trigger_count;
    end if;

    raise notice 'PASS %: direct=(%, %), function=(%, %), materialized=(%, %), trigger=(%, %)',
        case_name,
        direct_amount, direct_count,
        function_amount, function_count,
        materialized_amount, materialized_count,
        trigger_amount, trigger_count;
end;
$$;

select pg_temp.assert_reporting_snapshot(
    'baseline OP-METRO', 'OP-METRO', date '2026-04-29',
    36, 1, 36, 1, 36, 1
);
select pg_temp.assert_reporting_snapshot(
    'baseline OP-BUS', 'OP-BUS', date '2026-04-29',
    36, 1, 36, 1, 36, 1
);

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status, created_utc
) values (
    'PAY-CASE-CAPTURED', 'USER-1', 'TICKET-1', 'gateway-case-captured',
    36, 'DKK', 'Captured', '2026-04-29 10:00:00+00'
);

select pg_temp.assert_reporting_snapshot(
    'captured insert', 'OP-METRO', date '2026-04-29',
    72, 2, 36, 1, 72, 2
);

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status, created_utc
) values (
    'PAY-CASE-FAILED', 'USER-1', 'TICKET-1', 'gateway-case-failed',
    50, 'DKK', 'Failed', '2026-04-29 10:05:00+00'
);

select pg_temp.assert_reporting_snapshot(
    'failed insert', 'OP-METRO', date '2026-04-29',
    72, 2, 36, 1, 72, 2
);

update payments
set status = 'Captured'
where id = 'PAY-CASE-FAILED';

select pg_temp.assert_reporting_snapshot(
    'failed to captured correction', 'OP-METRO', date '2026-04-29',
    122, 3, 36, 1, 72, 2
);

update payments
set status = 'Refunded'
where id = 'PAY-CASE-CAPTURED';

select pg_temp.assert_reporting_snapshot(
    'captured to refunded correction', 'OP-METRO', date '2026-04-29',
    86, 2, 36, 1, 72, 2
);

delete from payments
where id = 'PAY-CASE-FAILED';

select pg_temp.assert_reporting_snapshot(
    'delete test data', 'OP-METRO', date '2026-04-29',
    36, 1, 36, 1, 72, 2
);

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status, created_utc
) values (
    'PAY-CASE-DUPLICATE', 'USER-1', 'TICKET-1', 'gateway-capture-0001',
    36, 'DKK', 'Captured', '2026-04-29 10:10:00+00'
);

select pg_temp.assert_reporting_snapshot(
    'duplicate external reference', 'OP-METRO', date '2026-04-29',
    72, 2, 36, 1, 108, 3
);

refresh materialized view daily_captured_revenue;

select pg_temp.assert_reporting_snapshot(
    'after materialized refresh', 'OP-METRO', date '2026-04-29',
    72, 2, 72, 2, 108, 3
);

select rebuild_daily_revenue_for('OP-METRO', date '2026-04-29');

select pg_temp.assert_reporting_snapshot(
    'after deterministic trigger rebuild', 'OP-METRO', date '2026-04-29',
    72, 2, 72, 2, 72, 2
);
