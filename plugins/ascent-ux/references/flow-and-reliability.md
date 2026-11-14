# Flow integrity, reliability and pleasantness: UX-F, UX-R and UX-P

The rules behind the functional, reliable and pleasant principles of `ux-review` ([ADR-022](../../../docs/framework/DECISIONS/ADR-022-ux-principles-flow-integrity-and-reliability.md)). This file defines them; `check-flow-integrity.sh` (UX-F), `check-ux-resilience.sh` (UX-R, UX-P), `flow-check`, `ux-review` and the `ux-reviewer` agent apply them. Severities come only from the `ux-severity` table in `ux-review`.

**Static** rules run in a script and are labelled "static". **Browser** rules run in the Playwright pass (Step 4 of `ux-review`, or `flow-check`), on `file://` or `localhost` (on a URL the operator names, navigation only), and override a static result for the same element. A rule whose contract key is missing is **unmeasured**, never met.

## The ladder

| Principle | Lenses | Families | Status values |
|---|---|---|---|
| 1. Functional | Flow integrity; Usability heuristics (task completion: UX-H3, UX-H5) | UX-F, UX-H | met, at risk, unmeasured |
| 2. Reliable | Reliability; States and content; Performance UX | UX-R, UX-H1, UX-H9 | met, at risk, unmeasured |
| 3. Accessible | Accessibility; Design system (contrast, motion with a reduced-motion path) | UX-U, WCAG 2.2 | met, at risk, unmeasured |
| 4. Pleasant | Design system (motion tokens), Usability heuristics (UX-H8), dark patterns, tone | UX-P, UX-H8 | observed, at risk (never met) |

The report names the lowest principle at risk, and lists the unmeasured principles apart with the key each one needs. The ladder orders the report; it never changes a finding's severity.

## UX-F: flow integrity (functional)

| Rule | Kind | Check | Evidence read |
|---|---|---|---|
| UX-F1 | static | every relative `href` and `src` of a page-level link, and every form `action`, resolves to a file in the scanned tree or a route in the router table | `<a href>`, `<form action>`, framework links (`<Link to>`, `<router-link to>`, `<NuxtLink to>`, Svelte `href`); router files: `react-router` route objects and `<Route>` elements, `pages/` and `app/` directories, `vue-router` routes, SvelteKit `src/routes/`, server routes (`app.get("/x")`, `router.post("/x")`); nested routes are joined to their parent (`children:`, an open `<Route>`) |
| UX-F2 | static | every in-page anchor `#id`, and every `aria-controls`, `aria-describedby` and `aria-labelledby` target, exists in the same file or view (`for` is UX-U3) | ids in the same file, quoted or not and in any case (`id=main`, `ID="menu"`), including ids in scanned JS templates; `#top` needs none; a hash-router link (`#/settings`, `#!/about`) is not an anchor |
| UX-F3 | static | each page in a core flow's `steps` has a way forward to the next step (a link, a form action, a navigation call, or one in a script the page loads; High when missing) and a way back or out (a link elsewhere, an external link, a back, cancel or close control, `history.back()`; Medium when missing); the last step needs only a way out. A step that is a route, or a component with no file-based route, is left to the walk | the contract's `core_flows[].steps`; the controls on each step page |
| UX-F4 | static | the app defines a not-found page or a catch-all route | `404.html`, `not-found.*`, `*` or `[...slug]` routes, a server fallback |
| UX-F5 | browser | walking a core flow's `steps` reaches every step with no same-origin 4xx or 5xx response and no uncaught console error | `browser_navigate`, `browser_network_requests`, `browser_console_messages` |
| UX-F6 | browser | the core flows pass the Step 4 checks (tree, keyboard walk, reflow) in every engine in `ux.engines` | the operator's per-engine Playwright runs (authoritative); the project's Playwright `projects` config as supporting evidence, never run |
| UX-F7 | static | the build targets match the contract's `browsers` | the `browserslist` key in `package.json` (not the `browserslist` package in a dependency list), `.browserslistrc`, `build.target` in `vite.config.*`, `targets` in `babel.config.*`, `target` in `tsconfig.json` |

What UX-F1 resolves and ignores:
- **Resolved:** a path relative to the page, a root-relative path against the scanned root and its base path, `index.html` for a directory, a trailing slash, a query string or fragment stripped first, dynamic segments (`[id]`, `:id`, `[...slug]`) matching any value.
- **Served from a URL:** a relative link in a server template (`.eta`, `.ejs`, `.hbs`, `.njk`) also resolves against the served files, since the template is not served from where it sits.
- **Where the scan starts:** a PATH may be relative, absolute or `../site`; links resolve inside it. A file over 512 KB is a bundle, not source: it is not read, and a NOTE says so. A path with a newline in it is skipped, and a link is printed without its query string, which can carry a token.
- **Not a resolution:** a catch-all route at the root (`*`, `/:pathMatch(.*)*`, `[...slug]`) is the not-found page; it never resolves a link.
- **Ignored:** `http:`, `https:` and protocol-relative links to other origins, `mailto:`, `tel:`, `javascript:` (UX-U checks those), `data:`, template expressions it cannot resolve (`{url}`, `${path}`, `:href="x"`) and values built by string concatenation in a script (`href="' + url + '"`), which are listed as unresolved, not failed.
- **Comments:** JS and CSS comments are skipped in script and style files, but only inside `<script>` and `<style>` in markup, where `/*` in text (`rm -rf /conf/*`) is not a comment.

UX-F2 reads attribute values inside script strings too (`aria-controls=\"nav\"`). An id that another scanned file defines (a shell page, or a view that renders it) is a NOTE, to confirm in the browser, not a failure.

