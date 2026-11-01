# Maintenance and Operations Manual: drills fixture

## Backup and restore

| What | How | When | Retention |
|---|---|---|---|
| db volume | `pg_dump` to the backup bucket | nightly | 35 days |
| orders | RDS automated backups | daily | 7 days |

Last restore drill: 2026-10-30 ([record](drills/2026-10-30-db.md)).

## Scheduled maintenance

Quarterly: the failover drill on 2026-10-20.
