#!/usr/bin/env bash
# go-rest-clean-arch architectural lint
# Scans the current directory tree for violations of the static-auditable
# hard rules from the go-rest-clean-arch skill.
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/Rhyanz46/go-rest-skills/main/tools/lint.sh)
#
# Or vendor it:
#   curl -fsSL https://raw.githubusercontent.com/Rhyanz46/go-rest-skills/v0.2.0/tools/lint.sh -o scripts/lint-arch.sh
#   chmod +x scripts/lint-arch.sh
#   ./scripts/lint-arch.sh
#
# Exit code 0 = clean, non-zero = violations found.
# Each rule that fails prints its number and the offending file:line.

set -u
shopt -s globstar nullglob 2>/dev/null || true

# ---- helpers ----------------------------------------------------------------

violations=0

# Use ripgrep when available (faster, ignores .gitignore by default), fall back to git grep.
have_rg() { command -v rg >/dev/null 2>&1; }

scan() {
    # scan <pattern> <path-or-glob...>
    local pattern="$1"; shift
    if have_rg; then
        rg -n --no-heading --color=never "$pattern" "$@" 2>/dev/null || true
    else
        # git grep falls back to all tracked files under the given paths
        git grep -n -E "$pattern" -- "$@" 2>/dev/null || true
    fi
}

report_violation() {
    local rule="$1" headline="$2" matches="$3"
    if [[ -n "$matches" ]]; then
        violations=$((violations + 1))
        printf '\n[Rule #%s] %s\n' "$rule" "$headline"
        printf '%s\n' "$matches" | sed 's/^/  /'
    fi
}

# ---- preconditions ----------------------------------------------------------

if [[ ! -d app ]]; then
    echo "skipped: no app/ directory at $(pwd) — this lint targets go-rest-clean-arch projects" >&2
    exit 0
fi

echo "go-rest-clean-arch lint — scanning $(pwd)"
echo "----------------------------------------"

# ---- Rule #4: layer dependency direction ------------------------------------

# Use case must NOT import GORM, schemas, or gin
m=$(scan '^[[:space:]]*"(gorm\.io/gorm|gin-gonic/gin)"|"[^"]*/database/schemas"' app/use_case)
report_violation 4 "use_case imports forbidden package (gorm, gin, or database/schemas)" "$m"

# Controller must NOT import GORM or schemas (gin is allowed and expected)
m=$(scan '^[[:space:]]*"gorm\.io/gorm"|"[^"]*/database/schemas"' app/controller)
report_violation 4 "controller imports forbidden package (gorm or database/schemas)" "$m"

# Repository must NOT import gin
m=$(scan '^[[:space:]]*"github\.com/gin-gonic/gin"' app/repository)
report_violation 4 "repository imports forbidden package (gin)" "$m"

# ---- Rule #6: three model sets — no GORM tags outside repo/schemas ----------

m=$(scan 'gorm:"' app/use_case app/controller)
report_violation 6 "GORM struct tags found outside repository/schemas layer" "$m"

# ---- Rule #7: GetAuthClaim only in controller -------------------------------

m=$(scan 'GetAuthClaim|GetUserIDFromContext|c\.Get\("user_id"\)|\*gin\.Context' app/use_case app/repository)
report_violation 7 "auth-context handle (gin.Context / GetAuthClaim) used outside controller" "$m"

# ---- Rule #9: validation in rules.go, not binding tags / ShouldBindJSON ----

# Find binding: tags inside the controller layer (allowed in path-param uri tags? no — push them to rules.go too)
m=$(scan 'binding:"' app/controller)
report_violation 9 "controller still uses binding: tag (legacy validation)" "$m"

# ShouldBindJSON inside controllers (binding query params via ShouldBindQuery is fine here — only JSON-body case is the smell)
m=$(scan 'ShouldBindJSON' app/controller)
report_violation 9 "controller uses c.ShouldBindJSON (use map_validator.ValidateJSON[T] instead)" "$m"

