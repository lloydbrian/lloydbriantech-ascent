# Threat model: orders

| Field | Value |
|---|---|
| reviewed_on | 2026-11-10 |
| reviewed_by | Jane Doe |
| method | STRIDE |

## Entry points

| Id | Entry point | Trust boundary | Auth |
|---|---|---|---|
| EP-1 | GET,DELETE /api/items/{id} | internet → api | required |
| EP-2 | POST /api/chat | internet → api → model provider | required |
| EP-3 | GET /api/catalog | internet → api | none |

## Threats

| Id | Entry point | STRIDE | Threat | Mitigation | Status |
|---|---|---|---|---|---|
| TH-1 | EP-1 | E | A user deletes another user's item | Ownership check in `src/items/delete.ts` | mitigated |
| TH-2 | EP-1 | T | A crafted id reaches the file system | Ids are validated as UUIDs in `src/items/delete.ts` | mitigated |
| TH-3 | EP-2 | I | A prompt injection reveals the system prompt | Output filter in `src/chat/guard.ts` | mitigated |
| TH-4 | EP-2 | D | A burst of chat requests runs up the model bill | Rate limit in `src/http/limits.ts` | mitigated |
| TH-5 | EP-3 | D | Unbounded catalog listing exhausts the database | — | accepted (ADR-012) |
| TH-6 | EP-1, EP-2 | S | A stolen session cookie is replayed | Short-lived cookies set in `src/http/session.ts` | mitigated |
| TH-7 | all | R | A user denies having deleted an item | Audit log in `src/items/delete.ts` | mitigated |

## Notes

The model provider is outside the trust boundary: nothing it returns is trusted.
