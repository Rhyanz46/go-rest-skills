# Routes & Main.go Setup Guide

> **🤖 AI Agent Reference**: This guide provides EXAMPLES for creating the `routes` folder and `main.go` file that connect all layers of your Clean Architecture application.
>
> **⚠️ IMPORTANT**: Read `ai_instruction/instruction_order.md` for the mandatory learning sequence. This guide should be read AFTER completing `app_package.md`.
>
> **📝 Project Name Format**: Replace `<PROJECT_NAME>` with your actual Go module name:
> - **GitHub:** `github.com/your-org/your-service`
> - **GitLab:** `gitlab.com/company/project-name`
> - **Internal:** `company.internal/product/service-name`
> - **Local:** `my-project` (for local development only)

## 🎯 Purpose

This guide provides:
- Complete understanding of how `main.go` initializes and connects all layers
- How to create `routes` folder to wire HTTP requests to controllers
- The flow from HTTP request → Controller → Use Case → Repository
- Best practices for dependency injection and service initialization

## 📋 Table of Contents

1. [Architecture Flow](#architecture-flow)
2. [Folder Structure](#folder-structure)
3. [🚨 PRE-REQUISITES: Required Dependencies](#-pre-requisites-required-dependencies-user-must-create-manually)
4. [main.go Setup](#main-go-setup)
5. [routes Folder Setup](#routes-folder-setup)
6. [Database Connections](#database-connections)
7. [Service Initialization](#service-initialization)
8. [Controller & Route Wiring](#controller--route-wiring)
9. [Complete Examples](#complete-examples)

## 🔄 Architecture Flow

```text
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   HTTP      │    │  Controller │    │   Use Case  │    │ Repository  │
│   Request   │───▶│   Layer     │───▶│    Layer    │───▶│    Layer    │
│             │    │             │    │             │    │             │
│             │    │ HTTP → DTO  │    │  Business   │    │  Database   │
│             │    │ Validation  │    │   Logic     │    │ Operations  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │                   │
       └───────────────────┼───────────────────┼───────────────────┘
                           │                   │
                    ┌──────┴──────┐    ┌──────┴──────┐
                    │   Routes    │    │   main.go   │
                    │  Wiring     │    │ Initialization│
                    └─────────────┘    └─────────────┘
```

## 📁 Folder Structure

```
<PROJECT_ROOT>/
├── main.go                    # Entry point - orchestrates everything
├── routes/                    # Route definitions and dependency injection
│   ├── init.go              # Route initialization entry point
│   └── rest.go              # All routes and dependency injection
├── app/                      # Application layers
│   ├── controller/           # HTTP handlers
│   ├── use_case/            # Business logic
│   └── repository/          # Data access
├── database/                 # Database connections and schemas
├── config/                   # Configuration management
├── pkg/                      # Shared utilities
└── services/                 # External services (if any)
```

## 🚨 PRE-REQUISITES: Required Dependencies (USER MUST CREATE MANUALLY)

**🛑 STRICT RULE**: AI Agent CANNOT create these dependencies. User MUST create them MANUALLY first:

### 1. pkg/http_middleware/ (MANDATORY - Create Manually)

**Purpose**: Security middleware for CORS, JWT auth, and APM

**User Must Create**:
```
pkg/http_middleware/http.go
```

**Required Functions**:
- `CORS()` - Security headers & CORS
- `JWTAuthentication()` - Token validation
- `CronAuthentication()` - Special auth for cron jobs
- `ElasticAPM()` - APM transaction tracking

**Dependencies**: User must add to go.mod:
- `go.elastic.co/apm/v2`
- `github.com/gin-gonic/gin`
- `github.com/labstack/gommon/log`

### 2. pkg/auth_utils/ (MANDATORY - Create Manually)

**Purpose**: JWT handling and user authentication

**User Must Create**:
```
pkg/auth_utils/models.go      // AuthClaim struct
pkg/auth_utils/token.go      // GenerateToken, ValidateToken
pkg/auth_utils/auth.go       // GetAuthClaim, WithAuthClaim
```

**Dependencies**: User must add to go.mod:
- `github.com/golang-jwt/jwt/v5`
- `github.com/google/uuid`
- `crypto/aes`, `crypto/cipher`

### 3. services/elasticsearch_service/ (MANDATORY - Create Manually)

**Purpose**: Elasticsearch client for logs and configurations

**User Must Create**:
```
services/elasticsearch_service/interfaces.go        // ElasticsearchService interface
services/elasticsearch_service/elasticsearch_service.go // Implementation
```

**Dependencies**: User must add to go.mod:
- `github.com/elastic/go-elasticsearch/v8`
- `github.com/elastic/go-elasticsearch/v8/esapi`

### 4. pkg/apm_helper/ (OPTIONAL - Create Manually if using APM)

**Purpose**: APM function tracking and logging

**User Must Create**:
```
pkg/apm_helper/function_tracker.go    // TrackFunction
pkg/apm_helper/logger.go             // LogToTransaction
```

**Dependencies**: User must add to go.mod:
- `go.elastic.co/apm/v2`
- `github.com/labstack/gommon/log`

### 🚨 AI Agent Behavior for Missing Dependencies:

**If ANY of these dependencies are missing:**

1. **STOP immediately** - DO NOT proceed with routes/main.go creation
2. **Inform user exactly what's missing**:
   ```
   ❌ MISSING DEPENDENCIES:

   pkg/http_middleware/http.go - Required for security middleware
   pkg/auth_utils/models.go - Required for JWT authentication
   pkg/auth_utils/token.go - Required for token validation
   pkg/auth_utils/auth.go - Required for context helpers
   services/elasticsearch_service/interfaces.go - Required for ES client

   Please create these files manually before I can proceed with routes/main.go setup.
   ```

3. **DO NOT offer to create them automatically**
4. **WAIT for user to create them**
5. **VERIFY existence** before proceeding

## 🚀 main.go Setup

### Purpose
- Initialize configuration
- Set up monitoring/logging
- Initialize all dependencies (DB, services, etc.)
- Start the HTTP server

### Complete main.go EXAMPLE:

```go
package main

import (
    "log"

    "go.elastic.co/apm/v2"
    "github.com/gin-gonic/gin"

    "<PROJECT_NAME>/config"
    "<PROJECT_NAME>/routes"

    _ "<PROJECT_NAME>/docs"  // For Swagger docs
)

// @title <PROJECT_NAME> API
// @version 1.0
// @description API for <PROJECT_NAME> using Clean Architecture
// @host localhost:8080
// @BasePath /api/v1
// @securityDefinitions.apikey BearerAuth
// @in header
// @name Authorization
// @description Type "Bearer" followed by a space and JWT token.
func main() {
    // 1. Load configuration
    cfg := config.Init()
    log.Println("✅ Configuration loaded")

    // 2. Initialize monitoring (APM) if enabled
    if err := initMonitoring(cfg); err != nil {
        log.Fatalf("❌ Failed to initialize monitoring: %v", err)
    }
    log.Println("✅ Monitoring initialized")

    // 3. Initialize database connections
    dbs := routes.InitializeDatabases(cfg)
    log.Println("✅ Database connections established")

    // 4. Initialize routes with dependencies
    engine := routes.InitRoutes(dbs.Main)
    log.Println("✅ Routes configured")

    // 5. Start the server
    startServer(engine, cfg.Rest)
}

// initMonitoring initializes APM or other monitoring tools
func initMonitoring(cfg *config.AppConfig) error {
    // Initialize Elastic APM if enabled
    if cfg.APM.Enabled {
        log.Println("📊 Initializing Elastic APM...")

        tracer, err := apm.NewTracer(cfg.APM.ServiceName, "1.0.0")
        if err != nil {
            return err
        }

        apm.SetDefaultTracer(tracer)
        log.Println("✅ APM initialized")
    }

    return nil
}
```

## 🛣️ routes Folder Setup

### Purpose
- Wire dependencies between layers
- Define HTTP routes
- Handle middleware setup
- Initialize controllers, use cases, and repositories

### routes/init.go EXAMPLE:

```go
package routes

import (
    "gorm.io/gorm"

    "<PROJECT_NAME>/app/controller"
    "<PROJECT_NAME>/app/repository"
    "<PROJECT_NAME>/app/use_case"
    "<PROJECT_NAME>/config"
    "<PROJECT_NAME>/database"
)

// DatabaseConnections holds all database connections
type DatabaseConnections struct {
    Main *gorm.DB
    // Add more databases if needed
    // ReadOnly *gorm.DB
    // Cache    *gorm.DB
}

// Services holds all external service instances
type Services struct {
    // Add external services here
    // EmailService   email.Service
    // SMSService    sms.Service
    // StorageService storage.Service
}

// StartServer starts the HTTP server
func startServer(engine *gin.Engine, restConfig config.Rest) {
    address := fmt.Sprintf("%s:%d", restConfig.Address, restConfig.Port)
    log.Printf("🚀 Server starting on %s", address)

    if err := engine.Run(address); err != nil {
        log.Fatalf("❌ Failed to start server: %v", err)
    }
}
```

### routes/rest.go EXAMPLE:

```go
package routes

import (
    "log"

    "<PROJECT_NAME>/app/controller"
    "<PROJECT_NAME>/app/repository"
    "<PROJECT_NAME>/app/use_case"
    "<PROJECT_NAME>/pkg/http_middleware"
    "github.com/gin-gonic/gin"
    "gorm.io/gorm"
)

// Container holds all dependencies
type Container struct {
    UserController controller.Controller
    // Add more controllers here as needed
    // ProductController controller.ProductController
    // OrderController   controller.OrderController
}

// NewContainer creates and wires all dependencies
func NewContainer(db *gorm.DB) *Container {
    // Repository Layer
    userRepo := repository.NewUserRepository(db)
    // productRepo := repository.NewProductRepository(db)

    // Use Case Layer
    userUseCase := use_case.NewUserUseCase(userRepo)
    // productUseCase := use_case.NewProductUseCase(productRepo)

    // Controller Layer
    userController := controller.NewUserController(userUseCase)
    // productController := controller.NewProductController(productUseCase)

    log.Println("✅ All dependencies initialized")

    return &Container{
        UserController: userController,
        // ProductController: productController,
    }
}

// InitRoutes initializes all application routes
func InitRoutes(db *gorm.DB) *gin.Engine {
    router := gin.Default()

    // Apply global middleware
    router.Use(http_middleware.CORS)

    // Create container with all dependencies
    container := NewContainer(db)

    // Public routes (no authentication)
    v1 := router.Group("/api/v1")
    {
        // Health check
        v1.GET("/ping", func(c *gin.Context) {
            c.JSON(200, gin.H{"message": "pong"})
        })

        // Public auth routes
        auth := v1.Group("/auth")
        {
            auth.POST("/login", container.UserController.Login)
            auth.POST("/register", container.UserController.Register)
        }
    }

    // Apply JWT middleware for protected routes
    router.Use(http_middleware.JWTAuthentication)

    // Protected routes (authentication required)
    v1 = router.Group("/api/v1")
    {
        // User routes
        users := v1.Group("/users")
        {
            users.GET("", container.UserController.ListUsers)
            users.GET("/:id", container.UserController.GetUser)
            users.POST("", container.UserController.CreateUser)
            users.PUT("/:id", container.UserController.UpdateUser)
            users.DELETE("/:id", container.UserController.DeleteUser)
        }

        // Add more route groups here
        // products := v1.Group("/products")
        // {
        //     products.GET("", container.ProductController.ListProducts)
        //     products.GET("/:id", container.ProductController.GetProduct)
        //     products.POST("", container.ProductController.CreateProduct)
        //     products.PUT("/:id", container.ProductController.UpdateProduct)
        //     products.DELETE("/:id", container.ProductController.DeleteProduct)
        // }
    }

    log.Println("✅ All routes configured")
    return router
}
```

## 🔗 Database Connection Flow

### database/database.go EXAMPLE:

```go
package database

import (
    "fmt"
    "log"
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
        dsn = "host=localhost user=postgres password=password dbname=mydb port=5432 sslmode=disable TimeZone=Asia/Jakarta"
    }

    var err error
    DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
        Logger: logger.Default.LogMode(logger.Info),
    })

    if err != nil {
        return fmt.Errorf("failed to connect database: %w", err)
    }

    log.Println("✅ Database connected successfully")
    return nil
}

// GetDB returns the database instance
func GetDB() *gorm.DB {
    return DB
}

// AutoMigrate runs database migrations
func AutoMigrate(models ...interface{}) error {
    if DB == nil {
        return fmt.Errorf("database not initialized")
    }

    return DB.AutoMigrate(models...)
}
```

## 🎮 Controller/UseCase/Repository Connection Flow

### EXAMPLE: How layers are connected in routes/init.go

```go
func InitializeControllers(dbs *DatabaseConnections, services *Services) RestRoutes {
    // 1. Repository Layer - Pass database connection
    userRepo := user_repository.NewUserRepository(dbs.Main)
    productRepo := product_repository.NewProductRepository(dbs.Main)

    // 2. Use Case Layer - Pass repositories and services
    userUseCase := user_use_case.NewUserUseCase(userRepo, services.EmailService)
    productUseCase := product_use_case.NewProductUseCase(productRepo)

    // 3. Controller Layer - Pass use cases
    userController := user_controller.NewUserController(userUseCase)
    productController := product_controller.NewProductController(productUseCase)

    return RestRoutes{
        UserRoute:    userController,
        ProductRoute: productController,
    }
}
```

## 📦 Complete Examples

### EXAMPLE: Simple Project (Users only):

```go
// routes/init.go - Simple Version
func InitializeControllers(dbs *DatabaseConnections, services *Services) RestRoutes {
    // Repository
    userRepo := user_repository.NewUserRepository(dbs.Main)

    // Use Case
    userUseCase := user_use_case.NewUserUseCase(userRepo)

    // Controller
    userController := user_controller.NewUserController(userUseCase)

    return RestRoutes{
        UserRoute: userController,
    }
}
```

### EXAMPLE: Complex Project (Multiple domains):

```go
// routes/init.go - Complex Version
func InitializeControllers(dbs *DatabaseConnections, services *Services) RestRoutes {
    // Initialize all repositories
    repos := repository.NewRepositories(dbs.Main, dbs.ReadOnly)

    // Initialize all use cases
    useCases := use_case.NewUseCases(repos, services)

    // Initialize all controllers
    controllers := controller.NewControllers(useCases)

    return RestRoutes{
        UserRoute:     controllers.User,
        ProductRoute:  controllers.Product,
        OrderRoute:    controllers.Order,
        PaymentRoute:  controllers.Payment,
        ReportRoute:   controllers.Report,
    }
}

// repository/init.go
func NewRepositories(mainDB, readOnlyDB *gorm.DB) *Repositories {
    return &Repositories{
        UserRepo:     user_repository.New(mainDB),
        ProductRepo:  product_repository.New(mainDB),
        OrderRepo:    order_repository.New(readOnlyDB), // Read-only for orders
        PaymentRepo:  payment_repository.New(mainDB),
        ReportRepo:   report_repository.New(readOnlyDB),
    }
}

// use_case/init.go
func NewUseCases(repos *Repositories, services *Services) *UseCases {
    return &UseCases{
        UserUseCase:     user_use_case.New(repos.UserRepo, services.EmailService),
        ProductUseCase:  product_use_case.New(repos.ProductRepo, services.StorageService),
        OrderUseCase:    order_use_case.New(repos.OrderRepo, repos.UserRepo, services.PaymentService),
        PaymentUseCase:  payment_use_case.New(repos.PaymentRepo, services.GatewayService),
        ReportUseCase:   report_use_case.New(repos.ReportRepo, services.EmailService),
    }
}
```

## 🎮 Simple vs Complex Examples

### Simple Project (Single Domain - Users only):

```go
// routes/rest.go - Simple Version
func NewContainer(db *gorm.DB) *Container {
    // Repository
    userRepo := repository.NewUserRepository(db)

    // Use Case
    userUseCase := use_case.NewUserUseCase(userRepo)

    // Controller
    userController := controller.NewUserController(userUseCase)

    return &Container{
        UserController: userController,
    }
}
```

### Complex Project (Multiple Domains):

```go
// routes/rest.go - Complex Version
type Container struct {
    UserController    controller.UserController
    ProductController controller.ProductController
    OrderController   controller.OrderController
    PaymentController controller.PaymentController
}

func NewContainer(db *gorm.DB) *Container {
    // Initialize all repositories
    userRepo := repository.NewUserRepository(db)
    productRepo := repository.NewProductRepository(db)
    orderRepo := repository.NewOrderRepository(db)
    paymentRepo := repository.NewPaymentRepository(db)

    // Initialize all use cases
    userUseCase := use_case.NewUserUseCase(userRepo)
    productUseCase := use_case.NewProductUseCase(productRepo)
    orderUseCase := use_case.NewOrderUseCase(orderRepo, userRepo)
    paymentUseCase := use_case.NewPaymentUseCase(paymentRepo)

    // Initialize all controllers
    return &Container{
        UserController:    controller.NewUserController(userUseCase),
        ProductController: controller.NewProductController(productUseCase),
        OrderController:   controller.NewOrderController(orderUseCase),
        PaymentController: controller.NewPaymentController(paymentUseCase),
    }
}
```

## 🔧 Configuration Setup

### config/init.go EXAMPLE:

```go
package config

import (
    "log"
    "os"
)

type AppConfig struct {
    Rest  Rest   `json:"rest"`
    APM   APM    `json:"apm"`
    Database Database `json:"database"`
}

type Rest struct {
    Address  string `json:"address"`
    Port     int    `json:"port"`
    Debug    bool   `json:"debug"`
    Prefix   string `json:"prefix"`
    Swagger  Swagger `json:"swagger"`
}

type APM struct {
    Enabled    bool   `json:"enabled"`
    ServiceName string `json:"service_name"`
    ServerURL   string `json:"server_url"`
    SecretToken string `json:"secret_token"`
}

type Swagger struct {
    Enabled   bool   `json:"enabled"`
    Username  string `json:"username"`
    Password  string `json:"password"`
}

type Database struct {
    Host     string `json:"host"`
    Port     int    `json:"port"`
    User     string `json:"user"`
    Password string `json:"password"`
    Name     string `json:"name"`
    SSLMode  string `json:"sslmode"`
}

func Init() *AppConfig {
    cfg := &AppConfig{
        Rest: Rest{
            Address: getEnv("REST_ADDRESS", "0.0.0.0"),
            Port:    getEnvInt("REST_PORT", 8080),
            Debug:   getEnvBool("REST_DEBUG", false),
            Prefix:  getEnv("REST_PREFIX", "/api/v1"),
            Swagger: Swagger{
                Enabled:  getEnvBool("SWAGGER_ENABLED", true),
                Username: getEnv("SWAGGER_USERNAME", ""),
                Password: getEnv("SWAGGER_PASSWORD", ""),
            },
        },
        APM: APM{
            Enabled:     getEnvBool("APM_ENABLED", false),
            ServiceName: getEnv("APM_SERVICE_NAME", "my-service"),
            ServerURL:   getEnv("APM_SERVER_URL", ""),
            SecretToken: getEnv("APM_SECRET_TOKEN", ""),
        },
        Database: Database{
            Host:     getEnv("DB_HOST", "localhost"),
            Port:     getEnvInt("DB_PORT", 5432),
            User:     getEnv("DB_USER", "postgres"),
            Password: getEnv("DB_PASSWORD", "password"),
            Name:     getEnv("DB_NAME", "mydb"),
            SSLMode:  getEnv("DB_SSLMODE", "disable"),
        },
    }

    log.Println("✅ Configuration initialized")
    return cfg
}

// Helper functions for environment variables
func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if intValue, err := strconv.Atoi(value); err == nil {
            return intValue
        }
    }
    return defaultValue
}

func getEnvBool(key string, defaultValue bool) bool {
    if value := os.Getenv(key); value != "" {
        if boolValue, err := strconv.ParseBool(value); err == nil {
            return boolValue
        }
    }
    return defaultValue
}
```

## ⚠️ Best Practices

1. **Dependency Injection**: Pass dependencies explicitly through constructors
2. **Error Handling**: Always check for errors during initialization
3. **Logging**: Log each initialization step for debugging
4. **Environment Variables**: Use environment variables for configuration
5. **Health Checks**: Always include a health check endpoint
6. **Swagger**: Enable Swagger documentation in development
7. **Middleware**: Apply middleware globally (CORS, logging, etc.)

## 🔍 Common Patterns

### EXAMPLE 1. Repository Initialization:
```go
func NewUserRepository(db *gorm.DB) UserRepository {
    return &userRepository{db: db}
}
```

### EXAMPLE 2. Use Case Initialization:
```go
func NewUserUseCase(repo UserRepository, emailService EmailService) UserUseCase {
    return &userUseCase{
        repo:         repo,
        emailService: emailService,
    }
}
```

### EXAMPLE 3. Controller Initialization:
```go
func NewUserController(useCase UserUseCase) UserController {
    return &userController{useCase: useCase}
}
```

## 🚨 Common Mistakes to Avoid

1. **❌ Circular Dependencies**: Don't import controller in repository
2. **❌ Global Variables**: Don't use global variables for dependencies
3. **❌ Hardcoded Values**: Always use environment variables
4. **❌ Skipping Error Checks**: Always handle initialization errors
5. **❌ Mixing Concerns**: Keep initialization separate from business logic

## ✅ AI Agent Checklist

Before creating routes and main.go:

- [ ] Environment variables are defined (.env file)
- [ ] All app layers (controller/use_case/repository) exist
- [ ] Database connection details are configured
- [ ] External service configs are ready (if any)
- [ ] Swagger documentation is desired
- [ ] Monitoring/APM is needed

**⚠️ REMINDER**: These are EXAMPLES only - adjust to your specific project requirements!