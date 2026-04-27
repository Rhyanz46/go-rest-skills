# Anti-Patterns: Salah vs Benar

This file is a quick lookup of concrete code shapes that violate the hard rules in `SKILL.md`, paired with the canonical correct shape. Read the matching section before writing or reviewing code in that area.

> **Use this with the rule numbers from SKILL.md.** Every section maps to one or more rules.

---

## A. Filter Pattern (rule #8)

### ❌ Salah — one method per query shape

```go
// app/repository/user_repository/repository.go
func (r *userRepository) GetByEmail(ctx context.Context, email string) (*User, int, error) { ... }
func (r *userRepository) GetByID(ctx context.Context, id uuid.UUID) (*User, int, error) { ... }
func (r *userRepository) FindByStatusAndRole(ctx context.Context, status, role string) ([]User, int, error) { ... }
```

Symptom: the repo grows a new method for every new query in a controller. Caller code can't compose conditions. Test coverage explodes.

### ✅ Benar — single Filter struct + one apply helper

```go
// app/repository/user_repository/filters.go
type UserFilter struct {
    Id     *uuid.UUID
    Email  *string
    Status *string
    Role   *string
}

func applyUserFilters(q *gorm.DB, f UserFilter) *gorm.DB {
    if f.Id != nil      { q = q.Where("id = ?",     *f.Id) }
    if f.Email != nil   { q = q.Where("email = ?",  *f.Email) }
    if f.Status != nil  { q = q.Where("status = ?", *f.Status) }
    if f.Role != nil    { q = q.Where("role = ?",   *f.Role) }
    return q
}

// app/repository/user_repository/interfaces.go
type UserRepository interface {
    GetOne(ctx context.Context, filter UserFilter) (*User, int, error)
    List(ctx context.Context, filter UserFilter, p *paginate_utils.PaginateData) ([]UserListItem, int64, int, error)
    // Create / Update / Delete also go through UserFilter for the WHERE side.
}
```

Use_case calls: `r.userRepo.GetOne(ctx, UserFilter{Email: &email})` — composable, testable, and the repo never grows a new method for a new combination of fields.

---

## B. Layer dependency direction (rule #4) and three model sets (rule #6)

### ❌ Salah — repo struct used directly in HTTP response

```go
// app/controller/track_controller/controller.go
func (ctrl *trackController) GetTracks(c *gin.Context) {
    tracks, _, _ := ctrl.trackUseCase.GetTracks(...)   // returns []track_repository.Track (GORM model)
    c.JSON(200, tracks)                                // GORM tags + relations leak to JSON
}
```

Symptom: GORM struct tags appear in the API contract, deleted_at fields leak to clients, adding a private DB column accidentally exposes it as JSON.

### ✅ Benar — three model sets + transforms at boundaries

```go
// app/repository/track_repository/models.go      ← speaks GORM
type Track struct {
    ID        uint      `gorm:"primaryKey"`
    UserID    *uuid.UUID
    Start     time.Time
    DeletedAt gorm.DeletedAt `gorm:"index"`
    // ...
}

// app/use_case/track_use_case/interfaces.go      ← speaks domain
type TrackResponse struct {
    ID    uint
    Owner uuid.UUID
    Start time.Time
}

// app/controller/track_controller/models.go      ← speaks HTTP
type TrackHTTPResponse struct {
    ID    uint      `json:"id"`
    Owner uuid.UUID `json:"owner"`
    Start time.Time `json:"start"`
}

// transform.go in each layer converts at the boundary.
```

The fields might be identical today. They will diverge in 6 months. Keep them separate from day one.

### B.1 — Subtle variant: importing `database/schemas` from a use_case

```go
// app/use_case/friend_use_case/usecase.go
import "planner-backend/database/schemas"   // ← violates rule #4

func (r *friendUseCase) Accept(...) {
    var f schemas.Friendship                 // GORM model in domain logic
    // ...
}
```

The schema package *is* the GORM model layer. Importing it into a use_case is the same crime as putting `gorm:` tags on a use_case struct — you've coupled domain logic to the persistence schema. Any future schema rename or split forces the use_case to change.

### ✅ Benar — repo returns its own domain type, use_case never sees `schemas`

```go
// app/repository/friends_repository/models.go
type Friendship struct {                     // domain-level, no GORM tags
    ID          uint
    RequesterID uuid.UUID
    AccepterID  uuid.UUID
    Status      string
}
// schema → domain transform stays inside the repository package.

// app/use_case/friend_use_case/usecase.go
import "planner-backend/app/repository/friends_repository"   // OK
// no schemas import anywhere
```

Grep that should be empty in a clean repo: `rg 'database/schemas' app/use_case/`.

### B.2 — Depending on a concrete struct instead of the layer's interface

```go
// app/use_case/track_use_case/interfaces.go
type UseCaseDependencies struct {
    TrackRepo *track_repository.trackRepository   // ← concrete unexported struct
}
```

Symptoms:
- The use_case can't be tested without spinning up a real GORM connection.
- A bug in `*trackRepository.GetOne` is impossible to substitute with a fake.
- Refactoring the repo (renaming a method, adding a parameter) silently breaks every consumer because there's no contract to look at.

### ✅ Benar — depend on the interface the layer publishes

```go
// app/use_case/track_use_case/interfaces.go
type UseCaseDependencies struct {
    TrackRepo track_repository.TrackRepository    // ← exported interface
}

// app/repository/track_repository/interfaces.go is the single place that
// declares TrackRepository — same package as its concrete implementation
// (provider-defined, not consumer-defined; see rule #6).
```

