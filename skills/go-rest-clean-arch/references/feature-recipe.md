# Feature Recipe — End-to-End Walkthrough

This file is the **concrete, file-by-file recipe** for adding a new feature in this Clean Architecture style. Read this when SKILL.md says "follow the layer order" and you need to know which file goes where, how the central wiring fits together, and how to handle the awkward bits (ownership filters, computed filters that depend on user TZ, datetime input validation).

The example feature throughout this doc is **`reminders`** — a CRUD feature where each row has `id`, `owner_user_id`, `title`, `due_at`, `created_at`, `updated_at`, with a list endpoint that supports pagination plus a computed filter `?status=upcoming|past` derived from `due_at` vs "now in user's TZ".

> **All file paths and patterns below are taken from a real working project.** When in doubt, grep that project for one of the existing features (`track`, `friends`, `sharing`, `template_plan`, `persona`) and mirror its shape.

---

## 1. Canonical file layout per layer

```
database/
  schemas/
    reminder.go                 ← GORM model + table name + indexes

app/
  repository/
    reminders_repository/
      models.go                 ← domain-level structs returned to the use_case
      filters.go                ← <Entity>Filter struct + applyXFilters helper
      interfaces.go             ← RemindersRepository interface + RepositoryDependencies
      repository.go             ← struct + concrete methods (GetOne / Create / Update / Delete / List / Count)

  use_case/
    reminders_use_case/
      interfaces.go             ← RemindersUseCase interface + UseCaseDependencies + request/response models
      usecase.go                ← method bodies (orchestration, business rules)
      validation.go             ← validateXRequest helpers (called from usecase.go)
      transform.go              ← repo.Reminder → domain.ReminderResponse mapping

  controller/
    reminders_controller/
      models.go                 ← HTTP request/response structs (json tags only, NO binding tags)
      rules.go                  ← *Rules vars built with map_validator.BuildRoles()
      interfaces.go             ← RemindersController interface + ControllerDependencies
      controller.go             ← gin handlers + Swagger annotations
```

Filenames are **exact**, not suggestions. A new feature that calls its repo file `repo.go` instead of `repository.go` violates the convention even if the code works.

---

## 2. Schema — `database/schemas/reminder.go`

```go
package schemas

import (
    "time"
    "github.com/google/uuid"
)

type Reminder struct {
    ID          uint      `gorm:"primaryKey"`
    OwnerUserID uuid.UUID `gorm:"type:uuid;not null;index"`
    Title       string    `gorm:"not null"`
    DueAt       time.Time `gorm:"not null;index"`
    CreatedAt   time.Time `gorm:"autoCreateTime"`
    UpdatedAt   time.Time `gorm:"autoUpdateTime"`
}

func (Reminder) TableName() string { return "reminders" }
```

Then **register the schema in `database/database.go`'s `AutoMigrate()` function**:

```go
// database/database.go
func AutoMigrate() error {
    // ...
    models := []interface{}{
        &schemas.TrackSetting{},
        // ... existing schemas ...
        &schemas.Reminder{},      // ← add at the bottom (or in a logical group)
    }
    if err := DB.AutoMigrate(models...); err != nil { /* ... */ }
    return nil
}
```

**There is no separate migration file.** GORM's `AutoMigrate` runs on every server start and is idempotent. This is intentional in this project — if you need a non-additive change (rename column, drop column), do it as an explicit `db.Exec("ALTER TABLE ...")` block above the `AutoMigrate` call, gated by an `IF NOT EXISTS` / `IF EXISTS` check.

---

## 3. Repository layer

### `app/repository/reminders_repository/models.go`

