---
name: go-rest-clean-arch
description: Canonical playbook for Go REST backends that follow the Clean Architecture pattern (controller → use_case → repository), map_validator-based request validation, and the strict Stop-and-Wait learning order. Use this skill whenever the user asks to design, scaffold, extend, or refactor a Go service in this style — typical signals are mentions of "clean architecture", "controller / use_case / repository / filter pattern", `map_validator`, an `app/{controller,use_case,repository}` layout, a `CLAUDE.md` that references `go-rest-clean-arch`, or the user explicitly invoking this playbook.
---

# go-rest-clean-arch — Playbook for Go REST backends in Clean Architecture style

This skill is the **canonical doctrine** for Go REST backends in this style — projects pin a version (e.g. `go-rest-clean-arch@v0.1.0`) from their `CLAUDE.md` and read from here. References live under `references/`; this SKILL.md is the entry point that tells future Claude **what to read, in what order, and what hard rules to enforce**.

## When this skill applies

Trigger only when the user is working on a Go REST service that already follows — or wants to follow — the structure:

```
app/
├── controller/<feature>/         # HTTP layer + map_validator rules
├── use_case/<feature>/           # business logic
└── repository/<feature>/         # GORM data access
config/  database/  routes/  pkg/
```

Strong signals: filenames such as `controller.go`/`usecase.go`/`repository.go` per feature, a `routes/routes.go` wiring with `setupAuthenticatedRoutes`, presence of `map_validator.BuildRoles()` in `rules.go`, a `CLAUDE.md` line pointing at `go-rest-clean-arch`, or the user explicitly invoking this playbook.

If the project is a generic Go module without these markers, **do not apply this skill** — ask the user first.

## Hard rules (apply always)

The rules are grouped to make scanning easier; the numbering is global so you can cite "rule #11" without ambiguity.

### Workflow & process

1. **Never skip the learning order.** Even if the user asks for APM or Swagger directly, verify Phase 1–2 are complete first; otherwise refuse and explain.
2. **Stop-and-Wait at every layer checkpoint.** After finishing a layer, summarise what was produced and wait for explicit user confirmation before moving to the next layer. Do not chain layers silently.
3. **Audit before fix for cross-cutting issues.** When a bug touches a cross-cutting concern (timezone, pagination, error handling, N+1, validation, auth context), grep every callsite of the affected pattern across the repo before editing anything. Sepotong-sepotong fix is the #1 cause of regressions in this codebase. Do the audit, list the spots, then refactor in one pass.

### Architecture & contracts

4. **Layer dependency direction is one-way.** Controller depends on use_case, use_case depends on repository. Never the other direction. No business logic in controllers, no HTTP types in use_case, no GORM types leaking out of repository.
5. **Signature `(result, statusCode int, error)` is mandatory below the controller.** Every public method on a repository or use_case returns this trio. The controller is the only place that converts `int` → HTTP response. Do not return `(result, error)` and let the controller "assume 500"; do not return `(int, error)` without a result; do not invent ad-hoc error wrappers per feature.
6. **Each layer owns its own contract — both interface AND models.** Three pieces per feature, three layers:
   - **Repository layer** owns `XRepository` interface in `app/repository/<feature>/interfaces.go` *plus* GORM-aware models in `models.go` (struct tags, schema imports). The use_case calls the **interface**, never the concrete `*xRepository` struct.
   - **Use_case layer** owns `XUseCase` interface in `app/use_case/<feature>/interfaces.go` *plus* domain-level structs (no GORM tags, no `gin.Context`, no JSON tags). The controller calls the **interface**, never the concrete `*xUseCase` struct.
   - **Controller layer** owns `XController` interface in `app/controller/<feature>/interfaces.go` *plus* HTTP DTOs in `models.go` (`json:` tags only, no GORM tags). Routes call the **interface**.

   Three corollaries:
   - **Interfaces are provider-defined.** The package that *implements* the interface is the same package that *defines* it. This is intentionally Java-flavoured rather than Go-idiomatic small consumer-defined interfaces — the project chose unified per-layer contracts so each feature has one obvious "API surface" to read. Don't try to "fix" it by moving interfaces into consumer packages.
   - **Callers depend on interfaces, never on concrete structs.** A `Controllers` field typed `*track_use_case.trackUseCase` is wrong; it must be `track_use_case.TrackUseCase`. Same for repos in use_cases.
   - **Conversions between layers happen in dedicated transform helpers** (`transformXToY` in `transform.go`). Never re-use a single struct across two layers — even if the fields look identical today, the layers will drift. Same goes for interfaces — never alias `XRepository` as `XUseCase` to skip a transform; that's a layering smell.