The same shape applies one layer up: controllers depend on `XUseCase` (interface), never on `*xUseCase` (concrete). Wiring in `app/controller/controllers.go` always assigns interface fields.

Quick smell test: any field in a `Dependencies` struct (`UseCaseDependencies`, `RepositoryDependencies`, `ControllerDependencies`) whose type is a pointer to a lowercase-named struct — that's depending on a concrete unexported struct, which is a violation.

---

## C. Auth context leak (rule #7)

### ❌ Salah — `*gin.Context` reaches the use_case

```go
// use_case
func (r *trackUseCase) ListMyTracks(ctx context.Context, c *gin.Context) (...) {
    userID, _ := common.GetUserIDFromContext(c)
    // ...
}
```

Symptom: use_case unit tests need a fake `*gin.Context`. Repository tests need it too if it leaks further. Auth source becomes implicit.

### ✅ Benar — IDs are explicit parameters

```go
// controller
func (ctrl *trackController) GetTracks(c *gin.Context) {
    userID, _ := common.GetUserIDFromContext(c)        // <-- only place this happens
    userUUID, _ := uuid.Parse(userID.(string))
    resp, code, err := ctrl.trackUseCase.ListMyTracks(c.Request.Context(), userUUID)
    // ...
}

// use_case
func (r *trackUseCase) ListMyTracks(ctx context.Context, userID uuid.UUID) (*TrackListResponse, int, error) {
    // ...
}
```

Use_case takes a `context.Context` (for cancellation/deadlines) and explicit IDs. Nothing else.

---

## D. Error trio `(result, int, error)` (rule #5)

### ❌ Salah — only `(result, error)`, controller invents the status

```go
// repo
func (r *userRepository) GetOne(ctx context.Context, f UserFilter) (*User, error) { ... }

// controller — assumes 500 on any error
if err != nil { c.JSON(500, gin.H{"error": err.Error()}); return }
```

Symptom: 404 vs 500 vs 409 distinctions are lost. Every error becomes a 500.

### ✅ Benar — repo and use_case carry the status

```go
// repo
func (r *userRepository) GetOne(ctx context.Context, f UserFilter) (*User, int, error) {
    var u schemas.User
    if err := applyUserFilters(r.db, f).First(&u).Error; err != nil {
        statusCode, repoErr := common.HandleGORMError(err)   // 404 / 500 / 409 ...
        return nil, statusCode, repoErr
    }
    return mapToDomain(&u), http.StatusOK, nil
}

// use_case forwards the trio
// controller passes the int directly to c.JSON
```

`pkg/common/HandleGORMError` (or `app/repository/common/`) gives canonical mappings — use them instead of inventing per-feature.

---

## E. N+1 in the use_case loop (rule #11)

### ❌ Salah — query per iteration

```go
func (r *templatePlanUseCase) GetActiveRecurringTemplates(ctx context.Context, userID uuid.UUID) ([]TemplatePlanResponse, int, error) {
    listItems, _, _, _ := r.templatePlanRepo.List(ctx, filter, nil)
    out := make([]TemplatePlanResponse, 0, len(listItems))
    for _, item := range listItems {
        full, _, err := r.templatePlanRepo.GetOne(ctx, TemplatePlanFilter{Id: &item.ID})  // ← per-iteration query
        if err != nil { continue }
        out = append(out, *r.transform(full))
    }
    return out, http.StatusOK, nil
}
```

Symptom: 1 + N queries for N templates. Latency grows linearly with row count.

### ✅ Benar — batch fetch + map lookup

```go
func (r *templatePlanUseCase) GetActiveRecurringTemplates(ctx context.Context, userID uuid.UUID) ([]TemplatePlanResponse, int, error) {
    // Either: have List return full templates instead of list items.
    // Or: collect IDs and fetch all in one shot:
    listItems, _, _, _ := r.templatePlanRepo.List(ctx, filter, nil)
    ids := make([]uint, len(listItems))
    for i, it := range listItems { ids[i] = it.ID }

    fulls, _, _ := r.templatePlanRepo.ListFull(ctx, TemplatePlanFilter{Ids: ids})  // ← one query
    out := make([]TemplatePlanResponse, 0, len(fulls))
    for _, t := range fulls {
        out = append(out, *r.transform(&t))
    }
    return out, http.StatusOK, nil
}
```

If the repo doesn't have a method that returns full rows for an `Ids: []uint` filter — **add one**. Don't loop and call `GetOne`.

### ❌ Salah — fan out via goroutines

```go
for _, id := range ids {
    go func(id uint) { full, _, _ := repo.GetOne(ctx, ...); ch <- full }(id)
}
```

Same N queries, just concurrent. DB connection pool fills up, "improves" latency for one user but tanks throughput. Forbidden.

### E.1 — Subtle variant: per-item validation loop

```go
// app/use_case/sharing_use_case/validation.go
func (r *sharingUseCase) validateTagOwnership(ctx context.Context, userID uuid.UUID, tagIDs []uint) error {
    for _, tagID := range tagIDs {
        _, status, err := r.trackRepo.GetOneTag(ctx, TagFilter{Id: &tagID})  // ← per-tag query
        if err != nil { /* ... */ }
        // also check ownership per tag
    }
    return nil
}
```

This isn't enrichment — it's *validation* — but it's still N+1. A user creating a share with 20 tags fires 20 queries for a single ownership check.

### ✅ Benar — single batch query, validate against the result set