```go
package reminders_repository

import (
    "time"
    "github.com/google/uuid"
    "planner-backend/database/schemas"
)

type Reminder struct {
    ID          uint
    OwnerUserID uuid.UUID
    Title       string
    DueAt       time.Time
    CreatedAt   time.Time
    UpdatedAt   time.Time
}

type CreateReminderRequest struct {
    OwnerUserID uuid.UUID
    Title       string
    DueAt       time.Time
}

type UpdateReminderRequest struct {
    Title *string
    DueAt *time.Time
}

// schema → domain transform stays inside the repo package
func transformFromSchema(s schemas.Reminder) Reminder {
    return Reminder{
        ID: s.ID, OwnerUserID: s.OwnerUserID, Title: s.Title, DueAt: s.DueAt,
        CreatedAt: s.CreatedAt, UpdatedAt: s.UpdatedAt,
    }
}
```

### `app/repository/reminders_repository/filters.go`

```go
package reminders_repository

import (
    "time"
    "github.com/google/uuid"
    "gorm.io/gorm"
)

type ReminderFilter struct {
    Id          *uint
    Ids         []uint
    OwnerUserID *uuid.UUID
    DueAtFrom   *time.Time     // inclusive
    DueAtTo     *time.Time     // exclusive
    OrderBy     *string
}

func applyReminderFilters(q *gorm.DB, f ReminderFilter) *gorm.DB {
    if f.Id != nil          { q = q.Where("id = ?", *f.Id) }
    if len(f.Ids) > 0       { q = q.Where("id IN ?", f.Ids) }
    if f.OwnerUserID != nil { q = q.Where("owner_user_id = ?", *f.OwnerUserID) }
    if f.DueAtFrom != nil   { q = q.Where("due_at >= ?", *f.DueAtFrom) }
    if f.DueAtTo != nil     { q = q.Where("due_at < ?",  *f.DueAtTo) }
    if f.OrderBy != nil     { q = q.Order(*f.OrderBy) }
    return q
}
```

**The repo never knows about `?status=upcoming`.** It only knows about concrete date ranges. The translation happens in the use_case.

### `app/repository/reminders_repository/interfaces.go`

```go
type RemindersRepository interface {
    GetOne(ctx context.Context, filter ReminderFilter) (*Reminder, int, error)
    Create(ctx context.Context, data CreateReminderRequest) (*Reminder, int, error)
    Update(ctx context.Context, filter ReminderFilter, data UpdateReminderRequest) (*Reminder, int, error)
    Delete(ctx context.Context, filter ReminderFilter) (int, error)
    List(ctx context.Context, filter ReminderFilter, paginate *paginate_utils.PaginateData) ([]Reminder, int64, int, error)
    Count(ctx context.Context, filter ReminderFilter) (int64, int, error)
}

type RepositoryDependencies struct {
    DB interface { WithContext(ctx context.Context) *gorm.DB }
}

type remindersRepository struct { db *gorm.DB }

func NewRemindersRepository(deps RepositoryDependencies) RemindersRepository {
    return &remindersRepository{ db: deps.DB.WithContext(context.Background()) }
}
```

`repository.go` is then mechanical — see any existing repo (`track_repository/repository.go`) for the canonical body.

---

## 4. Use case layer

### Ownership filter — auth from controller, never `GetAuthClaim` here (rule #7)

The controller pulls `userID` from the JWT context once and passes it as an explicit parameter. **The use_case never touches `*gin.Context` or `auth_utils.GetAuthClaim`.**

```go
// use_case/reminders_use_case/interfaces.go
type RemindersUseCase interface {
    List(ctx context.Context, ownerID uuid.UUID, statusFilter string, paginate *paginate_utils.PaginateData) (*ReminderListResponse, int, error)
    Get(ctx context.Context, ownerID uuid.UUID, id uint) (*ReminderResponse, int, error)
    Create(ctx context.Context, ownerID uuid.UUID, req CreateReminderRequest) (*ReminderResponse, int, error)
    Update(ctx context.Context, ownerID uuid.UUID, id uint, req UpdateReminderRequest) (*ReminderResponse, int, error)
    Delete(ctx context.Context, ownerID uuid.UUID, id uint) (int, error)
}
```

