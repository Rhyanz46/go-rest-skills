# AI Agent Learning Order Guide

> **🤖 AI Agent Reference**: This guide defines the exact order in which AI agents should learn and implement the project documentation to avoid confusion and ensure clean architecture compliance.

## 🎯 Purpose

This guide provides:
- **Mandatory learning sequence** for AI agents
- **Dependencies between documentation**
- **Progressive implementation order**
- **When each guide should be applied**

## 📋 MANDATORY Learning Order

### **Phase 1: Core Architecture & Foundation**
**Must complete in this exact order:**

1. **📖 First: `project_architecture.md`**
   - Purpose: Understand Clean Architecture principles
   - Prerequisites: None
   - Goal: Understand separation of concerns, layer responsibilities
   - Outcome: Know the big picture before diving into details

2. **📖 Second: `app_package.md`**
   - Purpose: Learn app/ folder development rules
   - Prerequisites: Must complete project_architecture.md first
   - Goal: Understand how to structure business logic layers
   - **Critical**: 99% completion required before APM implementation
   - Outcome: Can create Controller, Use Case, Repository layers

### **Phase 2: Bootstrap & Configuration**
**Complete after app_package.md is 99% done:**

3. **📖 Third: `main_and_routes_guide.md`**
   - Purpose: Learn how to connect all layers
   - Prerequisites: app_package.md 99% complete
   - Goal: Understand dependency injection and routing
   - Outcome: Can initialize and wire the complete application

4. **📖 Fourth: `MAP_VALIDATOR_GUIDE.md`**
   - Purpose: Learn request validation patterns (v0.0.41+ idioms)
   - Prerequisites: app_package.md (for controller context)
   - Goal: Replace `c.ShouldBindJSON` with `map_validator.ValidateJSON[T]` + short constructors (`Str`, `Int`, `Email`, `UUID`, `StrEnum`, `IntEnum`, `NestedObject`, `ListOfObject`) and chain helpers (`.Nullable`, `.Default`, `.WithMin`, `.WithMax`, `.Between`, `.Regex`, `.WithMsg`, `.UniqueFrom`, `.WithRequiredIf`, `.WithRequiredWithout`). Declare rules as package-level `var` (safe for concurrent use). 5-step pipeline is an escape hatch for advanced cases only.
   - Outcome: Can implement proper request validation

### **Phase 3: Documentation & Optional Enhancements**
**Implement only when core is fully functional:**

5. **📖 Fifth: `swagger_annotation_guide.md` (⚠️ OPTIONAL)**
   - Purpose: Add API documentation with Swagger
   - Prerequisites: app_package.md 99% complete, controllers working
   - **Optional**: Can be implemented anytime after core controllers work
   - When to implement: After controllers are fully functional
   - **AI Agent Rule**: Only add Swagger to HTTP handler functions in controllers
   - **Critical**: NEVER add Swagger annotations to use case, repository, or private functions
   - Outcome: Can generate comprehensive API documentation

6. **📖 Sixth: `apm_and_log_guide.md` (⚠️ OPTIONAL)**
   - Purpose: Add observability and monitoring
   - Prerequisites: **app_package.md 99% complete** (MANDATORY)
   - **Optional**: Can be implemented anytime after core features work
   - When to implement: After all business features are working
   - **AI Agent Rule**: Do not implement APM if app_package.md is <99% complete
   - Outcome: Can add APM tracking and structured logging

## 🔄 Implementation Flow Chart

```text
┌─────────────────┐
│ 1. project_architecture.md    │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 2. app_package.md             │
│   (99% COMPLETE)               │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 3. main_and_routes_guide.md    │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ 4. MAP_VALIDATOR_GUIDE.md     │
└─────────┬───────┘
          │
          ▼
┌─────────────────┐
│ Core Features Working?        │
│   - Controllers ✅            │
│   - Use Cases ✅               │
│   - Repositories ✅            │
│   - Routes ✅                  │
│   - Validation ✅              │
└─────┬───────┘
      │
      ▼
┌─────────────────┐
│ 5. swagger_annotation_guide.md │
│ (OPTIONAL - API documentation) │
└─────┬───────┘
      │
      ▼
┌─────────────────┐
│ 6. apm_and_log_guide.md       │
│ (OPTIONAL - Only when ready)    │
└─────────────────┘
```

