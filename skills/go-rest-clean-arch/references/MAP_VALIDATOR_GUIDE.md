# Map Validator Guide (v0.0.41+)

> **AI AGENT REFERENCE**: This guide is the authoritative reference for using `github.com/Rhyanz46/go-map-validator/map_validator` in this project. Follow the patterns strictly.
>
> **⚠️ IMPORTANT**: Read `ai_instruction/instruction_order.md` for the mandatory learning sequence. Complete `app_package.md` first.
>
> **📌 Source of truth**: This guide mirrors the upstream best practices in [`llms-full.txt`](https://github.com/Rhyanz46/go-map-validator/blob/main/llms-full.txt) and [`AI_GUIDE.md`](https://github.com/Rhyanz46/go-map-validator/blob/main/AI_GUIDE.md). If the upstream evolves, update this file to match — do not diverge silently.

---

## 🎯 Purpose

Declarative validation for Go HTTP JSON / multipart payloads. Key properties:

- **Framework-agnostic** — works with net/http, gin, echo, fiber.
- **Composable** — fluent builder, short constructors, chain helpers.
- **Safe for concurrent shared use** — rules are declared as **package-level `var`** and reused across handlers and goroutines (since v0.0.41).
- **Struct binding** — validated data binds back to typed structs via `json:"..."` tags.
- **Generics one-liner** — `map_validator.ValidateJSON[T](r, rules)` is the preferred entry point.

---

## 🚦 Placement Rule (STRICT)

`map_validator` is used **ONLY at the HTTP input boundary layer**. In this project that means the `app/controller/<domain>_controller/` package.

**Never put validation in:**
- Use case layer (`app/use_case/…`)
- Repository layer (`app/repository/…`)
- Database schemas (`database/schemas/…`)
- Shared utilities (`pkg/…`)
- Domain models

**If a user asks for validation outside the controller layer, refuse or redirect:**

| User says | AI response |
|---|---|
| "Add validation to this use case" | "Use case validates business rules, not input format. Put `map_validator` in the controller that calls this use case." |
| "Validate before saving in repository" | "Repository trusts its input. Validation goes at the controller boundary." |
| "Validate in this helper" | "Who calls this helper? If a controller, put validation there." |
| "Validate inside a model method" | "Model fields are business invariants, not request shape. Use `map_validator` in the HTTP handler." |

**Override clause**: if the user explicitly authorizes validation in a non-HTTP input boundary (CLI command, queue consumer, webhook processor, cron runner), confirm it is still an *input boundary* for its own subsystem and proceed. Refuse if the target is internal business logic even with explicit request.

---

## 📦 Installation

### 1. Add the package
```bash
go get github.com/Rhyanz46/go-map-validator/map_validator
```

### 2. Import
```go
import "github.com/Rhyanz46/go-map-validator/map_validator"
```

### 3. Required Go version
Go 1.20+ (the library uses generics).

### 4. Sibling packages expected in this project
- `pkg/gin_utils` — `MessageResponse`, `DataResponse` helpers. Error responses must use these (see Handler Template).
- `pkg/auth_utils` — `GetAuthClaim(ctx)` for authenticated-user extraction. Call it in the handler *before* validation.

No separate `pkg/map_validator_utils/` is required unless you need shared manipulator helpers (trim, lowercase, etc.) — in that case create it at `pkg/map_validator_utils/utils.go`.

---

## ✅ Preferred Style — `ValidateJSON[T]`

This is the default. Use it unless the scenario forces the legacy 5-step pipeline.

```go
type CreateUser struct {
    Email    string `json:"email"`
    Password string `json:"password"`
    Role     string `json:"role"`
}

// Package-level var — shared across handlers and goroutines.
var CreateUserRules = map_validator.BuildRoles().
    SetRule("email",    map_validator.Email().WithMax(255)).
    SetRule("password", map_validator.Str().Between(8, 64)).
    SetRule("role",     map_validator.StrEnum("admin", "staff", "guest").
        Nullable().Default("guest")).
    Done()

func (h *userController) CreateUser(c *gin.Context) {
    req, err := map_validator.ValidateJSON[CreateUser](c.Request, CreateUserRules)
    if err != nil {
        c.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
        return
    }
    // req is validated, defaults applied, bound into the typed struct.
    // Forward to the use case.
    ...
}
```

### Why `ValidateJSON[T]`?

- One call covers **Load → Validate → Bind**.
- Type parameter `T` guarantees the bound struct is a compile-time checked value.
- Errors are the same sentinels as the 5-step pipeline (`ErrNoRules`, `ErrInvalidJsonFormat`, or a validation error) — no difference in semantics, just less boilerplate.

---

## 🧱 Short Constructors (use these first)

Each returns a `Rules` value. Chain helpers freely.

| Constructor | Meaning |
|---|---|
| `Str()` | string field |
| `Int()` / `Int64()` | integer field (any int-family rule tolerates JSON float64) |
| `Float64()` | float field |
| `Bool()` | boolean field |
| `Email()` | email format (lenient — requires `@` and `.`) |
| `UUID()` | UUID format; returns `uuid.UUID` typed after bind |
| `UUIDToString()` | UUID format; keeps original string (easier struct binding) |
| `IPv4()` | strict IPv4 |
| `StrEnum(items...)` | string enum, e.g. `StrEnum("pending","active","done")` |
| `IntEnum(items...)` | int enum |
| `NestedObject(rulesWrapper)` | nested object |
| `ListOfObject(rulesWrapper)` | array of objects |

**Struct literals like `Rules{Type: reflect.String, Max: SetTotal(255)}` are an escape hatch**, not the default. Only reach for them when no short constructor fits.

---

## 🔗 Chain Helpers (value receivers, safe to chain)

```go
.Nullable()                  // field may be absent / null
.Default(v)                  // substitute v when absent
.WithMin(n)                  // Min length / numeric minimum
.WithMax(n)                  // Max length / numeric maximum — MUST on every string field
.Between(min, max)           // Min + Max combined
.Regex(pattern)              // Go regexp; strings only
.WithMsg(customMsg)          // replace default error messages
.UniqueFrom(fields...)       // value must differ from listed fields
.WithRequiredIf(fields...)   // required when listed fields are present
.WithRequiredWithout(fields...) // required when listed fields are absent
```

All helpers are **value receivers** — chaining is always safe.

---

## 🗂 Rules Organization

### Rule #1 — package-level `var`, never re-created per request

```go
// ❌ BAD — rebuilds rules on every request
func (h *userController) CreateUser(c *gin.Context) {
    rules := map_validator.BuildRoles().SetRule(...).Done()
    req, err := map_validator.ValidateJSON[CreateUser](c.Request, rules)
}

// ✅ GOOD — rules as package-level var
var CreateUserRules = map_validator.BuildRoles().SetRule(...).Done()

func (h *userController) CreateUser(c *gin.Context) {
    req, err := map_validator.ValidateJSON[CreateUser](c.Request, CreateUserRules)
}
```

### Rule #2 — file layout

For a domain with many handlers, put rule definitions in a sibling file of the controller:

```
app/controller/
└── user_controller/
    ├── controller.go   # HTTP handlers
    ├── interfaces.go
    ├── models.go       # HTTP DTOs (request/response structs)
    └── rules.go        # ← validation rules as package-level vars
```

Rules stay *next to* the controller because they are part of the HTTP boundary contract — they travel together when the domain moves.

### Rule #3 — naming

`<Action><Resource>Rules` — e.g. `CreateUserRules`, `UpdateTrackRules`, `SendFriendRequestRules`, `ApplyPlanRules`.

### Rule #4 — shared rules across handlers

If two handlers need the same rule set (e.g. `Update` and `PartialUpdate`), define one var and reuse it. Rules are safe for concurrent shared use since v0.0.41.

---

## 🏗 Canonical Handler Template

Every HTTP handler in this project should follow this six-step shape.

```go
func (h *userController) CreateUser(c *gin.Context) {
    // 1. Auth — extract current user from JWT middleware context
    authClaim := auth_utils.GetAuthClaim(c.Request.Context())
    if authClaim.UserID == uuid.Nil {
        c.JSON(http.StatusForbidden, gin_utils.MessageResponse{Message: "auth required"})
        return
    }

    // 2. Path params — parse URI-level identifiers
    orgID, err := uuid.Parse(c.Param("org_id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: "invalid org_id"})
        return
    }

    // 3. Validate body — the ONLY place map_validator is called
    req, err := map_validator.ValidateJSON[CreateUser](c.Request, CreateUserRules)
    if err != nil {
        c.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // 4. Authorization — business rule: can this user perform this action?
    //    (distinct from authentication above)
    if err := h.checkPermission(authClaim, orgID); err != nil {
        c.JSON(http.StatusForbidden, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // 5. Service call — delegate to the use case layer
    res, status, err := h.userUseCase.CreateUser(c.Request.Context(), authClaim.UserID, orgID, req)
    if err != nil {
        if status == http.StatusInternalServerError {
            c.JSON(status, gin_utils.MessageResponse{Message: "internal server error"})
            return
        }
        c.JSON(status, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // 6. Response
    c.JSON(status, gin_utils.DataResponse{Message: "user created", Data: res})
}
```

Never inline business logic between steps 3 and 5 — that belongs in the use case.

---

## 🔒 Security MUSTs

1. **`WithMax(n)` on every string field.** Without a max, an attacker can POST a megabyte-long string and exhaust memory. Set a realistic upper bound (usually 255–1000 for names, ≤ 4096 for descriptions).
2. **`UUID()` for every external ID.** If the payload contains an `id`, `user_id`, `target_user_id`, or similar opaque identifier, validate it as a UUID.
3. **`StrEnum()` / `IntEnum()` for every limited-value field.** Status, role, share mode, repeat mode, etc. — whitelist allowed values at the HTTP boundary.
4. **Trim / sanitize string inputs** via manipulators when the business cares about leading/trailing whitespace or casing. Use `strings.TrimSpace` as the default.
5. **Password fields**: validate *length only* (`Str().Between(8, 64)`) in the validator. Strength checks (character classes, dictionary attacks) belong in the use case or a dedicated password service.
6. **Never put DB lookups, API calls, or cross-system checks inside rules.** Rules are pure input-shape validation. Uniqueness against the database, existence checks, quota enforcement — all use case concerns.

---

## ❌ What NOT to do (anti-patterns)

| Anti-pattern | Why it's wrong | Do this instead |
|---|---|---|
| `rules := BuildRoles()...Done()` inside handler | Re-allocates on every request, no concurrency reuse | Package-level `var` |
| `Rules{Type: reflect.String, Max: SetTotal(100)}` when `Str().WithMax(100)` fits | Harder to read, bypasses short-constructor ergonomics | Use `Str()`, `Email()`, `UUID()`, etc. |
| `c.JSON(400, ErrorResponse{Message: "validation failed: " + err.Error()})` | Wraps the library's error with a useless prefix | Forward `err.Error()` verbatim |
| `if strings.Contains(err.Error(), "...") { ... }` | Couples handler to error text | Use sentinels `ErrNoRules`, `ErrInvalidJsonFormat` if branching is needed |
| Validating enum values in the use case with a for-loop | Duplicates rule logic, drifts out of sync | `StrEnum(...)` in the rule — single source of truth |
| Using `c.ShouldBindJSON(&req)` with `binding:"required"` struct tags | That's the GIN built-in path, not `map_validator` | Replace with `ValidateJSON[T]` |
| Password strength regex inside the validator | Strength is a business decision, and regex is brittle | Length-only in the rule; strength in the use case |

---

## 🧩 Advanced — 5-Step Pipeline

Use the legacy 5-step pipeline **only** when `ValidateJSON[T]` is insufficient. Concrete reasons:

- You need `GetFilledField()` / `GetNullField()` / `GetData()` between validation and bind (e.g. to build a partial-update map).
- You register an extension that must run under `AddExtension(...)`.
- You need to run custom logic between validate and bind that the typed bind cannot express.

```go
op, err := map_validator.NewValidateBuilder().SetRules(UpdateUserRules).LoadJsonHttp(c.Request)
if err != nil {
    c.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
    return
}
extra, err := op.RunValidate()
if err != nil {
    c.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
    return
}

// Inspect what the client actually sent vs. what stayed null.
filledOnly := extra.GetFilledField()
// filledOnly is map[string]interface{} — suitable for dynamic UPDATE
```

`ValidateJSON[T]` composes `LoadJsonHttp` + `RunValidate` + typed `Bind` internally. Both entry points share identical validation semantics — pick the one that fits.

---

## 🧬 Nested Objects & Lists

### Nested object

```go
var AddressRules = map_validator.BuildRoles().
    SetRule("street", map_validator.Str().WithMax(255)).
    SetRule("city",   map_validator.Str().WithMax(100)).
    Done()

var CreateUserRules = map_validator.BuildRoles().
    SetRule("name",    map_validator.Str().WithMax(100)).
    SetRule("address", map_validator.NestedObject(AddressRules).Nullable()).
    Done()
```

### List of objects

```go
var PlanItemRules = map_validator.BuildRoles().
    SetRule("name",   map_validator.Str().Between(1, 100)).
    SetRule("start",  map_validator.Str().Regex(`^\d{2}:\d{2}$`)).
    SetRule("end",    map_validator.Str().Regex(`^\d{2}:\d{2}$`)).
    SetRule("status", map_validator.StrEnum("not started", "in progress", "done")).
    Done()

var CreateTemplateRules = map_validator.BuildRoles().
    SetRule("name",  map_validator.Str().WithMax(100)).
    SetRule("plans", map_validator.ListOfObject(PlanItemRules)).
    Done()
```

Payload must be a JSON array of objects. Sending a single object for a `ListOfObject` rule yields `"field '<name>' is not valid list object"`.

### Limit nesting to 3 levels

If you need deeper nesting, redesign the API. Flat structures bind more reliably and compose better with future extensions.

### Primitive lists

```go
// ["red", "green", "blue"] — each item must be in the enum, list length ≤ 5
map_validator.Rules{
    Type: reflect.String,
    List: map_validator.BuildListRoles(),
    Enum: &map_validator.EnumField[any]{Items: []string{"red", "green", "blue"}},
    Max:  map_validator.SetTotal(5),
}
```

Primitive lists are one of the few places where the struct literal is the idiomatic form — short constructors do not cover this.

---

## 💬 Custom Messages

### Supported hooks
`OnTypeNotMatch`, `OnRegexString`, `OnMin`, `OnMax`, `OnUnique`, `OnEnumValueNotMatch`.

### Template variables
`${field}`, `${expected_type}`, `${actual_type}`, `${actual_length}`, `${expected_min_length}`, `${expected_max_length}`, `${unique_origin}`, `${unique_target}`, `${actual_value}`, `${enum_values}`.

### Example

```go
map_validator.Str().Between(2, 20).WithMsg(map_validator.CustomMsg{
    OnMin: map_validator.SetMessage("'${field}' too short — got ${actual_length}, need ≥ ${expected_min_length}"),
    OnMax: map_validator.SetMessage("'${field}' too long — got ${actual_length}, max ${expected_max_length}"),
})

map_validator.StrEnum("active", "inactive", "pending").WithMsg(map_validator.CustomMsg{
    OnEnumValueNotMatch: map_validator.SetMessage("'${field}' value '${actual_value}' is not one of ${enum_values}"),
})
```

**When to write custom messages**: user-facing public APIs where the error text is shown to end users. Skip for internal service-to-service APIs — the default messages are good enough and reduce maintenance.

---

## 🔧 Manipulators (post-validation transforms)

```go
var CreateUserRules = map_validator.BuildRoles().
    SetRule("name", map_validator.Str().WithMax(100)).
    SetManipulator("name", func(v interface{}) (interface{}, error) {
        return strings.TrimSpace(v.(string)), nil
    }).
    Done()

// Bulk (apply the same manipulator to multiple fields):
var rules = map_validator.BuildRoles().
    SetRule("name", map_validator.Str().WithMax(100)).
    SetRule("description", map_validator.Str().WithMax(500)).
    SetFieldsManipulator([]string{"name", "description"}, trim).
    Done()
```

**Rules for manipulators**:
- Run **after** validation, **before** Bind.
- Must be pure — no I/O, no DB, no side effects, no cross-field state.
- Return `(result, nil)` on success, `(nil, err)` to abort.

For shared manipulators (trim, lowercase, etc.), create `pkg/map_validator_utils/utils.go`:

```go
package map_validator_utils

import "strings"

func TrimValidation(data interface{}) (interface{}, error) {
    s, ok := data.(string)
    if !ok {
        return data, nil
    }
    return strings.TrimSpace(s), nil
}
```

---

## ⚠️ Validation Semantics — quick reference

| Concept | Behavior |
|---|---|
| JSON numbers | Decoded as `float64`. Int-family rules tolerate this — no manual conversion. |
| `LoadFormHttp` values | All strings. `Int` / `Bool` rules need a manipulator or extension to parse. |
| Email validation | Lenient — only checks for `@` and `.`. Use `.Regex(...)` for stricter rules. |
| Map iteration order | Non-deterministic (Go map). Don't rely on error-field ordering. |
| Bind mechanism | `json.Marshal` → `json.Unmarshal`. Struct tags `json:"..."` must match rule keys. |
| Empty body | Treated as empty map — rules surface missing-field errors normally. |
| Empty rules | `SetRules(empty)` does not panic. `Load*` returns `ErrNoRules`. |
| Strict mode | `SetSetting(Setting{Strict: true})` rejects keys not declared in rules at that object level. Nested objects need their own `Strict` setting — not inherited. |
| Null handling | Default: required. `.Nullable()` makes optional. `.Default(v)` substitutes `v` when absent. |
| UUID kinds | `UUID()` returns `uuid.UUID`. `UUIDToString()` returns original string. |
| IPv4 kinds | `IPV4: true` strict; `IPV4Network: true` requires last octet = 0; `IPv4OptionalPrefix: true` allows `/CIDR`. |

---

## 🧯 Error Sentinels

- `ErrNoRules` — from `Load*` when no rules were set.
- `ErrInvalidJsonFormat` — from `LoadJsonHttp` when the body is not valid JSON.
- `ErrUnsupportType` — from `LoadFormHttp` when a rule's Type is not `string`, `int`, or `bool`.

Validation errors are regular `error` values with human-readable text. The library currently returns the first encountered error; multi-error aggregation is on the roadmap.

**Always forward `err.Error()` verbatim** to the HTTP response body. Never prefix with `"validation failed: "` or similar — the user gets a clearer message and your handler stays decoupled from error text.

---

## 🧪 Testing Expectations

When generating handlers, also generate tests that cover:

1. **Happy path** — valid body, expected response.
2. **Missing required field** — expect 400 with `"we need '<field>' field"`.
3. **Oversized string** — expect 400 with max-length message.
4. **Wrong type** — expect 400 with type error.
5. **Invalid JSON** — expect 400 from `ErrInvalidJsonFormat`.
6. **Empty body** — expect 400 from missing-required-field.
7. **Unknown enum value** (if `StrEnum`/`IntEnum` used) — expect 400.
8. **Invalid UUID** (if `UUID()` used) — expect 400.

Verify the struct was actually bound — `json:"..."` tag / rule key mismatches are a silent failure mode.

---

## 📋 Best Practices Checklist

Use this before merging a PR that touches validation code.

### Security (MUST)
- [ ] Every string field has `.WithMax(n)` (DoS protection)
- [ ] Every external ID uses `UUID()`
- [ ] Every limited-value field uses `StrEnum()` / `IntEnum()`
- [ ] No DB / API / cross-system checks inside rules
- [ ] Password rules are length-only; strength checks are in the use case

### Code style (MUST / SHOULD)
- [ ] MUST use `ValidateJSON[T]` unless the 5-step pipeline is truly required
- [ ] MUST use short constructors (`Email()`, `Str().WithMax(n)`, `UUID()`, `StrEnum(...)`) — struct literals are an escape hatch
- [ ] MUST declare rules as package-level `var`, not per-request
- [ ] SHOULD follow naming `<Action><Resource>Rules` (e.g. `CreateUserRules`)
- [ ] SHOULD place rules in `app/controller/<domain>_controller/rules.go`

### Logic boundaries (MUST)
- [ ] MUST NOT put business logic in rules
- [ ] SHOULD limit nesting to 3 levels
- [ ] MUST NOT introduce side effects in manipulators
- [ ] MUST NOT invent validation for fields the user didn't request

### Handler flow (MUST)
- [ ] Handler order: auth → path params → validate body → authorization → service call → response
- [ ] Forward `err.Error()` as-is
- [ ] Log internal errors; return generic message for 500 responses
- [ ] Use `gin_utils.MessageResponse` / `gin_utils.DataResponse` for responses

### Testing (SHOULD)
- [ ] Every rule has happy-path + at least one unhappy-path test
- [ ] Edge cases: empty body, null, oversized, wrong type, missing field
- [ ] Struct binding verified — JSON tags match rule keys

### Documentation (SHOULD)
- [ ] Comment the *why* for non-obvious rules (magic limits, regex choice)
- [ ] Custom messages for user-facing endpoints; skip for internal APIs
- [ ] Swagger annotations on handlers — see `swagger_annotation_guide.md`

---

## 🚫 Things NOT yet supported

- Multi-error aggregation with field paths (first error only; opt-in on roadmap).
- URL params extraction helpers.
- Base64 validation.
- Multipart file size limits / image resolution checks.
- OpenAPI spec generator.
- Multi-validator per field (e.g. IPv4 + UUID combined).
- Custom messages for null errors and `RequiredIf` / `RequiredWithout`.

If the user asks for one of these, explain the gap and suggest either the roadmap item, a manipulator, an extension, or a service-layer check.

---

## 🗺 Quick Reference Card

```
Entry point:       ValidateJSON[T](r *http.Request, rules) (T, error)
Build rules:       BuildRoles().SetRule(k, rule).Done()   — package-level var
Share rules:       Safe for concurrent use (v0.0.41+)

Constructors:      Str Int Int64 Float64 Bool Email UUID UUIDToString IPv4
Enum:              StrEnum("a","b") IntEnum(1,2)
Nesting:           NestedObject(w) ListOfObject(w)

Chain:             .Nullable() .Default(v) .WithMin(n) .WithMax(n)
                   .Between(min,max) .Regex(pattern) .WithMsg(cm)
                   .UniqueFrom(…) .WithRequiredIf(…) .WithRequiredWithout(…)

Placement:         controller / handler layer ONLY
Business logic:    use case layer, never in rules
Errors:            forward err.Error() as-is, no prefixing

Min set checklist: Max on strings, UUID for IDs, Enum for limited values
File layout:       app/controller/<domain>_controller/rules.go
```

---

*This guide reflects go-map-validator v0.0.41+. If upstream releases introduce new helpers or behaviour changes, refresh this file from [`llms-full.txt`](https://github.com/Rhyanz46/go-map-validator/blob/main/llms-full.txt) and bump the reference.*
