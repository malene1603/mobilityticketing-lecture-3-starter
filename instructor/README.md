# Instructor materials

Release this folder after the first implementation submission deadline.

The sample solution deliberately does not call one mechanism universally best. It demonstrates observable behaviour and recommends a bounded design for a workload where delayed reporting is acceptable.

## Run the reference solution

Start from a clean container so that the seed data and fixed test identifiers are predictable:

```bash
docker compose down
docker compose up -d
docker compose exec -T postgres psql -U mobility -d mobility < instructor/migrations/020_reporting_function.sql
docker compose exec -T postgres psql -U mobility -d mobility < instructor/migrations/021_daily_revenue_trigger.sql
docker compose exec -T postgres psql -U mobility -d mobility < instructor/migrations/022_daily_captured_revenue.sql
docker compose exec -T postgres psql -U mobility -d mobility < instructor/migrations/023_rebuild_daily_revenue.sql
docker compose exec -T postgres psql -U mobility -d mobility < instructor/verify.sql
```

The verification script should finish with `PASS` notices for the baseline, insert, correction, delete, duplicate-delivery, refresh, and deterministic-rebuild cases.