## 🚨 Strict Rules for AI Agents

### **Rule #1: Never Skip Order**
- **ALWAYS** read guides in the specified order
- **NEVER** jump ahead to APM guide if app_package.md is not complete
- **NEVER** implement features without understanding the architecture

### **Rule #2: Verification Checkpoints**
Before moving to next guide, verify:
```
📋 Checkpoint: project_architecture.md → app_package.md
□ I understand Clean Architecture layers
□ I know the difference between layers
□ I understand dependency rules

📋 Checkpoint: app_package.md → main_and_routes_guide.md
□ I can create Controller/UseCase/Repository
□ I understand filter patterns
□ I know the model separation rules
□ Implementation progress: 99%

📋 Checkpoint: main_and_routes_guide.md → MAP_VALIDATOR_GUIDE.md
□ I can initialize the application
□ I can wire dependencies
□ I understand how routes connect to controllers
```

### **Rule #3: Swagger Implementation Criteria**
**Before implementing Swagger documentation, verify:**
```
✅ app_package.md is 99% complete
✅ Controllers are fully functional
✅ HTTP handlers are properly implemented
✅ Routes are connected and working
✅ Request/response structs are defined
✅ Only add Swagger to HTTP handler functions
✅ NEVER add Swagger to use case functions
✅ NEVER add Swagger to repository functions
✅ NEVER add Swagger to private/helper functions

⚠️ If ANY of the above is ❌, do NOT implement Swagger yet!
Focus on completing controllers first.
```

### **Rule #4: APM Implementation Criteria**
**Before implementing APM, verify:**
```
✅ app_package.md is 99% complete
✅ All business features are working
✅ Controllers handle HTTP properly
✅ Use cases implement business logic correctly
✅ Repositories manage data properly
✅ Routes connect all layers
✅ Validation works with map_validator
✅ Error handling follows the patterns
✅ The application is fully functional

⚠️ If ANY of the above is ❌, do NOT implement APM yet!
Focus on completing core functionality first.
```

## 🎯 When to Learn Each Guide

### **app_package.md - Critical Path**
- **Required**: 99% completion before anything else
- **Focus**: Business logic layers
- **Priority**: HIGHEST - Foundation of everything
- **Time Investment**: 70% of learning time

### **main_and_routes_guide.md - Critical Path**
- **Required**: After app_package.md
- **Focus**: Application bootstrap and wiring
- **Priority**: HIGH - Needed to run the application
- **Time Investment**: 20% of learning time

### **MAP_VALIDATOR_GUIDE.md - Critical Path**
- **Required**: After main_and_routes_guide.md
- **Focus**: Request validation
- **Priority**: HIGH - Essential for proper APIs
- **Time Investment**: 5% of learning time

### **swagger_annotation_guide.md - Optional**
- **Required**: After controllers are working
- **Focus**: API documentation generation
- **Priority**: MEDIUM - Nice to have for APIs
- **Time Investment**: 3% of learning time

### **apm_and_log_guide.md - Optional**
- **Required**: After all core functionality works
- **Focus**: Observability and monitoring
- **Priority**: LOW - Enhancement, not core
- **Time Investment**: 2% of learning time

## 📊 Learning Priorities

### **High Priority (Core Foundation) - 95%**
1. Clean Architecture principles (project_architecture.md)
2. App layer patterns (app_package.md)
3. Application bootstrap (main_and_routes_guide.md)
4. Request validation (MAP_VALIDATOR_GUIDE.md)

### **Medium Priority (Documentation) - 3%**
5. API documentation (swagger_annotation_guide.md)

### **Low Priority (Enhancement) - 2%**
6. APM and logging (apm_and_log_guide.md)

## 🤖 AI Agent Behavior Pattern