7. **Auth context (`GetAuthClaim`, `c.Get("user_id")`, `*gin.Context`) lives only in the controller.** Use_case and repository receive `userID uuid.UUID` (or whatever IDs they need) as explicit parameters. A repository signature that takes a `*gin.Context` is automatically wrong.

### Layer-specific patterns

8. **Filter Pattern is mandatory** for every list/query operation in repositories — see `references/app_package.md`. Never `GetByEmail`, `GetByID`, `FindByStatus`. One `<Entity>Filter` struct per entity, one `applyXFilters(query, filter)` helper, every list/getone goes through it.
9. **Validation lives in `rules.go` as package-level `var`** declared via `map_validator.BuildRoles()`, called from controllers with `map_validator.ValidateJSON[T]`. Do **not** use `c.ShouldBindJSON` or `binding:"..."` tags for validation in this style.
10. **Reuse shared utilities — never duplicate logic per feature.** Cross-cutting concerns must come from the shared `pkg/` layer or `app/*/common/`, not be re-implemented inside a feature folder. The canonical reusables:
    - **Pagination** → `pkg/paginate_utils/` (`PaginateData`, `Paginate(p)` GORM scope, `NewPagination(paginate, total)` response envelope). Every list endpoint accepts `*paginate_utils.PaginateData` in the use_case signature, the repo applies it via `db.Scopes(paginate_utils.Paginate(p))`, and the response wraps the slice with `paginate_utils.NewPagination(...)`. Never write per-feature `page`/`page_size` parsing, offset math, or response-shape code.
    - **Error mapping** → `app/use_case/common/error_mapper.go` and `app/repository/common/`. Use them; do not invent new repo-error → HTTP-status conversions per feature.
    - **Response envelope** → `app/controller/common/response.go` (`SendSuccess`, `SendError`). Do not hand-roll `c.JSON(...)` shapes per controller.
    - **Timezone helpers** → `app/use_case/common/timezone.go` (`ReinterpretDateInTZ`, `LoadLocationOrDefault`, `StartOfDayInTZ`, `EndOfDayInTZ`). **Never call `time.LoadLocation(...)` directly in `app/use_case/**/*.go`** — every "load this TZ string into a `*time.Location`" must go through `common.LoadLocationOrDefault`. The helper centralises the `Asia/Jakarta` fallback and gives one place to swap behaviour later. Direct `time.LoadLocation` calls also tend to silently `_` the error (a smell).

    When the user asks to "add pagination / filtering / error handling / timestamps to feature X", first **grep for existing helpers** in `pkg/` and `app/*/common/`, reuse them, and only add to the shared util if a genuinely new pattern is needed (and then move it to `common/` so the next feature inherits it).
11. **No N+1 queries from the use_case layer.** When iterating a slice of entities, never call `repo.GetOne(...)`, `repo.List(filter for a single ID)` or any other per-item query inside the loop. Three accepted shapes instead:
    - **Batch fetch then assemble in memory** — collect IDs first, call `repo.List(filter{Ids: ids})` (or a dedicated `GetByIDs`) once, build a `map[ID]Entity`, then enrich the slice.
    - **Eager-load at the repo layer** — push the relation into the repo via GORM `Preload(...)` / `Joins(...)` so the controller/use_case never has to fetch it again.
    - **Dedicated batch / aggregate method** — when the join is non-trivial, add a new method to the repo (`ListWithRelations`, `GetSummariesByDates`) and use that. Do **not** paper over the problem with a goroutine fan-out.

    Before declaring a use_case method done: mentally run it on a list of N=1000. If it fires N+1 queries, refactor or add the missing batch method to the repo. This applies to every loop that touches `r.<repo>.` inside `app/use_case/`.

### Discipline

