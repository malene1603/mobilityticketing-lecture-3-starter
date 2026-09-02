begin;

create or replace function rebuild_daily_revenue_for(
    requested_operator_id text,
    requested_date date
)
returns void
language plpgsql
as $$
begin
    delete from daily_revenue_by_operator
    where operator_id = requested_operator_id
      and revenue_date = requested_date;

    insert into daily_revenue_by_operator (
        operator_id, revenue_date, captured_amount, captured_payments
    )
    select
        r.operator_id,
        p.created_utc::date,
        sum(p.amount),
        count(*)
    from payments p
    join tickets t on t.id = p.ticket_id
    join trips tr on tr.id = t.trip_id
    join routes r on r.id = tr.route_id
    where r.operator_id = requested_operator_id
      and p.created_utc::date = requested_date
      and p.status = 'Captured'
    group by r.operator_id, p.created_utc::date;
end;
$$;

commit;
