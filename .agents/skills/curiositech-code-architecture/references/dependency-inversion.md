# Dependency Inversion — IoC Containers and Injection Patterns

Dependency inversion is the D in SOLID. This reference covers concrete IoC container implementations in TypeScript and Python, constructor injection patterns, and the honest answer to when DI is overkill.

---

## The Core Idea

Without DI:
```typescript
// Hard-coded dependency — untestable in isolation
class OrderService {
  private db = new PostgresConnection(process.env.DATABASE_URL);
  private mailer = new SendGridMailer(process.env.SENDGRID_API_KEY);

  async createOrder(userId: string) {
    // Can't test this without a real Postgres and real SendGrid
  }
}
```

With constructor injection:
```typescript
// Dependencies are injected — testable with any implementation
class OrderService {
  constructor(
    private readonly db: OrderRepository,     // Interface
    private readonly mailer: NotificationPort, // Interface
  ) {}

  async createOrder(userId: string) {
    // Test by passing in-memory implementations
  }
}
```

---

## TypeScript Patterns

### Manual Constructor Injection (No Container)

For small to medium applications, wire dependencies manually. Simple, explicit, no magic:

```typescript
// infrastructure/ioc/composition-root.ts
import { Pool } from 'pg';
import { PostgresOrderRepository } from '../database/postgres-order.repository';
import { SendGridNotificationAdapter } from '../messaging/sendgrid-notification.adapter';
import { CreateOrderUseCase } from '../../application/use-cases/create-order.use-case';
import { OrderController } from '../http/order.controller';

export function buildDependencies() {
  // Infrastructure
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });

  // Adapters
  const orderRepo = new PostgresOrderRepository(pool);
  const notifications = new SendGridNotificationAdapter(process.env.SENDGRID_KEY!);

  // Use Cases
  const createOrder = new CreateOrderUseCase(orderRepo, notifications);

  // Controllers
  const orderController = new OrderController(createOrder);

  return { orderController };
}

// main.ts
const { orderController } = buildDependencies();
app.use('/orders', orderController.router());
```

**Pros**: Zero magic, easy to trace, excellent TypeScript intellisense, no decorators.
**Cons**: As the app grows, this file becomes a wall of wiring code.

### InversifyJS (Decorator-Based IoC Container)

For large TypeScript applications needing automatic resolution:

```bash
npm install inversify reflect-metadata
# tsconfig.json: "experimentalDecorators": true, "emitDecoratorMetadata": true
```

```typescript
// Define symbols (tokens) for each type
// infrastructure/ioc/symbols.ts
export const SYMBOLS = {
  OrderRepository: Symbol('OrderRepository'),
  NotificationPort: Symbol('NotificationPort'),
  CreateOrderUseCase: Symbol('CreateOrderUseCase'),
};

// Mark injectable classes
// application/use-cases/create-order.use-case.ts
import { inject, injectable } from 'inversify';
import { SYMBOLS } from '../../infrastructure/ioc/symbols';

@injectable()
export class CreateOrderUseCase {
  constructor(
    @inject(SYMBOLS.OrderRepository) private readonly orderRepo: OrderRepository,
    @inject(SYMBOLS.NotificationPort) private readonly notifications: NotificationPort,
  ) {}
}

// infrastructure/ioc/container.ts
import { Container } from 'inversify';
import 'reflect-metadata';

const container = new Container();
container.bind(SYMBOLS.OrderRepository).to(PostgresOrderRepository).inSingletonScope();
container.bind(SYMBOLS.NotificationPort).to(SendGridNotificationAdapter).inSingletonScope();
container.bind(SYMBOLS.CreateOrderUseCase).to(CreateOrderUseCase).inTransientScope();

export { container };

// Usage
const useCase = container.get<CreateOrderUseCase>(SYMBOLS.CreateOrderUseCase);
```

**For tests** (swap to in-memory implementations):
```typescript
const testContainer = new Container();
testContainer.bind(SYMBOLS.OrderRepository).to(InMemoryOrderRepository).inSingletonScope();
testContainer.bind(SYMBOLS.NotificationPort).to(FakeNotificationAdapter).inSingletonScope();
testContainer.bind(SYMBOLS.CreateOrderUseCase).to(CreateOrderUseCase).inTransientScope();
```

### TSyringe (Microsoft — Lighter than InversifyJS)

```bash
npm install tsyringe reflect-metadata
```

