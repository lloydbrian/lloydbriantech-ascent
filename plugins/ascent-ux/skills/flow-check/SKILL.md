---
name: flow-check
description: >-
  Use when asked "can users finish the core flows?", "check for broken links",
  "is anything a dead end?", "does the UI survive a failed request?", "does it
  work in Firefox and WebKit (Safari's engine)?", or when ux-review flags the functional or
  reliable principle. Runs the flow-integrity and reliability checks (UX-F,
  UX-R, UX-P) with the contract's values, walks each core flow in the browser,
  repeats it in every engine the contract lists, and reports with file:line
  evidence. Read-only.
version: 0.3.1
allowed-tools: Read, Grep, Glob
---

# flow-check

The deep check of the functional and reliable principles behind [ux-review](../ux-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. It answers two questions for every core flow: can any user get from the first step to the last, and when something goes wrong on the way (a failed request, a double click, a reload, a lost connection), does the page tell them and keep their work?

The rules are defined in [flow-and-reliability.md](../../references/flow-and-reliability.md): UX-F1–F7 (flow integrity), UX-R1–R7 (reliability as experienced) and UX-P1–P4 (pleasantness, observed, never met). This skill applies them; it never redefines them.

## Rules

- All `ux-review` rules apply: read-only; repository-relative `file:line` evidence; fresh evidence; severities only from the `ux-review` severity table; no personal data; static until the browser confirms.
- **Contract values, not guesses, drive the scripts.** Every option passed to a script comes from a contract key, quoted in the report. A missing key makes its rule unmeasured: say so, and never pass an invented value. The one option with no key is `--base`: read it from the build config (`base` in `vite.config.*`, `basePath` in `next.config.*`, `homepage` in `package.json`), pass it only when one is set, and label it "(detected)" in Step 1. Single-quote every value in the commands; a value that contains a quote, `$`, `;`, a backtick or a newline is a contract error, never passed.
- **The walk navigates; it never acts for real.** It types and submits only when `core_flows[].test_data` names a fixture file and the target is `localhost` (Step 4). Never real data, never credentials, never a link off the site. The fixture must be a file inside the reviewed repository, never `.env*`, a key or a credentials file; name it to the operator before the first fill.
- **The operator's engines are authoritative.** An engine the operator does not run is unmeasured, never passed. A project's own Playwright `projects` config is supporting evidence and is never run.
- **The pleasant principle is never met.** A UX-P rule that passes is "observed".
- **Scripts and data.** `PLUGIN_ROOT` is two directories above this skill's base directory (shown when the skill loads): set it with `PLUGIN_ROOT="<skill base directory>/../.."`.

## Steps

### Step 1 — Contract values

Read the `ux:` section of `.ascent/contract.yml` (or `.claude/contract.yml`) and list the keys this skill uses, with their values or "missing":

| Key | Used by | Missing means |
|---|---|---|
| `core_flows[].pages` | `--core` for both scripts | severities for core files cannot be raised: say "(core flow guessed)" when you infer them |
| `core_flows[].steps` | `--flow` (UX-F3), the walk (UX-F5) | UX-F3 and UX-F5 unmeasured |
| `core_flows[].test_data` | the walk (Step 4) | `none`: the walk navigates only |
| `browsers` | `--browsers` (UX-F7) | UX-F7 unmeasured |
| `engines` | the engine loop (UX-F6) | UX-F6 unmeasured |
| `reliability.draft_fields` | `--draft-fields` (UX-R4) | the default, 6 |
| `reliability.url_state` | `--url-state` (UX-R5) | UX-R5 unmeasured |
| `reliability.offline` | `--offline` (UX-R6) | `optional`: UX-R6 not applied |
| `pleasant.motion_tokens` | `--motion-tokens` (UX-P2) | UX-P2 unmeasured |

With no contract, use ux-review Step 0: propose the keys from the repository, mark every guess `# guess`, and run with the guessed core flows labelled "(core flow guessed)".

### Step 2 — Flow integrity (static)

Run the script from the repository root and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-flow-integrity.sh" --core <each core-flow page> --flow <name>=<step>,<step>,... --browsers <browsers, comma-separated> [--base <deployment base path>] <src or pages directory>
```

- One `--flow` per core flow, with its `steps` in order. A step that is a route (`/teams/3`), or a component with no file-based route, prints a `NOTE`: the walk checks it.
- Each `FAIL` line is a finding at the severity it prints, marked "static".
- Each `NOTE` line (a link built at runtime, an id set at runtime, a route step) is unrated: list it under Other observations and settle it in the walk.

### Step 3 — Reliability and pleasantness (static)

```bash
bash "$PLUGIN_ROOT/scripts/check-ux-resilience.sh" --core <each core-flow page or component> [--url-state <each url_state page>] [--offline <required|optional|none>] [--draft-fields <n>] [--motion-tokens] <src directory>
```

- Pass as `--core` the files that hold a core flow's forms and requests, not only its pages: in a single-page app those are the components the routes render.
- For UX-R1 and UX-R2 the script also reads the local modules a file imports (relative imports, one level) and names them in the finding: a guard there, or a module that shows every failure it catches, already counts. Anything further away, and a UX-R3 or R4 draft or retry outside the file, is not followed: before rating a UX-R1, R2, R3 or R4 `FAIL`, read the hook or service the file imports. When it does the work, the finding is withdrawn and the reason given in one line.
- A UX-P rule that passes is "observed"; one that fails is a finding.

### Step 4 — The walk (UX-F5, browser)

When the Playwright tools (`mcp__plugin_playwright_playwright__*`) are available, the walk is **not optional**. It runs on `file://` pages or a `localhost` server (`localhost`, `127.0.0.1` or `[::1]`); on a URL the operator names it navigates only, with no submit and none of the localhost-only checks below. The same rules as ux-review Step 4 apply: if `file://` is blocked or the app needs a dev server, ask the operator to start one, give the exact command, and **wait for the answer**.

For each core flow, from its first step:
1. `browser_navigate` to the step. Reach the next step the way a user would: `browser_click` on the link or control that leads there, found with `browser_snapshot`. A step reached only by typing its URL is a UX-F3 finding (no way forward), confirmed.
2. When `test_data` names a fixture file and the target is `localhost`, fill the form from that file (`browser_fill_form`, using the selectors it lists for that step: the format is in the contract template) and submit. Otherwise navigate only, and say which steps a submit would have reached.
3. After each step, read `browser_network_requests` and `browser_console_messages`. A same-origin 4xx or 5xx, or an uncaught error, is a UX-F5 finding with the step, the URL and the message (never a token or a personal value from it).
4. On each step, check the way back or out (Back, Cancel, a link elsewhere) with `browser_navigate_back` or a click.

Walk mechanics, from the trials:
- **Confirm the port first.** A dev server whose port is taken starts on the next one (Vite moves 3000 to 3001). Ask the operator for the URL it printed, or read the listening ports; never assume the configured one.
- **Navigate; do not fetch from the page.** A strict Content Security Policy (`default-src 'none'`) blocks `fetch` in the page, and the console errors it raises are yours, not the app's. Check a link by navigating to it.
- **Wait for `load`, not network idle.** A page that polls or keeps a stream open never goes idle; wait for `load` and a short settle.
- **A failed request is a test.** When the operator serves only the front end, its API calls fail: read what the page then shows. A failure that looks like an empty list ("nothing here yet") is a confirmed UX-R2 finding; a visible "server unreachable" withdraws a static one.
- **Check the dead scripts.** A `pageerror` on load (a syntax error in an inline script) is a UX-F5 finding even when every link resolves: the static checks do not parse JavaScript.

Reliability in the browser, on `localhost` only:
- **Back and refresh (UX-R5):** on each `url_state` page, change a filter or tab, then `browser_navigate_back` and reload. The view state comes back from the URL, or it is a confirmed UX-R5 finding.
- **Double submit (UX-R1):** only with `test_data`: after a submit, `browser_snapshot` shows the control disabled or busy until the response.
- **Offline (UX-R6):** only when `reliability.offline` is `required`: `browser_evaluate` with `window.dispatchEvent(new Event('offline'))` and check that the page says so. The event does not change `navigator.onLine`, so a page that reads only that stays silent here: then the static result stands, and the operator checks it with the browser's network set to offline.

Without Playwright, say "walk not run: <reason>". Every UX-F and UX-R finding stays "static", and the rating carries "(static only)".

### Step 5 — The engine loop (UX-F6, browser)

The Playwright MCP server runs one engine per launch. For each engine in `ux.engines` after the first:
1. Ask the operator to add a Playwright server for that engine, as the plugin README's [Other engines](../../README.md#other-engines) shows, and **wait for the answer**. Its tools carry the server's name (`mcp__playwright-firefox__browser_navigate`) and work the same way.
2. Repeat the walk (Step 4) and ux-review Step 4's tree, keyboard and reflow checks on each core flow.
3. A failure that blocks a core flow in one engine is High (UX-F6); a layout or focus defect that does not block it is Medium.

Engine differences, from the trial. None of these is a finding:
- **WebKit on macOS: Tab skips links.** Like Safari's default, Tab reaches only form controls; Option+Tab (`Alt+Tab` in `browser_press_key`) reaches links too. Check keyboard reach in WebKit with `Alt+Tab`.
- **Firefox focuses scrollable regions.** A scrollable container that takes focus in Firefox only is the engine's behavior.
- **Console errors differ.** WebKit and Chromium log a failed request to the console; Firefox does not. Read UX-F5 from `browser_network_requests` in every engine, never from the console alone.
- **WebKit can ask for a localhost page's images over https.** On a first visit it may request subresources as `https://127.0.0.1:<port>/…` and fail with a TLS error. Reload once: report it only if it comes back.

An engine the operator does not run is listed as "unmeasured: not run", never passed. When the project has its own Playwright config with `projects` for several engines, cite it as supporting evidence and suggest the operator runs it; never run it yourself.

After the walk, check with Glob whether `.playwright-mcp/` exists in the reviewed repository; the server writes its snapshots and console logs into the directory Claude Code runs from, which is the reviewed repository when the session runs there (never `git status` there: an untrusted repository's git config can run commands). If it appeared, tell the operator and suggest adding it to `.gitignore`. Never delete files in the reviewed repository.

### Step 6 — Report

```
flow-check: <functional: met | at risk | unmeasured>, <reliable: met | at risk | unmeasured>, <pleasant: observed | at risk> [(static only)] — <H> High, <M> Medium, <L> Low
Contract values (Step 1): <key: value or missing, one per line>

Findings, most severe first: <ux-review X<n> blocks, with the rule id (UX-F3) as the criterion>

Other observations (unrated): <NOTE lines and withdrawn findings, one line each>

Flow integrity (Step 2): <script output, verbatim>
Reliability and pleasantness (Step 3): <script output, verbatim>
Walk (Step 4): <per flow: step | reached by | network and console | way out>, or "not run: <reason>"
Engines (Step 5): <per engine: run | not run (unmeasured)>
Recommended next: <accessibility-audit when the walk found keyboard or name failures; design:ux-copy for unclear error messages>
```

A principle is **met** only when its contract keys are present, every rule in it has run (static and, where the rule is a browser rule, in the browser), and none failed. A rule left unmeasured makes the principle unmeasured; a failure makes it at risk.

## What this skill does not do

- Fix links, add retries or write drafts. Fixes go through the delivery loop (`ascent-delivery`) and the operator's runbook.
- Run the project's end-to-end suite, load tests or uptime checks: `ascent-quality` checks the suite exists and CI runs it, and `ascent-ops` owns availability.
- Judge accessibility criterion by criterion: that is [accessibility-audit](../accessibility-audit/SKILL.md).
