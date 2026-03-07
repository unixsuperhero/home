# Refactoring Principles

Apply these principles when refactoring code. The user may provide additional context: $ARGUMENTS

---

## Core Philosophy

Refactor toward **composable, reusable code** by separating concerns across clear abstraction layers. Think "functional core, imperative shell" (Gary Bernhardt).

**ALMOST NEVER:** Use inheritance.
**ALMOST ALWAYS:** Favor composition.

---

## 1. Data-First

**Separate data from behavior.**

- Extract **value objects** that represent pure data
- Prefer methods that **return data** over methods that perform actions
- Data should flow through the system; behavior operates on data at boundaries
- When you see a method doing both computation AND side-effects, split it

**Goal:** Lower-level abstractions should be more **declarative** with **referential transparency** - a method name should consistently represent the same value (given the same state/args).

```ruby
# Before: mixed concerns
def process_order(order)
  total = order.items.sum(&:price) * (1 - order.discount)
  send_email(order.customer, total)
  save_to_db(order, total)
end

# After: data-first
def calculate_total(order)
  order.items.sum(&:price) * (1 - order.discount)
end
# Side effects happen elsewhere, at the boundary
```

---

## 2. Interface Over Implementation

**The interface IS the design.**

What matters most:
- **Method name** - clear, intention-revealing
- **Arguments** - minimal, well-typed
- **Return value** - predictable, useful

Requirements for composable objects:
- **No side-effects** in data/computation methods
- **Single atomic operation** per method (I call these "atomic operations")
- Methods expose information/possibilities, not workflows

```ruby
# Good: exposes possibilities via clear interface
class OrderCalculator
  def initialize(order) = @order = order

  def subtotal = @order.items.sum(&:price)
  def discount_amount = subtotal * @order.discount_rate
  def total = subtotal - discount_amount
  def tax(rate) = total * rate
  def final_total(tax_rate) = total + tax(tax_rate)
end
# Caller composes what they need from these atomic operations
```

---

## 3. Levels of Abstraction

Different rules for different layers:

### Low-Level (Data & Computation)
- **Atomic operations only** - one thing per method
- **Expose possibilities** - let callers compose
- **Minimal conditionals** - push decisions up
- **Pure functions** where possible
- These are your building blocks

### Mid-Level (Composition)
- Compose low-level objects
- Expose **domain-relevant data**
- Still mostly side-effect free
- Translate between raw data and domain concepts

### High-Level (Human/Business)
- **Human-focused interface** - names match what users care about
- **Business logic and procedures** live here (service layer)
- **Orchestrates** mid/low level objects
- **Side-effects happen here** at the boundary
- Should NOT do low-level data manipulation directly

```ruby
# Low: atomic, composable
class PriceCalculator
  def base_price(item) = item.unit_price * item.quantity
  def with_tax(amount, rate) = amount * (1 + rate)
end

# Mid: composes low-level, exposes domain data
class CartPricing
  def initialize(cart, calculator = PriceCalculator.new)
    @cart, @calc = cart, calculator
  end

  def line_totals = @cart.items.map { @calc.base_price(_1) }
  def subtotal = line_totals.sum
  def total_with_tax(rate) = @calc.with_tax(subtotal, rate)
end

# High: human-focused, orchestrates, side-effects at boundary
class CheckoutService
  def complete_purchase(cart, payment_method)
    pricing = CartPricing.new(cart)
    total = pricing.total_with_tax(TaxRates.for(cart.region))

    # Side effects at the high level boundary
    charge = PaymentGateway.charge(payment_method, total)
    OrderRepository.save(cart, charge)
    Mailer.send_receipt(cart.customer, total)
  end
end
```

---

## 4. Separate Presentation from Application

**Formatting and display are not business logic.**

Presentation logic:
- String formatting, templates, output structure
- CLI output, JSON serialization, HTML rendering
- User-facing messages, labels, formatting

Application logic:
- Domain rules, calculations, state transitions
- What data exists and how it relates
- Business decisions

Keep them in separate layers. Application code returns data; presentation code formats it.

```ruby
# Bad: application logic mixed with presentation
def show_order_status(order)
  if order.shipped?
    puts "Shipped on #{order.shipped_at.strftime('%B %d, %Y')}"
  elsif order.total > 100
    puts "Large order - Priority processing"
  else
    puts "Processing..."
  end
end

# Good: separated
class OrderStatus
  def initialize(order) = @order = order

  def state
    return :shipped if @order.shipped?
    return :priority if @order.total > 100
    :processing
  end

  def shipped_at = @order.shipped_at
end

class OrderStatusPresenter
  LABELS = { shipped: "Shipped on %s", priority: "Large order - Priority processing", processing: "Processing..." }

  def initialize(status) = @status = status

  def to_s
    case @status.state
    when :shipped then LABELS[:shipped] % @status.shipped_at.strftime('%B %d, %Y')
    else LABELS[@status.state]
    end
  end
end
```