# ---- Rule #10: time.LoadLocation only inside common/timezone.go -------------

# Find any time.LoadLocation call under app/ that is NOT in common/timezone.go
all=$(scan '\btime\.LoadLocation\b' app)
filtered=$(printf '%s' "$all" | grep -v 'app/use_case/common/timezone\.go' || true)
report_violation 10 "time.LoadLocation called directly (use common.LoadLocationOrDefault)" "$filtered"

# Hand-rolled pagination math under app/
m=$(scan '\(\s*[A-Za-z_][A-Za-z0-9_]*\s*-\s*1\s*\)\s*\*\s*[A-Za-z_][A-Za-z0-9_]*' app)
report_violation 10 "hand-rolled pagination offset math (use pkg/paginate_utils)" "$m"

# Direct gin.H responses in controllers (use common.SendSuccess/SendError)
m=$(scan 'c\.JSON\([^,]+,\s*gin\.H\{' app/controller)
report_violation 10 "raw gin.H response shape in controller (use common.SendSuccess/SendError)" "$m"

# ---- Rule #11: N+1 in use_case loops (heuristic) ----------------------------

# Find functions in use_case that loop and call a repo method by the typical r.<repo>. or .repo. shape.
# This is a heuristic — false positives possible. We report and let humans triage.
if have_rg; then
    n1=$(rg --multiline --multiline-dotall -n --no-heading \
        'for\s+_?,?\s*\w+\s*:?=\s*range[^{]+\{[^}]{0,400}r\.\w*[Rr]epo\.\w+\(' \
        app/use_case 2>/dev/null || true)
else
    n1=""
fi
report_violation 11 "loop in use_case with repo method call inside (likely N+1; verify and refactor to batch fetch)" "$n1"

# ---- Rule #12: placeholder no-op heuristics ---------------------------------

# Function bodies that are literally `// ... \n return nil` or `return X, nil` after a TODO/placeholder comment.
m=$(scan '//\s*(For now|TODO|placeholder|Implementation would go here|In production this should)' app)
report_violation 12 "placeholder/TODO comment likely guarding a no-op (verify the function actually implements its contract)" "$m"

# ---- Rule #8: Filter Pattern — flag GetByX / FindByX repository methods ----

m=$(scan 'func\s+\(\w+\s+\*?\w+Repository\w*\)\s+(GetBy|FindBy|ListBy)\w+' app/repository)
report_violation 8 "repository method named GetBy/FindBy/ListBy<X> (use Filter struct on GetOne/List instead)" "$m"

# ---- Rule #17: REST surface naming ------------------------------------------

# (a) JSON body keys must be snake_case — flag camelCase in json: tag
# Pattern: json:"<lower><any><Upper>...
m=$(scan 'json:"[a-z][a-zA-Z0-9_]*[A-Z]' app/controller)
report_violation 17 "json: tag value contains uppercase (use snake_case)" "$m"

# (b) Query / form / uri params must be kebab-case — flag underscore or uppercase in form/uri tag
m=$(scan 'form:"[a-z]+_[a-z0-9_]+"' app/controller)
report_violation 17 "form: tag value uses snake_case (use kebab-case)" "$m"

m=$(scan 'form:"[a-z][a-zA-Z0-9_-]*[A-Z]' app/controller)
report_violation 17 "form: tag value contains uppercase (use kebab-case)" "$m"

m=$(scan 'uri:"[a-z]+_[a-z0-9_]+"' app/controller)
report_violation 17 "uri: tag value uses snake_case (use kebab-case)" "$m"

m=$(scan 'uri:"[a-z][a-zA-Z0-9_-]*[A-Z]' app/controller)
report_violation 17 "uri: tag value contains uppercase (use kebab-case)" "$m"

