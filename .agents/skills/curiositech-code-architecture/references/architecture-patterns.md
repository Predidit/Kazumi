# Architecture Patterns Deep Dive

Detailed reference for the major architecture patterns covered in SKILL.md, with worked TypeScript examples for each.

---

## Clean Architecture — Full Example

Clean Architecture (Robert Martin, 2012) enforces a strict dependency rule: code dependencies point inward only. The outer layers (frameworks, databases) depend on the inner layers (domain, use cases), never the reverse.

### Layer Definitions

**Entities (innermost)**: Enterprise-wide business rules. These are the things your business is about, independent of any application concern. `Order`, `User`, `Payment`, `Invoice`. If you had no computer, these concepts would still exist. They contain business rules that apply across many applications.

**Use Cases**: Application-specific business logic. Each use case represents one action a user or system can take. `CreateOrder`, `ProcessRefund`, `GenerateInvoice`. Use cases orchestrate entity behavior. They can fail — they know about errors, exceptions, and edge cases. They know nothing about HTTP, databases, or UI.

**Interface Adapters**: Convert data between use cases and frameworks. Controllers convert HTTP requests to use case inputs and use case outputs to HTTP responses. Repository implementations convert domain entities to database rows and back. This layer knows about both the domain and the external tools, but its job is translation, not logic.

**Frameworks and Drivers (outermost)**: Express, Fastify, Postgres, Redis, Stripe. These are details. They can be swapped without changing your domain or use cases.

### Worked Example: Order System (TypeScript)

```
src/
  domain/
    entities/
      order.ts
      order-item.ts
    value-objects/
      money.ts
      order-id.ts
    events/
      order-created.event.ts
    repositories/
      order.repository.ts    ← Interface (port)
  application/
    use-cases/
      create-order/
        create-order.use-case.ts
        create-order.command.ts
        create-order.result.ts
      cancel-order/
        cancel-order.use-case.ts
    ports/
      notification.port.ts   ← Interface for notifications
      inventory.port.ts      ← Interface for inventory check
  infrastructure/
    database/
      postgres-order.repository.ts   ← Implements OrderRepository
      order.mapper.ts
    messaging/
      sendgrid-notification.ts       ← Implements NotificationPort
    http/
      order.controller.ts
      order.router.ts
    ioc/
      container.ts           ← Wires everything together
```

**Entity (no framework imports)**:
```typescript
// domain/entities/order.ts
import { OrderItem } from './order-item';
import { Money } from '../value-objects/money';
import { OrderId } from '../value-objects/order-id';
import { OrderCreatedEvent } from '../events/order-created.event';

export type OrderStatus = 'PENDING' | 'CONFIRMED' | 'SHIPPED' | 'CANCELLED';

export class Order {
  private readonly _events: unknown[] = [];

  private constructor(
    public readonly id: OrderId,
    public readonly userId: string,
    private readonly items: OrderItem[],
    private _status: OrderStatus,
    private readonly _createdAt: Date,
  ) {}

  static create(userId: string, items: OrderItem[]): Order {
    if (items.length === 0) throw new Error('Order must have at least one item');

    const order = new Order(
      OrderId.generate(),
      userId,
      items,
      'PENDING',
      new Date(),
    );
    order._events.push(new OrderCreatedEvent(order.id, userId));
    return order;
  }

  get total(): Money {
    return this.items.reduce(
      (sum, item) => sum.add(item.subtotal),
      Money.zero('USD'),
    );
  }

  cancel(): void {
    if (this._status === 'SHIPPED') throw new Error('Cannot cancel shipped order');
    this._status = 'CANCELLED';
  }

  get status(): OrderStatus { return this._status; }
  get domainEvents(): unknown[] { return [...this._events]; }
}
```

**Use Case (no database, no HTTP)**:
```typescript
// application/use-cases/create-order/create-order.use-case.ts
import { Order } from '../../../domain/entities/order';
import { OrderRepository } from '../../../domain/repositories/order.repository';
import { InventoryPort } from '../../ports/inventory.port';
import { NotificationPort } from '../../ports/notification.port';
import { CreateOrderCommand } from './create-order.command';
import { CreateOrderResult } from './create-order.result';

export class CreateOrderUseCase {
  constructor(
    private readonly orderRepo: OrderRepository,
    private readonly inventory: InventoryPort,
    private readonly notifications: NotificationPort,
  ) {}

  async execute(cmd: CreateOrderCommand): Promise<CreateOrderResult> {
    // Check inventory for each item
    for (const item of cmd.items) {
      const available = await this.inventory.isAvailable(item.productId, item.quantity);
      if (!available) {
        throw new InsufficientInventoryError(item.productId);
      }
    }

    // Create the domain entity (business rules enforced here)
    const order = Order.create(cmd.userId, cmd.items);

    // Persist
    await this.orderRepo.save(order);

    // Reserve inventory
    await this.inventory.reserve(order.id, cmd.items);

    // Notify (async — don't fail the order if notification fails)
    this.notifications.orderCreated(order).catch(console.error);

    return { orderId: order.id.value, total: order.total.amount };
  }
}
```