Every method takes `ownerID uuid.UUID` explicitly. Implementations forward it to `repo` filters as `OwnerUserID: &ownerID`.

### Computed filter `?status=upcoming|past` — translation lives in the use_case

```go
// use_case/reminders_use_case/usecase.go
func (r *remindersUseCase) List(ctx context.Context, ownerID uuid.UUID, statusFilter string, paginate *paginate_utils.PaginateData) (*ReminderListResponse, int, error) {
    filter := reminders_repository.ReminderFilter{ OwnerUserID: &ownerID }

    if statusFilter != "" {
        loc, _ := common.LoadLocationOrDefault(r.getUserTimezone(ctx, ownerID))
        nowInTz := time.Now().In(loc)
        switch statusFilter {
        case "upcoming":
            filter.DueAtFrom = &nowInTz
        case "past":
            filter.DueAtTo = &nowInTz
        default:
            return nil, http.StatusBadRequest, errors.New("status must be 'upcoming' or 'past'")
        }
    }

    items, total, code, err := r.remindersRepo.List(ctx, filter, paginate)
    if err != nil { return nil, code, common.RepositoryErrorToDomain(code, err) }

    resp := r.transformToListResponse(items, paginate, total)
    return resp, http.StatusOK, nil
}
```

Three things to notice:

1. The use_case **owns the timezone-aware translation**. The repo only sees concrete instants.
2. `getUserTimezone(ctx, ownerID)` mirrors the helper used by `track_use_case` — if your feature needs the user's TZ and the helper doesn't exist yet for your repo, copy the pattern (it's a single small method that reads `track_settings.timezone`).
3. **Never call `time.LoadLocation` directly** — always go through `common.LoadLocationOrDefault` (rule #10).

### Computed response field — derive at the use_case transform, mirror in controller

```go
// use_case/reminders_use_case/interfaces.go
type ReminderResponse struct {
    ID        uint      `json:"-"`        // domain-level — JSON tags optional here
    OwnerUserID uuid.UUID
    Title     string
    DueAt     time.Time
    Status    string                       // computed: "upcoming" | "past"
    CreatedAt time.Time
    UpdatedAt time.Time
}

// use_case/reminders_use_case/transform.go
func (r *remindersUseCase) transformToReminderResponse(ctx context.Context, item reminders_repository.Reminder) ReminderResponse {
    loc, _ := common.LoadLocationOrDefault(r.getUserTimezone(ctx, item.OwnerUserID))
    status := "upcoming"
    if item.DueAt.Before(time.Now().In(loc)) { status = "past" }
    return ReminderResponse{
        ID: item.ID, OwnerUserID: item.OwnerUserID, Title: item.Title,
        DueAt: item.DueAt, Status: status,
        CreatedAt: item.CreatedAt, UpdatedAt: item.UpdatedAt,
    }
}
```

For list responses, fetch the user's loc **once** before the loop (or pass it in) — calling `getUserTimezone` per item is N+1 (rule #11).

```go
func (r *remindersUseCase) transformToListResponse(items []reminders_repository.Reminder, paginate *paginate_utils.PaginateData, total int64) *ReminderListResponse {
    if len(items) == 0 {
        return &ReminderListResponse{ Items: []ReminderResponse{}, Pagination: paginate_utils.NewPagination(paginate, 0) }
    }
    loc, _ := common.LoadLocationOrDefault(r.getUserTimezone(context.Background(), items[0].OwnerUserID)) // single TZ lookup
    now := time.Now().In(loc)
    out := make([]ReminderResponse, len(items))
    for i, it := range items {
        status := "upcoming"
        if it.DueAt.Before(now) { status = "past" }
        out[i] = ReminderResponse{ /* ... use `now` and `loc` here ... */ Status: status }
    }
    return &ReminderListResponse{ Items: out, Pagination: paginate_utils.NewPagination(paginate, total) }
}
```

---

## 5. Controller layer

### `models.go` — HTTP DTOs, no binding tags

```go
// app/controller/reminders_controller/models.go
type CreateReminderRequest struct {
    Title string    `json:"title"`
    DueAt time.Time `json:"due_at"`
}
type UpdateReminderRequest struct {
    Title *string    `json:"title,omitempty"`
    DueAt *time.Time `json:"due_at,omitempty"`
}
type ListRemindersRequest struct {
    Status string `json:"-" form:"status"`
    Page     int  `json:"-" form:"page"`
    PageSize int  `json:"-" form:"page_size"`
}
```

> **Datetime validation note**: `map_validator` v0.0.41 does not ship a dedicated `Time()` constructor. For required ISO-8601 datetime fields, validate the string in `rules.go` with `Str().Regex(<RFC3339-pattern>)` and parse in the controller. Existing precedent: `app/controller/track_controller/rules.go` uses `iso8601DatetimeRegex` for `start`/`end` fields. Reuse that pattern.

### `rules.go` — single source of validation truth

```go
// app/controller/reminders_controller/rules.go
package reminders_controller

import "github.com/rhyanz46/map_validator"

const iso8601 = `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$`

var CreateReminderRules = map_validator.BuildRoles().
    SetRule("title", map_validator.Str().WithMin(1).WithMax(255)).
    SetRule("due_at", map_validator.Str().Regex(iso8601))

var UpdateReminderRules = map_validator.BuildRoles().
    SetRule("title",  map_validator.Str().WithMin(1).WithMax(255).Nullable()).
    SetRule("due_at", map_validator.Str().Regex(iso8601).Nullable())

var ListRemindersRules = map_validator.BuildRoles().
    SetRule("status",    map_validator.StrEnum("upcoming", "past").Nullable()).
    SetRule("page",      map_validator.Int().WithMin(1).Nullable()).
    SetRule("page_size", map_validator.Int().Between(1, 100).Nullable())
```

### `controller.go` — canonical handler shape

```go
// app/controller/reminders_controller/controller.go
// @Summary      Create reminder
// @Tags         Reminders
// @Accept       json
// @Produce      json
// @Security     BearerAuth
// @Param        body body CreateReminderRequest true "Reminder payload"
// @Success      201 {object} common.SuccessResponse
// @Failure      400 {object} common.ErrorResponse
// @Router       /reminders [post]
func (ctrl *remindersController) Create(c *gin.Context) {
    userID, ok := common.GetUserIDFromContext(c)
    if !ok { c.JSON(http.StatusUnauthorized, common.ErrorResponse{Message: "unauthenticated"}); return }
    ownerID, _ := uuid.Parse(userID.(string))

    req, err := map_validator.ValidateJSON[CreateReminderRequest](c.Request, CreateReminderRules)
    if err != nil { c.JSON(http.StatusBadRequest, common.ErrorResponse{Message: err.Error()}); return }

    dueAt, _ := time.Parse(time.RFC3339, req.DueAt.Format(time.RFC3339))   // already validated by rule
    resp, code, err := ctrl.useCase.Create(c.Request.Context(), ownerID, reminders_use_case.CreateReminderRequest{
        Title: req.Title, DueAt: dueAt,
    })
    if err != nil { c.JSON(code, common.ErrorResponse{Message: err.Error()}); return }

    c.JSON(code, common.SuccessResponse{Data: resp})
}
```

The pattern is always: extract `userID` → validate request → call use_case with the trio `(*gin.Context's context, ownerID, request)` → forward `(result, statusCode, error)` to gin.

---

## 6. Central wiring — three structs to update

Adding a new feature touches **three constructor files**, in this order:

1. **`app/repository/repositories.go`** — add field + factory call
   ```go
   type Repositories struct {
       // ... existing ...
       Reminders reminders_repository.RemindersRepository
   }
   func NewRepositories(db *gorm.DB) *Repositories {
       // ...
       return &Repositories{
           // ... existing ...
           Reminders: reminders_repository.NewRemindersRepository(reminders_repository.RepositoryDependencies{DB: dbInterface}),
       }
   }
   ```

2. **`app/use_case/use_cases.go`** — same shape
   ```go
   type UseCases struct {
       // ... existing ...
       Reminders reminders_use_case.RemindersUseCase
   }
   func NewUseCase(repos *repository.Repositories) *UseCases {
       // ...
       return &UseCases{
           // ... existing ...
           Reminders: reminders_use_case.NewRemindersUseCase(reminders_use_case.UseCaseDependencies{
               RemindersRepo: repos.Reminders,
               TrackRepo:     repos.Track, // only if you need it for getUserTimezone
           }),
       }
   }
   ```

3. **`app/controller/controllers.go`** — same shape
   ```go
   type Controllers struct {
       // ... existing ...
       Reminders reminders_controller.RemindersController
   }
   func NewControllers(useCases *use_case.UseCases) *Controllers {
       // ...
       return &Controllers{
           // ... existing ...
           Reminders: reminders_controller.NewRemindersController(reminders_controller.ControllerDependencies{
               RemindersUseCase: useCases.Reminders,
           }),
       }
   }
   ```

Compile after each step. If `repositories.go` doesn't compile, do not move to use_cases.go — Stop-and-Wait (rule #2).

---

## 7. Routes — `routes/routes.go`

Add a setup function, then call it from `setupAuthenticatedRoutes`:

```go
// routes/routes.go
func setupAuthenticatedRoutes(r *gin.Engine, ctrls *controller.Controllers) {
    authGroup := r.Group("")
    authGroup.Use(http_middleware.JWTAuthentication)

    setupTrackRoutes(authGroup, ctrls.Track)
    // ... existing ...
    setupReminderRoutes(authGroup, ctrls.Reminders)   // ← add this
}

func setupReminderRoutes(r *gin.RouterGroup, c reminders_controller.RemindersController) {
    r.GET("/api/reminders",        c.List)
    r.GET("/api/reminders/:id",    c.Get)
    r.POST("/api/reminders",       c.Create)
    r.PUT("/api/reminders/:id",    c.Update)
    r.DELETE("/api/reminders/:id", c.Delete)
}
```

Group-by-feature is the convention. Don't sprinkle reminder routes across other setup functions.

---

## 8. Stop-and-Wait checkpoint summary

After each layer, surface a status block to the user (rule #2):

```
Repository layer selesai:
- Files: schemas/reminder.go, app/repository/reminders_repository/{models,filters,interfaces,repository}.go
- AutoMigrate: registered Reminder in database/database.go
- Hard rules dipatuhi: Filter Pattern (#8), error trio (#5), three-model (#6)
- Belum disentuh: use_case, controller, routes

Lanjut ke use_case layer?
```

Same template per layer. Don't chain.

---

## 9. Quick checklist before declaring done

- [ ] Schema registered in `database/database.go` `AutoMigrate()`
- [ ] No GORM tags outside `database/schemas/` and `app/repository/<feature>/models.go` (rule #6)
- [ ] No `*gin.Context` outside `app/controller/` and `pkg/http_middleware/` (rule #7)
- [ ] No `time.LoadLocation` outside `app/use_case/common/timezone.go` (rule #10)
- [ ] Every repo/use_case method returns `(result, int, error)` or `(int, error)` (rule #5)
- [ ] No loop with `repo.GetOne(...)` inside (rule #11) — mentally simulate N=1000
- [ ] Validation rules in `rules.go` package-level vars; no `binding:` tags in models (rule #9)
- [ ] Three constructor files updated (`repositories.go`, `use_cases.go`, `controllers.go`)
- [ ] Routes registered in `routes/routes.go` `setupAuthenticatedRoutes`
- [ ] `go build ./...` passes; existing tests still green

If any box is unchecked, the feature isn't done — fix it before opening the PR.