# (c) Route strings must use kebab path segments + kebab path params
# Find r.<METHOD>("/api/...") declarations with underscore or uppercase inside the path string
m=$(scan 'r\.(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD)\("[^"]*_[^"]*"' routes)
report_violation 17 "route path contains underscore (use kebab-case for segments and :params)" "$m"

m=$(scan 'r\.(GET|POST|PUT|DELETE|PATCH|OPTIONS|HEAD)\("/[a-z][a-zA-Z0-9_/:-]*[A-Z]' routes)
report_violation 17 "route path contains uppercase (use kebab-case)" "$m"

# (d) c.Param / c.Query keys with snake_case — these usually mirror the route param,
# so this catches drift where you renamed the route but forgot the lookup
m=$(scan 'c\.(Param|Query)\("[a-z]+_[a-z0-9_]+"\)' app/controller)
report_violation 17 "c.Param/Query lookup uses snake_case key (must match kebab-case route param)" "$m"

# ---- Rule #18: 5xx sanitization + request_id propagation --------------------

# (a) Controllers must not call c.JSON with err.Error() anywhere in the call —
# multiline mode catches `c.JSON(code, ErrorResponse{... Message: err.Error() ...})`
if have_rg; then
    m=$(rg --multiline --multiline-dotall -n --no-heading \
        'c\.JSON\([^)]{0,400}err\.Error\(\)' \
        app/controller 2>/dev/null || true)
else
    m=$(scan 'c\.JSON\([^)]*err\.Error\(\)' app/controller)
fi
report_violation 18 "controller passes err.Error() through c.JSON (use common.SendError to sanitize 5xx)" "$m"

# (b) Controllers must not return raw gin.H error shapes (covered partly by rule #10, restated here)
m=$(scan 'c\.JSON\([^)]*gin\.H\{[^}]*"error"' app/controller)
report_violation 18 "controller returns ad-hoc gin.H error shape (use common.SendError)" "$m"

# (c) use_case / repository log lines should include request_id from context.
# Heuristic: log.Printf without RequestIDFrom mention in the same line. False
# positive prone, so report as advisory.
m=$(scan 'log\.(Printf|Println|Print|Errorf|Warnf|Infof)\(' app/use_case app/repository)
filtered=$(printf '%s' "$m" | grep -v 'RequestIDFrom\|request_id=' || true)
report_violation 18 "log line below the controller layer without request_id from context (advisory: include common_utils.RequestIDFrom(ctx))" "$filtered"

# ---- Rule #19: never ignore errors ------------------------------------------

# Discarding the error from common error-returning APIs without justification.
# Skip _test.go files — error swallowing in tests is sometimes intentional.
m=$(scan ',\s*_\s*:?=\s*(json\.(Marshal|Unmarshal)|os\.(Open|Create|ReadFile|WriteFile)|http\.(Get|Post|Do)|exec\.Command|tx\.(Commit|Rollback)|sql\.Open|db\.Exec|stmt\.Exec)' app)
filtered=$(printf '%s' "$m" | grep -v '_test\.go:' || true)
report_violation 19 "discarded error from a function that commonly returns one (use errcheck for full coverage)" "$filtered"

# Single-value type assertion (forbidden outside _test.go).
# Pattern: line whose LHS of := is a single identifier (no comma) followed by
# `value.(Type)` form. Two-value `v, ok := x.(T)` has a comma in LHS — skip.
m=$(scan '^\s*[A-Za-z_][A-Za-z0-9_]*\s*:=\s+[A-Za-z_][A-Za-z0-9_.]*\.\([A-Za-z_][A-Za-z0-9_.*\[\]]*\)\s*$' app)
filtered=$(printf '%s' "$m" | grep -v '_test\.go:' || true)
report_violation 19 "single-value type assertion (use two-value form: v, ok := i.(T))" "$filtered"

