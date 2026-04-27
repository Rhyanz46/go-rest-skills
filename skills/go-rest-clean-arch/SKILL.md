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
6. **Three sets of models, transform at every boundary.**
   - `app/repository/<feature>/models.go` speaks GORM (struct tags, schema imports, primary keys).
   - `app/use_case/<feature>/interfaces.go` speaks domain (no GORM tags, no `gin.Context`, no JSON tags).
   - `app/controller/<feature>/models.go` speaks HTTP (request/response shapes, JSON tags, no GORM tags).

   Conversion happens in dedicated transform helpers (`transformXToY`). Never re-use a single struct across two layers — even if the fields look identical today, the layers will drift.
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

## Pointers, not paraphrases

For every concrete pattern (filter struct shape, repository signatures, error mapper, validator rule examples, span/log fields, Swagger comment template), **read the reference file** rather than relying on memory. The references are the source of truth and may evolve; this SKILL.md only captures the orchestration rules.