---

## 5. Don't Mix Abstraction Levels

**Each method/class should operate at ONE level of abstraction.**

A method that mixes levels is hard to read and modify. When you see high-level intent next to low-level details, extract the details.

```ruby
# Bad: mixed levels in one method
def create_user_account(params)
  # High-level: validation
  return { error: "Invalid" } unless params[:email]&.match?(URI::MailTo::EMAIL_REGEXP)

  # Low-level: string manipulation
  username = params[:email].split('@').first.gsub(/[^a-z0-9]/i, '_').downcase

  # High-level: persistence
  user = User.create!(email: params[:email], username: username)

  # Low-level: formatting
  { success: true, message: "Welcome, #{user.username}!", id: user.id }
end

# Good: each method at one level
def create_user_account(params)
  return validation_error unless valid_email?(params[:email])

  user = User.create!(
    email: params[:email],
    username: username_from_email(params[:email])
  )

  success_response(user)
end

def valid_email?(email) = email&.match?(URI::MailTo::EMAIL_REGEXP)
def username_from_email(email) = email.split('@').first.gsub(/[^a-z0-9]/i, '_').downcase
def validation_error = { error: "Invalid" }
def success_response(user) = { success: true, message: "Welcome, #{user.username}!", id: user.id }
```

Signs you're mixing levels:
- A method has both loops/regex AND service calls
- Reading the method requires constant context-switching
- Some lines describe "what" while others describe "how"

---

## 6. Naming: Nouns Over Verbs

**Methods should be named for what they return, not what they do.**

### Method Naming Rules

In mid/low-level code, avoid verbs in method names unless the method's **only purpose** is to mutate internal state (like `push`/`pop` on an array).

If a method returns a value derived from state (or state + args), name it after **what the return value IS**:

```ruby
# Bad: verb-based naming
def strip_frontmatter(text)
  # ... returns content without frontmatter
end

def calculate_total(order)
  # ... returns a number
end

def resolve_task(name)
  # ... returns a task object
end

# Good: noun-based naming (what it returns)
def prompt  # returns the prompt content
def total   # returns the total
def task    # returns the task
```

### Class Naming Rules

Avoid actor/verb naming conventions. When you see an actor class, don't just rename it - consider where the logic belongs:

```ruby
# Bad: actor names (verbs disguised as nouns)
class TaskStarter; end
class TaskSwitcher; end
class AppResolver; end

# Also bad: just dropping the suffix
class TaskStart; end   # Still verb-based, not a thing

# Better: Add a method to the existing object
class Task
  def start; end       # Task#start - the task starts itself
  def switch_to; end   # Task#switch_to
end

class App
  def resolved_path; end  # App#resolved_path - returns the resolved path
end
```

**Decision process for actor classes:**

1. **First choice:** Look for an existing object that should own this behavior
   - `TaskStarter` → Does `Task` exist? Add `Task#start`
   - `AppResolver` → Does `App` exist? Add `App#resolved_path`
   - Make sure it's the same kind of object (not a different `Task` from another context)

2. **If logic is complex:** Extract to a helper class named after **what it represents**, not what it does
   - `TaskStarter` → `Task::Validation` or `Task::Prerequisites` (the things being checked)
   - `PriceCalculator` → `Pricing` or `CartPricing` (the pricing data)
   - Then `Task#start` can use these helpers internally

3. **Name extracted classes after data/state, not actions:**
   ```ruby
   # Bad
   class Task::TaskStarter; end
   class Task::TaskValidator; end

   # Good
   class Task::StartPrerequisites; end  # The prerequisites for starting
   class Task::ValidationResult; end    # The result of validation
   class Task::Status; end              # The current status
   ```

### Extract to Value Objects

When a method doesn't belong in the current class, extract it to a value object that owns that data:

```ruby
# Bad: Queue class has strip_frontmatter
class Queue
  def strip_frontmatter(text)
    # ... parsing logic
  end
end

# Good: Prompt value object owns its own data
class Prompt
  def initialize(doc)
    @doc = doc
  end

  def frontmatter           # the parsed frontmatter hash
    @doc.front_matter
  end

  def frontmatter_value(key) # a specific frontmatter value
    frontmatter[key]
  end

  def prompt                 # doc content without frontmatter
    @doc.content.strip
  end

  def task_name
    frontmatter_value('task_name')
  end
end
```

