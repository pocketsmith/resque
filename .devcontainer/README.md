# Dev Container for Resque

This dev container is configured to match the GitHub Actions test matrix with the following configuration:

- **Ruby version**: 3.4
- **Redis version**: latest
- **Rack version**: 3

## Getting Started

1. Open this repository in your editor (Cursor, VS Code, etc.)
2. When prompted, click "Reopen in Container" (or run the command "Dev Containers: Reopen in Container")
3. Wait for the container to build and start
4. Once inside the container, dependencies will be automatically installed via `bundle install`

## Running Tests

To run the full test suite:

```bash
bundle exec rake
```

To run a specific test file:

```bash
bundle exec ruby test/resque_test.rb
```

To run tests with verbose output:

```bash
VERBOSE=1 bundle exec rake
```

## Testing with Different Configurations

If you want to test with different versions, you can modify the environment variables and reinstall dependencies:

```bash
# Example: Test with rack 2
export RACK_VERSION=2
bundle install

# Run tests
bundle exec rake

# Reset to original configuration
export RACK_VERSION=3
bundle install
```

## Available Environment Variables

The following environment variables are set to match the test matrix:

- `REDIS_VERSION`: latest
- `RACK_VERSION`: 3
- `COVERAGE`: 1

## Services

### Redis

A Redis container runs as a sidecar service. From inside the container it is reachable at `redis://redis:6379`. The devcontainer also forwards port 6379 to your local machine, so you can connect via `localhost:6379` from outside the container (e.g. with a Redis GUI).

To connect to Redis CLI from inside the container:

```bash
redis-cli -h redis
```

Note: the test suite spins up its own Redis instance on port 9736 — that is separate from this service.

## Troubleshooting

### Redis Connection Issues

Make sure the Redis container is running:

```bash
redis-cli -h redis ping
```

Should return `PONG`.

### Rebuilding the Container

If you need to rebuild the container from scratch:

1. Run "Dev Containers: Rebuild Container" from the command palette
2. Or delete the container and volume manually:
   ```bash
   docker compose -f .devcontainer/docker-compose.yml down -v
   ```