**Repository Interface (in domain layer)**:
```typescript
// domain/repositories/order.repository.ts
import { Order } from '../entities/order';
import { OrderId } from '../value-objects/order-id';

export interface OrderRepository {
  save(order: Order): Promise<void>;
  findById(id: OrderId): Promise<Order | null>;
  findByUserId(userId: string): Promise<Order[]>;
}
```

**Infrastructure implementation (knows about Postgres)**:
```typescript
// infrastructure/database/postgres-order.repository.ts
import { Pool } from 'pg';
import { OrderRepository } from '../../domain/repositories/order.repository';
import { Order } from '../../domain/entities/order';
import { OrderMapper } from './order.mapper';

export class PostgresOrderRepository implements OrderRepository {
  constructor(private readonly pool: Pool) {}

  async save(order: Order): Promise<void> {
    const row = OrderMapper.toPersistence(order);
    await this.pool.query(
      'INSERT INTO orders (id, user_id, status, total_cents, created_at) VALUES ($1,$2,$3,$4,$5) ON CONFLICT (id) DO UPDATE SET ...',
      [row.id, row.userId, row.status, row.totalCents, row.createdAt],
    );
  }

  async findById(id: OrderId): Promise<Order | null> {
    const result = await this.pool.query('SELECT * FROM orders WHERE id = $1', [id.value]);
    if (!result.rows[0]) return null;
    return OrderMapper.toDomain(result.rows[0]);
  }

  async findByUserId(userId: string): Promise<Order[]> {
    const result = await this.pool.query('SELECT * FROM orders WHERE user_id = $1', [userId]);
    return result.rows.map(OrderMapper.toDomain);
  }
}
```

---

## Hexagonal Architecture — Practical Example

Ports and Adapters is a simpler vocabulary: the domain defines ports (interfaces), and adapters implement them. No strict layering beyond "inside the hexagon" vs "outside."

```typescript
// domain/ports/outbound/user-notification.port.ts
// The domain DEFINES this port (what it needs)
export interface UserNotificationPort {
  sendOrderConfirmation(userId: string, orderId: string): Promise<void>;
  sendShippingUpdate(userId: string, trackingNumber: string): Promise<void>;
}

// infrastructure/adapters/outbound/sendgrid-notification.adapter.ts
// An adapter IMPLEMENTS the port
import { UserNotificationPort } from '../../../domain/ports/outbound/user-notification.port';
import { SendGrid } from '@sendgrid/mail';

export class SendGridNotificationAdapter implements UserNotificationPort {
  async sendOrderConfirmation(userId: string, orderId: string): Promise<void> {
    // SendGrid-specific implementation
  }
  async sendShippingUpdate(userId: string, trackingNumber: string): Promise<void> {
    // SendGrid-specific implementation
  }
}

// tests/adapters/fake-notification.adapter.ts
// Test adapter — no real emails
export class FakeNotificationAdapter implements UserNotificationPort {
  public readonly sent: Array<{ type: string; userId: string }> = [];

  async sendOrderConfirmation(userId: string, orderId: string): Promise<void> {
    this.sent.push({ type: 'order-confirmation', userId });
  }
  async sendShippingUpdate(userId: string, trackingNumber: string): Promise<void> {
    this.sent.push({ type: 'shipping-update', userId });
  }
}
```

### Driving Adapters (Primary Ports)

```typescript
// These drive the application from the outside
// HTTP adapter:
class OrderHttpController {
  constructor(private readonly createOrder: CreateOrderUseCase) {}

  async handlePost(req: Request, res: Response) {
    const result = await this.createOrder.execute(CreateOrderCommand.fromRequest(req.body));
    res.json(result);
  }
}

// CLI adapter (same use case, different entry point):
class OrderCliAdapter {
  constructor(private readonly createOrder: CreateOrderUseCase) {}

  async run(args: string[]) {
    const command = CreateOrderCommand.fromCLIArgs(args);
    const result = await this.createOrder.execute(command);
    console.log(`Order created: ${result.orderId}`);
  }
}

// Test adapter (fastest feedback loop):
describe('CreateOrderUseCase', () => {
  it('should create an order and notify', async () => {
    const repo = new InMemoryOrderRepository();
    const notifications = new FakeNotificationAdapter();
    const inventory = new InMemoryInventoryAdapter();
    const useCase = new CreateOrderUseCase(repo, inventory, notifications);

    const result = await useCase.execute(/* ... */);

    expect(result.orderId).toBeDefined();
    expect(notifications.sent).toHaveLength(1);
  });
});
```

