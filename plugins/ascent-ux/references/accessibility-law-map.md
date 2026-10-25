# Accessibility law and standards map

**as_of: 2026-10-24.** Informational, not legal advice. Laws, dates and citations change. `ux-review` reports "standards status as_of 2026-10-24: refresh due" once this file is more than 90 days old. Refreshing it is a plugin change with a version bump (make test-plugins T10).

The plugin's default target, **WCAG 2.2 Level AA**, includes everything WCAG 2.0 and 2.1 AA require. Meeting it covers the technical standard of each row below. It does not settle the legal questions: scope, exceptions, deadlines and documentation.

## Standards status

| Standard | Status as of 2026-10-24 | Source |
|---|---|---|
| WCAG 2.2 | W3C Recommendation; also ISO/IEC 40500:2025 (October 2025) | <https://www.w3.org/news/2025/web-content-accessibility-guidelines-wcag-2-2-approved-as-iso-iec-international-standard> |
| ISO/IEC 40500 next edition | a draft in the enquiry stage; publication not confirmed | <https://www.iso.org/standard/94018.html> |
| WCAG 3 | W3C Working Draft (March 2026); not used for rating | <https://www.w3.org/WAI/Technical/Activity> |
| WAI-ARIA 1.2 | W3C Recommendation; the APG patterns are the keyboard reference | <https://www.w3.org/WAI/ARIA/apg/> |
| Design Tokens Format Module 2025.10 | first stable version (Community Group report, not a W3C Standard) | <https://www.w3.org/community/reports/design-tokens/CG-FINAL-format-20251028/> |

## Jurisdictions

| Contract value | Law or policy | Technical standard | Dates and status as of 2026-10-24 | Source |
|---|---|---|---|---|
| `us-ada-title-ii` | ADA Title II rule for state and local government web content and mobile apps | WCAG 2.1 AA | DOJ interim final rule extended compliance to 26 April 2027 (population 50,000 or more) and 26 April 2028 (smaller entities and special districts). Confirm in the Federal Register | <https://www.jdsupra.com/legalnews/doj-extends-title-ii-ada-web-2176958/> |
| `us-section-508` | Section 508, US federal agencies' information and communication technology | WCAG 2.0 AA, through the 2017 refresh | in force | <https://www.section508.gov/> |
| `us-ada-title-iii` | ADA Title III, public accommodations | no technical standard in regulation; courts and DOJ guidance commonly reference WCAG | case law, not a rule | <https://www.ada.gov/resources/web-guidance/> |
| `eu-eaa` | European Accessibility Act (Directive (EU) 2019/882), applied from 28 June 2025 through national laws | EN 301 549: v3.2.1 (WCAG 2.1 AA) in force; **v4.1.1** (September 2026) adopts WCAG 2.2 AA and awaits citation in the Official Journal (expected late 2026) | until v4.1.1 is cited, v3.2.1 gives the presumption of conformity | <https://www.deque.com/blog/en-301-549-v4-1-1-is-final-what-changed-what-it-means-and-what-you-should-do/> |
| `eu-wad` | Web Accessibility Directive (EU) 2016/2102, public sector bodies | EN 301 549 | in force | <https://digital-strategy.ec.europa.eu/en/policies/web-accessibility> |
| `uk-psbar` | UK Public Sector Bodies Accessibility Regulations 2018 | WCAG 2.2 AA (GOV.UK guidance since October 2024) | in force | <https://www.gov.uk/guidance/accessibility-requirements-for-public-sector-websites-and-apps> |
| `ca-aoda` | Ontario, Accessibility for Ontarians with Disabilities Act | WCAG 2.0 AA | in force | <https://www.ontario.ca/page/how-make-websites-accessible> |

## How a review uses this file

- The contract lists `jurisdictions`. For each one, the report states which WCAG version it references, and whether the plugin's target covers it.
- A project with no jurisdictions gets no legal statement, only the WCAG 2.2 AA evidence.
- Never write "compliant" or "non-compliant". Write "evidence against WCAG 2.2 AA; <n> criteria fail; <n> not tested".
