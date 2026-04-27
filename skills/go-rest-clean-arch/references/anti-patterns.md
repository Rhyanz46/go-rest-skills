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

## Summary — when in doubt

| Smell | Probably violates | Read |
|---|---|---|
| `GetByX`, `FindByY` repo methods | Filter Pattern (#8) | Section A |
| GORM tags in JSON response | Three-model rule (#6) | Section B |
| `import "...database/schemas"` in `app/use_case/` | Layer dependency (#4) | Section B.1 |
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