```typescript
import { injectable, inject, container } from 'tsyringe';

@injectable()
class CreateOrderUseCase {
  constructor(
    @inject('OrderRepository') private repo: OrderRepository,
    @inject('NotificationPort') private notif: NotificationPort,
  ) {}
}

// Registration
container.register('OrderRepository', { useClass: PostgresOrderRepository });
container.register('NotificationPort', { useClass: SendGridAdapter });

// Resolution
const useCase = container.resolve(CreateOrderUseCase);
```

### NestJS DI (Framework-Level)

NestJS has DI built in. If you're using NestJS, don't use InversifyJS or TSyringe — use NestJS's built-in system:

```typescript
// orders.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([OrderEntity])],
  controllers: [OrdersController],
  providers: [
    CreateOrderUseCase,
    {
      provide: 'OrderRepository',
      useClass: TypeOrmOrderRepository,
    },
    {
      provide: 'NotificationPort',
      useClass: SendGridAdapter,
    },
  ],
  exports: ['OrderRepository'],
})
export class OrdersModule {}

// For tests
describe('CreateOrderUseCase', () => {
  let useCase: CreateOrderUseCase;

  beforeEach(async () => {
    const module = await Test.createTestingModule({
      providers: [
        CreateOrderUseCase,
        { provide: 'OrderRepository', useClass: InMemoryOrderRepository },
        { provide: 'NotificationPort', useClass: FakeNotificationAdapter },
      ],
    }).compile();

    useCase = module.get(CreateOrderUseCase);
  });
});
```

---

## Python Patterns

### Manual Constructor Injection

Python doesn't require decorators for injection. Constructor injection is idiomatic:

```python
# domain/ports/order_repository.py
from abc import ABC, abstractmethod
from typing import Optional
from .order import Order

class OrderRepository(ABC):
    @abstractmethod
    async def save(self, order: Order) -> None: ...

    @abstractmethod
    async def find_by_id(self, order_id: str) -> Optional[Order]: ...


# application/use_cases/create_order.py
class CreateOrderUseCase:
    def __init__(
        self,
        order_repo: OrderRepository,
        notification_port: NotificationPort,
        inventory_port: InventoryPort,
    ) -> None:
        self._order_repo = order_repo
        self._notification_port = notification_port
        self._inventory_port = inventory_port

    async def execute(self, command: CreateOrderCommand) -> CreateOrderResult:
        # Business logic — no database, no HTTP, no framework
        ...


# infrastructure/composition_root.py
from infrastructure.database import PostgresOrderRepository
from infrastructure.messaging import SendGridAdapter
from application.use_cases import CreateOrderUseCase

def build_dependencies() -> dict:
    pool = asyncpg.create_pool(os.environ["DATABASE_URL"])
    order_repo = PostgresOrderRepository(pool)
    notifications = SendGridAdapter(os.environ["SENDGRID_KEY"])
    create_order = CreateOrderUseCase(order_repo, notifications, ...)
    return {"create_order": create_order}
```

### dependency-injector (Python Library)

For larger Python apps needing autowiring:

```bash
pip install dependency-injector
```

```python
# infrastructure/ioc/container.py
from dependency_injector import containers, providers
from infrastructure.database import PostgresOrderRepository
from infrastructure.messaging import SendGridAdapter
from application.use_cases import CreateOrderUseCase

class Container(containers.DeclarativeContainer):
    config = providers.Configuration()

    pool = providers.Singleton(
        asyncpg.create_pool,
        dsn=config.database.url,
    )

    order_repository = providers.Singleton(
        PostgresOrderRepository,
        pool=pool,
    )

    notification_port = providers.Singleton(
        SendGridAdapter,
        api_key=config.sendgrid.api_key,
    )

    create_order_use_case = providers.Factory(
        CreateOrderUseCase,
        order_repo=order_repository,
        notification_port=notification_port,
    )


# main.py
container = Container()
container.config.from_env()

create_order = container.create_order_use_case()
```

**For tests**:
```python
def test_create_order():
    with container.order_repository.override(InMemoryOrderRepository()):
        with container.notification_port.override(FakeNotificationAdapter()):
            use_case = container.create_order_use_case()
            result = asyncio.run(use_case.execute(command))
            assert result.order_id is not None
```

### FastAPI Dependency Injection

FastAPI has built-in DI for HTTP handlers — use it for request-level dependencies, not for core application wiring:

```python
# For HTTP-level concerns (auth, request context):
def get_current_user(token: str = Depends(oauth2_scheme)) -> User:
    return verify_jwt(token)

@app.post("/orders")
async def create_order(
    command: CreateOrderCommand,
    current_user: User = Depends(get_current_user),  # HTTP-level DI
    use_case: CreateOrderUseCase = Depends(get_use_case),  # App-level
):
    return await use_case.execute(command.with_user(current_user.id))
```