12. **No silent placeholder / no-op functions.** A function that returns `nil` with a comment like `// In production this should ...` lies to its caller. If the implementation isn't ready: return a specific error (`errors.New("not implemented: <reason>")`), don't expose the function on the interface, or remove it entirely. Stub no-ops have shipped real bugs in this codebase (e.g. `ApplyPlan` rewrite mode silently doing nothing because the delete helper was a `return nil` placeholder).
13. **Output timestamps stay UTC RFC3339, by design.** Use `time.Time` in response structs and let Go marshal it as `2026-04-26T12:34:56Z`. The frontend converts to user locale. Do **not** call `.In(userLoc)` before marshaling — that decision was tried, reverted, and the outcome was "client converts" wins. Filter inputs and bucket logic still use the user's TZ; only the JSON wire format is UTC.
14. **Swagger annotations only on HTTP handler functions** in controllers — never on use_case, repository, or private helpers.
15. **APM and structured logging** come last; require Phase 1–2 to be 99% complete (per `instruction_order.md`).
16. **Comments are allowed** when they capture non-obvious WHY (constraints, invariants, surprising behaviour, workarounds with ticket links). They are **not** required and not encouraged for restating what well-named code already says. Emojis in log messages and `.env` examples are fine in this codebase.
17. **No camelCase anywhere on the REST surface. Two casing buckets only:**
    - **JSON body keys** (request body, response body, error envelope) → `snake_case`. `created_at`, `user_id`, `due_at`, `tag_ids`. Never `createdAt`, `userId`, `dueAt`. Internal Go fields stay `PascalCase`; the conversion happens at the boundary via `json:"snake_case"` struct tags.
    - **Everything in the URL** (path segments, path params, query param names) → `kebab-case`. Never snake_case, never camelCase.
      - URL path: `/api/template-plan/:id/history`, `/api/persona-profile/answers` — not `/api/template_plan` and not `/api/templatePlan`.
      - Path params: `:id`, `:user-id`, `:tag-id` — not `:user_id` and not `:userId`. Read with `c.Param("user-id")`, declare in `form:"user-id"` if bound via struct.
      - Query params: `?date-from=`, `?page-size=`, `?sort-by=` — not `?date_from=` and not `?dateFrom=`. Bind via `form:"date-from"` tags on the request struct.
    - **HTTP headers** are exempt: they follow `Pascal-Kebab-Case` per RFC convention (`X-Auth-Cron`, `X-API-Key`, `Authorization`). Never `xAuthCron`.

    Three checkpoints to enforce, all caught by `tools/lint.sh`:
    - Every `json:"..."` tag value in `app/controller/<feature>/models.go` is snake_case (or `json:"-"` for hidden fields). Lint flags `json:"camelCase"`.
    - Every `form:"..."` tag value is kebab-case. Lint flags `form:"snake_case"` and `form:"camelCase"`.
    - Every route string in `routes/routes.go` uses kebab path segments and kebab path params. Lint flags any `_` or uppercase letter inside a `r.<METHOD>("/api/...")` path string.

    Why this split: URL is one namespace (kebab is the URL-native casing — case-insensitive, hyphen-tolerant); JSON is another (snake_case is the JSON-native casing per most ecosystems). Mixing them inside one of the two leaks ambiguity. Frontend/mobile teams in this ecosystem standardise on this split — diverging forces per-field mappers in every consumer.
