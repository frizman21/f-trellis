# README

## Initializing the local environment

The application runs in Docker. All Rails and database commands below execute inside the `web` container.

### 1. Create a local `.env`

Copy the example file and fill in any values you need to override:

```sh
cp .env.example .env
```

`.env` is gitignored. The default `docker-compose.yml` works without any overrides.

### 2. Start the containers

```sh
docker-compose up -d
```

On first boot the `web` container runs `bundle install` followed by `bin/rails db:prepare`, which creates and migrates the **development** database.

### 3. Create the test database

`db:prepare` only touches the current `RAILS_ENV` (development). Create the test database explicitly:

```sh
docker-compose exec web bundle exec rails db:create RAILS_ENV=test
docker-compose exec web bundle exec rails db:schema:load RAILS_ENV=test
```

### 4. Seed development data (optional)

```sh
docker-compose exec web bundle exec rails db:seed
```

## Running the test suite

```sh
docker-compose exec web bundle exec rails test
```

To reset the test database and run the full suite:

```sh
docker-compose exec web bundle exec rails test:db
```

See `CLAUDE.md` for the full command reference.
