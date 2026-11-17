# Acceptance: <change title>

**Change:** <slug> · **Runbook:** <runbook path> · **Drafted:** <YYYY-MM-DD>, criteria and evidence only

Claude drafted the criteria (delivery-loop Step 1) and their evidence (Steps 3 and 5). **Only a person fills in "Accepted by" and "Accepted on"**, after checking the criterion on beta. Claude never fills them in, and never on the person's behalf.

`check-acceptance.sh` must pass before the production step of the runbook; a record with an empty, placeholder or unlisted acceptor stops prod.

| # | Criterion | Evidence | Accepted by | Accepted on |
|---|---|---|---|---|
| 1 | <criterion, as confirmed in Step 1> | <tests/path/to.test.js:42, or manual: what was checked, where> | | |
| 2 | <criterion> | <evidence> | | |

How to fill it in:

- **Evidence** is a test at `path:line` (or `path:line-line`) inside the repository, or `manual: <what was checked, where>`. Several items are separated by `;`.
- **Accepted by** is the accepting person's name or handle. When the contract lists `delivery.acceptors`, it is one of them.
- **Accepted on** is the date the person accepted it, `YYYY-MM-DD`.