18. **Internal errors stay internal; clients see only `request_id` for 5xx.** Three coupled requirements:

    **(a) Request ID propagation.** Every incoming request must carry a `request_id` from the edge through every layer down to the repository:
    - A `RequestID` middleware (in `pkg/http_middleware/`) reads `X-Request-ID` from the header or generates a new UUID if absent.
    - It writes the ID into both `gin.Context` (for handlers) and the underlying `context.Context` (so `r.repo.GetOne(ctx, ...)` and downstream calls inherit it).
    - It echoes the ID back in `X-Request-ID` response header on every response.
    - A typed key + helpers live in `pkg/common_utils/request_context.go`: `WithRequestID(ctx, id)`, `RequestIDFrom(ctx) string`. Layers below the controller read the ID via `RequestIDFrom(ctx)` for logging, never from `gin.Context` (that would re-introduce the auth-context leak banned by rule #7).

    **(b) Error sanitization at the controller boundary.** When a use_case or repository returns `(_, statusCode, err)` with `statusCode >= 500`, the controller must NOT pass `err.Error()` to the client. The body returned to the client for any 5xx is a fixed shape:
    ```json
    { "success": false, "message": "internal server error", "request_id": "abc-123-..." }
    ```
    The original `err` is logged server-side (see (c)). For `statusCode < 500` (4xx — validation, business errors, not-found, conflict), `err.Error()` IS surfaced to the client because those messages are meant for the caller. The split is:
    - `4xx` → caller-facing message, `err.Error()` is fine.
    - `5xx` → generic message + `request_id`; the real reason is in the log.
    
    Enforce via `app/controller/common/response.go`'s `SendError(c, statusCode, err)` helper which performs the sanitization automatically. **Controllers must never call `c.JSON(...)` directly with an error payload.** Always go through `common.SendError`.

    **(c) Structured logging at every 5xx.** When `SendError` sees `statusCode >= 500`, it logs one line containing at minimum:
    - `request_id`
    - HTTP method + path
    - User ID (if authenticated, via `common.GetUserIDFromContext`)
    - Original `err` value (and stack trace if available)
    - Timestamp
    
    Logs from below the controller (use_case, repository) that want to participate in incident triage must include `RequestIDFrom(ctx)` in their log line — same key, so `grep request_id=abc-123` returns every line for the offending request.

    **Why this rule:** during an incident, the only thing the user can copy out of the browser is the `request_id`. Without it, you grep logs by timestamp and pray. With it, one `grep` returns the full request lifecycle: middleware → controller → use_case → repo → DB error. The rule pays for itself the first time production breaks.
19. **Never ignore errors. Every `error` return is checked, propagated, or justified.**
    - **Forbidden by default:** `result, _ := f()`, `_ = f()`, `go f()` where `f` returns `error`.
    - **Allowed only with an inline `// ignored: <reason>` comment** that names the specific reason — e.g. `_ = json.Marshal(v)  // ignored: marshal of known-good value cannot fail` or `_ = rows.Close()  // ignored: best-effort cleanup, primary error already returned`. The comment is the audit trail.
    - **Goroutines must surface errors.** Either:
      - The goroutine writes the error to a channel that the caller drains, or
      - The goroutine logs the error itself (with `request_id` from context per rule #18), or
      - The goroutine is documented as "fire-and-forget for an idempotent side-effect; failure is acceptable" with a comment.
      
      Never `go f()` and discard a non-nil error silently.
    - **Type assertions** must use the two-value form (`v, ok := i.(T)`) and check `ok`. Single-value `i.(T)` panics on mismatch and is forbidden outside test code.
    - **Enforce in CI** with `errcheck` (or `golangci-lint run --enable=errcheck`). Add it to the project's lint pipeline alongside `tools/lint.sh`. The skill's lint script flags the most common smells (`, _ :=` from common error-returning APIs) but `errcheck` is the comprehensive backstop.

    **Why:** silent error swallowing is the single largest source of "the app behaves weird in production but everything looks fine in dev". A discarded error today is a 3 AM incident next quarter.
20. **No memory leaks, no dangling resources, no orphaned goroutines.** Every acquired resource has a paired release on every code path:
    - **`context.WithCancel` / `WithTimeout` / `WithDeadline`** → `defer cancel()` immediately. `govet -lostcancel` catches the static cases; review covers the rest.
    - **`http.Response.Body`** → `defer resp.Body.Close()` immediately after the `if err != nil` check (the Body is non-nil even on some non-2xx responses). Drain it (`io.Copy(io.Discard, resp.Body)`) before close if you want connection reuse.
    - **`os.File`, `*sql.Rows`, `*os.Stdin` substitutes** → `defer f.Close()`. GORM usually manages rows, but raw `db.Raw(...).Rows()` calls are your responsibility.
    - **`time.NewTicker` / `time.NewTimer`** → `defer ticker.Stop()`. Especially long-lived tickers spawned from goroutines.
    - **Long-running goroutines** must accept a `context.Context` (or a `done <-chan struct{}`) and exit when it's cancelled. The pattern: spawn at startup with the app's root context, cancel on `SIGTERM`. Never spawn a goroutine that has no termination contract — it will outlive the request, the user, and eventually the server.
    - **Channels** that are sent to in a loop must have a documented close discipline. Forgotten close → leaked receivers blocked forever.
    - **Repositories that open transactions** (`db.Begin()`) must `defer tx.Rollback()` and explicitly `tx.Commit()` on the happy path; the rollback is a no-op after a successful commit.

    **Tools:**
    - `go vet ./...` (covers `lostcancel` plus several leak smells) — run in CI.
    - `golangci-lint run --enable=govet,errcheck,bodyclose,sqlclosecheck,rowserrcheck` for comprehensive coverage.
    - `go.uber.org/goleak` in tests — assert no goroutines leaked from a test (great for repository/use_case tests that spawn workers).

    The skill's `tools/lint.sh` carries a few shell-level smells (e.g. `context.WithCancel` with no nearby `defer cancel`), but Go's static analysis tooling is the real backstop. Wire it into CI alongside `lint-arch`.

    **Why:** a leaked goroutine silently consumes memory and DB connections until the pod OOM-kills. A leaked `resp.Body` exhausts the HTTP client's connection pool. Both bugs look fine in dev (tiny load, short uptime) and only surface under sustained traffic — i.e. exactly when you can't iterate fast.
21. **Bounded fan-out for independent third-party calls in list endpoints.** When a list response needs to enrich N items by calling an external HTTP service (account-service profile lookup, billing, geocoding, etc.), the calls run in parallel via `golang.org/x/sync/errgroup`, **not** sequentially. The shape:

    ```go
    import "golang.org/x/sync/errgroup"

    g, gctx := errgroup.WithContext(ctx)
    g.SetLimit(10)                                 // bounded concurrency
    for i := range items {
        i := i                                     // capture per-iteration
        g.Go(func() error {
            profile, err := r.accountClient.GetProfile(gctx, items[i].UserID)
            if err != nil {
                log.Printf("[enrich] request_id=%s user_id=%s err=%v",
                    common_utils.RequestIDFrom(gctx), items[i].UserID, err)
                return nil                         // tolerate per-item failure; don't break the whole list
            }
            items[i].Username = profile.Username
            return nil
        })
    }
    if err := g.Wait(); err != nil {
        return nil, http.StatusInternalServerError, err
    }
    ```

    **Read this with rule #11**, which bans concurrent fan-out for DB calls. The two rules don't contradict — they apply to different downstreams:
    - **DB** has a finite connection pool sized for the whole app. Fanning out 100 queries from one request will starve every other in-flight request. Rule #11 says batch-fetch instead.
    - **HTTP to a third-party service** has its own per-host pool (typically larger, tunable on the `http.Client`), and the bottleneck is round-trip latency, not your local connection pool. Rule #21 says fan out, but **bounded** (`g.SetLimit(10)` typically; never unbounded `for { go f() }`).

    Constraints:
    - Use **`errgroup.WithContext`**, not bare `sync.WaitGroup`. errgroup gives you ctx-cancellation, first-error short-circuit, and bounded concurrency in one type.
    - Set a concrete **`SetLimit`** — `10` is the default starting point. Never spawn `len(items)` goroutines unbounded; you'll DDoS the third-party and your egress cost will spike.
    - Per-item failures should usually be **tolerated** (return `nil` from the goroutine, log with `request_id`) so one flaky third-party row doesn't break the whole list response. Hard failures bubble via `g.Wait()`.
    - The goroutine must read `gctx` (the errgroup-derived context), not the outer `ctx`. errgroup's context is cancelled the moment any goroutine returns a non-nil error — the rest stop early instead of wasting calls.

    **When to reach for raw channels instead of errgroup.** errgroup is the canonical because it bundles bounded concurrency + ctx cancellation + error propagation in 5 lines. But channels are the underlying primitive and the right tool when:

    - **Streaming**: results need to be consumed as they arrive (e.g. write each enriched item to an SSE/WebSocket the moment it's ready, instead of buffering the whole list).
    - **Worker pool with a job queue**: a fixed pool of N workers drains a `chan Job` and emits to a `chan Result` — useful when the same workers are reused across multiple requests, or when jobs take wildly varying times.
    - **Backpressure**: a buffered channel `chan struct{}` of size N acts as a counting semaphore — workers `<- sem` before doing work and `sem <-` after; exceeds N → block.

    Canonical channel-semaphore + WaitGroup fan-out (use this when errgroup doesn't fit):

    ```go
    sem := make(chan struct{}, 10)           // bounded to 10 concurrent
    results := make(chan EnrichedItem, len(items))
    var wg sync.WaitGroup

    for i := range items {
        wg.Add(1)
        sem <- struct{}{}                    // acquire slot (blocks if 10 in flight)
        go func(i int) {
            defer wg.Done()
            defer func() { <-sem }()         // release slot
            profile, err := r.accountClient.GetProfile(ctx, items[i].UserID)
            if err != nil {
                log.Printf("[enrich] request_id=%s user_id=%s err=%v",
                    common_utils.RequestIDFrom(ctx), items[i].UserID, err)
                results <- EnrichedItem{Item: items[i]}   // partial result is OK
                return
            }
            results <- EnrichedItem{Item: items[i], Username: profile.Username}
        }(i)
    }

    go func() { wg.Wait(); close(results) }() // close drains the for-range below

    for r := range results {
        // process as they come in (stream to client, etc.)
    }
    ```

    Rules around channels (these are mandatory whenever you reach for them):
    - **Always have one writer or document the close discipline.** Whoever closes the channel should be the only writer, or all writers must coordinate. Closing a channel that another goroutine is writing to panics.
    - **`for range chan` requires the channel to be closed.** Forgetting `close(results)` deadlocks the range loop forever.
    - **Buffered channels for bounded concurrency**, unbuffered channels for synchronisation. Pick deliberately.
    - **The channel itself must respect ctx**: workers should `select { case sem <- struct{}{}: case <-ctx.Done(): return }` so cancellation actually unblocks. errgroup hides this; raw channels make you do it explicitly.

    **Choose the simplest tool that fits:** errgroup for "enrich a list with parallel calls and wait for all", channels for streaming / worker-pool / fancy backpressure. If you find yourself reinventing errgroup with channels, just use errgroup.

    **Tools:**
    - `golang.org/x/sync/errgroup` — canonical fan-out + wait + first-error.
    - `golang.org/x/sync/semaphore.NewWeighted(n)` — typed semaphore alternative to `chan struct{}`.
    - `golang.org/x/time/rate.Limiter` — when the third-party has explicit RPS limits.

    **Why:** a `GET /api/friends` that returns 50 friends, each enriched with a 200ms call to account-service, takes 10 seconds sequentially. With `SetLimit(10)`, it takes ~1 second. The user perceives the app as broken if list endpoints take > 2s. This rule is the difference between "snappy" and "users open a support ticket".

## Mandatory reading order

Read references in this exact sequence. Each line is a checkpoint — confirm understanding (or with the user, confirm completion of the implementation it describes) before moving to the next.

| Phase | Read | When to read it |
|------:|:----|:----|
| 0 | `references/instruction_order.md` | Always first. Re-read the rules + checkpoints below before starting any non-trivial task in such a project. |
| 1.1 | `references/project_architecture.md` | Before designing or touching any layer. Cements Clean Architecture principles, layer responsibilities, allowed dependencies. |
| 1.2 | `references/app_package.md` | Before creating or modifying any file under `app/`. This is the longest doc — only read sections relevant to the task (controller, use_case, repository, filter pattern, errors, transforms). 99% adherence is required before Phase 2/3. |
| 2.1 | `references/main_and_routes_guide.md` | Before touching `main.go`, `routes/`, or the wiring between layers. Covers dependency injection and route grouping. |
| 2.2 | `references/MAP_VALIDATOR_GUIDE.md` | Before adding or changing any controller request struct or `rules.go`. Use the v0.0.41+ short-constructor idioms (`Str`, `Int`, `Email`, `UUID`, `StrEnum`, `IntEnum`, `NestedObject`, `ListOfObject`) and chain helpers (`.Nullable`, `.Default`, `.WithMin`, `.WithMax`, `.Between`, `.Regex`, `.WithMsg`, `.UniqueFrom`, `.WithRequiredIf`, `.WithRequiredWithout`). The 5-step pipeline is an escape hatch only. |
| 3.1 (optional) | `references/swagger_annotation_guide.md` | Only after controllers + routes are working end-to-end. Annotate **HTTP handler functions only** — never use_case, repository, or private helpers. |
| 3.2 (optional) | `references/apm_and_log_guide.md` | Only when Phase 1–2 are 99% complete and all business features are working. |
| Sidebar | `references/anti-patterns.md` | Whenever you're about to write or review a loop with a repo call, a transform between layers, a filter struct, a placeholder function, or a timezone-dependent calculation. Concrete "salah vs benar" examples for every hard rule. |
| Recipe | `references/feature-recipe.md` | Whenever you're adding a new feature end-to-end. Concrete walkthrough: file layout per layer, schema + AutoMigrate, central wiring (`repositories.go` / `use_cases.go` / `controllers.go`), routes setup, ownership filter from controller, computed filter translation in use_case, datetime validation note. Use the `reminders` example as template. |
| Bootstrap | `references/bootstrap-new-project.md` | Whenever the user starts a brand-new Go REST project that should adopt this playbook from day one. Covers `go mod init`, dependency list, directory skeleton, the four shared utility packages (`pkg/paginate_utils/`, `app/*/common/`), database bootstrap, empty central wiring, `CLAUDE.md` pointer, and lint integration. End state: a project that compiles with zero features but is ready for the first one. |

If a user request requires content from a phase the project hasn't reached yet, refuse and explain — do not jump phases.

## Stop-and-Wait checkpoint template

Use this checkpoint pattern between layers. Confirm with the user before continuing:

```
Layer X selesai:
- Yang dibuat: <files + key types/functions>
- Hard rules dipatuhi: <bullet list>
- Belum disentuh: <next layer>

Lanjut ke layer berikutnya?
```

## Workflow patterns (cheat sheet)

### Adding a new feature end-to-end
1. Confirm Phase 1 (architecture + app_package) is already 99% in this codebase. If not, surface gaps first.
2. Layer order: **repository → use_case → controller → routes**. Stop-and-Wait between each.
3. For every layer, re-read the matching reference section before writing code.
4. Validation rules go in `controller/<feature>/rules.go`; request structs go in `controller/<feature>/models.go` without `binding` tags.
5. Wire into `routes/routes.go` last; add Swagger annotations only after the route works.

### Bug fix in an existing layer
1. Read only the reference for the layer you're touching plus `project_architecture.md`.
2. Apply the change without leaking concerns into adjacent layers.
3. Skip Stop-and-Wait if the change is a single-layer single-file fix; still announce what changed.

### When the user requests APM or Swagger up-front
- Verify Phase 1–2 completion. If incomplete, refuse with the checklist from `references/instruction_order.md` (Rule #3 / Rule #4) and offer to complete the prerequisite layers first.

## Lint contracts (automated rule enforcement)

Every static-auditable hard rule has a matching shell-script check in `tools/lint.sh` at the plugin repo root. Drop it into a project's CI to catch violations automatically — humans don't have to remember to grep. The script flags:

- Forbidden imports per layer (rule #4): GORM/schemas/gin in the wrong package.
- GORM tags outside repository/schemas (rule #6).
- `*gin.Context` / `GetAuthClaim` outside controllers (rule #7).
- Repo methods named `GetByX`/`FindByX` (rule #8).
- `c.ShouldBindJSON` or `binding:` tags in controllers (rule #9).
- `time.LoadLocation` outside `app/use_case/common/timezone.go` (rule #10).
- Hand-rolled pagination math, raw `gin.H` responses (rule #10).
- Use_case loops with repo method calls inside (rule #11, heuristic).
- Placeholder/TODO no-op comments (rule #12, heuristic).
- `time.Time.In(loc)` inside transform.go (rule #13, output-UTC).

Wire it via Makefile + CI — see `references/bootstrap-new-project.md` Step 10 for the canonical setup. Existing projects can run it ad-hoc:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Rhyanz46/go-rest-skills/main/tools/lint.sh)
```

Violations exit non-zero with file:line citations grouped by rule. Heuristic checks (rules #11, #12) may have false positives — verify before refactoring.

## Pointers, not paraphrases

For every concrete pattern (filter struct shape, repository signatures, error mapper, validator rule examples, span/log fields, Swagger comment template), **read the reference file** rather than relying on memory. The references are the source of truth and may evolve; this SKILL.md only captures the orchestration rules.
