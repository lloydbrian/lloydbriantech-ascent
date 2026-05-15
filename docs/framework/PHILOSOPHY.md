# ASCENT Philosophy

The set of beliefs about software, teams, and time that produced ASCENT. If you disagree with the philosophy, the framework's choices will not make sense.

---

## The problem ASCENT exists to solve

Most engineering frameworks optimize for Day 0 — the first commit, the first scaffold, the moment of greatest excitement and lowest accumulated debt. The frameworks are usually elegant on Day 0 and quietly degrade afterward.

The interesting problem is not Day 0. The interesting problem is Day 1000 — when:

- The original engineer has moved on
- Three teams have touched the codebase
- Two production incidents have left scar tissue in the form of patches no one understands
- The CI build takes nine minutes because no one has had time to investigate why
- The README references a deploy procedure that hasn't worked since the migration off Heroku
- The docs say "see the threat model" but no one can find the threat model
- The new engineer can't get the dev environment running without a half-day pairing session
- Three different log formats coexist, each from a different era's "we should improve logging"
- The phase plan from 2024 is still referenced but bears no resemblance to what's actually being built

This degradation is not the result of poor engineering. It is the result of normal engineering exposed to normal time. Skilled engineers under fatigue, handoff, and time pressure make the same compromises everyone makes — and the compromises accumulate.

ASCENT is built on the belief that **most software quality problems are not problems of skill. They are problems of consistency under fatigue, handoff, and time pressure.** The framework is structurally suspicious of the moment where consistency erodes — and it puts machinery in place to refuse that erosion.

## Five beliefs ASCENT is built on

### Belief 1 — Decisions decay into lore unless they are written down

Every project has decisions whose rationale is implicit in the code and explicit in the head of the engineer who made them. When that engineer moves on or forgets, the decisions become folk wisdom — preserved out of caution, modified out of confusion, eventually reversed when someone with more authority than context decides to "clean it up."

ADRs are the antidote. A decision with a written ADR can be questioned, argued with, and superseded — but it cannot be silently lost.

ASCENT enforces ADR discipline because the cost of writing an ADR is one hour and the cost of losing a decision is one career-spanning argument.

### Belief 2 — Documentation that no one reads is worse than no documentation

Empty documentation files create the illusion of coverage. A folder labeled `docs/security/` containing fifteen empty templates teaches future contributors that this project's docs are theater. Once they learn that, they stop reading the real docs too.

ASCENT generates the minimum viable documentation set on Day 0 (about ten files) and provides a `make doc-stub TYPE=<name>` mechanism for adding the rest on demand. The framework's bias is **build the doc when someone needs to write it, not before**.

This is in deliberate opposition to the industry pattern of shipping every doc-shaped artifact a "mature" project might have, regardless of whether anyone will ever fill them in.

### Belief 3 — Operator vocabulary is sacred

When an engineer types a command, they have made a small commitment to a name. The name is now in their fingers. Two months later, when someone "improves" the project by renaming `make dev` to `make dev-up`, the engineer's fingers betray them — and the betrayal happens during a production incident.

ASCENT's vocabulary discipline (no aliases, canonical names from Day 1, stub-first for deferred work) is not pedantry. It's respect for the muscle memory of the engineers who use the framework.

### Belief 4 — Frameworks should expose principles, not hide them

A framework that does everything for you teaches nothing. The next time you hit a problem the framework didn't anticipate, you're worse off than if you'd never used it — because you've now learned to defer to a tool instead of understanding the underlying patterns.

ASCENT's reference modules and ADRs exist to make the principles visible. The framework is opinionated about what's right, but it's transparent about why. A skilled user should be able to read the framework's source and learn engineering, not learn the framework.

This is in tension with maximum convenience. ASCENT chooses transparency.

### Belief 5 — A framework's job is to make consistency cheaper than inconsistency

The mistake most frameworks make is trying to make inconsistency impossible. This produces brittle systems that work brilliantly when used as intended and catastrophically when used as needed.

The better goal is to make consistency the path of least resistance. When the framework's defaults are sensible, the cost of deviating is the cost of writing an ADR — which is one hour. The cost of conforming is zero, because the conforming behavior is what's already there.

ASCENT's invariants are defaults, not laws. A project-level ADR can supersede any of them. The framework's job is to make the default the easy path and the override an explicit, traceable choice.

## What ASCENT is not

### ASCENT is not a starter kit

A starter kit answers the question "how do I get going?" ASCENT answers the question "how do I stay going?" The two are related but distinct. The paired starter repo (`lloydbriantech-ascent-starter`) is the starter-kit answer; the framework itself is the staying-going answer.

### ASCENT is not low-code

The framework does not abstract away the application. It scaffolds the architecture and the conventions; the application logic, the domain model, the UI flows — these remain the engineer's work. ASCENT is opinionated about the scaffolding around the application, not about the application itself.

### ASCENT is not a methodology

It is not Agile, it is not SAFe, it is not Shape Up. It does not prescribe sprint length, ceremony cadence, or estimation technique. It is a framework for *what gets built and how*, not for *how the team decides what to build*.

You can use Agile with ASCENT. You can use Shape Up with ASCENT. You can use no methodology with ASCENT. The framework is neutral on these questions.

### ASCENT is not magic

The framework codifies hard-won patterns from the author's own work. It does not invent new architectures. If you read the OpenClaw codebase that informed ASCENT, you'll find every pattern the framework enforces was already there in a working project. The framework's contribution is making those patterns repeatable across projects without re-deriving them each time.

### ASCENT is not for everyone

The framework is opinionated. It will frustrate engineers who want different opinions. It will be unhelpful for projects whose shape doesn't fit (mobile apps, ML training infrastructure, data pipelines, libraries). It will be overhead for projects with a one-person team and a six-week lifespan.

ASCENT is for projects where engineering discipline matters more than schedule pressure — and where someone is willing to invest in that discipline up front to harvest the returns over years.

## The "better than industry" goal

The author's stated ambition is for ASCENT projects to be observably better than industry norms — not in marketing but in measurable engineering quality. The metrics that would substantiate this claim:

- Time from `gh repo create` to running dev stack: target under two minutes
- Time from "I want to add X" to "X is in production": target a phase, not a quarter
- Time for a new contributor to make their first useful commit: target one day
- Months between framework-related production incidents: target many
- Months between someone asking "why does the code do this?" and finding the answer: target zero

These are aspirational. The framework's job is to make them achievable. The author's job is to demonstrate they're achieved.

## Why the framework dogfoods itself

ASCENT applies ASCENT to its own repository. The Makefile is the operator vocabulary; the ADRs are in the canonical format; the docs are persona-segmented; the contribution model uses Conventional Commits and semver. This is not a stunt.

If the framework can't be built using its own principles, the principles are wrong. Dogfooding is the cheapest possible validation that the framework is internally consistent.

It also means every commit to this repository tests a small slice of the framework's claims. If you find ASCENT's own repo violating an ASCENT principle, that's a bug — file it.

## Reading further

If this philosophy resonates, read:

- [`PRINCIPLES.md`](PRINCIPLES.md) — the fourteen invariants the philosophy produces
- [`SCOPE.md`](SCOPE.md) — what ASCENT is for and what it isn't
- [`ARCHITECTURE.md`](ARCHITECTURE.md) — how the framework is built
- [`ROADMAP.md`](ROADMAP.md) — where the framework is heading

If this philosophy doesn't resonate, save yourself the time and use a different framework. ASCENT is not trying to be universal. It is trying to be right for the projects it's right for.
