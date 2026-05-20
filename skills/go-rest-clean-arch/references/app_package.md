# App Package Documentation - Go Clean Architecture Blueprint

> **Note for AI Agents**: Replace `<PROJECT_NAME>` with your actual Go module name (e.g., `github.com/your-org/your-project`) and `<PROJECT_ROOT>` with your project's root directory path.
>
> **📝 Project Name Examples:**
> - **GitHub:** `github.com/your-org/your-service`
> - **GitLab:** `gitlab.com/company/project-name`
> - **Internal:** `company.internal/product/service-name`
> - **Local:** `my-project` (for local development only)
>
> **⚠️ NEVER use:** `project-name`, `<project-name>`, or un-replaced placeholders
>
> **⚠️ IMPORTANT**: Read `ai_instruction/instruction_order.md` for the mandatory learning sequence. This is the FOUNDATION guide that must be completed first.
>
> **🎯 99% Completion Rule**: This guide must be 99% complete before implementing APM or Swagger documentation. This ensures Clean Architecture principles are properly established first.

## 🔥 Quick Start Rules for AI Agents

### ALWAYS Follow These Rules:
1. **File Organization**: Every domain gets its own folder under `app/`
2. **Layer Separation**: NEVER import deeper layers (controllers can't import repository directly)
3. **Model Separation**: Each layer creates its own models - NEVER share models between layers
4. **Bottom-Up Development**: ALWAYS build from bottom layer up - Database → Repository → Use Case → Controller
5. **Build Verification**: Each layer MUST build successfully before moving to next layer
6. **Interface First**: ALWAYS define interfaces before implementations
7. **Error Pattern**: All layers below controller return `(result, int, error)`
8. **🔥 FILTER PATTERN (STRICT)**: NEVER create GetById, GetByEmail, GetByStatus methods. Use SINGLE filter object for ALL queries
9. **💬 COMMENTS OK**: Comments are allowed and encouraged where they clarify intent — package docs, godoc on exported identifiers, short rationale on non-obvious code. Don't narrate what well-named code already says. Swagger annotations on HTTP handlers are still required (see swagger_annotation_guide.md).
10. **⚖️ MINIMAL FEATURE RULE**: ALWAYS implement the SMALLEST possible version of what user wants

### File Structure Template:
```
app/
├── controller/
│   ├── [domain]_controller/
│   │   ├── models.go      # HTTP request/response models
│   │   ├── interfaces.go  # Controller interface
│   │   └── controller.go  # Implementation
├── use_case/
│   ├── [domain]_use_case/
│   │   ├── models.go      # Business logic models
│   │   ├── interfaces.go  # Use case interface
│   │   └── use_case.go    # Implementation
└── repository/
    ├── [domain]_repository/
    │   ├── models.go      # Database models
    │   ├── filters.go     # Filter structures
    │   ├── interfaces.go  # Repository interface
    │   └── repository.go  # Implementation
```

**Example for "users" domain:**
```
app/
├── controller/
│   └── users_controller/
│       ├── models.go
│       ├── interfaces.go
│       └── controller.go
├── use_case/
│   └── users_use_case/
│       ├── models.go
│       ├── interfaces.go
│       └── use_case.go
└── repository/
    └── users_repository/
        ├── models.go
        ├── filters.go
        ├── interfaces.go
        └── repository.go
```

## 🔄 STRICT Bottom-Up Layer Development

**🚨 MANDATORY DEVELOPMENT ORDER** - NEVER skip layers or work on multiple layers simultaneously:

### Development Flow:
```
1. Database Schemas (Bottom Layer)
   ↓
2. Repository Layer (Must build successfully)
   ↓
3. Use Case Layer (Must build successfully)
   ↓
4. Controller Layer (Top Layer)
   ↓
5. Routes Integration
```

### Step-by-Step Process:

#### Step 1: Database Schemas
- Create GORM models in `database/schemas/[domain].go`
- **BUILD VERIFICATION**: Run `go build ./database/...`
- **🚨 MANDATORY USER CONFIRMATION**: Must display build success and ask "✅ Database layer builds successfully. Proceed to Repository layer?" before continuing
- ❌ CANNOT proceed without user confirmation

#### Step 2: Repository Layer
- Create repository domain models (separate from database schemas)
- Create repository interfaces and implementations in `app/repository/[domain]_repository/`
- Map database schema models → repository domain models internally
- **BUILD VERIFICATION**: Run `go build ./app/repository/...`
- **🚨 MANDATORY USER CONFIRMATION**: Must display build success and ask "✅ Repository layer builds successfully. Proceed to Use Case layer?" before continuing
- ❌ CANNOT proceed without user confirmation

#### Step 3: Use Case Layer
- Create use case models (if needed)
- Create use case interfaces and implementations in `app/use_case/[domain]_use_case/`
- Use repository domain models (NEVER database schemas)
- **BUILD VERIFICATION**: Run `go build ./app/use_case/...`
- **🚨 MANDATORY USER CONFIRMATION**: Must display build success and ask "✅ Use Case layer builds successfully. Proceed to Controller layer?" before continuing
- ❌ CANNOT proceed without user confirmation

#### Step 4: Controller Layer
- Create controller DTOs and implementation in `app/controller/[domain]_controller/`
- Use map_validator for validation
- Use use case models (NEVER repository or database models)
- **BUILD VERIFICATION**: Run `go build ./app/controller/...`
- **🚨 MANDATORY USER CONFIRMATION**: Must display build success and ask "✅ Controller layer builds successfully. Proceed to Routes integration?" before continuing
- ❌ CANNOT proceed without user confirmation

#### Step 5: Routes Integration
- Update `routes/rest.go` to register new routes
- Update `routes/init.go` to wire dependencies
- **FINAL BUILD**: Run `go build ./...` to verify entire project
- **🚨 MANDATORY USER CONFIRMATION**: Must display build success and ask "✅ Entire project builds successfully. Feature implementation complete!" before finishing
- ❌ CANNOT finish without user confirmation

**⚠️ CRITICAL**: Each layer MUST build successfully AND receive user confirmation before proceeding to the next layer. AI Agent CANNOT skip layers or proceed without explicit user approval at each step.

### 🤖 AI Agent Mandatory Behavior Pattern

**AI Agent MUST follow this exact pattern for each layer:**

```bash
# 1. Build the layer
$ go build ./[layer-path]/...

# 2. Display success message
✅ [Layer Name] layer builds successfully.

# 3. Ask for confirmation (EXACT FORMAT)
✅ [Layer Name] layer builds successfully. Proceed to [Next Layer Name]?

# 4. WAIT for user response
# - If user says "yes" or "continue" → proceed to next layer
# - If user says "no" or "stop" → STOP and wait for further instructions
# - If user asks for changes → make requested changes, then rebuild

# 5. ONLY after confirmation → move to next layer
```

**🚨 STRICT FORBIDDEN BEHAVIORS:**
- ❌ NEVER proceed to next layer without build success
- ❌ NEVER proceed without asking user confirmation
- ❌ NEVER skip layers even if build succeeds
- ❌ NEVER work on multiple layers simultaneously
- ❌ NEVER assume user approval - must get explicit "yes"
- ❌ NEVER create GetById, GetByEmail, GetByStatus methods if they return SAME type - use Filter Pattern
- ❌ NEVER create multiple Get methods for different fields if they return SAME model
- ❌ NEVER duplicate methods with different names but same functionality

**✅ REQUIRED BEHAVIORS:**
- ✅ ALWAYS show build command used
- ✅ ALWAYS display build success message
- ✅ ALWAYS ask confirmation using exact format
- ✅ ALWAYS wait for user response
- ✅ ALWAYS stop if user declines
- ✅ ALWAYS use Filter Pattern for methods returning SAME type
- ✅ ALWAYS create filter struct with pointer fields for optional criteria
- ✅ ONLY create new method when return type is DIFFERENT from existing methods

---

## 📚 Documentation Contents

- [🔐 Authentication Context (CRITICAL)](#-authentication-context-critical)
- [Controller Layer Blueprint](#controller-layer)
- [Use Case Layer Blueprint](#use-case-layer)
- [Repository Layer Blueprint](#repository-layer)
- [Error Handling Rules](#error-handling-pattern)
- [Pagination & Filtering Rules](#pagination-and-filtering)
- [Model Transformation Rules](#layer-models-and-transformations)

## 🔐 Authentication Context (CRITICAL)

### When to Use GetAuthClaim:
**⚠️ STRICT RULE**: Use `auth_utils.GetAuthClaim(ctx)` ONLY when you need current user information for business logic.

### Best Practice: Use in Controller Layer Only
```go
// In Controller Layer (RECOMMENDED):
authClaim := auth_utils.GetAuthClaim(ctx)

// Get current user info:
userID := authClaim.UserID        // Current user ID
role := authClaim.Role           // User role (Superadmin, Owner, Member)
organizationID := authClaim.OrganizationID

// Example: Check user role
if authClaim.IsMember() {
    // Handle member access
}
```

### Usage in Other Layers:
- **Use Case Layer**: Allowed but requires user justification
- **Repository Layer**: Allowed but requires user justification

**🚨 AI Agent Warning Rule**:
If AI Agent finds `GetAuthClaim()` usage in Use Case or Repository layers:
```
⚠️ WARNING: Found GetAuthClaim() usage in [Layer Name].
Consider moving this logic to Controller layer.
Are you sure you need user context in this layer? Please confirm.
```

### Flow:
1. JWTAuthentication middleware validates token and sets context
2. Auth context automatically flows to all layers via `ctx context.Context`
3. **PREFERRED**: Use `GetAuthClaim()` in Controller layer
4. **ALLOWED**: Can use in other layers with strong justification
5. NO authentication checks needed in app layers (middleware handles it)

## 🚀 AI Agent Pre-Coding Checklist

**🛑 MANDATORY: AI Agents CANNOT START CODING app/ folder until ALL dependencies are verified and complete:**

### Rule #1: Complete Dependency Verification
**AI Agents MUST verify ALL dependencies exist BEFORE creating ANY app/ folder code:**

1. Check go.mod exists and has required modules
2. Verify main.go exists with proper structure
3. Verify database/database.go exists
4. Verify database/schemas/ folder exists (contains GORM models)
5. Verify pkg/paginate_utils/ exists with all 3 files
6. Verify app/repository/common/ exists with all 2 files
7. Verify pkg/gin_utils/message.go exists (CRITICAL for error responses)
8. Verify pkg/http_middleware/http.go exists (MANDATORY for authentication middleware)
9. Verify pkg/auth_utils/ exists with all 3 files (MANDATORY for JWT and auth context):
   - pkg/auth_utils/models.go (AuthClaim struct)
   - pkg/auth_utils/token.go (GenerateToken, ValidateToken)
   - pkg/auth_utils/auth.go (GetAuthClaim, WithAuthClaim)

**⚠️ STRICT RULE: If ANY dependency is missing → AI Agent CANNOT proceed with app/ coding**

### Verification Flow:
```text
AI Agent: Let me verify all dependencies first...

Step 1: Check go.mod...
Step 2: Check main.go...
Step 3: Check database/database.go...
Step 4: Check pkg/paginate_utils/...
Step 5: Check app/repository/common/...
Step 6: Check database/ folder...
Step 7: Check pkg/gin_utils/message.go...
Step 8: Check pkg/http_middleware/http.go...
Step 9: Check pkg/auth_utils/ (models.go, token.go, auth.go)...

Result: ✅ All dependencies verified → Can start app/ coding
Result: ❌ Missing dependencies → Cannot start app/ coding
```

### 1. Required Go Modules
Check if these dependencies are available in `go.mod`:

```bash
# Check with: go mod tidy && go mod download
github.com/gin-gonic/gin          # HTTP Framework
github.com/google/uuid            # UUID Generation
gorm.io/gorm                      # ORM
gorm.io/driver/postgres           # PostgreSQL Driver (or other DB driver)
github.com/swaggo/gin-swagger     # Swagger Documentation
github.com/swaggo/swag            # Swagger Generator
```

**If any dependency is missing, ASK USER to add:**
```bash
go get github.com/gin-gonic/gin
go get github.com/google/uuid
go get gorm.io/gorm
go get gorm.io/driver/postgres
go get github.com/swaggo/gin-swagger
go get github.com/swaggo/swag
```

### 2. Required Project Structure - STRICT VERIFICATION

**🛑 AI Agents MUST verify ALL these exist BEFORE ANY app/ coding:**

```
<PROJECT_ROOT>/
├── go.mod                        # ❌ CANNOT CODING WITHOUT THIS
├── main.go                       # ❌ CANNOT CODING WITHOUT THIS
├── database/
│   ├── database.go               # ❌ CANNOT CODING WITHOUT THIS (DB connection)
│   └── schemas/                  # ❌ CANNOT CODING WITHOUT THIS (GORM models)
│       ├── account.go            # Example GORM model
│       ├── cart.go               # Example GORM model
│       └── shop.go               # Example GORM model
├── pkg/
│   └── paginate_utils/           # ❌ CANNOT CODING WITHOUT THIS
│       ├── models.go             # ❌ CANNOT CODING WITHOUT THIS
│       ├── function.go           # ❌ CANNOT CODING WITHOUT THIS
│       └── gorm.go               # ❌ CANNOT CODING WITHOUT THIS
│   └── gin_utils/                # ❌ CANNOT CODING WITHOUT THIS
│       └── message.go            # ❌ CANNOT CODING WITHOUT THIS
├── app/
│   └── repository/
│       └── common/               # ❌ CANNOT CODING WITHOUT THIS
│           ├── query_helpers.go  # ❌ CANNOT CODING WITHOUT THIS
│           └── error_helpers.go  # ❌ CANNOT CODING WITHOUT THIS
```

**AI Agent Verification Commands:**
```bash
# MUST run these checks BEFORE creating any app/ code:
test -f go.mod || echo "❌ MISSING: go.mod"
test -f main.go || echo "❌ MISSING: main.go"
test -f database/database.go || echo "❌ MISSING: database/database.go"
test -d database/schemas || echo "❌ MISSING: database/schemas/ folder (GORM models)"
test -f pkg/paginate_utils/models.go || echo "❌ MISSING: pkg/paginate_utils/models.go"
test -f pkg/paginate_utils/function.go || echo "❌ MISSING: pkg/paginate_utils/function.go"
test -f pkg/paginate_utils/gorm.go || echo "❌ MISSING: pkg/paginate_utils/gorm.go"
test -f pkg/gin_utils/message.go || echo "❌ MISSING: pkg/gin_utils/message.go (CRITICAL)"
test -f app/repository/common/query_helpers.go || echo "❌ MISSING: app/repository/common/query_helpers.go"
test -f app/repository/common/error_helpers.go || echo "❌ MISSING: app/repository/common/error_helpers.go"
test -d database/ || echo "❌ MISSING: database/ folder"
```

**If ANY of these are MISSING, ask USER for confirmation first, then create AUTOMATICALLY:**

**🛑 CRITICAL: AI AGENT CANNOT PROCEED WITHOUT THESE DEPENDENCIES**

**Rule #2: Missing Dependencies = STOP CODING**

**IF ANY of these are MISSING → AI Agent MUST STOP creating app/ code:**

```text
❌ BLOCKER: Missing dependencies detected!
🚫 HALT: Cannot create ANY app/ folder code
📋 REQUIRED: All prerequisites must exist first

Missing items that block app/ coding:
- go.mod (❌ CANNOT CODING WITHOUT THIS)
- main.go (❌ CANNOT CODING WITHOUT THIS)
- database/database.go (❌ CANNOT CODING WITHOUT THIS - DB connection)
- database/schemas/ folder (❌ CANNOT CODING WITHOUT THIS - GORM models)
- pkg/paginate_utils/ (❌ CANNOT CODING WITHOUT THIS)
- pkg/gin_utils/message.go (❌ CANNOT CODING WITHOUT THIS - CRITICAL)
- app/repository/common/ (❌ CANNOT CODING WITHOUT THIS)
```

**⚠️ AI AGENT CONFIRMATION RULE:**
1. **🛑 DETECT missing dependencies → IMMEDIATELY STOP app/ coding**
2. **❓ ASK user for confirmation to create missing items**
3. **✅ IF user confirms → Create ALL missing dependencies AUTOMATICALLY**
4. **❌ IF user declines → STOP completely, wait for manual creation**
5. **🔄 ONLY after ALL dependencies exist → Can start app/ coding**

### Example AI Agent Flow:
```text
AI Agent: 🛑 STOP! I need to verify ALL dependencies before ANY app/ coding...

Step 1: Checking go.mod... ❌ MISSING
Step 2: Checking main.go... ❌ MISSING
Step 3: Checking database/database.go... ❌ MISSING
Step 4: Checking pkg/paginate_utils/... ❌ MISSING
Step 5: Checking app/repository/common/... ❌ MISSING
Step 6: Checking database/... ❌ MISSING

🚫 CRITICAL BLOCKER: ALL dependencies are missing!
❌ Cannot proceed with app/ folder coding
❌ Cannot create controllers, use cases, or repositories
❌ Must resolve ALL dependencies first

I can create ALL missing dependencies automatically with the correct code.

Do you want me to create ALL prerequisites now?
[✅ Yes, create ALL dependencies automatically]
[❌ No, I'll create them manually first]

User: [✅ Yes, create ALL dependencies automatically]

AI Agent:
✅ Creating ALL prerequisites now...

[Creating go.mod]
[Creating main.go]
[Creating database/database.go]
[Creating pkg/paginate_utils/models.go]
[Creating pkg/paginate_utils/function.go]
[Creating pkg/paginate_utils/gorm.go]
[Creating app/repository/common/query_helpers.go]
[Creating app/repository/common/error_helpers.go]
[Creating database/ folder]

✅ ALL dependencies created successfully!
✅ Verification passed: All 9 items now exist
🚀 READY: Now I can create your app/ folder code

User: [❌ No, I'll create them manually first]

AI Agent:
🛑 UNDERSTOOD: Waiting for manual dependency creation...
❌ I will NOT create any app/ folder code
❌ I will NOT proceed with domain implementation
✅ Please create all dependencies, then I'll be ready to help
```

### AI Agent Final Verification Rule:
```text
BEFORE creating ANY app/ code, ALWAYS run:

if [ ! -f "go.mod" ] || [ ! -f "main.go" ] || [ ! -f "database/database.go" ] || \
   [ ! -f "pkg/paginate_utils/models.go" ] || [ ! -f "pkg/paginate_utils/function.go" ] || \
   [ ! -f "pkg/paginate_utils/gorm.go" ] || [ ! -f "pkg/gin_utils/message.go" ] || \
   [ ! -f "app/repository/common/query_helpers.go" ] || [ ! -f "app/repository/common/error_helpers.go" ]; then
    echo "🛑 CANNOT PROCEED: Missing dependencies"
    echo "❌ Please resolve all prerequisites first"
    echo "❌ CRITICAL: pkg/gin_utils/message.go is required for error responses"
    exit 1
else
    echo "✅ All dependencies verified"
    echo "🚀 Ready to create app/ folder code"
fi
```

**🚫 IRONCLAD RULE: AI agents MUST NOT create app/ folder until ALL 9 prerequisites exist!**

---

## ⚖️ Minimal Feature Implementation Rule

### Rule #7: SMALLEST Possible Implementation

**🎯 AI Agents MUST implement the MINIMAL version of user requests:**

#### What "MINIMAL" Means:
- **Basic CRUD only** - No fancy features unless explicitly requested
- **Simple validation** - Only essential validation, not comprehensive
- **Basic fields only** - Minimum required fields, no optional extras
- **Direct relationships** - No complex nested structures unless asked
- **Standard HTTP responses** - No custom response formats
- **Essential middleware** - Only necessary authentication/validation

#### Implementation Priority:
1. **Core functionality first** - The main thing user asked for
2. **Basic validation** - Only what prevents crashes
3. **Simple error handling** - Standard error responses
4. **Essential endpoints** - Minimum required endpoints
5. **Basic pagination** - Only if returning lists

#### What AVOID in Minimal Implementation:
❌ **OVER-ENGINEERING:**
- Complex caching mechanisms
- Advanced search/filtering
- Multiple response formats
- Extensive logging/metrics
- Complex business logic
- Custom middleware
- Fancy validations
- Relationship optimizations
- Batch operations
- Advanced features user didn't ask for

### Example: User Request vs Minimal Implementation

#### User Request: "I want user management"
**❌ OVER-ENGINEERED (AVOID):**
- User roles & permissions system
- Email verification workflow
- Password reset with tokens
- User profile with social links
- Activity logging
- Advanced user search
- Bulk user operations
- User analytics dashboard

**✅ MINIMAL IMPLEMENTATION (DO THIS):**
- Basic CRUD: Create, Read, Update, Delete users
- Simple fields: ID, Name, Email, Password, CreatedAt, UpdatedAt
- Basic validation: Required fields, email format
- Standard endpoints: GET, POST, PUT, DELETE
- Simple pagination for list endpoint

#### User Request: "I want product catalog"
**❌ OVER-ENGINEERED (AVOID):**
- Product categories with unlimited nesting
- Product variants with complex pricing
- Inventory management system
- Product reviews and ratings
- Product recommendation engine
- Advanced search with filters
- Product analytics
- Bulk import/export

**✅ MINIMAL IMPLEMENTATION (DO THIS):**
- Basic CRUD: Create, Read, Update, Delete products
- Simple fields: ID, Name, Description, Price, CreatedAt, UpdatedAt
- Basic validation: Required fields, positive price
- Standard endpoints: GET, POST, PUT, DELETE
- Simple pagination for list endpoint

### AI Agent Minimal Implementation Checklist:

#### Before Adding Features, Ask:
```text
🤔 Did user EXPLICITLY ask for this?
❌ If NO → DON'T add it
✅ If YES → Is there a SIMPLER way?
```

#### Minimal Implementation Flow:
1. **Identify core request** - What does user ACTUALLY want?
2. **Strip to basics** - Remove all "nice-to-have" features
3. **Standard patterns** - Use existing patterns without modifications
4. **Essential fields only** - Minimum fields required for functionality
5. **Basic validation** - Only prevent crashes, not comprehensive validation
6. **Standard responses** - Use existing response patterns

#### If User Wants More:
```text
AI Agent: I've implemented the basic version with core functionality.
This includes:
✅ Basic CRUD operations
✅ Essential fields and validation
✅ Standard API endpoints

Would you like me to add any specific features?
[📋 Add advanced search]
[🔒 Add authentication]
[📊 Add analytics]
[⚙️ Add configuration options]
```

### 3. Required Configuration Files
Check if these files exist:

```
<PROJECT_ROOT>/
├── main.go                       # ⚠️ MUST have basic server setup
├── go.mod                        # ⚠️ MUST have correct module name
├── config/                       # ⚠️ Recommended for DB config
│   └── database.go
└── docs/                         # ⚠️ Recommended for Swagger
    └── docs.go
```

### 4. Stop-and-Wait Verification
**AI Agents MUST STOP and WAIT for user confirmation before proceeding:**

```text
🛑 STOP! I need to verify project dependencies:

[✅] Go modules installed
[❓] pkg/paginate_utils exists manually?
[❓] app/repository/common exists manually?
[❓] database/database.go created manually?
[❓] main.go created manually?
[❓] database/ folder exists?
[❓] go.mod has correct module name?

Please confirm:
1. Have you MANUALLY created all the prerequisite files?
2. Is this a new project or existing project?
3. What's the Go module name (e.g., github.com/org/project)?
4. Which database driver are you using?

⚠️ IMPORTANT: I cannot proceed until ALL prerequisites are created MANUALLY by you.

If any required files/directories are missing, please create them manually using:
- Commands I provide
- Code templates from Appendices A, B, and C
```

### Example AI Agent Conversation for Missing Prerequisites:
```text
User: "Create products domain"

AI Agent:
🛑 STOP! Let me check prerequisites first...

Checking prerequisites:
❌ pkg/paginate_utils/ - MISSING
❌ database/database.go - MISSING
❌ main.go - MISSING
❌ app/repository/common/ - MISSING

❌ CRITICAL: Several prerequisites are missing!

Please create these files MANUALLY first:

1️⃣ Create directories:
   mkdir -p pkg/paginate_utils
   mkdir -p pkg/gin_utils
   mkdir -p app/repository/common
   mkdir -p database
   mkdir -p database/schemas

2️⃣ Create files:
   touch main.go
   touch database/database.go
   touch database/schemas/{account.go,cart.go,shop.go}
   touch pkg/paginate_utils/{models.go,function.go,gorm.go}
   touch pkg/gin_utils/message.go
   touch app/repository/common/query_helpers.go
   touch app/repository/common/error_helpers.go

3️⃣ Copy code from appendices:
   - Appendix A: Complete paginate_utils code (3 files)
   - Appendix B: Repository common helpers (2 files)
   - Appendix D: gin_utils MessageResponse (1 file - CRITICAL)
   - Appendix E: database schemas (examples for reference)
   - Appendix C: main.go and config templates

### Step 1: Ask User for Domain Information
```

## 📁 Creating App Folders - Step-by-Step Instructions

### Before Creating App Folders:
1. ✅ **Complete the Pre-Coding Checklist** (see above)
2. ✅ **Verify all dependencies exist**
3. ✅ **Confirm project name with user**

### 🚨 CRITICAL PREREQUISITES - Must Exist BEFORE Creating app/:

**These files/directories MUST exist before app/ folder can be created:**

```
<PROJECT_ROOT>/
├── go.mod                        # ✅ MUST exist (Go module initialized)
├── main.go                       # ✅ MUST exist (basic server setup)
├── config/
│   └── database.go               # ✅ MUST exist (database configuration)
├── pkg/
│   ├── http_middleware/          # ✅ MUST exist (authentication middleware)
│   │   └── http.go               # JWTAuthentication, CORS, ElasticAPM
│   ├── auth_utils/               # ✅ MUST exist (JWT and auth context)
│   │   ├── models.go             # AuthClaim struct
│   │   ├── token.go              # GenerateToken, ValidateToken
│   │   └── auth.go               # GetAuthClaim, WithAuthClaim
│   ├── gin_utils/                # ✅ MUST exist (error responses)
│   │   └── message.go            # MessageResponse struct
│   └── paginate_utils/           # ✅ MUST exist (pagination dependency)
│       ├── models.go
│       ├── function.go
│       └── gorm.go
├── app/repository/
│   └── common/                   # ✅ MUST exist (helper functions)
│       ├── query_helpers.go
│       └── error_helpers.go
└── database/                     # ⚠️ For existing projects (migration files)
```

**If ANY of these are missing, AI agents MUST ask for confirmation first:**

```text
🛑 STOP! Critical prerequisites missing:

❌ go.mod exists?
❌ main.go exists?
❌ database/database.go exists?
❌ pkg/paginate_utils/ exists?
❌ app/repository/common/ exists?
❌ pkg/http_middleware/http.go exists?
❌ pkg/auth_utils/ (models.go, token.go, auth.go) exists?
❌ pkg/gin_utils/message.go exists?
❌ database/ exists? (if existing project)

⚠️ SECURITY CRITICAL: pkg/http_middleware/ and pkg/auth_utils/ MUST be created manually by user.
I CANNOT create authentication and security-related files automatically.

Missing Files Status:
- pkg/http_middleware/http.go: ❌ USER MUST CREATE MANUALLY
- pkg/auth_utils/: ❌ USER MUST CREATE MANUALLY
- Other dependencies: I can create automatically

Create options:
[✅ Yes, create non-security dependencies automatically]
[❌ No, I'll create everything manually]

[If user confirms ✅]:
Creating non-security prerequisites automatically...
⚠️ SKIPPING: pkg/http_middleware/ (USER MUST CREATE)
⚠️ SKIPPING: pkg/auth_utils/ (USER MUST CREATE)
✅ Running: go mod init <project-name>
✅ Created database/database.go with DB configuration
✅ Created pkg/paginate_utils/ with pagination helpers
✅ Created app/repository/common/ with query & error helpers
✅ Created pkg/gin_utils/message.go with error response
✅ Created main.go with basic server setup
❌ SECURITY DEPENDENCIES MISSING: Cannot proceed with app/ folder
Please create pkg/http_middleware/ and pkg/auth_utils/ manually first.

[If user selects ❌]:
I cannot create app/ folder until all prerequisites are set up.
Please create ALL dependencies manually, especially:
- pkg/http_middleware/http.go (SECURITY CRITICAL)
- pkg/auth_utils/ models.go, token.go, auth.go (SECURITY CRITICAL)
```

### Step 1: Ask User for Domain Information
```text
🤔 I need some information to create your app structure:

1. What domain do you want to create? (e.g., users, products, orders)
2. What features do you need? (CRUD: Create, Read, Update, Delete)
3. Any specific business logic requirements?

Example:
- Domain: "users"
- Features: ["Create user", "Get user by ID", "List users", "Update user", "Delete user"]
```

### Step 2: Create Domain Directory Structure
```bash
# Replace [domain] with actual domain name (e.g., users, products)
mkdir -p app/controller/[domain]_controller
mkdir -p app/use_case/[domain]_use_case
mkdir -p app/repository/[domain]_repository

# Verify structure
tree app/
# Should show:
# app/
# ├── controller/
# │   └── [domain]_controller/
# ├── use_case/
# │   └── [domain]_use_case/
# └── repository/
#     └── [domain]_repository/
```

### Step 3: Create All Files for Domain
Follow the blueprint below to create files in the correct order:

```bash
# Controller layer files
touch app/controller/[domain]_controller/{models.go,interfaces.go,controller.go}

# Use case layer files
touch app/use_case/[domain]_use_case/{models.go,interfaces.go,use_case.go}

# Repository layer files
touch app/repository/[domain]_repository/{models.go,filters.go,interfaces.go,repository.go}
```

### Step 4: Verify Complete Structure
```bash
# Check all files exist
ls -la app/controller/[domain]_controller/
ls -la app/use_case/[domain]_use_case/
ls -la app/repository/[domain]_repository/

# Should show 3 files in each directory
```

### Step 5: Generate Code (Following This Documentation)
1. Start with **Repository Models** (`app/repository/[domain]_repository/models.go`)
2. Create **Repository Filters** (`app/repository/[domain]_repository/filters.go`)
3. Define **Repository Interface** (`app/repository/[domain]_repository/interfaces.go`)
4. Implement **Repository** (`app/repository/[domain]_repository/repository.go`)
5. Create **Use Case Models** (`app/use_case/[domain]_use_case/models.go`)
6. Define **Use Case Interface** (`app/use_case/[domain]_use_case/interfaces.go`)
7. Implement **Use Case** (`app/use_case/[domain]_use_case/use_case.go`)
8. Create **Controller Models** (`app/controller/[domain]_controller/models.go`)
9. Define **Controller Interface** (`app/controller/[domain]_controller/interfaces.go`)
10. Implement **Controller** (`app/controller/[domain]_controller/controller.go`)

### Quick Template Generator
For standard CRUD domains, use this template:

```bash
DOMAIN="<your-domain-name>"

# Create directory structure
mkdir -p app/controller/${DOMAIN}_controller
mkdir -p app/use_case/${DOMAIN}_use_case
mkdir -p app/repository/${DOMAIN}_repository

# Create empty files
touch app/controller/${DOMAIN}_controller/{models.go,interfaces.go,controller.go}
touch app/use_case/${DOMAIN}_use_case/{models.go,interfaces.go,use_case.go}
touch app/repository/${DOMAIN}_repository/{models.go,filters.go,interfaces.go,repository.go}

echo "✅ Created ${DOMAIN} domain folder structure"
echo "📝 Ready to generate code following the blueprint"

# Verify structure
tree app/
```

---

## Overview

The `app/` package implements Clean Architecture with strict layer separation. AI agents MUST follow these principles when generating code.

---

# Controller Layer Blueprint

## 🎯 Purpose
Handle HTTP requests, validation, and response transformation. Controller is the **ONLY** layer that knows about HTTP.

## 🔧 Controller Validation with map_validator

**🛑 RULE: Use `map_validator.ValidateJSON[T]` instead of `c.ShouldBindJSON` for ALL request validation.**

Preferred style is the one-liner `ValidateJSON[T]` generic entry point with short constructors and chain helpers (v0.0.41+). Legacy struct literals and the 5-step pipeline are escape hatches, not defaults — see `MAP_VALIDATOR_GUIDE.md` for when they apply.

### Rules as package-level `var`

Rules are safe for concurrent shared use since v0.0.41. Declare them once per domain in `app/controller/<domain>_controller/rules.go`:

```go
package user_controller

import "github.com/Rhyanz46/go-map-validator/map_validator"

var CreateUserRules = map_validator.BuildRoles().
    SetRule("email",    map_validator.Email().WithMax(255)).
    SetRule("password", map_validator.Str().Between(8, 64)).
    SetRule("role",     map_validator.StrEnum("admin", "staff", "guest").
        Nullable().Default("staff")).
    Done()
```

### Validate + bind in the handler

```go
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

**Security MUSTs (non-negotiable):**
- Every string field has `.WithMax(n)` (DoS protection).
- Every external ID uses `UUID()`.
- Every limited-value field uses `StrEnum()` / `IntEnum()`.
- No DB / API / cross-system checks inside rules — business logic lives in the use case.

**📋 For the full reference (short constructors, chain helpers, nested objects, custom messages, manipulators, 5-step pipeline, anti-patterns, testing checklist), see `MAP_VALIDATOR_GUIDE.md`.**

## ⚖️ Minimal Controller Implementation

**🛑 RULE: Implement ONLY the endpoints user EXPLICITLY requested:**

### Basic CRUD Template (Minimal):
```go
// MINIMAL: Only these 4 endpoints unless user asks for more
GET    /api/[domain]        → List (with pagination)
GET    /api/[domain]/:id    → Get by ID
POST   /api/[domain]        → Create (with map_validator)
PUT    /api/[domain]/:id    → Update (with map_validator)
DELETE /api/[domain]/:id    → Delete
```

### What AVOID in Controllers:
❌ **OVER-ENGINEERING:**
- Multiple endpoint variations (e.g., /api/users/profile, /api/users/me)
- Advanced search endpoints
- Bulk operation endpoints
- Custom response formats
- ShouldBindJSON validation - **USE map_validator INSTEAD**
- Complex parameter validation
- Middleware chaining
- Advanced Swagger documentation

### What IMPLEMENT (Minimal):
✅ **ESSENTIALS ONLY:**
- Basic 4 CRUD endpoints
- map_validator for ALL request validation
- Simple field validation (required, max length, regex)
- Standard JSON responses with gin_utils.MessageResponse
- Basic error handling
- Essential Swagger annotations
- TrimValidation for string fields

## 📁 File Organization (REQUIRED)
```
app/controller/[domain]_controller/
├── models.go      # HTTP request/response models
├── interfaces.go  # Controller interface
└── controller.go  # Implementation
```

## 🔥 Model Separation Rule for Controller Layer

**🚨 CRITICAL**: Controller layer MUST create its own DTOs - NEVER use use case, repository, or database models!

**What Controller Layer CAN use:**
- Use case response models (through use case interface)
- Controller-specific request/response DTOs
- HTTP-specific constructs (gin.Context, http.Status*)

**What Controller Layer CANNOT use:**
- ❌ Repository domain models
- ❌ Database schema models
- ❌ Use case internal models
- ❌ Direct GORM models

## 📝 Models (`models.go`)
ALWAYS create 3 types of models:

### 1. Request Models (for parsing HTTP input)
```go
// MUST use json tags for API
// Use binding tags ONLY for Swagger documentation
// Actual validation is done with map_validator
type CreateUserRequest struct {
    Email     string `json:"email" binding:"required,email"`
    Password  string `json:"password" binding:"required,min=8"`
    FirstName string `json:"first_name" binding:"required"`
    LastName  string `json:"last_name" binding:"required"`
}

// For query parameters
type ListUsersQuery struct {
    Search *string `form:"search"`
    Status *string `form:"status"`
    Page   int     `form:"page,default=1"`
    Limit  int     `form:"limit,default=10"`
}
```

### 2. Response Models (for API output)
```go
// MUST use json tags
type CreateUserResponse struct {
    ID    uuid.UUID `json:"id"`
    Email string    `json:"email"`
}

type ListUsersResponse struct {
    Data     []UserResponse `json:"data"`
    Paginate PaginateResponse `json:"paginate"`
}

type PaginateResponse struct {
    Page       int   `json:"page"`
    Limit      int   `json:"limit"`
    Total      int64 `json:"total"`
    TotalPages int   `json:"total_pages"`
}
```

### 3. Error Response Models
```go
type ErrorResponse struct {
    Code    string `json:"code"`
    Message string `json:"message"`
}

type SuccessResponse struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Message string      `json:"message,omitempty"`
}
```

## 🔧 Interface Rules (`interfaces.go`)
```go
// ALWAYS start with domain name
// ALWAYS use context.Context as first parameter
// ALWAYS return (result, int, error) except for GET which returns data
type UserController interface {
    // CRUD operations
    CreateUser(ctx context.Context, req CreateUserRequest) (*CreateUserResponse, int, error)
    GetUser(ctx context.Context, id uuid.UUID) (*UserResponse, int, error)
    UpdateUser(ctx context.Context, id uuid.UUID, req UpdateUserRequest) (*UserResponse, int, error)
    DeleteUser(ctx context.Context, id uuid.UUID) (int, error)

    // List operations
    ListUsers(ctx context.Context, query ListUsersQuery, paginate *paginate_utils.PaginateData) (*ListUsersResponse, int, error)
}

// Dependencies injection
type ControllerDependencies struct {
    UserUseCase user_use_case.UserUseCase
    // Add other dependencies here
}
```

## 🚀 Implementation Rules (`controller.go`)
```go
// ALWAYS follow this pattern:
// 1. Parse/Validate input
// 2. Transform to use case request
// 3. Call use case
// 4. Transform to HTTP response
// 5. Handle errors properly

package user_controller

import (
    "net/http"
    "reflect"

    "github.com/gin-gonic/gin"
    "<PROJECT_NAME>/pkg/map_validator_utils"
    "<PROJECT_NAME>/pkg/constant"
)

type userController struct {
    userUseCase user_use_case.UserUseCase
}

// Constructor: ALWAYS use New[Domain]Controller
func NewUserController(deps ControllerDependencies) UserController {
    return &userController{
        userUseCase: deps.UserUseCase,
    }
}

// Rules live at package level — safe for concurrent shared use since v0.0.41.
// Conventionally placed in a sibling file: app/controller/user_controller/rules.go
var CreateUserRules = map_validator.BuildRoles().
    SetRule("name",  map_validator.Str().WithMax(255).Regex(constant.RegexExcludeSpecialCharSpace)).
    SetRule("email", map_validator.Email().WithMax(255)).
    SetFieldsManipulator([]string{"name", "email"}, map_validator_utils.TrimValidation).
    Done()

// ALWAYS add Swagger comments
// @Summary Create a new user
// @Description Create a new user with the provided information
// @Tags users
// @Accept json
// @Produce json
// @Param request body CreateUserRequest true "User creation request"
// @Success 201 {object} CreateUserResponse
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users [post]
func (c *userController) CreateUser(ctx *gin.Context) {
    // 1. Validate + bind — ValidateJSON[T] is the preferred one-liner
    req, err := map_validator.ValidateJSON[CreateUserRequest](ctx.Request, CreateUserRules)
    if err != nil {
        ctx.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // 2. Call use case (transform happens inside use case)
    result, statusCode, err := c.userUseCase.CreateUser(ctx.Request.Context(), req)
    if err != nil {
        ctx.JSON(statusCode, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // 3. Return response
    ctx.JSON(statusCode, SuccessResponse{
        Success: true,
        Data:    result,
    })
}
```

## 📋 Controller Cheat Sheet

### ALWAYS Do:
- ✅ Use `map_validator.ValidateJSON[T]` for ALL POST/PUT/PATCH request validation
- ✅ Declare rules as package-level `var` in `app/controller/<domain>_controller/rules.go`
- ✅ Use short constructors: `Str()`, `Int()`, `Email()`, `UUID()`, `StrEnum(...)`, etc.
- ✅ Use chain helpers: `.WithMax`, `.Between`, `.Nullable`, `.Default`, `.Regex`, …
- ✅ `WithMax(n)` on every string field (DoS protection) — non-negotiable
- ✅ `UUID()` for every external ID
- ✅ `StrEnum() / IntEnum()` for every limited-value field
- ✅ Use `ShouldBindQuery()` for GET parameters (map_validator focuses on JSON bodies)
- ✅ Apply `TrimValidation` manipulator for string fields needing whitespace trim
- ✅ Parse UUID path params with error handling
- ✅ Return status codes from use case
- ✅ Add Swagger comments
- ✅ Use dependency injection
- ✅ Use `gin_utils.MessageResponse` for error responses
- ✅ Forward `err.Error()` verbatim — no prefix wrapping

### NEVER Do:
- ❌ Import repository directly
- ❌ Write business logic in controller
- ❌ Skip validation
- ❌ Use `ShouldBindJSON()` — **USE `map_validator.ValidateJSON[T]` INSTEAD**
- ❌ Build rules inside the handler body — rules must be package-level `var`
- ❌ Reach for the 5-step pipeline (`NewValidateBuilder().SetRules(...).LoadJsonHttp(...)`) unless you truly need pre-bind introspection via `GetFilledField()` / `GetNullField()` / `GetData()`
- ❌ Use struct literals `Rules{Type: reflect.String, Max: SetTotal(255)}` when a short constructor fits
- ❌ Wrap error messages with prefixes like `"validation: "`
- ❌ Put DB lookups, API calls, or cross-system checks inside rules

### map_validator Reference:
- **Detailed guide**: See `MAP_VALIDATOR_GUIDE.md` (preferred style, short constructors, chain helpers, canonical handler template, anti-patterns, testing checklist)
- **Field types**: `Str`, `Int`, `Int64`, `Float64`, `Bool`, `Email`, `UUID`, `UUIDToString`, `IPv4`, `StrEnum`, `IntEnum`, `NestedObject`, `ListOfObject`
- **Common patterns**: `.WithMax`, `.Between`, `.Regex`, `.Nullable`, `.Default`, `.WithRequiredIf`, `.WithRequiredWithout`, `.UniqueFrom`
- **Error handling**: Always use `gin_utils.MessageResponse`, forward `err.Error()` verbatim
- **Required imports**: `github.com/Rhyanz46/go-map-validator/map_validator`, optional `<project>/pkg/map_validator_utils` for shared manipulators

### Binding Tags Clarification:
- **Swagger / OpenAPI**: `binding:"required,email"` struct tags are used only by the Swagger generator for docs — they do NOT perform runtime validation
- **Runtime validation**: Only `map_validator.ValidateJSON[T]` validates the request body at runtime
- **Don't rely on**: `ShouldBindJSON` or `binding:"..."` for validation — it was the GIN built-in path, not this project's contract

---

# Use Case Layer Blueprint

## ⚖️ Minimal Use Case Implementation

**🛑 RULE: Implement ONLY the business logic user EXPLICITLY requested:**

### Basic Use Case Template (Minimal):
```go
// MINIMAL: Only these 4 methods unless user asks for more
func (uc *DomainUseCase) Create(req CreateRequest) (*Response, int, error)
func (uc *DomainUseCase) GetByID(id string) (*Response, int, error)
func (uc *DomainUseCase) Update(req UpdateRequest) (*Response, int, error)
func (uc *DomainUseCase) Delete(id string) (int, error)
func (uc *DomainUseCase) List(req ListRequest) (*ListResponse, int, error)
```

### What AVOID in Use Cases:
❌ **OVER-ENGINEERING:**
- Complex business rules user didn't ask for
- Advanced validation logic
- Multiple data sources
- Caching mechanisms
- Event publishing
- Workflow orchestration
- Complex transaction management
- Business analytics

### What IMPLEMENT (Minimal):
✅ **ESSENTIALS ONLY:**
- Basic CRUD operations
- Simple validation (required fields, basic format)
- Direct database operations
- Simple error handling
- Essential transformations between layers

#### Request Models (`models.go`)
```go
package account_controller

import (
    "time"
    "github.com/google/uuid"
)

// HTTP Request Models - Controller Layer Specific
type RegisterRequest struct {
    Email     string `json:"email" binding:"required,email"`
    Password  string `json:"password" binding:"required,min=8"`
    FirstName string `json:"first_name" binding:"required"`
    LastName  string `json:"last_name" binding:"required"`
    Phone     string `json:"phone"`
}

type LoginRequest struct {
    Email    string `json:"email" binding:"required,email"`
    Password string `json:"password" binding:"required"`
}

type ListAccountsQuery struct {
    Search        *string    `form:"search"`
    Status        []string   `form:"status"`
    Role          []string   `form:"role"`
    CreatedFrom   *time.Time `form:"created_from"`
    CreatedTo     *time.Time `form:"created_to"`
    City          *string    `form:"city"`
    Country       *string    `form:"country"`
    SortBy        string     `form:"sort_by"`
    SortDirection string     `form:"sort_direction"`
}
```

#### Response Models
```go
// HTTP Response Models - Controller Layer Specific
type RegisterResponse struct {
    ID       uuid.UUID `json:"id"`
    Email    string    `json:"email"`
    FullName string    `json:"full_name"`
}

type LoginResponse struct {
    Token        string      `json:"token"`
    RefreshToken string      `json:"refresh_token"`
    ExpiresAt    time.Time   `json:"expires_at"`
    Account      AccountData `json:"account"`
}

type AccountData struct {
    ID       uuid.UUID `json:"id"`
    Email    string    `json:"email"`
    FullName string    `json:"full_name"`
    Avatar   string    `json:"avatar"`
    Role     string    `json:"role"`
}

type ListAccountsResponse struct {
    Data     []AccountListResponse `json:"data"`
    Paginate PaginateResponse      `json:"paginate"`
}

type AccountListResponse struct {
    ID        uuid.UUID `json:"id"`
    Email     string    `json:"email"`
    FullName  string    `json:"full_name"`
    Phone     string    `json:"phone"`
    Status    string    `json:"status"`
    Role      string    `json:"role"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type PaginateResponse struct {
    Page       int   `json:"page"`
    Limit      int   `json:"limit"`
    Total      int64 `json:"total"`
    TotalPages int   `json:"total_pages"`
}
```

#### Controller Interface
```go
package account_controller

import "github.com/gin-gonic/gin"

// AccountController defines the interface for account HTTP handlers
type AccountController interface {
    Register(ctx *gin.Context)
    Login(ctx *gin.Context)
    GetProfile(ctx *gin.Context)
    UpdateProfile(ctx *gin.Context)
    RequestPasswordReset(ctx *gin.Context)
    ResetPassword(ctx *gin.Context)
    ListAccounts(ctx *gin.Context)
}

// ControllerDependencies defines what the controller needs
type ControllerDependencies struct {
    AccountUseCase account_use_case.AccountUseCase
}
```

#### Controller Implementation Example
```go
package account_controller

import (
    "net/http"
    "strconv"

    "github.com/gin-gonic/gin"
)

type accountController struct {
    accountUseCase account_use_case.AccountUseCase
}

func NewAccountController(deps ControllerDependencies) AccountController {
    return &accountController{
        accountUseCase: deps.AccountUseCase,
    }
}

// ListAccounts godoc
// @Summary List all accounts
// @Description Get paginated list of accounts with filtering options
// @Tags accounts
// @Accept json
// @Produce json
// @Security BearerAuth
// @Param page query int false "Page number" default(1)
// @Param limit query int false "Items per page" default(10)
// @Param search query string false "Search in name, email, phone"
// @Param status query []string false "Filter by status"
// @Param role query []string false "Filter by role"
// @Param created_from query string false "Filter by creation date from"
// @Param created_to query string false "Filter by creation date to"
// @Param city query string false "Filter by city"
// @Param country query string false "Filter by country"
// @Param sort_by query string false "Sort by field"
// @Param sort_direction query string false "Sort direction" default(desc)
// @Success 200 {object} ListAccountsResponse
// @Failure 400 {object} ErrorResponse
// @Failure 401 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /v1/accounts [get]
func (c *accountController) ListAccounts(ctx *gin.Context) {
    // 1. Parse query parameters
    var query ListAccountsQuery
    if err := ctx.ShouldBindQuery(&query); err != nil {
        ctx.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // 2. Parse pagination
    pagination, err := c.parsePagination(ctx)
    if err != nil {
        ctx.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // 3. Transform to use case request
    req := account_use_case.ListAccountsRequest{
        Search:        query.Search,
        Status:        query.Status,
        Role:          query.Role,
        CreatedFrom:   query.CreatedFrom,
        CreatedTo:     query.CreatedTo,
        City:          query.City,
        Country:       query.Country,
        SortBy:        query.SortBy,
        SortDirection: query.SortDirection,
    }

    // 4. Call use case
    result, statusCode, err := c.accountUseCase.ListAccounts(ctx.Request.Context(), req, pagination)
    if err != nil {
        ctx.JSON(statusCode, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // 5. Transform to HTTP response
    response := ListAccountsResponse{
        Data: make([]AccountListResponse, len(result.Accounts)),
        Paginate: PaginateResponse{
            Page:       result.Page,
            Limit:      result.Limit,
            Total:      result.Total,
            TotalPages: result.TotalPages,
        },
    }

    // Transform accounts
    for i, acc := range result.Accounts {
        response.Data[i] = AccountListResponse{
            ID:        acc.ID,
            Email:     acc.Email,
            FullName:  acc.FullName,
            Phone:     acc.Phone,
            Status:    acc.Status,
            Role:      acc.Role,
            CreatedAt: acc.CreatedAt,
            UpdatedAt: acc.UpdatedAt,
        }
    }

    ctx.JSON(http.StatusOK, SuccessResponse{
        Success: true,
        Data:    response,
    })
}

// Helper functions
func (c *accountController) parsePagination(ctx *gin.Context) (*paginate_utils.PaginateData, error) {
    // Get page parameter with default
    pageStr := ctx.DefaultQuery("page", "1")
    page, err := strconv.Atoi(pageStr)
    if err != nil || page < 1 {
        page = 1
    }

    // Get limit parameter with default
    limitStr := ctx.DefaultQuery("limit", "10")
    limit, err := strconv.Atoi(limitStr)
    if err != nil || limit < 1 || limit > 100 {
        limit = 10
    }

    return &paginate_utils.PaginateData{
        Page:  page,
        Limit: limit,
    }, nil
}
```

## 2. Use Case Layer

**Purpose**: Implement application business rules and orchestrate workflows

**Responsibilities**:
- Implement business rules
- Orchestrate repository calls
- Coordinate external services
- Handle business validation
- Manage transactions
- Perform authorization checks

### 🔥 Model Separation Rule for Use Case Layer

**🚨 CRITICAL**: Use Case layer MUST create its own models - NEVER use repository or database models directly!

**What Use Case Layer CAN use:**
- Repository domain models (from repository interfaces)
- Use Case-specific request/response models
- External service models (if needed)

**What Use Case Layer CANNOT use:**
- ❌ Database schema models (`database/schemas/*`)
- ❌ Direct GORM models
- ❌ Repository implementation details

### Use Case Models

#### Request Models (`models.go`)
```go
package account_use_case

import (
    "time"
)

// Request Models - Use Case Layer Specific
type RegisterRequest struct {
    Email     string
    Password  string
    FirstName string
    LastName  string
    Phone     string
    Bio       string
    Address   string
    City      string
    Country   string
    PostalCode string
}

type LoginRequest struct {
    Email    string
    Password string
}

type ListAccountsRequest struct {
    Search          *string    `json:"search,omitempty"`
    Status          []string   `json:"status,omitempty"`
    Role            []string   `json:"role,omitempty"`
    CreatedFrom     *time.Time `json:"created_from,omitempty"`
    CreatedTo       *time.Time `json:"created_to,omitempty"`
    LastLoginFrom   *time.Time `json:"last_login_from,omitempty"`
    LastLoginTo     *time.Time `json:"last_login_to,omitempty"`
    City            *string    `json:"city,omitempty"`
    Country         *string    `json:"country,omitempty"`
    DateOfBirthFrom *time.Time `json:"date_of_birth_from,omitempty"`
    DateOfBirthTo   *time.Time `json:"date_of_birth_to,omitempty"`
    SortBy          string     `json:"sort_by,omitempty"`
    SortDirection   string     `json:"sort_direction,omitempty"`
}
```

#### Response Models
```go
// Response Models - Use Case Layer Specific
type RegisterResponse struct {
    ID       uuid.UUID
    Email    string
    FullName string
}

type LoginResponse struct {
    Token        string
    RefreshToken string
    ExpiresAt    time.Time
    Account      AccountData
}

type AccountData struct {
    ID       uuid.UUID
    Email    string
    FullName string
    Avatar   string
    Role     string
}

type ProfileResponse struct {
    ID          uuid.UUID
    Email       string
    FirstName   string
    LastName    string
    Phone       string
    Avatar      string
    Bio         string
    Address     string
    City        string
    Country     string
    PostalCode  string
    DateOfBirth *time.Time
    CreatedAt   time.Time
    UpdatedAt   time.Time
}

type AccountListResponse struct {
    ID        uuid.UUID `json:"id"`
    Email     string    `json:"email"`
    FirstName string    `json:"first_name"`
    LastName  string    `json:"last_name"`
    FullName  string    `json:"full_name"`
    Phone     string    `json:"phone"`
    Status    string    `json:"status"`
    Role      string    `json:"role"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type ListAccountsResponse struct {
    Accounts  []AccountListResponse `json:"accounts"`
    Total     int64                 `json:"total"`
    Page      int                   `json:"page"`
    Limit     int                   `json:"limit"`
    TotalPages int                   `json:"total_pages"`
}
```

### Use Case Interfaces

```go
package account_use_case

import "context"

// AccountUseCase defines the interface for account business logic
type AccountUseCase interface {
    // Authentication
    Register(ctx context.Context, req RegisterRequest) (*RegisterResponse, int, error)
    Login(ctx context.Context, req LoginRequest) (*LoginResponse, int, error)

    // Profile Management
    GetProfile(ctx context.Context) (*ProfileResponse, int, error)
    UpdateProfile(ctx context.Context, req UpdateProfileRequest) (*ProfileResponse, int, error)

    // Account Management - Menggunakan filter pattern
    GetAccount(ctx context.Context, id uuid.UUID) (*AccountResponse, int, error)
    UpdateAccount(ctx context.Context, id uuid.UUID, req UpdateAccountRequest) (*AccountResponse, int, error)
    ListAccounts(ctx context.Context, req ListAccountsRequest, paginate *paginate_utils.PaginateData) (*ListAccountsResponse, int, error)

    // Password Management - Fungsi terpisah karena logic berbeda
    RequestPasswordReset(ctx context.Context, req PasswordResetRequest) (int, error)
    ResetPassword(ctx context.Context, req ResetPasswordRequest) (int, error)
}

// UseCaseDependencies defines what the use case needs
type UseCaseDependencies struct {
    AccountRepo     account_repository.AccountRepository
    EmailService    email_service.EmailService
    TokenService    TokenService
    PasswordService PasswordService
}

// Supporting interfaces
type TokenService interface {
    GenerateAccessToken(userID uuid.UUID) (string, error)
    GenerateRefreshToken() (string, error)
    ValidateToken(token string) (*TokenClaims, error)
}

type PasswordService interface {
    HashPassword(password string) (string, error)
    VerifyPassword(hashedPassword, password string) error
    GenerateResetToken() (string, error)
}
```

### Use Case Implementation Example

```go
package account_use_case

import (
    "context"
    "errors"
    "fmt"
    "math"
    "time"

    "<PROJECT_NAME>/pkg/paginate_utils"
    "github.com/google/uuid"
)

type accountUseCase struct {
    accountRepo     account_repository.AccountRepository
    emailService    email_service.EmailService
    tokenService    TokenService
    passwordService PasswordService
}

func NewAccountUseCase(deps UseCaseDependencies) AccountUseCase {
    return &accountUseCase{
        accountRepo:     deps.AccountRepo,
        emailService:    deps.EmailService,
        tokenService:    deps.TokenService,
        passwordService: deps.PasswordService,
    }
}

func (u *accountUseCase) GetAccount(ctx context.Context, id uuid.UUID) (*AccountResponse, int, error) {
    // Get account by ID using filter
    account, statusCode, err := u.accountRepo.GetOne(ctx, account_repository.AccountFilter{
        Id: &id,
    })
    if err != nil {
        return nil, statusCode, fmt.Errorf("failed to get account: %w", err)
    }

    // Transform to response
    return &AccountResponse{
        ID:        account.ID,
        Email:     account.Email,
        FirstName: account.FirstName,
        LastName:  account.LastName,
        Status:    string(account.Status),
    }, http.StatusOK, nil
}

func (u *accountUseCase) UpdateAccount(ctx context.Context, id uuid.UUID, req UpdateAccountRequest) (*AccountResponse, int, error) {
    // Validate request
    if err := req.Validate(); err != nil {
        return nil, http.StatusBadRequest, fmt.Errorf("validation failed: %w", err)
    }

    // Update account using filter
    account, statusCode, err := u.accountRepo.Update(ctx,
        account_repository.AccountFilter{
            Id: &id,
        },
        account_repository.UpdateAccountRequest{
            FirstName: req.FirstName,
            LastName:  req.LastName,
            Phone:     req.Phone,
        },
    )
    if err != nil {
        return nil, statusCode, fmt.Errorf("failed to update account: %w", err)
    }

    // Transform to response
    return &AccountResponse{
        ID:        account.ID,
        Email:     account.Email,
        FirstName: account.FirstName,
        LastName:  account.LastName,
        Status:    string(account.Status),
    }, http.StatusOK, nil
}

func (u *accountUseCase) ListAccounts(ctx context.Context, req ListAccountsRequest, paginate *paginate_utils.PaginateData) (*ListAccountsResponse, int, error) {
    // 1. Transform use case filter to repository filter
    repoFilter := u.transformToRepoFilter(req)

    // 2. Get accounts from repository
    items, statusCode, err := u.accountRepo.List(ctx, repoFilter, paginate)
    if err != nil {
        return nil, statusCode, fmt.Errorf("failed to list accounts: %w", err)
    }

    // 3. Transform to use case response
    accounts := make([]AccountListResponse, len(items))
    for i, item := range items {
        accounts[i] = AccountListResponse{
            ID:        item.ID,
            Email:     item.Email,
            FirstName: item.FirstName,
            LastName:  item.LastName,
            FullName:  fmt.Sprintf("%s %s", item.FirstName, item.LastName),
            Phone:     item.Phone,
            Status:    item.Status,
            Role:      item.Role,
            CreatedAt: item.CreatedAt,
            UpdatedAt: item.UpdatedAt,
        }
    }

    // 4. Get total count for pagination
    total, statusCode, err := u.accountRepo.Count(ctx, repoFilter)
    if err != nil {
        return nil, statusCode, fmt.Errorf("failed to count accounts: %w", err)
    }

    // 5. Calculate total pages
    totalPages := int(math.Ceil(float64(total) / float64(paginate.Limit)))
    if totalPages == 0 {
        totalPages = 1
    }

    return &ListAccountsResponse{
        Accounts:  accounts,
        Total:     total,
        Page:      paginate.Page,
        Limit:     paginate.Limit,
        TotalPages: totalPages,
    }, http.StatusOK, nil
}

// transformToRepoFilter transforms use case request to repository filter
func (u *accountUseCase) transformToRepoFilter(req ListAccountsRequest) account_repository.AccountFilter {
    filter := account_repository.AccountFilter{
        Search:    req.Search,
        City:      req.City,
        Country:   req.Country,
    }

    // Transform status list
    if len(req.Status) > 0 {
        statusList := make([]account_repository.AccountStatus, len(req.Status))
        for i, status := range req.Status {
            statusList[i] = account_repository.AccountStatus(status)
        }
        filter.StatusList = statusList
    }

    // Transform role list
    if len(req.Role) > 0 {
        roleList := make([]account_repository.UserRole, len(req.Role))
        for i, role := range req.Role {
            roleList[i] = account_repository.UserRole(role)
        }
        filter.RoleList = roleList
    }

    // Set date ranges
    filter.CreatedFrom = req.CreatedFrom
    filter.CreatedTo = req.CreatedTo

    return filter
}

// Business errors
var (
    ErrEmailAlreadyExists = errors.New("email already exists")
    ErrInvalidEmail      = errors.New("invalid email format")
    ErrPasswordTooShort  = errors.New("password must be at least 8 characters")
)
```

### Use Case Helper Models

```go
// Request models untuk update dengan pointer fields (opsional)
type UpdateAccountRequest struct {
    FirstName *string `json:"first_name,omitempty"`
    LastName  *string `json:"last_name,omitempty"`
    Phone     *string `json:"phone,omitempty"`
}

func (u *UpdateAccountRequest) Validate() error {
    // Validasi minimal: setidaknya satu field harus diisi
    if u.FirstName == nil && u.LastName == nil && u.Phone == nil {
        return errors.New("at least one field must be provided")
    }
    return nil
}
```

# Repository Layer Blueprint

## ⚖️ Minimal Repository Implementation

**🛑 RULE: Implement ONLY the data operations user EXPLICITLY requested:**

### Basic Repository Template (Minimal):
```go
// MINIMAL: Only these 5 methods unless user asks for more
func (r *DomainRepository) Create(model *Model) error
func (r *DomainRepository) GetByID(id string) (*Model, error)
func (r *DomainRepository) Update(model *Model) error
func (r *DomainRepository) Delete(id string) error
func (r *DomainRepository) List(filter Filter) ([]*Model, error)
```

### What AVOID in Repositories:
❌ **OVER-ENGINEERING:**
- Complex query optimization
- Advanced filtering user didn't ask for
- Multiple database connections
- Caching layers
- Event sourcing
- Complex transaction management
- Batch operations
- Data migration logic
- Advanced relationship loading

### What IMPLEMENT (Minimal):
✅ **ESSENTIALS ONLY:**
- Basic CRUD operations with GORM
- Simple filter object for search/pagination
- Basic error handling using helpers
- Direct table operations
- Simple relationships (only if needed)
- Standard pagination using paginate_utils

## Repository Layer

**Purpose**: Manage data persistence and retrieval operations

**Responsibilities**:
- Database operations (CRUD)
- Data mapping between layers
- Simple filtering and pagination
- Basic error handling
- Connection handling

### 🔥 CRITICAL: Model Separation Rules

**🚨 NEVER share models between layers! Each layer creates its own models:**

```
Database Layer:      database/schemas/models.go      (GORM models - DB queries only)
         ↓ (internal mapping)
Repository Layer:    app/repository/[domain]_repository/models.go  (Domain models)
         ↓ (expose through interfaces)
Use Case Layer:      app/use_case/[domain]_use_case/models.go       (Use case models)
         ↓ (expose through interfaces)
Controller Layer:    app/controller/[domain]_controller/dto.go      (Request/Response DTOs)
```

**STRICT RULES:**
- Database schema models are ONLY for database queries
- Repository layer creates its OWN domain models - NEVER expose database schemas to use case layer
- Repository maps database schema models → repository domain models internally
- Use case layer ONLY knows about repository domain models - NEVER imports database schemas
- Controller layer creates DTOs - NEVER imports repository or database models

**Why This Matters:**
- Prevents tight coupling between layers
- Allows database changes without breaking business logic
- Each layer has single responsibility
- Clean dependencies and testability

### Repository Models

#### Domain Models (`models.go`)
```go
package account_repository

import (
    "time"
    "gorm.io/gorm"
)

// Domain Models - Repository Layer Specific
type Account struct {
    ID        uuid.UUID      `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    Email     string         `gorm:"uniqueIndex;not null"`
    Password  string         `gorm:"not null"`
    FirstName string         `gorm:"not null"`
    LastName  string         `gorm:"not null"`
    Phone     string
    Status    AccountStatus  `gorm:"not null;default:'active'"`
    Role      AccountRole    `gorm:"not null;default:'user'"`
    LastLogin *time.Time
    CreatedAt time.Time
    UpdatedAt time.Time
    DeletedAt gorm.DeletedAt `gorm:"index"`

    // Relationships
    Profile   UserProfile `gorm:"foreignKey:AccountID"`
    Sessions  []Session   `gorm:"foreignKey:AccountID"`
}

type UserProfile struct {
    ID          uuid.UUID `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    AccountID   uuid.UUID `gorm:"type:uuid;not null"`
    Bio         string
    Address     string
    City        string
    Country     string
    PostalCode  string
    DateOfBirth *time.Time
    Preferences string `gorm:"type:jsonb"`
    CreatedAt   time.Time
    UpdatedAt   time.Time
}

type Session struct {
    ID           uuid.UUID  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    AccountID    uuid.UUID  `gorm:"type:uuid;not null"`
    Token        string     `gorm:"uniqueIndex;not null"`
    RefreshToken string     `gorm:"uniqueIndex;not null"`
    ExpiresAt    time.Time  `gorm:"not null"`
    IsActive     bool       `gorm:"not null;default:true"`
    CreatedAt    time.Time
    LastUsedAt   *time.Time
}

type PasswordReset struct {
    ID        uuid.UUID  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    AccountID uuid.UUID  `gorm:"type:uuid;not null"`
    Token     string     `gorm:"uniqueIndex;not null"`
    ExpiresAt time.Time  `gorm:"not null"`
    Used      bool       `gorm:"not null;default:false"`
    CreatedAt time.Time
}
```

#### Enums and Constants
```go
// Enums
type AccountStatus string
const (
    AccountStatusActive    AccountStatus = "active"
    AccountStatusInactive  AccountStatus = "inactive"
    AccountStatusSuspended AccountStatus = "suspended"
    AccountStatusLocked    AccountStatus = "locked"
)

type UserRole string
const (
    UserRoleUser       UserRole = "user"
    UserRoleAdmin      UserRole = "admin"
    UserRoleSuperAdmin UserRole = "super_admin"
)
```

#### Filter Structures
```go
// Filter Structure
type AccountFilter struct {
    Id                   *uuid.UUID   `json:"id,omitempty"`              // Filter by single ID
    Ids                  []uuid.UUID  `json:"ids,omitempty"`             // Filter by multiple IDs
    Email                *string      `json:"email,omitempty"`           // Filter by exact email
    Search               *string      `json:"search,omitempty"`          // Search in name, email, phone
    StatusList           []AccountStatus `json:"status_list,omitempty"` // Filter by multiple statuses
    RoleList             []UserRole    `json:"role_list,omitempty"`      // Filter by multiple roles
    CreatedFrom          *time.Time    `json:"created_from,omitempty"`   // Filter by creation date (from)
    CreatedTo            *time.Time    `json:"created_to,omitempty"`     // Filter by creation date (to)
    LastLoginFrom        *time.Time    `json:"last_login_from,omitempty"` // Filter by last login (from)
    LastLoginTo          *time.Time    `json:"last_login_to,omitempty"`   // Filter by last login (to)
    City                 *string      `json:"city,omitempty"`            // Filter by city
    Country              *string      `json:"country,omitempty"`         // Filter by country
    DateOfBirthFrom      *time.Time    `json:"date_of_birth_from,omitempty"`
    DateOfBirthTo        *time.Time    `json:"date_of_birth_to,omitempty"`
}
```

#### List Item Model
```go
// List item model for optimized queries
type AccountListItem struct {
    ID        uuid.UUID   `json:"id"`
    Email     string      `json:"email"`
    FirstName string      `json:"first_name"`
    LastName  string      `json:"last_name"`
    Phone     string      `json:"phone"`
    Status    string      `json:"status"`
    Role      string      `json:"role"`
    CreatedAt time.Time   `json:"created_at"`
    UpdatedAt time.Time   `json:"updated_at"`
}
```

### Repository Interfaces

```go
package account_repository

import (
    "context"
    "<PROJECT_NAME>/pkg/paginate_utils"
    "github.com/google/uuid"
)

// AccountRepository defines the interface for account data operations
type AccountRepository interface {
    // Single query operations using filter
    // Filter field yang tidak diisi akan diabaikan (nilai pointer opsional)
    GetOne(ctx context.Context, filter AccountFilter) (*Account, int, error)

    // CRUD Operations
    Create(ctx context.Context, data CreateAccountRequest) (*Account, int, error)
    Update(ctx context.Context, filter AccountFilter, data UpdateAccountRequest) (*Account, int, error)
    Delete(ctx context.Context, filter AccountFilter) (int, error)

    // List Operations with Pagination
    List(ctx context.Context, filter AccountFilter, paginate *paginate_utils.PaginateData) ([]AccountListItem, int, error)
    Count(ctx context.Context, filter AccountFilter) (int64, int, error)
}

// 🚨 STRICT FORBIDDEN METHODS
// ❌ NEVER create these individual methods:
// - GetById(ctx, id) → Use GetOne(ctx, AccountFilter{Id: &id})
// - GetByEmail(ctx, email) → Use GetOne(ctx, AccountFilter{Email: &email})
// - GetByStatus(ctx, status) → Use GetOne(ctx, AccountFilter{Status: &status})
// - GetByPhone(ctx, phone) → Use GetOne(ctx, AccountFilter{Phone: &phone})
// - GetByIdAndStatus(ctx, id, status) → Use GetOne(ctx, AccountFilter{Id: &id, Status: &status})
//
// ✅ ALLOWED: Create NEW method ONLY if return type is DIFFERENT:
// - GetLoginInfo(ctx, email) → (*LoginInfo, int, error) // Different return type
// - GetProfile(ctx, id) → (*Profile, int, error)       // Different return type
// - GetStatistics(ctx, filter) → (*Statistics, int, error) // Different return type
//
// ✅ ALWAYS use single GetOne() method with filter for ALL queries returning SAME model
// ✅ ALWAYS use single List() method with filter for ALL queries returning SAME list model

// Repository Dependencies
type RepositoryDependencies struct {
    DB *gorm.DB
}

// Supporting interfaces for database operations
type DatabaseExecutor interface {
    WithContext(ctx context.Context) *gorm.DB
}
```

### Penjelasan Filter Pattern untuk Repository

#### Mengapa Gunakan Filter Pattern?

1. **Konsistensi**: Semua query menggunakan filter object yang sama, tidak perlu banyak fungsi berbeda
2. **Fleksibilitas**: Bisa kombinasi berbagai kriteria query (by ID, email, status, dll) dalam satu fungsi
3. **Maintainable**: Tambah filter baru cukup di struct filter, tidak perlu tambah fungsi baru
4. **Efficient**: Query builder yang dinamis berdasarkan field yang diisi

#### Contoh Penggunaan Filter:

```go
// Get by ID
account, statusCode, err := repo.GetOne(ctx, AccountFilter{
    Id: &accountID, // Hanya field ini yang digunakan
})

// Get by Email
account, statusCode, err := repo.GetOne(ctx, AccountFilter{
    Email: &email, // Hanya field ini yang digunakan
})

// Get by ID and Status
account, statusCode, err := repo.GetOne(ctx, AccountFilter{
    Id:     &accountID,
    Status: &AccountStatusActive, // Kombinasi filter
})

// Get by multiple criteria
account, statusCode, err := repo.GetOne(ctx, AccountFilter{
    Id:         &accountID,
    Email:      &email,
    StatusList: []AccountStatus{AccountStatusActive, AccountStatusVerified},
})
```

#### When to Create New Methods (Return Type is Different)

```go
// ❌ WRONG: Same return type (*Account) - use Filter Pattern
func (r *accountRepository) GetById(ctx context.Context, id uuid.UUID) (*Account, int, error)
func (r *accountRepository) GetByEmail(ctx context.Context, email string) (*Account, int, error)

// ✅ CORRECT: Different return types - can create separate methods
func (r *accountRepository) GetOne(ctx context.Context, filter AccountFilter) (*Account, int, error)
func (r *accountRepository) GetLoginInfo(ctx context.Context, email string) (*LoginInfo, int, error)     // Different: *LoginInfo
func (r *accountRepository) GetProfile(ctx context.Context, id uuid.UUID) (*Profile, int, error)       // Different: *Profile
func (r *accountRepository) GetStatistics(ctx context.Context, filter AccountFilter) (*Statistics, int, error) // Different: *Statistics

// ✅ CORRECT: Use Filter Pattern for same return types
account, err := repo.GetOne(ctx, AccountFilter{Id: &id})        // Get by ID
account, err := repo.GetOne(ctx, AccountFilter{Email: &email})  // Get by Email - same *Account return
```

### Repository Implementation Example

```go
package account_repository

import (
    "context"
    "errors"
    "time"

    "<PROJECT_NAME>/app/repository/common"
    "<PROJECT_NAME>/pkg/paginate_utils"
    "github.com/google/uuid"
    "gorm.io/gorm"
)

type accountRepository struct {
    db *gorm.DB
}

func NewAccountAccountRepository(deps RepositoryDependencies) AccountRepository {
    return &accountRepository{
        db: deps.DB,
    }
}

// GetOne retrieves a single account based on filter criteria
// Method ini menggantikan GetAccountByID dan GetAccountByEmail
// Gunakan field yang relevan di AccountFilter untuk query
func (r *accountRepository) GetOne(ctx context.Context, filter AccountFilter) (*Account, int, error) {
    db := r.db.WithContext(ctx)

    // Build query dengan filter yang diberikan
    query := applyAccountFilters(db, filter, searchInAllFields)

    var account Account
    if err := query.First(&account).Error; err != nil {
        return nil, handleGORMError(err)
    }

    return &account, http.StatusOK, nil
}

// Create creates a new account
func (r *accountRepository) Create(ctx context.Context, data CreateAccountRequest) (*Account, int, error) {
    db := r.db.WithContext(ctx)

    // Map CreateAccountRequest to Account model
    account := Account{
        Email:     data.Email,
        Password:  data.Password,
        FirstName: data.FirstName,
        LastName:  data.LastName,
        Phone:     data.Phone,
        Status:    AccountStatusActive,
        Role:      UserRoleUser,
    }

    if err := db.Create(&account).Error; err != nil {
        return nil, handleGORMError(err)
    }

    return &account, http.StatusCreated, nil
}

// Update updates account(s) based on filter
func (r *accountRepository) Update(ctx context.Context, filter AccountFilter, data UpdateAccountRequest) (*Account, int, error) {
    db := r.db.WithContext(ctx)

    // Build query dengan filter untuk menentukan record mana yang akan diupdate
    query := applyAccountFilters(db, filter, searchInAllFields)

    // Build update map hanya untuk field yang tidak nil
    updates := make(map[string]interface{})
    if data.FirstName != nil {
        updates["first_name"] = *data.FirstName
    }
    if data.LastName != nil {
        updates["last_name"] = *data.LastName
    }
    if data.Phone != nil {
        updates["phone"] = *data.Phone
    }
    if data.Avatar != nil {
        updates["avatar"] = *data.Avatar
    }
    updates["updated_at"] = time.Now()

    if err := query.Updates(updates).Error; err != nil {
        return nil, handleGORMError(err)
    }

    // Return updated record
    return r.GetOne(ctx, filter)
}

// Delete deletes account(s) based on filter
func (r *accountRepository) Delete(ctx context.Context, filter AccountFilter) (int, error) {
    db := r.db.WithContext(ctx)

    // Build query dengan filter
    query := applyAccountFilters(db, filter, searchInAllFields)

    // Soft delete
    if err := query.Delete(&Account{}).Error; err != nil {
        return handleGORMError(err)
    }

    return http.StatusOK, nil
}

// List returns paginated list of accounts
func (r *accountRepository) List(ctx context.Context, filter AccountFilter, paginate *paginate_utils.PaginateData) ([]AccountListItem, int, error) {
    db := r.db.WithContext(ctx)

    // Build base query with filters
    base := applyAccountFilters(db.Model(&Account{}), filter, searchInAllFields)

    // Select only required fields for list view
    selectQuery := base.Select(`
        id,
        email,
        first_name,
        last_name,
        phone,
        status,
        role,
        created_at,
        updated_at
    `)

    // Apply pagination and ordering
    q := common.ApplyPagination(selectQuery, paginate)
    q = common.ApplyOrderBy(q, "created_at DESC")

    // Execute query
    var accounts []Account
    if err := q.Find(&accounts).Error; err != nil {
        return nil, handleGORMError(err)
    }

    // Transform to list items
    result := make([]AccountListItem, len(accounts))
    for i, account := range accounts {
        result[i] = AccountListItem{
            ID:        account.ID,
            Email:     account.Email,
            FirstName: account.FirstName,
            LastName:  account.LastName,
            Phone:     account.Phone,
            Status:    string(account.Status),
            Role:      string(account.Role),
            CreatedAt: account.CreatedAt,
            UpdatedAt: account.UpdatedAt,
        }
    }

    return result, http.StatusOK, nil
}

// Count returns total count of accounts matching filter
func (r *accountRepository) Count(ctx context.Context, filter AccountFilter) (int64, int, error) {
    db := r.db.WithContext(ctx)

    // Build base query with filters
    base := applyAccountFilters(db.Model(&Account{}), filter, searchInAllFields)

    var count int64
    if err := base.Count(&count).Error; err != nil {
        return 0, handleGORMError(err)
    }

    return count, http.StatusOK, nil
}

// Helper function to handle GORM errors and return HTTP status codes
func handleGORMError(err error) (int, error) {
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return http.StatusNotFound, ErrAccountNotFound
    }
    if errors.Is(err, gorm.ErrDuplicatedKey) {
        return http.StatusConflict, ErrAccountAlreadyExists
    }
    return http.StatusInternalServerError, err
}

// Repository errors
var (
    ErrAccountNotFound     = errors.New("account not found")
    ErrAccountAlreadyExists = errors.New("account already exists")
    ErrInvalidUUID         = errors.New("invalid UUID")
)
```

## Best Practices for Repository Interface Design

### Kapan Gunakan Filter Pattern vs Fungsi Terpisah?

#### Gunakan Filter Pattern ketika:
1. **Return value sama**: Jika fungsi-fungsi mengembalikan tipe data yang sama
   - ✅ `GetByID()`, `GetByEmail()`, `GetByPhone()` → semua return `*Account`
   - Gunakan `GetOne(filter AccountFilter)`

2. **Query logic kompleks**: Jika perlu kombinasi filter yang dinamis
   - ✅ `GetActiveUsersInCity()` → bisa kombinasi status + location
   - Gunakan `List(filter AccountFilter)`

3. **Extensibility**: Jika kemungkinan akan ada filter baru di masa depan
   - ✅ Filter bisa ditambah tanpa ubah interface
   - Gunakan filter object

#### Gunakan Fungsi Terpisah ketika:
1. **Return value berbeda**: Jika fungsi mengembalikan tipe data yang berbeda
   - ✅ `GetUser()` → return `*User`
   - ✅ `GetUserProfile()` → return `*UserProfile`
   - ✅ `GetUserSettings()` → return `*UserSettings`

2. **Business logic unik**: Jika setiap fungsi memiliki logic yang sangat berbeda
   - ✅ `ActivateAccount()` → punya logic activation
   - ✅ `DeactivateAccount()` → punya logic deactivation
   - ✅ `ResetPassword()` → punya password reset logic

3. **External dependencies**: Jika fungsi memanggil service yang berbeda
   - ✅ `SendWelcomeEmail()` → panggil email service
   - ✅ `GenerateReport()` → panggil reporting service
   - ✅ `ProcessPayment()` → panggil payment service

### Repository Filters Implementation

```go
// applyAccountFilters applies filters to GORM query
func applyAccountFilters(query *gorm.DB, filter AccountFilter, searchMode searchMode) *gorm.DB {
    // Single ID filter
    if filter.Id != nil {
        query = query.Where("id = ?", *filter.Id)
    }

    // Multiple IDs filter
    if len(filter.Ids) > 0 {
        query = query.Where("id in (?)", filter.Ids)
    }

    // Exact email filter
    if filter.Email != nil {
        query = query.Where("email = ?", *filter.Email)
    }

    // Search filter with different modes
    if filter.Search != nil {
        searchTerm := "%" + *filter.Search + "%"
        switch searchMode {
        case searchInNameOnly:
            query = query.Where("first_name ILIKE ? OR last_name ILIKE ?", searchTerm, searchTerm)
        case searchInEmailOnly:
            query = query.Where("email ILIKE ?", searchTerm)
        default: // searchInAllFields
            query = query.Where(`
                first_name ILIKE ? OR
                last_name ILIKE ? OR
                email ILIKE ? OR
                phone ILIKE ?
            `, searchTerm, searchTerm, searchTerm, searchTerm)
        }
    }

    // Multiple status filter
    if len(filter.StatusList) > 0 {
        query = query.Where("status in (?)", filter.StatusList)
    }

    // Multiple role filter
    if len(filter.RoleList) > 0 {
        query = query.Where("role in (?)", filter.RoleList)
    }

    // Creation date range filter
    if filter.CreatedFrom != nil {
        query = query.Where("created_at >= ?", *filter.CreatedFrom)
    }
    if filter.CreatedTo != nil {
        query = query.Where("created_at <= ?", *filter.CreatedTo)
    }

    // City filter
    if filter.City != nil {
        query = query.Joins("JOIN user_profiles ON user_profiles.account_id = accounts.id")
        query = query.Where("user_profiles.city ILIKE ?", "%"+*filter.City+"%")
    }

    // Country filter
    if filter.Country != nil {
        query = query.Joins("JOIN user_profiles ON user_profiles.account_id = accounts.id")
        query = query.Where("user_profiles.country ILIKE ?", "%"+*filter.Country+"%")
    }

    return query
}

type searchMode int

const (
    searchInAllFields searchMode = iota
    searchInNameOnly
    searchInEmailOnly
)
```

## 4. Error Handling Pattern

### Return Pattern
All layers below the controller (Use Case, Repository, Service) must return `(result, int, error)` where:
- `result`: The actual data being returned (can be nil for operations that don't return data)
- `int`: HTTP status code representing the outcome
- `error`: Error details if something went wrong

### Error Handling Examples

#### Use Case Implementation (Update untuk Filter Pattern)
```go
func (u *accountUseCase) CreateAccount(ctx context.Context, req CreateAccountRequest) (*CreateResponse, int, error) {
    // Validate input
    if err := req.Validate(); err != nil {
        return nil, http.StatusBadRequest, fmt.Errorf("validation failed: %w", err)
    }

    // Check if account exists using filter
    existingAccount, statusCode, err := u.repo.GetOne(ctx, account_repository.AccountFilter{
        Email: &req.Email,
    })
    if err != nil && statusCode != http.StatusNotFound {
        return nil, statusCode, fmt.Errorf("failed to check email: %w", err)
    }
    if existingAccount != nil {
        return nil, http.StatusConflict, fmt.Errorf("email already exists")
    }

    // Create account
    account, statusCode, err := u.repo.Create(ctx, req)
    if err != nil {
        return nil, statusCode, fmt.Errorf("failed to create account: %w", err)
    }

    return &CreateResponse{
        ID:    account.ID,
        Email: account.Email,
    }, http.StatusCreated, nil
}

func (u *accountUseCase) GetAccount(ctx context.Context, id uuid.UUID) (*AccountResponse, int, error) {
    // Get account by ID using filter
    account, statusCode, err := u.repo.GetOne(ctx, account_repository.AccountFilter{
        Id: &id,
    })
    if err != nil {
        return nil, statusCode, fmt.Errorf("failed to get account: %w", err)
    }

    // Transform to response
    return &AccountResponse{
        ID:        account.ID,
        Email:     account.Email,
        FirstName: account.FirstName,
        LastName:  account.LastName,
        Status:    string(account.Status),
    }, http.StatusOK, nil
}
```

#### Repository Implementation dengan Filter Pattern
```go
// Helper function to handle GORM errors and return HTTP status codes
func handleGORMError(err error) (int, error) {
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return http.StatusNotFound, ErrAccountNotFound
    }
    if errors.Is(err, gorm.ErrDuplicatedKey) {
        return http.StatusConflict, ErrAccountAlreadyExists
    }
    return http.StatusInternalServerError, err
}
```

#### Controller Handling (Update untuk Filter Pattern)
```go
func (c *accountController) GetAccount(ctx *gin.Context) {
    id := ctx.Param("id")
    uuid, err := uuid.Parse(id)
    if err != nil {
        ctx.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: "Invalid ID"})
        return
    }

    result, statusCode, err := c.useCase.GetAccount(ctx.Request.Context(), uuid)
    if err != nil {
        ctx.JSON(statusCode, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    ctx.JSON(http.StatusOK, SuccessResponse{Data: result})
}

// Package-level rules (safe for concurrent use since v0.0.41).
// Conventionally placed in app/controller/account_controller/rules.go
var UpdateAccountRules = map_validator.BuildRoles().
    SetRule("name", map_validator.Str().WithMax(255).
        Regex(constant.RegexExcludeSpecialCharSpace).Nullable()).
    SetManipulator("name", map_validator_utils.TrimValidation).
    Done()

func (c *accountController) UpdateAccount(ctx *gin.Context) {
    id := ctx.Param("id")
    uuid, err := uuid.Parse(id)
    if err != nil {
        ctx.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: "Invalid ID"})
        return
    }

    req, err := map_validator.ValidateJSON[UpdateAccountRequest](ctx.Request, UpdateAccountRules)
    if err != nil {
        ctx.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    result, statusCode, err := c.useCase.UpdateAccount(ctx.Request.Context(), uuid, req)
    if err != nil {
        ctx.JSON(statusCode, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    ctx.JSON(statusCode, SuccessResponse{Data: result})
}
```

## 5. Pagination and Filtering - CRITICAL DEPENDENCY

### ⚠️ IMPORTANT: paginate_utils Package

**ALWAYS use `paginate_utils` for ANY function that returns a list!**

This is a **required dependency** that provides consistent pagination across all repositories. AI agents MUST NOT create custom pagination logic.

#### Where to Find paginate_utils:
- **Location**: `<PROJECT_ROOT>/pkg/paginate_utils/`
- **Files**: `models.go`, `function.go`, `gorm.go`
- **ALWAYS Available**: This package exists in EVERY project

#### Usage Rules:
```go
// ✅ ALWAYS do this for list functions:
func (r *repository) ListUsers(ctx context.Context, filter Filter, paginate *paginate_utils.PaginateData) ([]User, int, error) {
    // Use paginate_utils for ALL list operations
}

// ❌ NEVER do this:
func (r *repository) ListUsers(page, limit int) ([]User, error) {
    // Custom pagination is FORBIDDEN
}
```

### PaginateData Structure (READ-ONLY)

```go
// <PROJECT_ROOT>/pkg/paginate_utils/models.go - DO NOT MODIFY THIS FILE!
package paginate_utils

// PaginateData holds pagination information
// This struct is READ-ONLY. Use it as-is.
type PaginateData struct {
    Page      int   `json:"page"`      // Current page number (1-based)
    Limit     int   `json:"limit"`     // Items per page
    TotalData int64 `json:"total_data"` // Total items (filled by CountTotal)
}
```

### paginate_utils Functions (READ-ONLY)

#### Function.go - Helper Functions
```go
// <PROJECT_ROOT>/pkg/paginate_utils/function.go - DO NOT MODIFY THIS FILE!

// CheckPaginateFromMap extracts pagination from map[string]interface{}
// Used for parsing query parameters from HTTP requests
func CheckPaginateFromMap(filter map[string]interface{}, p *PaginateData) error {
    // Internal logic - DO NOT change
    if p == nil {
        return errors.New("paginate struct is nil")
    }
    // ... implementation details
}

// Defaults applied automatically:
// - Page: defaults to 1 if <= 0
// - Limit: defaults to 10 if <= 0
```

#### GORM.go - Database Scope
```go
// <PROJECT_ROOT>/pkg/paginate_utils/gorm.go - DO NOT MODIFY THIS FILE!

// Paginate returns GORM scope for applying LIMIT and OFFSET
// Usage: query.Scopes(paginate_utils.Paginate(paginateData))
func Paginate(p *PaginateData) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        if p == nil {
            return db
        }
        offset := (p.Page - 1) * p.Limit
        return db.Offset(offset).Limit(p.Limit)
    }
}
```

## 📋 Pagination Implementation Rules

### Step 1: Add Paginate Parameter to Interface
```go
// Repository Interface - ALWAYS add paginate parameter for list functions
type UserRepository interface {
    // ✅ List functions MUST accept PaginateData
    List(ctx context.Context, filter Filter, paginate *paginate_utils.PaginateData) ([]User, int64, error)
    Count(ctx context.Context, filter Filter) (int64, int, error)

    // Single record functions DON'T need pagination
    GetOne(ctx context.Context, filter Filter) (*User, int, error)
}
```

### Step 2: Use Common Query Helpers
```go
// app/repository/common/query_helpers.go - USE THESE HELPERS

// ApplyPagination - Applies LIMIT/OFFSET to query
func ApplyPagination(query *gorm.DB, paginate *paginate_utils.PaginateData) *gorm.DB

// ApplyOrderBy - Applies ORDER BY with default "created_at DESC"
func ApplyOrderBy(query *gorm.DB, orderBy string) *gorm.DB

// CountTotal - Counts total and updates paginate.TotalData
func CountTotal(query *gorm.DB, paginate *paginate_utils.PaginateData) error
```

### Step 3: Implementation Pattern (MUST FOLLOW)
```go
// Repository Implementation
func (r *userRepository) List(ctx context.Context, filter Filter, paginate *paginate_utils.PaginateData) ([]User, int64, int, error) {
    db := r.db.WithContext(ctx)

    // 1. Build query with filters
    base := applyUserFilters(db.Model(&User{}), filter)

    // 2. Get total count FIRST (important!)
    if err := common.CountTotal(base, paginate); err != nil {
        return nil, 0, common.HandleGORMError(err)
    }

    // 3. Apply pagination and ordering
    query := common.ApplyPagination(base, paginate)
    query = common.ApplyOrderBy(query, "created_at DESC")

    // 4. Execute query
    var users []User
    if err := query.Find(&users).Error; err != nil {
        return nil, 0, common.HandleGORMError(err)
    }

    return users, paginate.TotalData, http.StatusOK, nil
}

// Count function
func (r *userRepository) Count(ctx context.Context, filter Filter) (int64, int, error) {
    db := r.db.WithContext(ctx)

    // Build query with filters
    base := applyUserFilters(db.Model(&User{}), filter)

    var count int64
    if err := base.Count(&count).Error; err != nil {
        return 0, common.HandleGORMError(err)
    }

    return count, http.StatusOK, nil
}
```

### Step 4: Controller Usage Pattern
```go
// Controller - Parse pagination from query parameters
func (c *userController) ListUsers(ctx *gin.Context) {
    // Parse query parameters
    var query ListUsersQuery
    ctx.ShouldBindQuery(&query)

    // Create PaginateData
    paginate := &paginate_utils.PaginateData{
        Page:  query.Page,
        Limit: query.Limit,
    }

    // Call repository
    users, total, statusCode, err := c.userRepo.List(ctx, useCaseFilter, paginate)
    if err != nil {
        ctx.JSON(statusCode, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // Return response
    ctx.JSON(statusCode, SuccessResponse{
        Success: true,
        Data: ListUsersResponse{
            Data: users,
            Paginate: PaginateResponse{
                Page:       paginate.Page,
                Limit:      paginate.Limit,
                Total:      total,
                TotalPages: int(math.Ceil(float64(total) / float64(paginate.Limit))),
            },
        },
    })
}
```

## ⚠️ CRITICAL REMINDERS FOR AI AGENTS

### DO NOT:
- ❌ Create custom pagination logic
- ❌ Copy paginate_utils code (it exists!)
- ❌ Modify paginate_utils files
- ❌ Use (page, limit) directly in SQL
- ❌ Create custom error handling
- ❌ Skip using common helpers

### ALWAYS:
- ✅ Import `<PROJECT_NAME>/pkg/paginate_utils`
- ✅ Use `PaginateData` struct for parameters
- ✅ Use `query.Scopes(paginate_utils.Paginate(paginate))`
- ✅ Use pagination helpers: `ApplyPagination`, `ApplyOrderBy`, `CountTotal`
- ✅ Use error helpers: `HandleGORMError`, `ValidateRequiredID`
- ✅ Return `paginate.TotalData` for response metadata

### Required Import:
```go
import (
    "<PROJECT_NAME>/pkg/paginate_utils"
    "<PROJECT_NAME>/app/repository/common"
)
```

### Common Helper Functions Available:
```go
// From query_helpers.go:
common.ApplyPagination(query, paginate)     // Apply pagination
common.ApplyOrderBy(query, orderBy)         // Apply sorting
common.CountTotal(query, paginate)           // Get total count

// From error_helpers.go:
common.HandleGORMError(err)                // Handle GORM errors
common.ValidateRequiredID(id)               // Validate ID
```

This package is **ESSENTIAL** and must be used for ALL list operations!

## 6. Layer Models and Transformations

### Why Models in Each Layer?

1. **Maintainability**: Changes in one layer don't cascade to others
2. **Testability**: Each layer can be tested independently
3. **Flexibility**: Easy to swap implementations
4. **Clarity**: Each layer's models express its specific concerns

### Transformation Examples

#### Controller to Use Case
```go
// Controller transforms HTTP request to Use Case request
func (c *accountController) ListAccounts(ctx *gin.Context) {
    // Parse HTTP query parameters
    var query ListAccountsQuery
    ctx.ShouldBindQuery(&query)

    // Transform to Use Case request
    req := account_use_case.ListAccountsRequest{
        Search:   query.Search,
        Status:   query.Status,
        SortBy:   query.SortBy,
    }

    // Call Use Case
    result, statusCode, err := c.useCase.ListAccounts(ctx, req, pagination)
}
```

#### Use Case to Repository
```go
// Use Case transforms its filter to Repository filter
func (u *accountUseCase) transformToRepoFilter(req ListAccountsRequest) account_repository.AccountFilter {
    filter := account_repository.AccountFilter{
        Search:  req.Search,
        City:    req.City,
    }

    // Transform string status to enum
    if len(req.Status) > 0 {
        statusList := make([]account_repository.AccountStatus, len(req.Status))
        for i, status := range req.Status {
            statusList[i] = account_repository.AccountStatus(status)
        }
        filter.StatusList = statusList
    }

    return filter
}
```

#### Repository to Use Case
```go
// Repository transforms DB model to Use Case list item
func (r *accountRepository) ListAccounts(ctx context.Context, filter AccountFilter, paginate *paginate_utils.PaginateData) ([]AccountListItem, int, error) {
    // Query database
    var accounts []Account
    q.Find(&accounts)

    // Transform to Use Case response
    result := make([]AccountListItem, len(accounts))
    for i, account := range accounts {
        result[i] = AccountListItem{
            ID:        account.ID,
            Email:     account.Email,
            FirstName: account.FirstName,
            // ... other fields
        }
    }

    return result, http.StatusOK, nil
}
```

#### Use Case to Controller
```go
// Use Case returns response that Controller transforms to HTTP response
func (c *accountController) ListAccounts(ctx *gin.Context) {
    // Call Use Case
    useCaseResp, statusCode, err := c.useCase.ListAccounts(ctx, req, pagination)

    // Transform to HTTP response
    httpResp := ListAccountsResponse{
        Data: make([]AccountListResponse, len(useCaseResp.Accounts)),
    }

    for i, acc := range useCaseResp.Accounts {
        httpResp.Data[i] = AccountListResponse{
            ID:       acc.ID,
            Email:    acc.Email,
            FullName: acc.FullName,
        }
    }

    ctx.JSON(statusCode, httpResp)
}
```

---

# 🚀 Complete Blueprint Summary

## 📋 MUST-Follow Rules for AI Agents

### 💬 COMMENTS RULE

**Comments are allowed** — use them where they clarify intent that the code itself cannot. Swagger annotations on HTTP handlers are still required (see `swagger_annotation_guide.md`).

**GOOD uses of comments:**
- ✅ Swagger annotations on HTTP handlers (`@Summary`, `@Router`, `@Param`, `@Success`, `@Failure`, …) — required
- ✅ Package-level docstrings (`// Package foo …`) explaining what the package does
- ✅ Godoc on exported identifiers (types, funcs, vars) when the name alone is insufficient
- ✅ Short rationale for non-obvious decisions (why this approach, not what it does)
- ✅ Notes about gotchas, invariants, or constraints a future reader would miss

**AVOID (not forbidden, but low value):**
- ❌ Restating what well-named code already says (`// increment counter`, `counter++`)
- ❌ Stale TODOs with no owner / date
- ❌ Commented-out code left in the tree

**Code should still be self-documenting through:**
- Clear variable names
- Clear function names
- Proper structure
- Meaningful constants

The comments add context; they don't replace good naming. A handler covered by Swagger annotations rarely needs additional inline comments, but a non-obvious business rule or a cross-service integration detail absolutely may.

#### ❌ AVOID — redundant comments that only restate the code:
```go
// User request model for registration
type CreateUserRequest struct {
    Email     string `json:"email"`      // User's email address
    Password  string `json:"password"`   // User's password (min 8 chars)
    FirstName string `json:"first_name"` // User's first name
    LastName  string `json:"last_name"`  // User's last name
}

// CreateUserRules defines the validation rules for CreateUser.
// Rules as package-level var — safe for concurrent shared use.
var CreateUserRules = map_validator.BuildRoles().
    SetRule("name",  map_validator.Str().WithMax(255)).
    SetRule("email", map_validator.Email().WithMax(255)).
    SetFieldsManipulator([]string{"name", "email"}, map_validator_utils.TrimValidation).
    Done()

// CreateUser creates a new user in the system
func (c *userController) CreateUser(ctx *gin.Context) {
    // Validate request body
    req, err := map_validator.ValidateJSON[CreateUserRequest](ctx.Request, CreateUserRules)
    if err != nil {
        // Return 400 on validation error
        ctx.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // Call use case
    result, statusCode, err := c.userUseCase.CreateUser(ctx.Request.Context(), req)
    if err != nil {
        // Handle error
        ctx.JSON(statusCode, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    // Return success response
    ctx.JSON(statusCode, SuccessResponse{
        Success: true,
        Data:    result,
    })
}
```

#### ✅ PREFERRED — Swagger + comments that carry real information:
```go
type CreateUserRequest struct {
    Email     string `json:"email"`
    Password  string `json:"password"`
    FirstName string `json:"first_name"`
    LastName  string `json:"last_name"`
}

// Shared at package level — see MAP_VALIDATOR_GUIDE.md for placement and naming conventions.
var CreateUserRules = map_validator.BuildRoles().
    SetRule("email",      map_validator.Email().WithMax(255)).
    SetRule("password",   map_validator.Str().Between(8, 64)).
    SetRule("first_name", map_validator.Str().WithMax(255)).
    SetRule("last_name",  map_validator.Str().WithMax(255)).
    SetFieldsManipulator([]string{"email", "first_name", "last_name"}, map_validator_utils.TrimValidation).
    Done()

// @Summary Create a new user
// @Description Create a new user with the provided information
// @Tags users
// @Accept json
// @Produce json
// @Param request body CreateUserRequest true "User creation request"
// @Success 201 {object} CreateUserResponse
// @Failure 400 {object} ErrorResponse
// @Failure 500 {object} ErrorResponse
// @Router /api/v1/users [post]
func (c *userController) CreateUser(ctx *gin.Context) {
    req, err := map_validator.ValidateJSON[CreateUserRequest](ctx.Request, CreateUserRules)
    if err != nil {
        ctx.JSON(http.StatusBadRequest, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    result, statusCode, err := c.userUseCase.CreateUser(ctx.Request.Context(), req)
    if err != nil {
        ctx.JSON(statusCode, gin_utils.MessageResponse{Message: err.Error()})
        return
    }

    ctx.JSON(statusCode, SuccessResponse{
        Success: true,
        Data:    result,
    })
}
```

### 1. Folder Structure
```
app/
├── controller/
│   └── [domain]_controller/
│       ├── models.go      # Request/Response models
│       ├── interfaces.go  # Interface
│       └── controller.go  # HTTP handlers
├── use_case/
│   └── [domain]_use_case/
│       ├── models.go      # Business models
│       ├── interfaces.go  # Interface
│       └── use_case.go    # Business logic
└── repository/
    └── [domain]_repository/
        ├── models.go      # Database models
        ├── filters.go     # Filter structures
        ├── interfaces.go  # Interface
        └── repository.go  # DB operations
```

### 2. Interface Naming
- **Controller**: `UserController`, `ProductController`
- **Use Case**: `UserUseCase`, `ProductUseCase`
- **Repository**: `UserRepository`, `ProductRepository`

### 3. Method Naming
- **CRUD**: Create, Get, Update, Delete
- **List**: Use with pagination
- **Query**: Use for complex searches
- **Count**: Return count with filter

### 4. Error Pattern
```go
// ALWAYS return (result, status, error)
// Status = HTTP status code (200, 400, 404, 500)
func (s *Service) DoSomething(ctx context.Context) (*Result, int, error)
```

### 5. Model Transformation
```go
// Controller → Use Case
controllerReq → useCaseReq

// Use Case → Repository
useCaseReq → repoFilter

// Repository → Use Case
dbModel → useCaseModel

// Use Case → Controller
useCaseResp → controllerResp
```

### 6. Dependency Injection
```go
// ALWAYS use struct injection
type Dependencies struct {
    Repo     Repository
    Service  ExternalService
    Config   Config
}

// ALWAYS have constructor
func NewService(deps Dependencies) *Service {
    return &Service{...}
}
```

### 7. Common Patterns

#### Repository Filter
```go
// ✅ Use this:
GetOne(ctx context.Context, filter Filter) (*Model, error)

// ❌ NOT this:
GetByID(id uuid.UUID) (*Model, error)
GetByEmail(email string) (*Model, error)
GetByName(name string) (*Model, error)
```

#### Validation
```go
// ✅ Controller: Use binding tags
type Request struct {
    Name string `json:"name" binding:"required"`
}

// ✅ Use Case: Custom validation
func (r *Request) Validate() error {
    if len(r.Name) < 3 {
        return errors.New("name too short")
    }
    return nil
}
```

#### Pagination
```go
// ✅ ALWAYS use paginate_utils
result, statusCode, err := repo.List(ctx, filter, paginate)

// ✅ Transform to response
resp := ListResponse{
    Data:     items,
    Paginate: PaginateResponse{
        Page:   paginate.Page,
        Limit:  paginate.Limit,
        Total:  total,
    },
}
```

## 🎯 Final Checklist

Before generating code, AI agents should:

1. [ ] Create correct folder structure
2. [ ] Define interfaces first
3. [ ] Create models for each layer
4. [ ] Follow naming conventions
5. [ ] Use proper error handling
6. [ ] Add validation
7. [ ] Implement transformations
8. [ ] Add Swagger documentation
9. [ ] Use dependency injection
10. [ ] Follow pagination pattern

Remember: **Consistency over cleverness**. Follow the patterns exactly as shown in this blueprint!

---

# 📚 Appendices - Required Code Templates

## Appendix A: paginate_utils Package (CRITICAL DEPENDENCY)

**If this package doesn't exist, create these files EXACTLY as shown:**

### A.1. `pkg/paginate_utils/models.go`
```go
package paginate_utils

// PaginateData holds pagination information
// This struct is READ-ONLY. Use it as-is.
type PaginateData struct {
    Page      int   `json:"page"`       // Current page number (1-based)
    Limit     int   `json:"limit"`      // Items per page
    TotalData int64 `json:"total_data"` // Total items (filled by CountTotal)
}
```

### A.2. `pkg/paginate_utils/function.go`
```go
package paginate_utils

import (
    "errors"
    "strconv"
)

// CheckPaginateFromMap extracts pagination from map[string]interface{}
// Used for parsing query parameters from HTTP requests
func CheckPaginateFromMap(filter map[string]interface{}, p *PaginateData) error {
    if p == nil {
        return errors.New("paginate struct is nil")
    }

    // Extract page from map
    if v, ok := filter["page"]; ok {
        if s, ok := v.(string); ok {
            if i, err := strconv.Atoi(s); err == nil {
                p.Page = i
            }
        }
    }

    // Extract limit from map
    if v, ok := filter["limit"]; ok {
        if s, ok := v.(string); ok {
            if i, err := strconv.Atoi(s); err == nil {
                p.Limit = i
            }
        }
    }

    // Apply defaults
    if p.Page <= 0 {
        p.Page = 1
    }
    if p.Limit <= 0 {
        p.Limit = 10
    }

    return nil
}
```

### A.3. `pkg/paginate_utils/gorm.go`
```go
package paginate_utils

import "gorm.io/gorm"

// Paginate returns GORM scope for applying LIMIT and OFFSET
// Usage: query.Scopes(paginate_utils.Paginate(paginateData))
func Paginate(p *PaginateData) func(db *gorm.DB) *gorm.DB {
    return func(db *gorm.DB) *gorm.DB {
        if p == nil {
            return db
        }
        offset := (p.Page - 1) * p.Limit
        return db.Offset(offset).Limit(p.Limit)
    }
}
```

## Appendix B: Repository Common Helpers (CRITICAL DEPENDENCY)

**If this directory doesn't exist, create these 2 files EXACTLY as shown:**
- `query_helpers.go` - Pagination and query helpers
- `error_helpers.go` - Error handling and validation helpers

### B.1. `app/repository/common/query_helpers.go`
```go
package common

import (
    "<PROJECT_NAME>/pkg/paginate_utils"
    "gorm.io/gorm"
)

func ApplyPagination(query *gorm.DB, paginate *paginate_utils.PaginateData) *gorm.DB {
    if paginate == nil {
        return query
    }
    return query.Scopes(paginate_utils.Paginate(paginate))
}

func ApplyOrderBy(query *gorm.DB, orderBy string) *gorm.DB {
    if orderBy == "" {
        orderBy = "created_at DESC"
    }
    return query.Order(orderBy)
}

func CountTotal(query *gorm.DB, paginate *paginate_utils.PaginateData) error {
    if paginate == nil {
        return nil
    }
    var total int64
    if err := query.Count(&total).Error; err != nil {
        return err
    }
    paginate.TotalData = total
    return nil
}
```

### B.2. `app/repository/common/error_helpers.go`
```go
package common

import (
    "errors"
    "net/http"
    "gorm.io/gorm"
)

const (
    ErrIDRequired          = "id is required"
    ErrRecordNotFound      = "record not found"
    ErrInvalidInput        = "invalid input provided"
    ErrTypeAssertionFailed = "type assertion failed"
)

func HandleGORMError(err error) (int, error) {
    if err == nil {
        return http.StatusOK, nil
    }
    if errors.Is(err, gorm.ErrRecordNotFound) {
        return http.StatusNotFound, err
    }
    return http.StatusInternalServerError, err
}

func ValidateRequiredID(id interface{}) (int, error) {
    if id == nil {
        return http.StatusBadRequest, errors.New(ErrIDRequired)
    }
    return http.StatusOK, nil
}
```

## Appendix D: gin_utils MessageResponse (CRITICAL DEPENDENCY)

**This is REQUIRED for all controller error responses. Create this file if it doesn't exist:**

### D.1. `pkg/gin_utils/message.go`
```go
package gin_utils

// MessageResponse is the standard error response format for all controllers
type MessageResponse struct {
    Message string `json:"message"`
}
```

**⚠️ IMPORTANT:**
- This file is REQUIRED for ALL controller implementations
- All controllers MUST use `gin_utils.MessageResponse` for error responses
- DO NOT use custom error response structures
- DO NOT wrap error messages with prefixes

## Appendix E: Database Schemas - GORM Models (CRITICAL)

**Repository layer requires these GORM model files as references:**

### E.1. `database/schemas/account.go` - Example
```go
package schemas

import (
    "time"
    "github.com/google/uuid"
    "gorm.io/gorm"
)

type Account struct {
    ID        uuid.UUID  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    Name      string     `gorm:"size:255;not null"`
    Email     string     `gorm:"size:255;not null;uniqueIndex"`
    Password  string     `gorm:"size:255;not null"`
    City      string     `gorm:"size:100"`
    Balance   float64    `gorm:"default:0"`
    Status    int        `gorm:"default:1"` // 1:active, 0:inactive
    CreatedAt time.Time
    UpdatedAt time.Time
    DeletedAt gorm.DeletedAt `gorm:"index"`
}

func (Account) TableName() string {
    return "accounts"
}
```

### E.2. `database/schemas/cart.go` - Example
```go
package schemas

import (
    "time"
    "github.com/google/uuid"
    "gorm.io/gorm"
)

type Cart struct {
    ID        uuid.UUID  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    AccountID uuid.UUID  `gorm:"type:uuid;not null;index"`
    Total     float64    `gorm:"default:0"`
    Status    string     `gorm:"size:50;default:'active'"` // active, checkout, abandoned
    CreatedAt time.Time
    UpdatedAt time.Time
    DeletedAt gorm.DeletedAt `gorm:"index"`

    // Relationships
    Account   Account   `gorm:"foreignKey:AccountID"`
    Items     []CartItem `gorm:"foreignKey:CartID"`
}

func (Cart) TableName() string {
    return "carts"
}

type CartItem struct {
    ID       uuid.UUID `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    CartID   uuid.UUID `gorm:"type:uuid;not null;index"`
    ProductID uuid.UUID `gorm:"type:uuid;not null;index"`
    Quantity int       `gorm:"not null;default:1"`
    Price    float64   `gorm:"not null"`
    CreatedAt time.Time
    UpdatedAt time.Time

    // Relationships
    Cart Cart `gorm:"foreignKey:CartID"`
}

func (CartItem) TableName() string {
    return "cart_items"
}
```

### E.3. `database/schemas/shop.go` - Example
```go
package schemas

import (
    "time"
    "github.com/google/uuid"
    "gorm.io/gorm"
)

type Shop struct {
    ID          uuid.UUID  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    Name        string     `gorm:"size:255;not null"`
    Description string     `gorm:"type:text"`
    OwnerID     uuid.UUID  `gorm:"type:uuid;not null;index"`
    Status      string     `gorm:"size:50;default:'active'"` // active, inactive, suspended
    Rating      float64    `gorm:"default:0"`
    CreatedAt   time.Time
    UpdatedAt   time.Time
    DeletedAt   gorm.DeletedAt `gorm:"index"`

    // Relationships
    Owner   Account   `gorm:"foreignKey:OwnerID"`
    Products []Product `gorm:"foreignKey:ShopID"`
}

func (Shop) TableName() string {
    return "shops"
}

type Product struct {
    ID          uuid.UUID  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    ShopID      uuid.UUID  `gorm:"type:uuid;not null;index"`
    Name        string     `gorm:"size:255;not null"`
    Description string     `gorm:"type:text"`
    Price       float64    `gorm:"not null;default:0"`
    Stock       int        `gorm:"default:0"`
    Status      string     `gorm:"size:50;default:'active'"` // active, inactive, out_of_stock
    CreatedAt   time.Time
    UpdatedAt   time.Time
    DeletedAt   gorm.DeletedAt `gorm:"index"`

    // Relationships
    Shop Shop `gorm:"foreignKey:ShopID"`
}

func (Product) TableName() string {
    return "products"
}
```

**⚠️ IMPORTANT NOTES:**
- These are GORM models used by repository layer as reference
- Repository models in `app/repository/[domain]_repository/models.go` should reference these
- Always use UUID for primary keys
- Include soft deletes with `DeletedAt gorm.DeletedAt`
- Add proper GORM tags for constraints and indexes
- Define foreign key relationships properly

## Appendix C: Basic Project Setup Templates

### C.1. `main.go` Template
```go
package main

import (
    "log"
    "net/http"

    "github.com/gin-gonic/gin"
    "gorm.io/gorm"
)

// @title <PROJECT_NAME> API
// @version 1.0
// @description API for <PROJECT_NAME>
// @host localhost:8080
// @BasePath /api/v1
func main() {
    // Initialize Gin
    r := gin.Default()

    // Health check
    r.GET("/health", func(c *gin.Context) {
        c.JSON(http.StatusOK, gin.H{
            "status": "healthy",
        })
    })

    // API v1 group
    v1 := r.Group("/api/v1")
    {
        // Add routes here
        // v1.GET("/users", userController.ListUsers)
    }

    log.Println("Server starting on :8080")
    log.Fatal(r.Run(":8080"))
}
```

### C.2. `go.mod` Template
```go
module <PROJECT_NAME>

go 1.21

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/google/uuid v1.3.0
    github.com/swaggo/gin-swagger v1.6.0
    github.com/swaggo/swag v1.16.1
    gorm.io/driver/postgres v1.5.2
    gorm.io/gorm v1.25.4
)
```

### C.3. `database/database.go` Template
```go
package config

import (
    "fmt"
    "os"

    "gorm.io/driver/postgres"
    "gorm.io/gorm"
    "gorm.io/gorm/logger"
)

var DB *gorm.DB

// InitDatabase initializes database connection
func InitDatabase() error {
    dsn := os.Getenv("DATABASE_URL")
    if dsn == "" {
        // Default for development
        dsn = "host=localhost user=gorm password=gorm dbname=gorm port=9920 sslmode=disable TimeZone=Asia/Jakarta"
    }

    var err error
    DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Info),
    })

    if err != nil {
        return fmt.Errorf("failed to connect database: %w", err)
    }

    return nil
}
```

### C.4. `docs/docs.go` Template
```go
package docs

// This file is generated by swag init
// Run: swag init -g main.go

//go:generate swag init

// @title <PROJECT_NAME> API
// @version 1.0
// @description API documentation for <PROJECT_NAME>
// @termsOfService http://swagger.io/terms/

// @contact.name API Support
// @contact.url http://www.swagger.io/support
// @contact.email support@swagger.io

// @license.name Apache 2.0
// @license.url http://www.apache.org/licenses/LICENSE-2.0.html

// @host localhost:8080
// @BasePath /api/v1

// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and JWT token.

package docs
```

## Appendix D: Setup Commands

### D.1. Initialize New Project
```bash
# Create project directory
mkdir <project-name>
cd <project-name>

# Initialize Go module
go mod init <PROJECT_NAME>

# Install dependencies
go get github.com/gin-gonic/gin
go get github.com/google/uuid
go get gorm.io/gorm
go get gorm.io/driver/postgres
go get github.com/swaggo/gin-swagger
go get github.com/swaggo/swag

# MANUAL STEP: Create directory structure
mkdir -p pkg/paginate_utils
mkdir -p pkg/gin_utils
mkdir -p app/repository/common
mkdir -p app/controller
mkdir -p app/use_case
mkdir -p app/repository
mkdir -p database
mkdir -p database/schemas
mkdir -p docs

# MANUAL STEP: Create required empty files
touch main.go
touch database/database.go
touch database/schemas/{account.go,cart.go,shop.go}
touch pkg/paginate_utils/models.go
touch pkg/paginate_utils/function.go
touch pkg/paginate_utils/gorm.go
touch pkg/gin_utils/message.go
touch app/repository/common/query_helpers.go
touch app/repository/common/error_helpers.go
touch docs/docs.go

# MANUAL STEP: Copy code from appendices into these files:
# - Appendix A: paginate_utils code (3 files)
# - Appendix B: Repository common helpers (2 files)
# - Appendix D: gin_utils message.go (1 file)
# - Appendix E: database schemas (examples for reference)
# - Appendix C: main.go and config templates
# - Appendix C.4: docs/docs.go template

# Generate Swagger docs
swag init

# Run project
go run main.go
```

⚠️ **IMPORTANT:** All files above must be created MANUALLY by the user. AI agents should NOT create these files automatically.

### D.2. Verify Setup
```bash
# Check dependencies
go mod tidy
go mod verify

# Check build
go build

# Check tests
go test ./...

# Run with env file
# Create .env file with DATABASE_URL
DATABASE_URL="host=localhost user=postgres password=password dbname=mydb port=5432 sslmode=disable"
```

## 🎯 AI Agent Quick Start Commands

When AI agent joins a new project:

1. **Check project type:**
   ```text
   Is this a new Go project or existing project?
   ```

2. **If new project:**
   ```text
   I'll help you set up the project structure. Please provide:
   - Project name
   - Go module name (github.com/org/project)
   - Database preference
   ```

3. **If existing project:**
   ```text
   Let me check if all required dependencies exist...
   Checking for pkg/paginate_utils...
   Checking for app/repository/common...
   Checking go.mod...
   ```

4. **Before generating any domain code:**
   ```text
   ✅ Dependencies verified
   ✅ Project structure ready
   🚀 Ready to generate your domain code

   Which domain do you want to create? (e.g., users, products, orders)
   ```

### Example Conversation Flow:
```text
User: "Create a users domain for my API"

AI Agent:
🛑 STOP! I need to verify project dependencies first...

[Checks dependencies]

✅ Dependencies verified
✅ Project structure ready

🤔 I need some information to create your users domain:
1. What user fields do you need? (email, password, name, etc.)
2. What features? (registration, login, profile management)
3. Authentication required?

User: "Standard user registration, login, profile management with JWT"

AI Agent:
Perfect! Creating users domain structure...

[Executes folder creation commands]

✅ Created app/users folder structure
📝 Ready to generate code following the blueprint

Starting with repository models...
```

---

## 🎯 Complete Example: Creating "Users" Domain

### AI Agent Workflow:
```bash
# Step 1: Create directories (using CORRECT structure)
mkdir -p app/controller/users_controller
mkdir -p app/use_case/users_use_case
mkdir -p app/repository/users_repository

# Step 2: Create all files
touch app/controller/users_controller/{models.go,interfaces.go,controller.go}
touch app/use_case/users_use_case/{models.go,interfaces.go,use_case.go}
touch app/repository/users_repository/{models.go,filters.go,interfaces.go,repository.go}

# Step 3: Verify structure
tree app/
# app/
# ├── controller/
# │   └── users_controller/
# │       ├── interfaces.go
# │       ├── models.go
# │       └── controller.go
# ├── use_case/
# │   └── users_use_case/
# │       ├── interfaces.go
# │       ├── models.go
# │       └── use_case.go
# └── repository/
#     └── users_repository/
#         ├── filters.go
#         ├── interfaces.go
#         ├── models.go
#         └── repository.go

echo "✅ Users domain folder structure created successfully!"
```

### Step 4: Generate Code Sequence:
```text
1. 📝 app/repository/users_repository/models.go
   - User struct with GORM tags
   - UserStatus, UserRole enums

2. 📝 app/repository/users_repository/filters.go
   - UserFilter struct for dynamic queries

3. 📝 app/repository/users_repository/interfaces.go
   - UserRepository interface

4. 📝 app/repository/users_repository/repository.go
   - UserRepository implementation

5. 📝 app/use_case/users_use_case/models.go
   - Request/response models for business logic

6. 📝 app/use_case/users_use_case/interfaces.go
   - UserUseCase interface

7. 📝 app/use_case/users_use_case/use_case.go
   - UserUseCase implementation

8. 📝 app/controller/users_controller/models.go
   - HTTP request/response models

9. 📝 app/controller/users_controller/interfaces.go
   - UserController interface

10. 📝 app/controller/users_controller/controller.go
    - UserController implementation with routes
```

This documentation now provides everything AI agents need to set up and work with Go projects using Clean Architecture pattern!