---

## Vertical Slice Architecture

Instead of organizing by technical layer, organize by feature slice — each slice contains everything needed to fulfill one user story.

```
src/
  features/
    create-order/
      create-order.handler.ts      ← Entry point (HTTP, CLI, whatever)
      create-order.command.ts      ← Input DTO
      create-order.validator.ts    ← Input validation
      create-order.service.ts      ← Business logic (may be thin)
      create-order.repository.ts   ← Data access (may call shared)
      create-order.test.ts         ← All tests for this slice
    cancel-order/
      ...
    get-order/
      ...
  shared/
    database/
      pg-client.ts
    auth/
      jwt-middleware.ts
    errors/
      application-errors.ts
```

**When this wins**: Teams that frequently add new features without touching old ones. Each slice is independently releasable. No team steps on another team's work. Code deletion is clean (delete the folder).

**When this hurts**: When slices share a lot of logic and you end up with duplicated code across them. Solution: extract to `shared/` but keep the boundary explicit.

---

## Feature-Based Organization — Detailed Structure

```
src/
  features/
    orders/
      # Public API (only exports, never internal paths)
      index.ts

      # Domain (if using Clean Architecture within the feature)
      domain/
        order.entity.ts
        order.repository.interface.ts

      # Application
      application/
        create-order.use-case.ts
        cancel-order.use-case.ts

      # Infrastructure
      infrastructure/
        postgres-order.repository.ts
        order.mapper.ts

      # HTTP
      http/
        orders.controller.ts
        orders.router.ts

      # Tests
      __tests__/
        create-order.use-case.test.ts
        orders.controller.integration.test.ts

    users/
      index.ts
      ...

    payments/
      index.ts
      ...

  shared/
    # Cross-cutting concerns
    database/
      pg-pool.ts
      transaction.ts

    auth/
      jwt.middleware.ts
      auth.guard.ts

    errors/
      domain-error.ts
      http-error.ts

    config/
      app.config.ts
      database.config.ts

  # Entry points
  main.ts
  app.ts
```

**index.ts (public API for the orders feature)**:
```typescript
// src/features/orders/index.ts
export { CreateOrderUseCase } from './application/create-order.use-case';
export { CancelOrderUseCase } from './application/cancel-order.use-case';
export { OrderRepository } from './domain/order.repository.interface';
export { ordersRouter } from './http/orders.router';
export type { Order, OrderStatus } from './domain/order.entity';

// Never export internal implementation details:
// DO NOT: export { PostgresOrderRepository } from './infrastructure/...'
// DO NOT: export { OrderMapper } from './infrastructure/...'
```

---

## SOLID at Module Scale

SOLID principles apply beyond classes to module design:

**Single Responsibility at Module Level**: A module (feature folder) owns one domain concept. If you're making a change to "orders" functionality and you're touching files in three different feature folders, your module boundaries are wrong.

**Open/Closed at Module Level**: You should be able to add a new feature (new folder in `features/`) without modifying existing features. If adding `payments/` requires changing `orders/`, you have a coupling problem.

**Liskov Substitution at Module Level**: Any implementation of a port/interface must be substitutable. If your `PostgresOrderRepository` and `InMemoryOrderRepository` behave differently at the contract level (not just implementation), you have a broken abstraction.

**Interface Segregation at Module Level**: Don't create a massive `OrderService` interface with 20 methods that half the consumers don't use. Create focused interfaces: `OrderReader`, `OrderWriter`, `OrderCanceller`. Consumers depend only on what they need.

**Dependency Inversion at Module Level**: Features depend on shared interfaces (ports), not on each other's concrete implementations. The `payments` feature doesn't import `PostgresOrderRepository` — it imports the `OrderRepository` interface.

---

## Architecture Decision Record Template

Document major architecture decisions. Future-you and your teammates will thank you:

```markdown
# ADR-001: Feature-Based Organization over Layer-Based

## Status
Accepted (2026-01-15)

## Context
We're starting a new order management service. The team is 4 developers.
Layer-based (MVC) is what everyone is familiar with, but feature-based
was proposed for better locality and scalability.

## Decision
We will use feature-based organization with a shared/ folder for
cross-cutting concerns.

## Consequences
Positive:
- All code for a feature is co-located; new team members can ramp up one feature at a time
- Deleting a feature is a folder deletion
- No cross-feature contamination (enforced via import rules)

Negative:
- Some duplication is acceptable within features to avoid coupling
- Requires explicit shared/ module to prevent accidental coupling

## Implementation Notes
- ESLint rule: no internal module imports (only from feature index.ts)
- Shared services must be justified; prefer feature-local implementations
```
