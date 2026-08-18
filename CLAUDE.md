# Claude Configuration

## Change Requests
All work must be defined in a change request (a GitHub Issue) before implementation
begins. A change request states what changes, why, how it will be implemented, and
how it will be tested.

Canonical rule, applies to every repo:
https://gist.githubusercontent.com/frizman21/8999e3d47a9ee9f40a0ceda4f20be8f9/raw/19600ec1b432ae86a5c85c3899831557a5b7e90e/gistfile1.txt

Read it before starting work on an issue and before opening a PR.

## Dependency Updates
Dependabot pull requests are worked one dependency at a time, with breaking-change
fixes in the same PR that introduced them, and existing test coverage preserved
rather than weakened to make a bump pass.

Canonical rule, applies to every repo:
https://gist.githubusercontent.com/frizman21/b36ee602d7e5b30061c989fa2f9300f5/raw/faba3c844bcdbdd973a69d1b09ab5095e6825dd2/gistfile1.txt

Read it before touching a Dependabot PR. It covers the baseline suites to run
before and after — including a production-environment boot with eager loading,
which the unit tests do not exercise — and when to escalate instead of forcing a
resolution.

## Data Model
See `docs/application-data-structures.md` for the data structures the
application is built from (Source, SourceDatum, SourceProcessingReport, Skill,
SkillRevision, Project) and for the ontology that carries knowledge content
(EntityType, EntityTypeAttribute, Entity, EntityAttributeValue, Relationship).

A new kind of thing is a row in `entity_types`, not a new model and a
migration. Note that `EntityTypeAttribute` names its enumeration column
`value_type`: `type` is reserved by Rails for single-table inheritance.

The "tier 1 knowledge entity" pattern and every entity that followed it
(Person, Organization, Facility, Part, Science, Technology, Contract and the
relationships among them) were removed in change request #4, along with
`docs/data-model-spec.md`. Do not reintroduce that shape.

## Development Environment
This project runs in Docker containers. All Rails and database commands must be executed within the containerized environment.

**Note**: You can assume the development environment is running when testing or development work is needed.

## Command Patterns
All commands below run inside the web container. Substitute `[prefix]` with:

```
docker-compose exec web bundle exec
```

(For shell access, use `docker-compose exec web bash` instead.)

- **Rails commands**: `[prefix] rails [command]`
- **Rails console**: `[prefix] rails console`
- **Database commands**: `[prefix] rails db:[command]`

## Testing
This project uses Rails' built-in test framework (Minitest) with the following commands:

- **Run all tests**: `[prefix] rails test`
- **Run all tests with fresh database**: `[prefix] rails test:db`
- **Run specific test file**: `[prefix] rails test test/models/travel_test.rb`
- **Run specific test**: `[prefix] rails test test/models/travel_test.rb:test_method_name`
- **Run model tests**: `[prefix] rails test test/models/`
- **Run controller tests**: `[prefix] rails test test/controllers/`
- **Run system tests**: `[prefix] rails test:system`

**IMPORTANT**: Always run tests after making changes to views, controllers, or models to ensure nothing is broken:
- After updating view templates (especially forms), run system tests to ensure they still render and function correctly
- After modifying controllers, run controller tests to verify endpoints still work
- After changing models or database-related code, run model tests
- For significant changes, run the full test suite to catch any unexpected interactions

## Linting/Code Quality
- **Lint command**: [Add specific linting command when known]
- **Type checking**: [Add type checking command when known]

## Database Seeding
- **Seed database**: `[prefix] rails db:seed`
- **Reset and seed**: `[prefix] rails db:reset`

## Seed Data for New Models/Controllers/Views
**IMPORTANT**: Whenever a new model, controller, or view is created (or an existing one is modified in a way that affects what is shown on screen), automatically add representative seed data to `db/seeds.rb` and run `db:seed` so the visual changes can be reviewed immediately in the browser.

- Add enough records to exercise the view (e.g., multiple rows for index pages, a variety of attribute values where relevant).
- Make the seed code idempotent (e.g., use `find_or_create_by!` or guard with `Model.exists?`) so re-running seeds does not create duplicates.
- After updating seeds, run: `[prefix] rails db:seed`.

## JavaScript and Turbo Drive
**IMPORTANT**: This Rails 7+ application uses Turbo Drive which intercepts navigation and can prevent JavaScript from loading properly on initial page visits (works on refresh but not on first load).

**Always apply this pattern when adding JavaScript to views:**

```javascript
function initializeMyForm() {
  // Your JavaScript initialization code here
  const element = document.getElementById('my-element');
  if (element) {
    element.addEventListener('click', myFunction);
  }
}

// Initialize on both DOMContentLoaded and Turbo events
document.addEventListener('DOMContentLoaded', initializeMyForm);
document.addEventListener('turbo:load', initializeMyForm);
document.addEventListener('turbo:frame-load', initializeMyForm);
```

**Key Points:**
- Wrap all initialization in a reusable function
- Add safety checks for element existence
- Listen for all three events: `DOMContentLoaded`, `turbo:load`, and `turbo:frame-load`
- This ensures JavaScript works on first visit, navigation, and refresh

**Preventing Duplicate Event Listeners:**
Since the initialization function runs multiple times with Turbo, prevent duplicate event listeners by cloning elements to remove existing listeners:

```javascript
// Remove existing listeners by cloning the element
const button = document.getElementById('my-button');
if (button) {
  const newButton = button.cloneNode(true);
  button.parentNode.replaceChild(newButton, button);
  newButton.addEventListener('click', myFunction);
}
```

This prevents issues like buttons triggering multiple times or forms adding duplicate rows.