# Bootstrap a New Go REST Project

This file is the **zero-to-running** recipe for starting a brand-new Go REST backend that adopts `go-rest-clean-arch` from day one. Follow these steps in order; each step compiles before moving to the next (Stop-and-Wait, rule #2).

The output is a project that:
- Has `CLAUDE.md` pinning a specific skill version (no in-repo `ai_instruction/`).
- Has all the shared utilities (`pkg/paginate_utils/`, `app/use_case/common/`, `app/controller/common/`, `app/repository/common/`) that the skill assumes.
- Compiles with **no features yet** — ready for the first feature, which you add via `feature-recipe.md`.

---

## Step 0 — Prerequisites

- Go ≥ 1.22 installed.
- Git configured locally with the right author for commits.
- Decide on a module path: `github.com/<owner>/<repo-name>` (e.g. `github.com/rhyanz46/something-backend`).
- Decide which version of the skill to pin. Recommended: latest stable tag (e.g. `v0.2.0`).

---

## Step 1 — Initialise the repo

```bash
mkdir something-backend && cd something-backend
git init
go mod init github.com/<owner>/something-backend
```

Add `.gitignore`:

```gitignore
# Binaries
/main
*.exe

# Local data
/data/
*.db

# Editor / OS
.vscode/
.idea/
.DS_Store

# Env
.env
```

---

## Step 2 — Pull in the canonical dependencies

```bash
go get github.com/gin-gonic/gin
go get gorm.io/gorm
go get gorm.io/driver/postgres
go get gorm.io/driver/sqlite
go get github.com/google/uuid
go get github.com/joho/godotenv
go get github.com/rhyanz46/map_validator
```

Optional but recommended:

```bash
go get github.com/swaggo/swag/cmd/swag
go get github.com/swaggo/gin-swagger
```

---

## Step 3 — Create the directory skeleton

```bash
mkdir -p \
  config \
  database/schemas \
  pkg/paginate_utils \
  pkg/http_middleware \
  pkg/auth_utils \
  pkg/common_utils \
  app/controller/common \
  app/use_case/common \
  app/repository/common \
  routes
```

Empty Go packages will fail to build — Step 4 fills them.

---

## Step 4 — Drop in the shared utilities

These four packages are **prerequisites** for the skill's hard rules. Without them, rule #10 ("reuse pkg/") is impossible.

### `pkg/paginate_utils/`

Three files — see `references/app_package.md` Appendix A for full source. Minimum shape:

```go
// pkg/paginate_utils/models.go
package paginate_utils

type PaginateData struct {
    Page  int
    Limit int
}

type Pagination struct {
    Page       int   `json:"page"`
    Limit      int   `json:"limit"`
    Total      int64 `json:"total"`
    TotalPages int64 `json:"total_pages"`
    HasNext    bool  `json:"has_next"`
    HasPrev    bool  `json:"has_prev"`
}

func NewPagination(p *PaginateData, total int64) *Pagination {
    if p == nil {
        return nil
    }
    pages := total / int64(p.Limit)
    if total%int64(p.Limit) != 0 { pages++ }
    return &Pagination{
        Page: p.Page, Limit: p.Limit, Total: total, TotalPages: pages,
        HasNext: int64(p.Page) < pages, HasPrev: p.Page > 1,
    }
}
```

```go
// pkg/paginate_utils/gorm.go
package paginate_utils

import "gorm.io/gorm"

func Paginate(p *PaginateData) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        if p == nil { return db }
        if p.Page < 1 { p.Page = 1 }
        if p.Limit < 1 { p.Limit = 20 }
        if p.Limit > 100 { p.Limit = 100 }
        return db.Offset((p.Page - 1) * p.Limit).Limit(p.Limit)
    }
}
```

### `app/use_case/common/`

```go
// app/use_case/common/error_mapper.go
package common

import (
    "errors"
    "net/http"
)

func RepositoryErrorToDomain(statusCode int, err error) error {
    if err == nil { return nil }
    return err
}

func NewValidationError(msg string) error      { return errors.New(msg) }
func NewDomainError(code, msg string) error    { return errors.New(code + ": " + msg) }
func WrapError(err error, code, msg string) error {
    return errors.New(code + ": " + msg + ": " + err.Error())
}

const StatusOK                  = http.StatusOK
const StatusBadRequest          = http.StatusBadRequest
const StatusInternalServerError = http.StatusInternalServerError
```

```go
// app/use_case/common/timezone.go
package common

import "time"

const DefaultTimezone = "Asia/Jakarta"

func LoadLocationOrDefault(tz string) (*time.Location, string) {
    if tz != "" {
        if loc, err := time.LoadLocation(tz); err == nil { return loc, tz }
    }
    loc, _ := time.LoadLocation(DefaultTimezone)
    return loc, DefaultTimezone
}

func ReinterpretDateInTZ(date time.Time, loc *time.Location) time.Time {
    return time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, loc)
}

func StartOfDayInTZ(t time.Time, loc *time.Location) time.Time {
    d := t.In(loc)
    return time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, loc)
}

func EndOfDayInTZ(t time.Time, loc *time.Location) time.Time {
    d := t.In(loc)
    return time.Date(d.Year(), d.Month(), d.Day(), 23, 59, 59, int(time.Second-time.Nanosecond), loc)
}
```

### `app/controller/common/response.go`

```go
package common

import (
    "github.com/gin-gonic/gin"
)

type SuccessResponse struct {
    Success bool        `json:"success"`
    Message string      `json:"message,omitempty"`
    Data    interface{} `json:"data,omitempty"`
}

type ErrorResponse struct {
    Success bool   `json:"success"`
    Message string `json:"message"`
}

const CtxKeyUserID = "user_id"

func SendSuccess(c *gin.Context, statusCode int, data interface{}) {
    c.JSON(statusCode, SuccessResponse{Success: true, Data: data})
}

func SendError(c *gin.Context, statusCode int, msg string) {
    c.JSON(statusCode, ErrorResponse{Success: false, Message: msg})
}

func GetUserIDFromContext(c *gin.Context) (interface{}, bool) {
    return c.Get(CtxKeyUserID)
}
```

### `app/repository/common/error_helpers.go`

```go
package common

import (
    "errors"
    "net/http"

    "gorm.io/gorm"
)

func HandleGORMError(err error) (int, error) {
    if err == nil { return http.StatusOK, nil }
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return http.StatusNotFound, errors.New("not found")
    }
    return http.StatusInternalServerError, err
}
```

Compile check:

```bash
go build ./...
```

If this passes, the prerequisite layer is healthy.

---

## Step 5 — Database bootstrap

```go
// database/database.go
package database

import (
    "errors"
    "fmt"
    "log"
    "os"

    "gorm.io/driver/postgres"
    "gorm.io/driver/sqlite"
    "gorm.io/gorm"
)

var DB *gorm.DB

func InitDatabase() error {
    if os.Getenv("DB_HOST") == "" {
        d, err := gorm.Open(sqlite.Open("data/app.db"), &gorm.Config{})
        if err != nil { return err }
        DB = d
        log.Println("✅ SQLite initialised")
        return nil
    }
    dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
        os.Getenv("DB_HOST"), os.Getenv("DB_PORT"),
        os.Getenv("DB_USER"), os.Getenv("DB_PASSWORD"), os.Getenv("DB_NAME"))
    d, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
    if err != nil { return err }
    DB = d
    log.Println("✅ PostgreSQL initialised")
    return nil
}

func GetDB() *gorm.DB { return DB }

func AutoMigrate() error {
    if DB == nil { return errors.New("database not initialized") }
    log.Println("🔄 Running database migrations...")
    models := []interface{}{
        // schemas registered here as features are added
    }
    if err := DB.AutoMigrate(models...); err != nil { return err }
    log.Println("✅ Migrations complete")
    return nil
}
```

---

## Step 6 — Empty central wiring

These three files must compile **before** any feature exists. They just have empty structs.

```go
// app/repository/repositories.go
package repository

import (
    "context"
    "gorm.io/gorm"
)

type Repositories struct {
    // features added here
}

func NewRepositories(db *gorm.DB) *Repositories {
    _ = &databaseConnection{db: db}
    return &Repositories{}
}

type databaseConnection struct{ db *gorm.DB }
func (d *databaseConnection) WithContext(ctx context.Context) *gorm.DB {
    return d.db.WithContext(ctx)
}
```

```go
// app/use_case/use_cases.go
package use_case

import "github.com/<owner>/something-backend/app/repository"

type UseCases struct {
    // features added here
}

func NewUseCase(repos *repository.Repositories) *UseCases {
    _ = repos
    return &UseCases{}
}
```

```go
// app/controller/controllers.go
package controller

import "github.com/<owner>/something-backend/app/use_case"

type Controllers struct {
    // features added here
}

func NewControllers(useCases *use_case.UseCases) *Controllers {
    _ = useCases
    return &Controllers{}
}
```

---

## Step 7 — Routes scaffolding

```go
// routes/routes.go
package routes

import (
    "github.com/<owner>/something-backend/app/controller"
    "github.com/gin-gonic/gin"
)

type RouterDependencies struct {
    Controllers *controller.Controllers
}

func SetupRoutes(deps *RouterDependencies) *gin.Engine {
    r := gin.Default()
    setupAuthenticatedRoutes(r, deps.Controllers)
    return r
}

func setupAuthenticatedRoutes(r *gin.Engine, ctrls *controller.Controllers) {
    authGroup := r.Group("")
    // authGroup.Use(http_middleware.JWTAuthentication)   // wire when auth middleware lands
    _ = authGroup
    _ = ctrls
}
```

---

## Step 8 — `main.go`

```go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/<owner>/something-backend/app/controller"
    "github.com/<owner>/something-backend/app/repository"
    "github.com/<owner>/something-backend/app/use_case"
    "github.com/<owner>/something-backend/database"
    "github.com/<owner>/something-backend/routes"

    "github.com/joho/godotenv"
)

func main() {
    _ = godotenv.Load()

    if err := database.InitDatabase(); err != nil { log.Fatal(err) }
    if err := database.AutoMigrate(); err != nil { log.Fatal(err) }

    db := database.GetDB()
    repos := repository.NewRepositories(db)
    useCases := use_case.NewUseCase(repos)
    controllers := controller.NewControllers(useCases)

    router := routes.SetupRoutes(&routes.RouterDependencies{Controllers: controllers})

    server := &http.Server{Addr: "0.0.0.0:7281", Handler: router}

    go func() {
        log.Printf("Server running on %s", server.Addr)
        if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    _ = server.Shutdown(ctx)
}
```

Compile + run:

```bash
go build ./... && go run main.go
# expect: "✅ SQLite initialised" + "✅ Migrations complete" + "Server running on 0.0.0.0:7281"
```

---

## Step 9 — Adopt the skill via `CLAUDE.md`

```markdown
# something-backend — AI working notes

## Doctrine

This project follows **`go-rest-clean-arch@v0.2.0`** — a Go REST Clean Architecture playbook published as a Claude Code plugin.

- Source: <https://github.com/Rhyanz46/go-rest-skills>
- Skill name: `rhyanz46:go-rest-clean-arch`
- Pinned version: **`v0.2.0`** (bump deliberately after reviewing the diff)

The skill carries the canonical rules. Read its `SKILL.md` (installed locally via `/plugin install rhyanz46@go-rest-skills`, or fetched from the repo above at the pinned tag) before doing non-trivial work in this codebase.

There is no in-repo `ai_instruction/`. All doctrine lives in the skill.

## Project-specific overrides

(Add notes here only when this repo deviates from the canonical playbook.)

— none yet —

## Updating the doctrine

Doctrine changes flow through the skill repo. To bump:
1. Review the skill repo diff between the pinned and target tag.
2. Update `Pinned version` above.
3. Refresh installed plugin:
   ```
   /plugin marketplace update go-rest-skills
   /plugin uninstall rhyanz46@go-rest-skills
   /plugin install rhyanz46@go-rest-skills
   /reload-plugins
   ```
```

---

## Step 10 — Drop in the lint script (Tahap 4)

Add a Makefile target so every contributor runs the architecture lint locally and in CI:

```makefile
# Makefile
.PHONY: lint-arch
lint-arch:
	@bash <(curl -fsSL https://raw.githubusercontent.com/Rhyanz46/go-rest-skills/v0.2.0/tools/lint.sh)
```

Or copy `tools/lint.sh` into the repo at `scripts/lint-arch.sh` if you don't want a curl-at-runtime dependency.

Run once now to confirm a clean baseline:

```bash
make lint-arch
# expected: ✅ all clean (no features yet, but the script must pass)
```

Wire into CI (GitHub Actions example):

```yaml
# .github/workflows/lint.yml
name: Architecture lint
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make lint-arch
```

---

## Step 11 — First commit

```bash
git add .
git commit --author="<Name> <email>" -m "Bootstrap project on go-rest-clean-arch@v0.2.0"
```

---

## Verification checklist

- [ ] `go build ./...` passes with no warnings.
- [ ] `go run main.go` starts the server and migrates the DB.
- [ ] `make lint-arch` exits 0.
- [ ] `CLAUDE.md` exists at repo root and pins a specific skill version.
- [ ] **No `ai_instruction/` directory** in the repo.
- [ ] All four shared utility packages exist (`pkg/paginate_utils/`, `app/use_case/common/`, `app/controller/common/`, `app/repository/common/`).
- [ ] Three central structs (`Repositories`, `UseCases`, `Controllers`) compile empty.

If every box is checked, the project is ready for the first feature — open `feature-recipe.md` and follow it.

---

## What you do NOT do at bootstrap time

- Do **not** create example/demo features. Empty wiring is the goal.
- Do **not** copy `ai_instruction/` from another project. The skill is the source.
- Do **not** add Swagger annotations yet (rule #14 — only after handlers exist).
- Do **not** add APM/OTel yet (rule #15 — Phase 3.2 after core works).
- Do **not** invent a custom `Pagination` struct — use the one in `pkg/paginate_utils/`.
- Do **not** invent a custom error type — use the helpers in `app/use_case/common/`.

The skill enforces what NOT to do; this recipe enforces the same at bootstrap time.
