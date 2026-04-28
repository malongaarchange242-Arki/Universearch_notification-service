FROM elixir:1.14-alpine AS builder

# Install build dependencies
RUN apk add --no-cache build-base gcc postgresql-client git

WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./

# Install Elixir dependencies
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get

# Copy source code
COPY . .

# Compile project
RUN mix compile && \
    MIX_ENV=prod mix ecto.create 2>/dev/null || true && \
    MIX_ENV=prod mix release --overwrite

# Runtime stage
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache openssl postgresql-client bash ca-certificates

WORKDIR /app

# Copy release from builder
COPY --from=builder /app/_build/prod/rel/notification_service ./

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD /app/bin/notification_service rpc "System.halt()"

# Start the application
CMD ["/app/bin/notification_service", "start"]