# Goroutine swallowing error: `go func() { _ = f(...) }()` heuristic
if have_rg; then
    m=$(rg --multiline --multiline-dotall -n --no-heading \
        'go\s+func\([^)]*\)\s*\{[^}]{0,200}_\s*=\s*\w' \
        app 2>/dev/null || true)
    report_violation 19 "goroutine likely swallows error (assign to _ instead of logging it)" "$m"
fi

# ---- Rule #20: resource cleanup ---------------------------------------------

# context.WithCancel/WithTimeout/WithDeadline without `defer cancel()` nearby.
# Heuristic: scan for the assignment, then check if `defer cancel()` appears
# within the next 5 lines of the same file. False positives possible — review.
if have_rg; then
    matches=$(rg -n --no-heading 'context\.(WithCancel|WithTimeout|WithDeadline)\(' app 2>/dev/null || true)
    leak_lines=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        file="${line%%:*}"
        rest="${line#*:}"
        lineno="${rest%%:*}"
        end=$((lineno + 8))
        if [[ -f "$file" ]]; then
            # Accept either `defer cancel()` OR a bare `cancel()` call within the window.
            if ! sed -n "${lineno},${end}p" "$file" 2>/dev/null | grep -qE 'defer\s+cancel\(\)|^\s*cancel\(\)'; then
                leak_lines+="${line}"$'\n'
            fi
        fi
    done <<< "$matches"
    leak_lines="${leak_lines%$'\n'}"
    report_violation 20 "context.WithCancel/WithTimeout/WithDeadline without 'defer cancel()' or explicit cancel() nearby" "$leak_lines"
fi

# http.Get / http.Post / client.Do calls — ensure response.Body.Close is
# deferred nearby. http.NewRequest is excluded — it builds a request and never
# returns a body to close.
if have_rg; then
    matches=$(rg -n --no-heading '(http\.Get\(|http\.Post\(|\.Do\(req|httpClient\.Do\()' app pkg 2>/dev/null || true)
    leak_lines=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        file="${line%%:*}"
        rest="${line#*:}"
        lineno="${rest%%:*}"
        end=$((lineno + 8))
        if [[ -f "$file" ]]; then
            if ! sed -n "${lineno},${end}p" "$file" 2>/dev/null | grep -q 'defer.*\.Body\.Close'; then
                leak_lines+="${line}"$'\n'
            fi
        fi
    done <<< "$matches"
    leak_lines="${leak_lines%$'\n'}"
    report_violation 20 "HTTP request without nearby 'defer resp.Body.Close()'" "$leak_lines"
fi

# Bare `go func()` without a context parameter — heuristic for leaked goroutines.
m=$(scan 'go\s+func\(\s*\)' app pkg)
report_violation 20 "goroutine spawned without a context parameter (verify it has a termination contract)" "$m"

# time.NewTicker without nearby Stop() — heuristic
if have_rg; then
    matches=$(rg -n --no-heading 'time\.NewTicker\(' app pkg 2>/dev/null || true)
    leak_lines=""
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        file="${line%%:*}"
        rest="${line#*:}"
        lineno="${rest%%:*}"
        end=$((lineno + 6))
        if [[ -f "$file" ]]; then
            if ! sed -n "${lineno},${end}p" "$file" 2>/dev/null | grep -q '\.Stop()'; then
                leak_lines+="${line}"$'\n'
            fi
        fi
    done <<< "$matches"
    leak_lines="${leak_lines%$'\n'}"
    report_violation 20 "time.NewTicker without nearby 'defer ticker.Stop()'" "$leak_lines"
fi

# ---- Rule #22: swagger gated by basic auth + env ---------------------------

