# AI design guide

What makes an AI application worth keeping, in the order a team decides it. `ai-design` works from this page; `ai-review` and the `ai-reviewer` agent judge against it. The rules that files can show are in [ai-rules.md](ai-rules.md); this page also covers what files cannot.

## 1. Start from the work, and its baseline

An AI application earns its place against the way the work is done today. Before any design: what the work is and who does it; how it is measured now (minutes per case, errors per hundred, cases a day), on a date; how many cases a day; whether a result can be checked, and by whom. The baseline and the target it must reach go in the design record (AI-V1). A pilot measures the application against that baseline, the same way, before a production launch (AI-V2). Without a baseline, "it works" means "it runs".

## 2. The least autonomy that does the job

Three rungs, lowest first. Recommend the lowest that fits, and say why each lower one does or does not:

1. **A single prompt.** One model call, no tools. Classifying, drafting, extracting, summarising: most work stops here.
2. **A fixed workflow.** Steps known in advance, in code: a chain (classify, then draft), a router (one of several prompts by type), parallel calls with a vote. Code decides the order; the model fills each step.
3. **An agent.** The model picks its own next step and calls tools until it is done. Choose an agent only when the steps cannot be known in advance, and only when every irreversible action has a limit enforced in code and a person's approval.

Signs of more autonomy than the job needs: an agent loop that always runs the same steps in the same order (a workflow); a tool the model calls on every run with the same arguments (a function call in code); a model deciding something a rule in code could decide (a threshold, a lookup, a permission).

## 3. Tools

Each tool the model can call is declared: its name, whether it can be undone, whether a person approves it, and the file whose code enforces its limit (AI-A2, AI-A3).
- **Reversible or not.** A tool that cannot be undone, costs money or acts outside the system (sends an email, refunds, deletes, posts) is irreversible. An application with one is tier 3 (GOV-A5, AI-A5). A tool that only reads, inside or outside (a search, a fetch, a database query), changes nothing and is reversible; what its query sends out is a data question for the threat model (SEC-T5), not a reason to approve each call.
- **Limits in code, never in the prompt.** "Never refund more than 50" in a prompt is a request; `if amount > MAX_REFUND: raise` is a limit. The `limit enforced in` file names the tool and holds the check.
- **A clear contract for the model.** A tool's name says what it does; its description says when to use it and when not to; its parameters have types and examples; its errors say what to do next ("order not found: ask for the order number"), because the model reads them.
- **Few tools.** Each added tool is one more way to be wrong. Prefer one tool with a clear purpose to three overlapping ones.

## 4. Limits and the off switch

A workflow or an agent declares the most steps, tokens and seconds one task may use, and every model call sets an output token limit (AI-A4): the most one answer, and one task, can cost is bounded. A flag turns the AI off without a deploy, and the code reads it (AI-K1): when the model misbehaves at 2 a.m., someone can stop it.

## 5. Models

Name the model in one place in code (AI-M1), so a change of model is one reviewed edit, and declare a fallback that is wired (AI-M2): models are retired and have outages. At tier 3, record why this model, against which others, on the golden set (AI-M3).

## 6. Prompts and the golden set

Prompts live in files, one a prompt, so a change shows in review (AI-P1). The golden set is the application's own test set, in four slices (AI-G1, [evidence-formats.md](evidence-formats.md)):
- **typical**: the everyday cases, in proportion;
- **edge**: empty, very long, the wrong language, ambiguous;
- **attack**: injected instructions, attempts to leak data or misuse a tool, held to its own target (AI-E3);
- **regression**: every failure found in production, added as a case, so it stays fixed (AI-L2).

Eval results are fresh, newer than the last prompt or golden-set change, and meet their targets (AI-E1–E4). A golden set with a version lets a result name what it ran on.

## 7. Retrieval

When the application retrieves: measure retrieval on its own (faithfulness, context recall), against targets (AI-R1), and give every source an owner and a review date (AI-R2). A stale source answers wrongly with confidence.

## 8. Running it

Trace model calls (AI-O1), and decide what the traces keep: what is stored, what is redacted, what is dropped (AI-O2), because prompts and outputs hold personal data. Route model calls through a gateway with allowed models, a budget, an alert and rate limits (AI-C1, AI-C2); alert on the cost of one task (AI-C3). Fine-tuning has a spend cap, a personal-data check of its dataset and an eval against the golden set (AI-F1).

## 9. The improvement loop

A person looks at the evidence again by a date (AI-L1). Each failure found becomes a regression case (AI-L2). The tier is reviewed by its own date (GOV-A4).

## 10. What files cannot show

Recommend these, and write them into the ADR as recommendations, never as findings: that the people who use the output are trained to check it; that a person can override or undo the AI's output in one step; that users can report a bad output and someone reads the reports; that the people affected by a decision about them know AI took part.