```go
func (r *sharingUseCase) validateTagOwnership(ctx context.Context, userID uuid.UUID, tagIDs []uint) error {
    tags, _, _, err := r.trackRepo.ListTags(ctx, TagFilter{Ids: tagIDs, OwnerUserID: &userID}, nil)
    if err != nil { return common.RepositoryErrorToDomain(...) }
    if len(tags) != len(tagIDs) {
        return errors.New("one or more tags not found or not owned by user")
    }
    return nil
}
```

One query, both existence and ownership verified. Same shape applies to "all tracks belong to user", "all friend IDs are accepted", etc.

---

## F. Reusing pagination per feature (rule #10)

### ❌ Salah — hand-rolled pagination per controller

```go
type GetTracksRequest struct {
    Page     int `form:"page"`
    PageSize int `form:"page_size"`
}

// controller
offset := (req.Page - 1) * req.PageSize
if offset < 0 { offset = 0 }
db.Offset(offset).Limit(req.PageSize).Find(&tracks)
total := int64(0); db.Model(&Track{}).Count(&total)
c.JSON(200, gin.H{
    "data":  tracks,
    "page":  req.Page,
    "size":  req.PageSize,
    "total": total,
})
```

Symptom: every list endpoint reinvents offset math, response shape, and edge-case handling (page < 1, page_size > 100). The five places will drift.

### ✅ Benar — `pkg/paginate_utils` once

```go
// controller
paginate := paginate_utils.PaginateData{Page: req.Page, Limit: req.PageSize}
resp, code, err := ctrl.useCase.ListTracks(ctx, filter, &paginate)

// repo
query := applyTrackFilters(db.Model(&schemas.Track{}), filter)
var total int64
query.Count(&total)
query = query.Scopes(paginate_utils.Paginate(p))
query.Find(&tracks)

// use_case wraps the response
return &TrackListResponse{
    Tracks:     items,
    Total:      total,
    Pagination: paginate_utils.NewPagination(p, total),
}, http.StatusOK, nil
```

One source of truth for offset math, response shape, and edge case handling.

---

## G. Placeholder no-op (rule #12)

### ❌ Salah — function returns nil but does nothing

```go
// "TODO: implement properly later"
func (r *templatePlanUseCase) deleteAllTracksByDateAndUser(ctx context.Context, date time.Time, userID uuid.UUID) error {
    // For now, return nil as placeholder
    return nil
}
```

Real bug shipped: `ApplyPlan(rewrite=true)` called this, got `nil`, then created new tracks on top of the old ones — duplicates everywhere.

### ✅ Benar — implement, error out, or remove

```go
// Option 1: implement.
func (r *templatePlanUseCase) deleteAllTracksByDateAndUser(ctx context.Context, date time.Time, userID uuid.UUID) error {
    _, err := r.trackRepo.Delete(ctx, track_repository.TrackFilter{UserID: &userID, Date: &date})
    return err
}

// Option 2: signal explicitly that the dependency isn't ready.
func (r *templatePlanUseCase) deleteAllTracksByDateAndUser(...) error {
    return errors.New("not implemented: needs trackRepo.DeleteByDateAndUser; tracked in #123")
}

// Option 3: remove the function from the interface entirely until needed.
```

A `return nil` lies to the caller. Either the function works, or it returns an error that says it doesn't.

### G.1 — Subtle variant: a function whose body is *one branch* of real work, gated by a `// TODO`

```go
func (r *templatePlanUseCase) ensureSingleInProgressTrack(ctx context.Context, userID uuid.UUID, created []interface{}) error {
    hasInProgress := false
    for _, t := range created { /* ... detect ... */ }

    if hasInProgress {
        // This would complete all other "in progress" tracks for this user.
        // Implementation would go here in production.
        // For now, just return nil.
    }
    return nil
}
```

This is worse than the obvious placeholder — there *is* logic (the detection loop), but the actual side-effect is gated behind a `// TODO`. The function reads like it's working. Callers see no error, code reviewers skim past the comment.

Treat it the same way: either implement the side-effect, return an explicit error, or delete the function. Don't ship "half a function".

---

## H. Timezone — server-local "today" (rule #13 + timezone helpers from rule #10)

### ❌ Salah — server's `time.Now()` for "today"

```go
now := time.Now()
today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
```

In a container with `TZ=UTC` (most production hosts), this gives UTC midnight. A user in WIB at 6 AM today gets yesterday's stats.

### ✅ Benar — anchor to user/owner timezone via helpers

```go
loc, _ := common.LoadLocationOrDefault(r.getUserTimezone(ctx, userID))
today := common.StartOfDayInTZ(time.Now(), loc)  // midnight in user's TZ
```

For input dates parsed from the wire (e.g. `?date=2026-04-25` parsed by gin to UTC midnight), reinterpret them:

```go
anchored := common.ReinterpretDateInTZ(*req.Date, loc)
```

For output, **don't** convert — keep `time.Time` UTC and let frontend localize (rule #13).

### H.1 — Subtle variant: direct `time.LoadLocation` calls scattered across the use_case

```go
// app/use_case/track_use_case/usecase.go (×6 callsites)
loc, err := time.LoadLocation(userTimezone)
if err != nil {
    loc, _ = time.LoadLocation("Asia/Jakarta")   // fallback duplicated everywhere
}
```

The fallback is fine in isolation. Repeated 11 times across 2 files, it becomes a maintenance liability — change the default TZ once and you must hunt every callsite. Plus most callsites silently `_` the error (a smell of its own).

### ✅ Benar — funnel through one helper

```go
loc, tz := common.LoadLocationOrDefault(userTimezone)
// loc is never nil; tz tells you whether the input was honoured or fell back
```