# Find every swagger registration (ginSwagger.WrapHandler / swaggerFiles.Handler).
# For each, check that the same file mentions BOTH `gin.BasicAuth` AND an env-
# presence guard ("if user ==" or `SwaggerUser` / `SwaggerPassword` /
# `SWAGGER_USER` / `SWAGGER_PASSWORD` reference). Missing either → flag.
if have_rg; then
    swag_files=$(rg -l --no-heading 'ginSwagger\.WrapHandler|swaggerFiles\.Handler' routes app pkg 2>/dev/null || true)
    bad=""
    for f in $swag_files; do
        [[ -z "$f" || ! -f "$f" ]] && continue
        body=$(cat "$f")
        has_basicauth=$(printf '%s' "$body" | grep -c 'gin\.BasicAuth' || true)
        has_envgate=$(printf '%s' "$body" | grep -cE 'SwaggerUser|SwaggerPassword|SWAGGER_USER|SWAGGER_PASSWORD' || true)
        if [[ "$has_basicauth" -eq 0 || "$has_envgate" -eq 0 ]]; then
            bad+="${f}: swagger registered without BasicAuth + env presence gate"$'\n'
        fi
    done
    bad="${bad%$'\n'}"
    report_violation 22 "swagger UI exposed without BasicAuth gated on SWAGGER_USER/SWAGGER_PASSWORD env presence" "$bad"
fi

# Hardcoded credentials in BasicAuth — anything that isn't a variable lookup.
# Pattern: gin.Accounts{"some-literal": "another-literal"}
m=$(scan 'gin\.Accounts\{"[^"]+": ?"[^"]+"\}' routes app pkg)
report_violation 22 "swagger BasicAuth uses hardcoded credentials (must come from config/env)" "$m"

# ---- Rule #23: orphan prevention --------------------------------------------

# (a) GORM many2many tag without a `constraint:` clause → no documented policy
# Pattern: `gorm:"many2many:..."` with no `constraint:` mentioned in the tag.
m=$(scan 'gorm:"[^"]*many2many:[^"]*"' database/schemas)
filtered=$(printf '%s' "$m" | grep -v 'constraint:' || true)
report_violation 23 "many2many relation without 'constraint:OnDelete/OnUpdate' — orphan policy not declared" "$filtered"

# (b) foreignKey tag without constraint:OnDelete
m=$(scan 'gorm:"[^"]*foreignKey:[^"]*"' database/schemas)
filtered=$(printf '%s' "$m" | grep -v 'constraint:' || true)
report_violation 23 "foreignKey relation without 'constraint:OnDelete' — orphan policy not declared" "$filtered"

# (c) Soft-delete asymmetry — flag schemas that use gorm.DeletedAt and also
# reference an m2m join. Heuristic only: surface the file so the reviewer can
# verify the join table also has gorm.DeletedAt or hard-delete is intentional.
if have_rg; then
    soft_delete_files=$(rg -l --no-heading 'gorm\.DeletedAt' database/schemas 2>/dev/null || true)
    bad=""
    for f in $soft_delete_files; do
        [[ -z "$f" || ! -f "$f" ]] && continue
        if grep -q 'many2many:' "$f"; then
            bad+="${f}: schema uses gorm.DeletedAt and many2many — verify join table soft-delete symmetry"$'\n'
        fi
    done
    bad="${bad%$'\n'}"
    report_violation 23 "advisory: soft-delete symmetry not statically verifiable; manual review required" "$bad"
fi

# ---- Rule #13: output timestamps stay UTC -----------------------------------

# Detect .In(<loc>) inside transform.go files (heuristic — the function name "transform" is the smell)
m=$(scan '\.In\(' app/use_case/**/transform.go 2>/dev/null || scan '\.In\(' app/use_case)
filtered=$(printf '%s' "$m" | grep '/transform\.go:' || true)
report_violation 13 "time.Time.In(loc) called inside a transform — output should stay UTC, only filter inputs convert" "$filtered"

# ---- summary ----------------------------------------------------------------

echo
if [[ "$violations" -eq 0 ]]; then
    echo "✅ go-rest-clean-arch lint: all clean"
    exit 0
else
    echo "❌ go-rest-clean-arch lint: $violations rule(s) flagged"
    echo "   Fix the issues above or add a justification comment in your PR."
    exit 1
fi
