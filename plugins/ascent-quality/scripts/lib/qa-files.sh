# qa-files.sh — file discovery shared by check-test-inventory.sh and check-tests.sh.
# Sourced, never run. Sets ARGS to "K=<kind> <file>" pairs for awk. Read-only.
#
# Kinds:
#   t    a test file by name: *.test.* and *.spec.* (JS and TS), *.cy.*, test_*.py,
#        *_test.py, *_test.go, *.bats, test-*.sh, test_*.sh, *_test.sh, *.test.sh
#   td   any other JS, TS, Python or Go file under tests/, test/, spec/, __tests__/,
#        e2e/ or cypress/; awk counts it as a test when it holds a test block
#   s    any other JS, TS, Python or Go file (source)
#   ci   CI configuration: .github/workflows/*.yml, .gitlab-ci.yml, Jenkinsfile,
#        .circleci/config.yml, azure-pipelines.yml, bitbucket-pipelines.yml,
#        .travis.yml, .buildkite/*.yml
#   pkg  package.json
#   make Makefile, GNUmakefile, *.mk
#   cfg  test runner configuration: playwright, cypress, jest, vitest and mocha
#        configs, pytest.ini, pyproject.toml, setup.cfg, tox.ini
#   doc  Markdown (*.md)
# Skipped directories: dependencies, build output, virtualenvs, caches, and test
# fixtures (fixtures/, testdata/, __fixtures__/, __snapshots__/), whose files are
# inputs to tests rather than tests.
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

QA_SKIP='( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name build -o -name .venv -o -name venv -o -name .tox -o -name .terraform -o -name coverage -o -name .next -o -name .nuxt -o -name target -o -name __pycache__ -o -name .pytest_cache -o -name fixtures -o -name testdata -o -name __fixtures__ -o -name __snapshots__ -o -name .playwright-mcp )'

ARGS=()
qa_add() { case "$2" in /*|./*) ARGS+=("K=$1" "$2") ;; *) ARGS+=("K=$1" "./$2") ;; esac; }

# qa_kind FILE — sets QA_K to the kind of FILE, or to "" when the scripts ignore
# it. A variable, not output, so there is no subshell per file; nocasematch
# (bash 3.1+) makes the patterns case-insensitive.
qa_kind() {
  local f="$1" lb="${1##*/}"
  QA_K=""
  shopt -s nocasematch
  qa_kind_of "$f" "$lb"
  shopt -u nocasematch
  return 0
}
qa_kind_of() {
  local f="$1" lb="$2"
  case "$f" in
    */.github/workflows/*.yml|*/.github/workflows/*.yaml|*/.buildkite/*.yml|*/.buildkite/*.yaml|*/.circleci/config.yml) QA_K=ci; return ;;
  esac
  case "$lb" in
    .gitlab-ci.yml|jenkinsfile|azure-pipelines.yml|bitbucket-pipelines.yml|.travis.yml) QA_K=ci; return ;;
    package.json) QA_K=pkg; return ;;
    makefile|gnumakefile|*.mk) QA_K=make; return ;;
    playwright.config.*|cypress.config.*|cypress.json|jest.config.*|vitest.config.*|.mocharc*|pytest.ini|pyproject.toml|setup.cfg|tox.ini) QA_K=cfg; return ;;
    *.md) QA_K=doc; return ;;
    *.test.js|*.test.jsx|*.test.ts|*.test.tsx|*.test.mjs|*.test.cjs|*.test.mts|*.test.cts) QA_K=t; return ;;
    *.spec.js|*.spec.jsx|*.spec.ts|*.spec.tsx|*.spec.mjs|*.spec.cjs|*.spec.mts|*.spec.cts) QA_K=t; return ;;
    *.cy.js|*.cy.ts|*.cy.jsx|*.cy.tsx|*.e2e.js|*.e2e.ts) QA_K=t; return ;;
    test_*.py|*_test.py|*_test.go|*.bats) QA_K=t; return ;;
    test-*.sh|test_*.sh|*_test.sh|*.test.sh) QA_K=t; return ;;
    *.js|*.jsx|*.ts|*.tsx|*.mjs|*.cjs|*.mts|*.cts|*.py|*.go)
      case "$lb" in *.d.ts) return ;; esac
      case "/$f" in */tests/*|*/test/*|*/spec/*|*/__tests__/*|*/e2e/*|*/cypress/*) QA_K=td ;; *) QA_K=s ;; esac
      return ;;
  esac
}

# qa_collect PROG KEEP AS PATH... — adds to ARGS the files under each PATH whose
# kind is in KEEP (space-separated kinds), labelled AS when AS is set. A directory
# is searched; a file named directly must be of a kept kind (else exit 2).
qa_collect() {
  local prog="$1" kinds="$2" keep=" $2 " as="$3" p f; shift 3
  for p in "$@"; do
    # ./ keeps find from reading a path that starts with - as an expression.
    case "$p" in .|..|/*|./*|../*) ;; *) p="./$p" ;; esac
    if [ -d "$p" ]; then
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        # Typed by the path below the search root: an ancestor named test/ is not a test directory.
        qa_kind "${f#"$p"}"
        case "$keep" in *" $QA_K "*) qa_add "${as:-$QA_K}" "$f" ;; esac
      done <<EOF_FILES
$(# shellcheck disable=SC2086
  find "$p" $QA_SKIP -prune -o -type f -print 2>/dev/null | LC_ALL=C sort || true)
EOF_FILES
    elif [ -f "$p" ]; then
      qa_kind "$p"
      case "$keep" in
        *" $QA_K "*) [ -n "$QA_K" ] && qa_add "${as:-$QA_K}" "$p" ;;
        *) echo "$prog: not a file this check reads ($kinds): $p" >&2; exit 2 ;;
      esac
    else
      echo "$prog: no such file or directory: $p" >&2; exit 2
    fi
  done
  return 0
}
