# Claude Configuration

## Development Environment
This project runs in Docker containers. All Rails and database commands must be executed within the containerized environment.

**Note**: You can assume the development environment is running when testing or development work is needed.

## Command Patterns
- **Rails commands**: `docker-compose exec web bundle exec rails [command]`
- **Rails console**: `docker-compose exec web bundle exec rails console`
- **Database commands**: `docker-compose exec web bundle exec rails db:[command]`
- **General shell access**: `docker-compose exec web bash`

## Testing
This project uses Rails' built-in test framework (Minitest) with the following commands:

- **Run all tests**: `docker-compose exec web bundle exec rails test`
- **Run all tests with fresh database**: `docker-compose exec web bundle exec rails test:db`
- **Run specific test file**: `docker-compose exec web bundle exec rails test test/models/travel_test.rb`
- **Run specific test**: `docker-compose exec web bundle exec rails test test/models/travel_test.rb:test_method_name`
- **Run model tests**: `docker-compose exec web bundle exec rails test test/models/`
- **Run controller tests**: `docker-compose exec web bundle exec rails test test/controllers/`
- **Run system tests**: `docker-compose exec web bundle exec rails test:system`
- **Run business card tests** (skipped by default to avoid OpenAI API costs): `docker-compose exec -e BUSINESS_CARD_TESTS=true web bundle exec rails test`

**IMPORTANT**: Always run tests after making changes to views, controllers, or models to ensure nothing is broken:
- After updating view templates (especially forms), run system tests to ensure they still render and function correctly
- After modifying controllers, run controller tests to verify endpoints still work
- After changing models or database-related code, run model tests
- For significant changes, run the full test suite to catch any unexpected interactions

## Linting/Code Quality
- **Lint command**: [Add specific linting command when known]
- **Type checking**: [Add type checking command when known]

## Database Seeding
- **Seed database**: `docker-compose exec web bundle exec rails db:seed`
- **Reset and seed**: `docker-compose exec web bundle exec rails db:reset`

## Seed Data for New Models/Controllers/Views
**IMPORTANT**: Whenever a new model, controller, or view is created (or an existing one is modified in a way that affects what is shown on screen), automatically add representative seed data to `db/seeds.rb` and run `db:seed` so the visual changes can be reviewed immediately in the browser.

- Add enough records to exercise the view (e.g., multiple rows for index pages, a variety of attribute values where relevant).
- Make the seed code idempotent (e.g., use `find_or_create_by!` or guard with `Model.exists?`) so re-running seeds does not create duplicates.
- After updating seeds, run: `docker-compose exec web bundle exec rails db:seed`.

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