Rule of thumb: in `app/use_case/**`, the only acceptable callsite of `time.LoadLocation` is **inside** `app/use_case/common/timezone.go`. Anywhere else, use the helper. Same logic applies to other "load this thing or fall back" primitives — wrap once, reuse.

---

## I. Audit-before-fix (rule #3)

### ❌ Salah — fix one callsite, miss four others

> "Bug: filter `?date=2026-04-25` returns wrong tracks for Tokyo user. Fixed in `track_use_case.GetTracks`."
> *... two weeks later ...*
> "Bug: filter `?date_from=...` returns wrong tracks for Tokyo user."
> *... two weeks later ...*
> "Bug: shared history endpoint returns wrong dates for owner timezone."

Same root cause, three separate tickets, three separate PRs, all because the first fix didn't grep for every callsite of the affected pattern.

### ✅ Benar — grep first, refactor all callers in one pass

```bash
# Before fixing the first symptom, find every related callsite:
rg -n 'time.Now\(\)' app/use_case/
rg -n 'filter\.Date|filter\.DateFrom|filter\.DateTo' app/repository/
rg -n 'Format\("2006-01-02"\)' app/use_case/
```

Then either: refactor all in one PR, or open one ticket that lists all spots and fix in dedicated commits inside one branch. Don't ship symptom-fix PRs and hope the next person notices.

---

## J. REST surface naming — two buckets, no exceptions (rule #17)

### ❌ Salah — camelCase JSON keys

```go
// app/controller/track_controller/models.go
type TrackResponse struct {
    ID        uint      `json:"id"`
    UserID    uuid.UUID `json:"userId"`        // ← camelCase
    CreatedAt time.Time `json:"createdAt"`     // ← camelCase
    DueAt     time.Time `json:"dueAt"`         // ← camelCase
}
```

Frontend has to write `response.userId ?? response.user_id` shims because half the backend uses snake, half uses camel. Forever.

### ✅ Benar — snake_case JSON keys

```go
type TrackResponse struct {
    ID        uint      `json:"id"`
    UserID    uuid.UUID `json:"user_id"`
    CreatedAt time.Time `json:"created_at"`
    DueAt     time.Time `json:"due_at"`
}
```

### ❌ Salah — snake_case in query / path params

```go
// request struct
type GetTracksRequest struct {
    DateFrom *time.Time `form:"date_from"`     // ← snake in URL
    PageSize int        `form:"page_size"`     // ← snake in URL
}

// routes
r.GET("/api/shared/:user_id/tracks", c.GetSharedTracks)   // ← snake path param
r.GET("/api/template_plan/:id", c.GetTemplate)            // ← snake path segment
```

Client URL becomes `/api/shared/abc123/tracks?date_from=2026-04-25&page_size=20`. Underscore inside URL paths is technically valid but uncommon, conflicts with auto-link parsers, and mixes two casings on the same surface (path is `/template_plan` snake, but `/api` is just a word — looks wrong).

### ✅ Benar — kebab-case for everything in the URL

```go
type GetTracksRequest struct {
    DateFrom *time.Time `form:"date-from"`
    PageSize int        `form:"page-size"`
}

r.GET("/api/shared/:user-id/tracks", c.GetSharedTracks)
r.GET("/api/template-plan/:id", c.GetTemplate)

// inside the controller:
userID := c.Param("user-id")   // matches the route declaration
```

Client URL becomes `/api/shared/abc123/tracks?date-from=2026-04-25&page-size=20`. Reads as one consistent dialect.

### ❌ Salah — camelCase URL paths

```go
r.GET("/api/templatePlan/:id", c.GetTemplate)
r.POST("/api/personaProfile/answers", c.SubmitAnswers)
```

Some clients lowercase URLs; some don't. Inconsistent behaviour across proxies and CDNs.

### ✅ Benar — kebab-case URL paths

```go
r.GET("/api/template-plan/:id", c.GetTemplate)
r.POST("/api/persona-profile/answers", c.SubmitAnswers)
```

### Quick mental model

| Surface | Casing | Example |
|---|---|---|
| JSON body keys | `snake_case` | `"user_id": "abc"` |
| URL path segment | `kebab-case` | `/api/template-plan` |
| URL path param | `kebab-case` | `:user-id` |
| URL query param | `kebab-case` | `?date-from=2026-04-25` |
| HTTP header | `Pascal-Kebab` | `X-Auth-Cron` |
| Internal Go field | `PascalCase` | `UserID uuid.UUID` |

Boundary conversion is the controller's job (`json:"..."`, `form:"..."` tags + `c.Param("...")`). Use_case and repository layers never see the wire casing.

---

## K. Internal errors leaking to clients (rule #18)

### ❌ Salah — raw `err.Error()` shipped to client at 5xx

```go
// app/controller/track_controller/controller.go
resp, code, err := ctrl.useCase.GetTrack(c.Request.Context(), id)
if err != nil {
    c.JSON(code, gin.H{"error": err.Error()})   // ← leaks DB / internal detail
    return
}
```

When the DB times out and use_case returns `(nil, 500, errors.New("dial tcp 10.0.0.5:5432: connection refused"))`, the client gets that exact string. Now an attacker knows your internal subnet, and a frontend has to render database error strings in a popup. Plus there's no `request_id` for support to grep with.

### ❌ Salah — manually crafted error response per controller

```go
if err != nil {
    if code >= 500 {
        log.Println("internal error:", err)
        c.JSON(code, gin.H{"message": "something went wrong"})
        return
    }
    c.JSON(code, gin.H{"message": err.Error()})
    return
}
```