**Anti-pattern**: Putting business logic in `Depends()` functions. They're for request-scoped concerns (auth, rate limiting, request ID). Use Cases contain business logic and are wired at startup.

---

## When DI Is Overkill

DI containers are an investment. They pay off when:
- You have many classes with complex dependency trees
- You frequently need to swap implementations (testing, multiple environments)
- Multiple developers would otherwise manually wire the same dependencies

DI containers are overkill when:

**Small scripts and lambdas**:
```python
# A serverless function doesn't need DI
def handler(event, context):
    order = parse_order(event)
    save_to_dynamodb(order)     # Just call it directly
    send_email(order)
    return {"statusCode": 200}
```

**Go** — the community consensus is that constructor injection without a container is idiomatic Go:
```go
// Go: just wire in main()
func main() {
    db := postgres.Connect(os.Getenv("DATABASE_URL"))
    orderRepo := postgres.NewOrderRepository(db)
    notifications := sendgrid.NewAdapter(os.Getenv("SENDGRID_KEY"))
    useCase := orders.NewCreateOrderUseCase(orderRepo, notifications)
    server := http.NewServer(useCase)
    server.Run(":8080")
}
```

**When you only have one implementation** of each interface and no plans to change it: the interface adds ceremony without enabling flexibility. Build the interface when you need the swap, not preemptively.

**Simple data pipelines**: Where the "business logic" is transformations on data, not complex domain rules with invariants.

---

## DI Anti-Patterns

### Service Locator (Global Registry)

```typescript
// Anti-pattern: Service Locator
const services = new ServiceLocator();

class CreateOrderUseCase {
  execute() {
    // Hidden dependency — impossible to test without the global registry
    const repo = services.get<OrderRepository>('orderRepo');
    const mailer = services.get<NotificationPort>('mailer');
  }
}
```

The Service Locator is a dependency inversion failure: dependencies are pulled from a global object rather than injected. It hides what the class needs, making it impossible to understand from the constructor signature alone. Test setup becomes complex ("what services do I need to register for this test?").

### Constructor Parameter Explosion

```typescript
// Anti-pattern: too many constructor parameters
class CreateOrderUseCase {
  constructor(
    private orderRepo: OrderRepository,
    private userRepo: UserRepository,
    private inventoryService: InventoryService,
    private paymentService: PaymentService,
    private notificationService: NotificationService,
    private auditLog: AuditLogService,
    private discountCalculator: DiscountCalculator,
    private taxService: TaxService,
  ) {}
}
```

Eight constructor parameters signals the class is doing too much. It violates Single Responsibility. Solutions:
1. Split into multiple use cases (CreateOrderUseCase + ApplyDiscountUseCase)
2. Group related dependencies into a facade (OrderFulfillmentService that aggregates inventory + payment + notification)
3. Use an explicit command-handler pattern where the handler orchestrates sub-operations

### Injecting Factories Instead of Dependencies

```typescript
// Anti-pattern: injecting factories
class CreateOrderUseCase {
  constructor(private readonly repoFactory: () => OrderRepository) {}

  async execute() {
    const repo = this.repoFactory();  // Why? Just inject the repo
  }
}

// Only inject a factory when you genuinely need different instances
// (e.g., per-tenant database connections, scoped resources)
```

---

## Testing Without DI Containers

Even without a container, you can test with injected fakes:

```typescript
// In test:
const orderRepo = new InMemoryOrderRepository();
const notifications = new SpyNotificationAdapter();
const useCase = new CreateOrderUseCase(orderRepo, notifications);

await useCase.execute({ userId: 'user-1', items: [...] });

expect(orderRepo.orders.size).toBe(1);
expect(notifications.sentMessages).toHaveLength(1);
expect(notifications.sentMessages[0].type).toBe('order-confirmation');
```

The fake/spy classes live in `src/__tests__/fakes/` or alongside their interface in `src/domain/repositories/__tests__/`:

```typescript
// src/__tests__/fakes/in-memory-order.repository.ts
export class InMemoryOrderRepository implements OrderRepository {
  public readonly orders = new Map<string, Order>();

  async save(order: Order): Promise<void> {
    this.orders.set(order.id.value, order);
  }

  async findById(id: OrderId): Promise<Order | null> {
    return this.orders.get(id.value) ?? null;
  }

  async findByUserId(userId: string): Promise<Order[]> {
    return Array.from(this.orders.values()).filter(o => o.userId === userId);
  }
}
```

This is simpler than mocking frameworks for domain-level testing. The fake is real code — it can have assertions, state inspection, and behavior customization without complex mock setup.