### **When Starting New Project:**
```
🤖 AI Agent: "I'll help you create your Go Clean Architecture project."

1️⃣ "Let me verify the learning order first..."
   ✅ Read project_architecture.md → "✅ Clean Architecture understood"

2️⃣ "Now let's learn app package development rules..."
   ✅ Read app_package.md → "✅ App package patterns understood"

3️⃣ "Let's check for prerequisites..."
   ✅ Verify dependencies → "✅ Ready to start development"

4️⃣ "Starting app/ folder creation..."
   [Build app layers following app_package.md rules]

5️⃣ "Let's connect everything with routes..."
   ✅ Read main_and_routes_guide.md → "✅ Application initialized"
```

### **When User Asks for Swagger Documentation:**
```
🤖 User: "Add Swagger documentation to my users controller"

🤖 AI Agent Response:
"I can add Swagger documentation to your HTTP handler functions. Let me verify the prerequisites first:

✅ Swagger Implementation Checklist:
□ Controllers handle HTTP requests properly?
□ HTTP handlers are public functions in controllers?
□ Request/response structs are defined?
□ Routes are connected and working?

⚠️ Important: I will ONLY add Swagger annotations to HTTP handler functions.
I will NOT add Swagger to:
- Private/helper functions
- Use case functions
- Repository functions
- Any non-HTTP handler functions

Is this approach acceptable? I'll proceed with documenting only the HTTP handlers in your controllers."
```

### **When User Asks for APM:**
```
🤖 User: "Add APM tracking to my users controller"

🤖 AI Agent Response:
"Before implementing APM, I need to verify core functionality is complete:

❌ Core Development Checklist:
□ Controllers handle HTTP requests properly?
□ Use cases implement business logic correctly?
□ Repositories manage data properly?
□ Routes connect all layers successfully?
□ app_package.md implementation is 99% complete?

⚠️ I cannot implement APM until core functionality is working.
This ensures clean architecture principles are followed first.

Would you like me to:
1. Review and complete core functionality first
2. Continue with core development if needed
3. Explain why APM should come after business logic works"
```

## 🎯 Success Metrics

### **Phase 1 Completion (Core Architecture):**
- ✅ AI agent can explain Clean Architecture
- ✅ AI agent can create proper layer structure
- ✅ AI agent follows separation of concerns
- ✅ AI agent implements Filter Pattern correctly

### **Phase 2 Completion (Functional Application):**
- ✅ AI agent can wire all layers together
- ✅ AI agent can initialize the application
- ✅ AI agent can create working routes
- ✅ AI agent can implement proper validation

### **Phase 3 Completion (Production Ready):**
- ✅ Application is fully functional
- ✅ All business requirements are met
- ✅ Code follows Clean Architecture principles
- ✅ Optional: Swagger documentation can be generated
- ✅ Optional: APM can be added for observability

## ⚠️ Common Pitfalls to Avoid

### **❌ Wrong Order:**
```
1. Start with APM implementation
2. Create services without understanding layers
3. Skip architecture principles
4. Implement features without validation
```

### **✅ Right Order:**
```
1. Learn Clean Architecture (project_architecture.md)
2. Master app layer patterns (app_package.md)
3. Connect everything (main_and_routes_guide.md)
4. Add validation (MAP_VALIDATOR_GUIDE.md)
5. Document APIs (swagger_annotation_guide.md)
6. Enhance with APM (apm_and_log_guide.md)
```

## 📋 Final Checklist for AI Agent

Before implementing any feature:
```
□ Have I read project_architecture.md?
□ Do I understand Clean Architecture layers?
□ Have I read app_package.md?
□ Do I understand the Filter Pattern?
□ Have I read main_and_routes_guide.md?
□ Do I know how to connect layers?
□ Have I read MAP_VALIDATOR_GUIDE.md?
□ Do I know how to validate requests?
□ Is app_package.md implementation 99% complete?
□ Are core business features working?
□ Only then: Consider swagger_annotation_guide.md for API docs
□ Only then: Consider apm_and_log_guide.md for monitoring
```

**Remember**: Clean Architecture comes first, documentation and monitoring come later!