Better than the first version, but every controller now repeats the 4xx-vs-5xx branch. Drift inevitable: one controller forgets to log, another forgets to return `request_id`, a third leaks the original error in a 503.

### ✅ Benar — single chokepoint via `common.SendError`

```go
import "github.com/<owner>/something-backend/app/controller/common"

resp, code, err := ctrl.useCase.GetTrack(c.Request.Context(), id)
if err != nil {
    common.SendError(c, code, err)   // does the right thing for 4xx and 5xx
    return
}
common.SendSuccess(c, code, resp)
```

`SendError` handles:
- 4xx → returns `err.Error()` to client (caller-facing message).
- 5xx → logs `request_id`, method, path, user_id, and original `err`; returns generic `"internal server error"` + `request_id` to client.

Controllers stay short; sanitization can't be forgotten because the helper enforces it.

### ❌ Salah — request_id only in `gin.Context`, not in `context.Context`

```go
// middleware
c.Set("request_id", id)
c.Next()

// use_case (downstream)
func (r *trackUseCase) GetTrack(ctx context.Context, id uint) (*Track, int, error) {
    log.Printf("fetching track %d", id)   // ← no request_id here
    // ...
}
```

The use_case never sees `gin.Context` (rule #7), so it can't log the `request_id`. When the DB error occurs three layers down, the log line has no correlation key. Incident triage = 🔥.

### ✅ Benar — `context.Context` carries the ID through every layer

```go
// middleware sets BOTH
c.Set("request_id", id)
c.Request = c.Request.WithContext(common_utils.WithRequestID(c.Request.Context(), id))

// use_case logs with the ID, no gin dependency
func (r *trackUseCase) GetTrack(ctx context.Context, id uint) (*Track, int, error) {
    if err := r.somethingRisky(ctx); err != nil {
        log.Printf("[track_use_case] request_id=%s err=%v",
            common_utils.RequestIDFrom(ctx), err)
        return nil, http.StatusInternalServerError, err
    }
    // ...
}
```

Now `grep request_id=abc-123` returns every log line for the failing request: middleware ⇒ controller ⇒ use_case ⇒ repo ⇒ DB error.

### Smell test for code reviewers

| Smell | Likely violating |
|---|---|
| `c.JSON(...err.Error()...)` in a controller | rule #18 (b) — 5xx sanitization |
| `gin.H{"error": ...}` shape returned | rule #18 (b) and rule #10 (response envelope) |
| `log.Printf` in use_case without `RequestIDFrom(ctx)` | rule #18 (c) — structured logging |
| No `X-Request-ID` in response header | rule #18 (a) — middleware not wired |
| Request-id read from `c.GetString("request_id")` inside use_case | rule #7 — auth-context-style leak; use `RequestIDFrom(ctx)` instead |

---

## L. Silently ignored errors (rule #19)

### ❌ Salah — discarding the error with `_`

```go
result, _ := r.repo.GetOne(ctx, filter)
return result, http.StatusOK, nil

// later, when the DB is down:
//   result == zero value, statusCode == 200, no log line, no alert.
//   Frontend renders empty data. Users tweet at you.
```

The 200 OK is a lie. The repo could not load anything; the use_case said "all good". Errors that aren't checked aren't errors — they're silent landmines.

### ❌ Salah — fire-and-forget goroutine that swallows the error

```go
go func() {
    _ = r.notifyExternalService(ctx, payload)
}()
```

If the external service is down for an hour, you have **zero** evidence in the logs. Eventually a customer notices and you find out via a support ticket.

### ✅ Benar — check, propagate, or justify with a comment

```go
result, code, err := r.repo.GetOne(ctx, filter)
if err != nil {
    return nil, code, common.RepositoryErrorToDomain(code, err)
}
return result, http.StatusOK, nil
```

Or, when ignoring is genuinely correct, a one-line comment names the reason:

```go
defer func() {
    _ = rows.Close()  // ignored: best-effort cleanup; primary error already returned
}()

_ = json.Marshal(staticConfig)  // ignored: marshal of known-good static value cannot fail in this context
```

For goroutines, surface the error explicitly:

```go
go func() {
    if err := r.notifyExternalService(ctx, payload); err != nil {
        log.Printf("[notify] request_id=%s err=%v",
            common_utils.RequestIDFrom(ctx), err)
    }
}()
```

If the side-effect is truly fire-and-forget (idempotent retry, low-stakes hint), document it with a comment. No comment + ignored goroutine error = a violation.

### ❌ Salah — single-value type assertion

```go
userIDStr := userID.(string)         // panics on type mismatch
ownerID := uuid.Parse(userIDStr).(uuid.UUID)
```

A handful of these will eventually panic in production on a malformed JWT.

### ✅ Benar — two-value type assertion + check

```go
userIDStr, ok := userID.(string)
if !ok {
    common.SendError(c, http.StatusInternalServerError, errors.New("user_id in context is not a string"))
    return
}
```

### Enforcement

- `errcheck ./...` (or `golangci-lint run --enable=errcheck`) flags every unchecked error return at compile time.
- `tools/lint.sh` catches the loudest smells (e.g. `_ = json.Marshal(`) but `errcheck` is exhaustive — wire both.

---

## M. Resource leaks and dangling goroutines (rule #20)

### ❌ Salah — `context.WithTimeout` without `defer cancel()`

```go
ctx, _ := context.WithTimeout(parentCtx, 5*time.Second)
result, err := r.client.Do(ctx, req)
// cancel was never called → goroutine inside WithTimeout leaks for 5s after each call
```

Under load this is fine for a while, then the runtime hits its goroutine cap and everything stalls.

### ✅ Benar

```go
ctx, cancel := context.WithTimeout(parentCtx, 5*time.Second)
defer cancel()
result, err := r.client.Do(ctx, req)
```

`go vet` (`lostcancel`) catches this statically — wire it into CI.

### ❌ Salah — `http.Response.Body` not closed

```go
resp, err := http.Get(url)
if err != nil { return err }
data, err := io.ReadAll(resp.Body)
return data, err
// resp.Body never closed → connection stays in pool, eventually exhausts the client
```

### ✅ Benar — `defer Close` immediately after the err check

```go
resp, err := http.Get(url)
if err != nil { return nil, err }
defer resp.Body.Close()                          // ← closes on every return path
data, err := io.ReadAll(resp.Body)
return data, err
```

Bonus — drain before close to keep the connection reusable: `io.Copy(io.Discard, resp.Body)` before the `Close`. `bodyclose` linter catches the missing close.

### ❌ Salah — long-running goroutine with no termination contract

```go
func InitKeyRotator(svc *Svc) {
    go func() {
        for {
            svc.refreshKey()
            time.Sleep(1 * time.Hour)
        }
    }()
}
```

The goroutine outlives the server's graceful shutdown. On `SIGTERM`, the process kills it mid-`refreshKey()` (data corruption risk). Worse: if the function is called twice (in tests, in hot reload), you accumulate goroutines forever.

### ✅ Benar — context-driven lifecycle

```go
func InitKeyRotator(ctx context.Context, svc *Svc) {
    go func() {
        ticker := time.NewTicker(1 * time.Hour)
        defer ticker.Stop()
        for {
            select {
            case <-ctx.Done():
                return
            case <-ticker.C:
                if err := svc.refreshKey(); err != nil {
                    log.Printf("[key-rotator] err=%v", err)
                }
            }
        }
    }()
}

// in main.go:
ctx, cancel := context.WithCancel(context.Background())
defer cancel()
InitKeyRotator(ctx, svc)
// on SIGTERM: cancel() → goroutine exits cleanly, ticker stops.
```

### ❌ Salah — DB transaction without rollback safety net

```go
tx := db.Begin()
if err := tx.Create(&a).Error; err != nil {
    return err  // ← transaction left dangling; locks held until DB times it out
}
return tx.Commit().Error
```

### ✅ Benar — defer rollback as the safety net; commit is the explicit happy path

```go
tx := db.Begin()
defer func() {
    if r := recover(); r != nil { tx.Rollback(); panic(r) }
}()
if err := tx.Create(&a).Error; err != nil {
    tx.Rollback()
    return err
}
return tx.Commit().Error  // rollback after successful commit is a no-op in most drivers
```

### Enforcement

- `go vet ./...` for `lostcancel`.
- `golangci-lint run --enable=bodyclose,sqlclosecheck,rowserrcheck` for HTTP body / SQL row leaks.
- `go.uber.org/goleak.VerifyNone(t)` at the end of integration tests asserts no goroutines leaked.

If you spawn a goroutine in this codebase, it must satisfy at least one of:
1. Has a `context.Context` parameter and exits on `<-ctx.Done()`.
2. Completes within bounded time (no `for { ... }` loop without exit) and is `go`-ed from a request handler.
3. Has a comment explaining why it's lifetime-coupled to the process and tested for leakage.

---

## N. Sequential third-party calls in a list loop (rule #21)

### ❌ Salah — sequential blocking calls

```go
func (r *friendsUseCase) ListFriends(ctx context.Context, ownerID uuid.UUID) ([]Friend, int, error) {
    friends, _, _, _ := r.friendsRepo.List(ctx, FriendFilter{OwnerID: &ownerID}, nil)

    for i := range friends {
        profile, err := r.accountClient.GetProfile(ctx, friends[i].UserID)  // ← 200ms × N items
        if err == nil {
            friends[i].Username = profile.Username
        }
    }

    return friends, http.StatusOK, nil
}
```

50 friends × 200ms each = **10 seconds**. The user thinks the app is broken.

### ❌ Salah — unbounded fan-out

```go
var wg sync.WaitGroup
for i := range friends {
    i := i
    wg.Add(1)
    go func() {
        defer wg.Done()
        profile, _ := r.accountClient.GetProfile(ctx, friends[i].UserID)
        friends[i].Username = profile.Username
    }()
}
wg.Wait()
```

50 friends → 50 simultaneous requests. Account-service rate-limits or throttles. Your egress bill spikes. Errors silently dropped (rule #19 violation too). And if list grows to 5,000 items, you've just DDoSed a teammate's service.

### ✅ Benar — bounded fan-out via `errgroup`

```go
import (
    "golang.org/x/sync/errgroup"
    "github.com/<owner>/something-backend/pkg/common_utils"
)

func (r *friendsUseCase) ListFriends(ctx context.Context, ownerID uuid.UUID) ([]Friend, int, error) {
    friends, _, _, _ := r.friendsRepo.List(ctx, FriendFilter{OwnerID: &ownerID}, nil)

    g, gctx := errgroup.WithContext(ctx)
    g.SetLimit(10)                                  // at most 10 concurrent calls

    for i := range friends {
        i := i                                      // capture index
        g.Go(func() error {
            profile, err := r.accountClient.GetProfile(gctx, friends[i].UserID)
            if err != nil {
                log.Printf("[friends.enrich] request_id=%s user_id=%s err=%v",
                    common_utils.RequestIDFrom(gctx), friends[i].UserID, err)
                return nil                          // tolerate per-item failure
            }
            friends[i].Username = profile.Username
            return nil
        })
    }
    if err := g.Wait(); err != nil {
        return nil, http.StatusInternalServerError, err
    }

    return friends, http.StatusOK, nil
}
```

50 friends with `SetLimit(10)` → **~1 second** total. Account-service sees a controlled trickle. Errors are logged with `request_id` for triage. If the third-party goes hard-down, `g.Wait()` returns the error and the controller returns a 500.

### Three rules of thumb when deciding fan-out vs sequential

| Per-item operation | Fan out? | Why |
|---|---|---|
| DB query (`r.repo.X(ctx, ...)`) | **No** — batch fetch (rule #11) | DB pool is finite, shared across requests |
| HTTP call to internal/third-party service | **Yes**, bounded (rule #21) | HTTP pool tolerates parallelism; latency dominates |
| Pure CPU work (transform, sort) | Usually no, single goroutine | Goroutine overhead > work |
| Mixed (HTTP + transform) | Fan out the HTTP, transform in the same goroutine | Don't pipeline unless N is very large |

### Common mistakes inside the goroutine body

| Mistake | Fix |
|---|---|
| `g.Go(func() error { return r.accountClient.GetProfile(ctx, ...) })` — uses outer `ctx` | Use `gctx` (errgroup-derived) so failures cancel siblings |
| Forgetting `i := i` before `g.Go(...)` | Loop variable capture; without it, every goroutine sees the last `i` |
| Returning the per-item error from `g.Go` | Hard-fails the whole list on one bad row; usually you want to log + return nil |
| Unbounded `g.Go` with no `SetLimit` | Same as `sync.WaitGroup` mistake — 5,000 simultaneous calls |
| Mutating `items[i]` from the goroutine without thinking about it | Safe **only** because each goroutine writes a different index. Don't append to a shared slice without a mutex |

### N.1 — Channel-based fan-out (when streaming or worker pool fits better than errgroup)

Two valid alternatives exist when `errgroup` is too coarse:

**(a) Bounded semaphore via buffered `chan struct{}`** — same shape as errgroup, but you own the goroutines. Use this when you want to start streaming results to the caller (SSE, WebSocket) the moment each item is ready.

```go
sem := make(chan struct{}, 10)
results := make(chan EnrichedItem, len(items))
var wg sync.WaitGroup

for i := range items {
    wg.Add(1)
    select {
    case sem <- struct{}{}:                       // acquire (blocks if 10 in flight)
    case <-ctx.Done():
        wg.Done()
        continue                                  // request cancelled — stop spawning
    }
    go func(i int) {
        defer wg.Done()
        defer func() { <-sem }()                  // release on every return path
        profile, err := r.accountClient.GetProfile(ctx, items[i].UserID)
        if err != nil {
            log.Printf("[enrich] request_id=%s user_id=%s err=%v",
                common_utils.RequestIDFrom(ctx), items[i].UserID, err)
            results <- EnrichedItem{Item: items[i]}
            return
        }
        results <- EnrichedItem{Item: items[i], Username: profile.Username}
    }(i)
}

go func() { wg.Wait(); close(results) }()

for r := range results {
    // stream to client immediately, or accumulate
}
```

**(b) Worker pool with job + result channels** — fixed N workers, each draining `jobs` and emitting on `results`. Reuse this when the same set of workers serves many requests (e.g. an app-wide enricher service) or when jobs have wildly varying durations and you want fairness.

```go
jobs := make(chan int, len(items))                // buffered to avoid blocking the producer
results := make(chan EnrichedItem, len(items))

const workers = 10
var wg sync.WaitGroup
for w := 0; w < workers; w++ {
    wg.Add(1)
    go func() {
        defer wg.Done()
        for i := range jobs {
            select {
            case <-ctx.Done():
                return                            // stop on cancel
            default:
            }
            profile, err := r.accountClient.GetProfile(ctx, items[i].UserID)
            // ... build EnrichedItem ...
            results <- enriched
        }
    }()
}

for i := range items { jobs <- i }
close(jobs)                                       // signal workers no more work
go func() { wg.Wait(); close(results) }()

for r := range results { /* drain */ }
```

### Hard rules when reaching for raw channels (rule #20 + rule #21)

| Rule | Why |
|---|---|
| Exactly one goroutine closes a given channel | Closing twice panics; closing a channel another goroutine is writing to panics |
| `for r := range ch` requires `close(ch)` somewhere | Without close → deadlock |
| Buffered channels = bounded concurrency; unbuffered = synchronisation | Pick deliberately, don't default to unbuffered |
| Acquire/release a semaphore slot must respect `<-ctx.Done()` | `sem <- struct{}{}` blocks forever if pool is full and ctx is cancelled — hidden goroutine leak |
| `defer func() { <-sem }()` immediately after `sem <- struct{}{}` | Mirror `defer cancel()` discipline; release on every return path including panics |

### When errgroup is enough — don't reinvent it

If your needs are: **fan out N independent calls, wait for all, surface first error, bound concurrency** — that's literally what `errgroup` does in 5 lines. Channels are for the cases errgroup can't handle (streaming, worker pool, multi-stage pipelines). Don't write 30 lines of channel choreography for a problem errgroup solves in 5.

---

---

## O. Swagger UI exposed without auth (rule #22)

### ❌ Salah — Swagger registered unconditionally, no auth

```go
// routes/routes.go
func SetupRoutes(deps *RouterDependencies) *gin.Engine {
    r := gin.Default()
    r.GET("/swagger/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))   // ← anyone can read
    setupAuthenticatedRoutes(r, deps.Controllers)
    return r
}
```

A pen-test scanner finds `/swagger/index.html` in 2 minutes. They now have your full API surface, every parameter, every error model, and the bearer-token scheme — enough to plan a targeted attack without ever logging in.

### ❌ Salah — credentials hardcoded

```go
swag := r.Group("/swagger", gin.BasicAuth(gin.Accounts{
    "admin": "admin123",                                  // ← in source, in git history forever
}))
swag.GET("/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
```

Now the password is in every git commit, every CI log, every grep. Rotating it requires a code change.

### ❌ Salah — falls back to empty credentials when env unset

```go
user := os.Getenv("SWAGGER_USER")        // "" if unset
pass := os.Getenv("SWAGGER_PASSWORD")    // "" if unset

swag := r.Group("/swagger", gin.BasicAuth(gin.Accounts{user: pass}))   // {"": ""}
swag.GET("/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
```

`gin.Accounts{"": ""}` is undefined territory — depending on framework version it may accept any (or no) credentials. Even if it consistently rejects, the route still *exists*, leaks WWW-Authenticate hints, and gives an attacker something to brute-force.

### ✅ Benar — gate on env presence, then BasicAuth

```go
func setupSwagger(r *gin.Engine) {
    user := config.APP.Rest.SwaggerUser
    pass := config.APP.Rest.SwaggerPassword
    if user == "" || pass == "" {
        log.Println("⚠️  swagger disabled (SWAGGER_USER / SWAGGER_PASSWORD not set)")
        return                                       // route never registered → 404
    }
    swag := r.Group("/swagger", gin.BasicAuth(gin.Accounts{user: pass}))
    swag.GET("/*any", ginSwagger.WrapHandler(swaggerFiles.Handler))
    log.Println("📘 swagger enabled at /swagger (basic auth required)")
}
```

Operational effects:

| Environment | `SWAGGER_USER`/`SWAGGER_PASSWORD` | `/swagger/*` returns |
|---|---|---|
| Production | unset | 404 (route doesn't exist) |
| Staging (internal-only) | set to non-empty | 401 without creds, 200 with creds |
| Local dev | set in `.env` | 401 without creds, 200 with creds |
| Anonymous attacker | any env | 404 in prod, 401 elsewhere — never 200 |

### Verification

After deploy, confirm the gate works:

```bash
# production (env unset) → expect 404
curl -i https://api.example.com/swagger/index.html

# staging (env set) — without auth → expect 401
curl -i https://staging.example.com/swagger/index.html

# staging — with auth → expect 200
curl -i -u "$SWAGGER_USER:$SWAGGER_PASSWORD" https://staging.example.com/swagger/index.html
```

If production returns 200 or 401 (instead of 404), the gate is broken. Fix immediately and audit access logs.

---

## Summary — when in doubt

| Smell | Probably violates | Read |
|---|---|---|
| `GetByX`, `FindByY` repo methods | Filter Pattern (#8) | Section A |
| GORM tags in JSON response | Three-model rule (#6) | Section B |
| `import "...database/schemas"` in `app/use_case/` | Layer dependency (#4) | Section B.1 |
| Dependencies struct holding `*lowercaseStruct` | Interface contract (#6) | Section B.2 |
| `*gin.Context` below controller | Auth leak (#7) | Section C |
| `(result, error)` from repo | Error trio (#5) | Section D |
| Loop with `repo.GetOne` inside | N+1 (#11) | Section E |
| Loop with `repo.<Validate/Check>One` inside | N+1 (#11) | Section E.1 |
| `page`/`page_size` parsing in controller | Reuse pkg/ (#10) | Section F |
| `// TODO implement, return nil` | Placeholder ban (#12) | Section G |
| Function with detection logic + `// TODO` gating side-effect | Placeholder ban (#12) | Section G.1 |
| `time.Now().Location()` for "today" | Timezone (#13 + helpers) | Section H |
| `time.LoadLocation(...)` outside `app/use_case/common/` | Reuse pkg/ (#10) | Section H.1 |
| Many small bugs with same root cause | Audit-before-fix (#3) | Section I |
| `json:"camelCase"` / `form:"snake_case"` / underscore in URL path | REST surface naming (#17) | Section J |
| `c.JSON(...err.Error()...)` or `gin.H{"error": ...}` from controller | 5xx sanitization (#18) | Section K |
| use_case `log.Printf` without `RequestIDFrom(ctx)` | request_id propagation (#18) | Section K |
| `_, _ := f()` / `go f()` swallowing an error | Never ignore errors (#19) | Section L |
| Single-value type assertion `i.(T)` outside test code | Never ignore errors (#19) | Section L |
| `context.WithTimeout/Cancel/Deadline` without `defer cancel()` | Resource cleanup (#20) | Section M |
| `http.Response.Body` not closed; goroutine without context exit | Resource cleanup (#20) | Section M |
| Sequential third-party calls in a list loop (10s+ latency) | Bounded fan-out (#21) | Section N |
| Unbounded `go func()` over a list of items | Bounded fan-out (#21) | Section N |
| Closing a channel twice or writing to a closed channel | Channel discipline (#20+#21) | Section N.1 |
| `ginSwagger.WrapHandler` registered without `gin.BasicAuth` | Swagger gating (#22) | Section O |
| Swagger creds hardcoded or derived from possibly-empty env | Swagger gating (#22) | Section O |