The value object:
- Owns the data it represents
- Exposes data through noun-named accessors
- Keeps related data together

---

## 7. File Organization

**Name files after the main class/module they define.**

Follow the project's conventions for file locations. Each file should define one primary class, with inner classes in subdirectories.

```
# Bad: lib/hiiro/tasks.rb defines multiple top-level classes
class Hiiro
  class TaskManager; end      # Main class
  class TaskManager::Config; end  # Inner class
  class Environment; end      # Separate class, doesn't belong here
  class Task; end             # Separate class, doesn't belong here
  class Tree; end             # Separate class, doesn't belong here
end

# Good: Extract to proper file structure
lib/hiiro/task_manager.rb         # Hiiro::TaskManager (main class)
lib/hiiro/task_manager/config.rb  # Hiiro::TaskManager::Config (inner class)
lib/hiiro/environment.rb          # Hiiro::Environment (separate file)
lib/hiiro/task.rb                 # Hiiro::Task (separate file)
lib/hiiro/tree.rb                 # Hiiro::Tree (separate file)
```

### Inner Classes vs Top-Level Classes

If an "inner" class is used throughout the codebase (not just by its parent), promote it to the appropriate namespace:

```ruby
# Bad: Queue::Prompt is used everywhere but nested under Queue
class Queue
  class Prompt; end  # Used by TaskLauncher, Environment, Commands...
end

# Good: Promote to accessible namespace if widely used
class Prompt; end  # Or Hiiro::Prompt if that's the project convention
```

### Alternate Constructors

Classes that need to be constructed from different sources should provide **alternate constructors** with the `from_` prefix:

```ruby
class Prompt
  def initialize(doc)
    @doc = doc
  end

  # Alternate constructor - builds from a file path
  def self.from_file(path)
    doc = FrontMatterParser::Parser.parse_file(path)
    new(doc)
  end

  # Alternate constructor - builds from raw text
  def self.from_text(text)
    doc = FrontMatterParser::Parser.new(:md).call(text)
    new(doc)
  end
end

# Usage
prompt = Prompt.from_file('/path/to/file.md')
prompt = Prompt.from_text("---\ntitle: Hello\n---\nContent")
prompt = Prompt.new(already_parsed_doc)
```

This pattern:
- Keeps `initialize` simple (takes the canonical form)
- Makes construction context explicit in the method name
- Allows the class to be easily used in different contexts

---

## Refactoring Checklist

When reviewing code, ask:

1. **Is data mixed with behavior?** Extract value objects / computation methods
2. **Does this method have side-effects AND return data?** Split it
3. **Is this method doing multiple things?** Break into atomic operations
4. **Are there conditionals in low-level code?** Push decisions up to callers
5. **Is low-level code making business decisions?** Move logic up the stack
6. **Is high-level code doing data manipulation?** Extract to lower layer
7. **Is the interface clear?** Method name, args, return value should be obvious
8. **Can this be composed?** If not, it might be doing too much
9. **Is presentation mixed with logic?** Separate formatting from domain rules
10. **Does this method mix abstraction levels?** Extract details to helpers
11. **Does this method have a verb name but return data (and doesn't modify internal state)?** Rename to what it returns
12. **Is this class named like an actor (TaskStarter)?** Move logic to the object it acts on (Task#start), or extract to a noun class (Task::Status)
13. **Does this method belong here?** If not, extract to a value object that owns the data
14. **Is this file named after its main class?** Rename file to match (e.g., `tasks.rb` → `task_manager.rb`)
15. **Are there multiple top-level classes in one file?** Extract each to its own file
16. **Is this inner class used throughout the codebase?** Promote to an accessible namespace
17. **Does this class need to be constructed from different sources?** Add `from_*` alternate constructors
18. **Is this using inheritance?** Refactor to use composition instead

---

## Apply Now

Look at the code in context and identify refactoring opportunities based on these principles. Prioritize changes that:
1. Separate data from behavior
2. Create clear, composable interfaces
3. Respect abstraction boundaries
4. Keep presentation separate from application logic
5. Maintain consistent abstraction level within each method
6. Use noun-based naming (methods named for what they return, classes named for things)
7. Organize files properly (one main class per file, named after that class)

Explain your reasoning as you refactor.