UX-F4 applies when the app has more than one page or a router. `pages/` counts as file routes only in Next, Nuxt, Astro or Gatsby (named in a scanned `package.json`); elsewhere it is a folder name.

**The walk (UX-F5).** Navigation only, unless the contract's `core_flows[].test_data` names a fixture file the operator wrote and the target is `localhost`: then the walk may type that data and submit. Never real data, never credentials, never a link off the site. The fixture is a file inside the reviewed repository, never `.env*`, a key or a credentials file, and Claude names it to the operator before the first fill.

**The engine loop (UX-F6).** The Playwright MCP server runs one engine per launch. The skill asks the operator to add a server for Firefox, then WebKit (the plugin README, Other engines), and repeats the core-flow checks in each. An engine the operator does not run is unmeasured.

## UX-R: reliability as experienced

| Rule | Kind | Check | Evidence read |
|---|---|---|---|
| UX-R1 | static | a form that submits through a script disables its submit control, sets `aria-disabled`, or guards a pending flag before the request, so a double click sends one request (`aria-busy` is progress, UX-P1, not a guard) | submit handlers: `disabled = true`, `disabled={saving}`, `:disabled="busy"`, `isSubmitting`, `pending` (`useFormStatus`, `useTransition`, form libraries), a guard such as `if (busy) return`, a debounce or throttle |
| UX-R2 | static | every request (`fetch`, `axios`, `ky`, `XMLHttpRequest`, or a call on an API client such as `api.list()`) has a failure path that changes what the user sees (an error, status, notice or message state, a re-render, a toast) or hands the failure to the caller (returns a value, throws, maps it to a fallback value); `console.*` alone fails. A data hook (`useQuery`, `useSWR`, `useFetch`) must read its error state. A request that is returned to the caller, or whose results are checked (`.kind`, `.ok`, `.error`), has a failure path | the failure branches: a `.catch` on a chain that makes a request (a `.catch` on `.json()` is a parse fallback), a `catch` whose `try` makes a request (with its `finally`), `if (!response.ok)` or a failing `status` test as an `if` condition, `onError`; `isError` or `error` read in the render |
| UX-R3 | static | after a failed request on a core flow the user can try again: a retry control, or a retry in code with a limit | a "try again" or "retry" control in the error branch; `retry:` in react-query or SWR; a bounded loop |
| UX-R4 | static | a core-flow form with `ux.reliability.draft_fields` fields or more (default 6) keeps a draft across reload | input or change handlers that write `localStorage`, `sessionStorage`, IndexedDB or a draft request, and a restore on load |
| UX-R5 | static, browser-confirmed | view state in `ux.reliability.url_state` (filters, sort, page, tab) is kept in the URL, so Back and refresh keep it | `URLSearchParams`, `history.pushState` or `replaceState`, router query or search params on the listed pages; the browser reloads, goes Back and compares. An empty list (`url_state: []`) means no page keeps view state: UX-R5 not applied |
| UX-R6 | static | when `ux.reliability.offline` is `required`, the app tells the user it is offline and what is not saved; otherwise not applied (a missing key means `optional`) | `navigator.onLine`, `online` and `offline` listeners, a service worker with an offline page |
| UX-R7 | static | an update shown before the server confirms (optimistic update) is rolled back, or an error shown, when the request fails | `onMutate` with an `onError` rollback (the script); state set before `await` and restored in `catch` (read by the reviewer) |

The reliability lens is about what the user sees in the page. Whether the service stays up is `ascent-ops` and `ascent-architecture` (`quality_targets`); server latency under load is `ascent-quality` (QA-L).

## UX-P: pleasantness, verifiable observations

A UX-P rule that passes is reported as "observed", never "met"; the pleasant principle has no target, so it is never met. A rule that fails is a finding.

| Rule | Kind | Check | Evidence read |
|---|---|---|---|
| UX-P1 | static | an async action on a core flow shows progress before its request returns: a spinner, `aria-busy` or progress text | the handlers UX-R1 reads, and the render of the pending state |
| UX-P2 | static | when `ux.pleasant.motion_tokens` is true, transition and animation durations and easings come from motion tokens, not literals | `transition`, `animation` and their `-duration` declarations (the script), except the sub-millisecond reduced-motion reset (`0.01ms !important`); JS animation options (read by the reviewer); the motion tokens in `ux.tokens` |
| UX-P3 | static | no consent, marketing or subscription checkbox is checked by default | `<input type="checkbox" checked>`, `defaultChecked`, `:checked="true"`, whose `name`, `id` or label text (up to `</label>`) matches consent, marketing, newsletter, subscribe, share my or our data, sharing or partners |
| UX-P4 | static | where there is a sign-up or subscribe control, there is also a way to cancel, unsubscribe or delete the account | a sign-up is a link, button, label or submit control whose text starts with sign up, create account or subscribe, is register or join on its own, or is register or join followed by now, free, us, an account or the like ("Join call" is not a sign-up), or a link to a sign-up page; headings, lists and prose are not; the way out is text that names unsubscribe, cancel, delete or close the account |

**Tone is not a rule.** When the copy on a core flow is unclear, the review suggests `design:ux-copy` and lists the strings under Other observations, unrated.

## Out of scope

- Uptime, availability and error budgets: `ascent-ops`, `ascent-architecture`.
- Taste: colour, type, layout and brand are the operator's choice through `design-directions`.
- Open redirects, CSRF and other security concerns found on the way: marked `→ ascent-security`, unrated.
- Running the project's own end-to-end suite: the operator runs it; `ascent-quality` (QA-I) checks that it exists and that CI runs it.
