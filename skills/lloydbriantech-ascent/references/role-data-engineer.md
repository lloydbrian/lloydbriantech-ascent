# role-data-engineer

> The data-engineer role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model.

## What this role owns

The data-engineer owns the data layer's shape and behavior. Schema decisions, index discipline, migration safety, query performance, data-quality enforcement.

Specific responsibilities:

- **Schema design** — table shapes, column types, constraints, relationships
- **Indexing** — what's indexed, why, and the trade-off accepted (writes for reads)
- **Migration safety** — schema changes that don't break running services
- **Query optimization** — making the slow queries fast, before they're a problem
- **Data quality** — constraints, checks, and observability on the data itself

## When this role engages

| Trigger | Engagement |
|---|---|
| New project | Initial schema design; the architect engages this role at design time |
| Schema change (per [feature-lifecycle.md](feature-lifecycle.md) Stage 2 trigger) | Pair with [role-architect.md](role-architect.md) on the design; pair with [role-developer.md](role-developer.md) on the migration |
| Query performance degradation | Investigate; add indexes, restructure queries, or surface the design issue back to architect |
| Migration in production | Author the migration plan with explicit safety properties (online, reversible, bounded duration) |
| New data source | Schema design for ingestion; data-quality checks on landing |

## Key practices

### Schema design

Decide normalization vs. denormalization at design time, not later. Normalized for write-heavy workloads with clear entity boundaries; denormalized for read-heavy workloads where the JOIN cost is the bottleneck.

Column types are precise: `VARCHAR(255)` is rarely right; `TEXT` for unbounded user input, specific lengths for structured identifiers. Constraints (NOT NULL, CHECK, FOREIGN KEY) live in the schema, not in application code — the database enforces invariants the application can forget.

### Index discipline

Indexes accelerate reads at the cost of write speed and storage. Every index is justified:

- The query it accelerates exists and matters
- The cardinality of the indexed column is high enough to help
- The write-amplification cost is acceptable

An unjustified index is technical debt. A justified index has a comment in the migration explaining why.

### Migration safety

Production schema changes follow the **online migration pattern**:

1. **Add** new columns or tables without breaking existing readers (NULL default; existing application code ignores)
2. **Backfill** asynchronously, in batches, with monitoring
3. **Switch** application code to read from the new shape
4. **Drop** old columns / tables after the switch is stable

Each step is independently shippable and reversible. Never combine add and drop in one migration; the rollback path becomes destructive.

Migrations are bounded: a step that takes hours of table lock is not online. If it can't be made online, the architect engages on a phased approach.

### Query optimization

Before optimizing: measure. The query plan tells the truth; intuition about what's slow is wrong as often as it's right.

When optimizing:

- Indexes first (cheapest)
- Query restructuring second (no schema change)
- Materialized views or aggregates third (cache concern)
- Denormalization fourth (last resort; requires architect engagement)

### Data quality

Data quality is enforced at the schema (constraints) and observed at the application boundary (checks on ingestion). Bad data that lands in the database costs more to fix than the constraint that would have rejected it.

Observability for data: row counts, fresh-data lag, NULL rates on required-by-convention columns. The `ascent-data-health` skill (lands in scaffolded projects) surfaces these.

## Hand-offs

**Upstream (data-engineer receives from):**

- [role-architect.md](role-architect.md) when a schema-touching feature is designed
- [role-developer.md](role-developer.md) when a query underperforms or a data-quality issue surfaces

**Downstream (data-engineer hands to):**

- `role-developer.md` — the schema and any new query patterns
- `role-devops.md` — migration plans that need scheduling and monitoring

## Anti-patterns

- **`VARCHAR(255)` as default.** Type laziness. Either the field is unbounded text or it has a real maximum derived from the domain.
- **Indexes added without measurement.** Speculative indexes accumulate, slow writes, and consume storage. Justify each one.
- **Combined add-and-drop migrations.** Rollback becomes destructive. Split into reversible steps.
- **Application-enforced constraints.** Uniqueness, foreign-key integrity, NOT NULL — these belong to the database. Application code forgets; databases don't.
- **Migrations longer than the deploy window.** Schema changes that lock tables for hours break the online-migration property. Engage the architect.
- **JOINs through the application.** Fetching rows from one table and looking up rows from another in code, instead of a JOIN. The database is faster; let it do the join.

## What this role doesn't own

- **Application-level data flow.** That's [role-developer.md](role-developer.md). The data-engineer owns the data; the developer owns the code that reads and writes it.
- **AI model training data.** That's [role-ai-engineer.md](role-ai-engineer.md), even if it lives in the same database.
- **Backup and disaster recovery.** That's [role-devops.md](role-devops.md). The data-engineer specifies what needs to survive; devops operates the survival mechanism.
- **Data privacy classification.** That's [role-cybersecurity.md](role-cybersecurity.md). The data-engineer enforces; cybersecurity decides what to enforce.

## Cross-references

- `feature-lifecycle.md` Stage 2 — when schema changes engage this role
- The `ascent-data-health` skill — runtime data-quality observability in scaffolded projects
