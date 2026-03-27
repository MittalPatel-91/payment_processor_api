# Payment Processor API (Rails)

Backend service built for the “AI-Assisted Build (Ruby on Rails Assignment)” requirements:

- REST API to accept payment requests
- Background job processing (Delayed Job via `ActiveJob`)
- DB persistence with request status
- Idempotency (duplicate request protection + payload mismatch detection)
- Retry logic with exponential backoff
- Concurrency/race condition handling
- Cancellation rules
- JSON (structured) logging

## Tech stack

- **Ruby on Rails**: 8.1.x
- **Database**: PostgreSQL
- **Job runner**: `delayed_job_active_record` (ActiveJob adapter: `:delayed_job`)
- **Tests**: RSpec (`rspec-rails`) + FactoryBot

## Setup

Install dependencies:

```bash
bundle install
```

Create and migrate DB:

```bash
bin/rails db:create db:migrate
```

Start the API server:

```bash
bin/rails server
```

Start the background worker (Delayed Job):

```bash
bin/delayed_job start
```

Stop worker:

```bash
bin/delayed_job stop
```

## API

Routes are defined under `api/v1`:

- `POST /api/v1/payments` (create)
- `GET /api/v1/payments/:id` (show status/result)
- `POST /api/v1/payments/:id/cancel` (cancel if allowed)

### Create payment

**Request header**

**`Idempotency-Key`**
- Required header for creating payments
- Ensures safe retries and prevents duplicate processing

**Request body**

- `amount` (required, > 0)
- `currency` (required, 3-letter ISO code, uppercase, e.g. `INR`)
- `user_id` (required)

Example:

```bash
curl -X POST "http://localhost:3000/api/v1/payments" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: 2b94d676-2e3c-4a92-a6e2-bc8e9e7fd21d" \
  -d '{"amount":100,"currency":"INR","user_id":1}'
```

**Response**

- `202 Accepted` with the `Payment` record JSON. The job is enqueued when status is `pending`.

### Show payment

```bash
curl "http://localhost:3000/api/v1/payments/<id>"
```

- `200 OK` on success
- `404 Not Found` if the payment does not exist

### Cancel payment

```bash
curl -X POST "http://localhost:3000/api/v1/payments/<id>/cancel"
```

- `200 OK` if cancelled
- `409 Conflict` if not cancellable in the current state

## Statuses and processing model

Payments move through these statuses (see `Payment.status` enum):

- `pending` → created, job can be enqueued
- `processing` → job has claimed the record (row locked)
- `completed` → downstream processing succeeded
- `failed` → downstream processing failed (also used as “ready for retry” state)
- `cancelled` → cancellation requested while `pending`

Cancellation rule (see `Payment#cancellable?`): only `pending` payments can be cancelled.

## Idempotency (duplicate handling)

Idempotency is enforced using:

- `request_uuid` (from `Idempotency-Key`) with a **unique DB index**
- `payload_hash` (SHA256 of payload JSON) to detect same key + different payload

Behavior:

- Same `Idempotency-Key` + **same payload** → returns the existing record (no duplicate processing)
- Same `Idempotency-Key` + **different payload** → returns `409 Conflict` (`IdempotencyConflictError`)
- Concurrent requests with same key are protected by DB uniqueness + retry on `RecordNotUnique`

## Retries and downstream failures

The “downstream” is simulated in `PaymentProcessor` and fails randomly (~30%) with:

- `Payment gateway timeout`

Retry behavior (see `ProcessPaymentJob`):

- `MAX_RETRIES = 3`
- Exponential backoff: \(2^{attempt}\) seconds
- On failure, `retry_count` is incremented and the job is rescheduled until retries are exhausted
- During retries, status remains `failed` (used as a retryable state)
- On final failure (after max retries), payment remains `failed` with `error_message`

### Retry Semantics

The `failed` status is used for both:
- temporary failures (retryable)
- terminal failures (after max retries)

Retries are controlled via `retry_count` and logged explicitly.

## Concurrency / race conditions

- `request_uuid` has a unique index
- background job uses `with_lock` to avoid concurrent state transitions
- cancellation also uses `with_lock` to avoid cancelling while a transition is in progress

## Logging

Logs are emitted as JSON with keys like:

- `event`
- `request_uuid`, `payment_id`
- `from_status`, `to_status`
- `retry_count`, `retry_attempt`
- `job_id`, `queue`

Examples include events like `payment_request_received`, `payment_processing_started`,
`payment_status_updated`, `payment_retry_scheduled`, and `payment_permanently_failed`.

## Running tests

Run the full suite:

```bash
bundle exec rspec
```

Notable coverage:

- idempotency hit/miss/mismatch + race retry (`spec/services/idempotency_handler_spec.rb`)
- status validation + payload validation + cancellable rules (`spec/models/payment_spec.rb`)
- job success, retry, final failure (`spec/jobs/process_payment_job_spec.rb`)
- API behavior (idempotency + cancel + 404/422) (`spec/requests/api/v1/payments_spec.rb`)
