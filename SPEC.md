# openpanel_dart

Sources:
- Docs: <https://openpanel.dev/docs>
  - API track: <https://openpanel.dev/docs/api/track>
  - API authentication: <https://openpanel.dev/docs/api/authentication>
  - How it works: <https://openpanel.dev/docs/how-it-works>
  - SDKs: <https://openpanel.dev/docs/sdks>
- OpenAPI: <https://api.openpanel.dev/openapi.json> (2026-10-11)

## Transport

- Base URL defaults to `https://api.openpanel.dev`. For self-hosted deployments the SDK is pointed at the operator's own domain (the docs recommend appending `/api` on the web SDK, but any reachable base URL works because this SDK always appends `/track`).
- Authentication headers:
  - `openpanel-client-id` (required)
  - `openpanel-client-secret` (only required for server-side events; for public clients it is optional and must be treated as non confidential)
- SDK identity headers: `openpanel-sdk-name`, `openpanel-sdk-version`.
- The `User-Agent` is used by the backend to distinguish client events (which create sessions) from server events. This SDK therefore sends a multi-token user agent.

## `POST /track`

Unified ingestion endpoint. Body:

```json
{ "type": "<one of>", "payload": { ... } }
```

### `track`

Required payload: `name`.

| Field        | Type               | Required | Notes                          |
|--------------|--------------------|----------|--------------------------------|
| `name`       | string (min 1)     | yes      | Event name.                    |
| `properties` | object             | no       | Arbitrary key/value pairs.     |
| `profileId`  | string \| number   | no       | Profile attached to the event. |
| `groups`     | array<string> \| null | no    | Groups attached to the event.  |

### `identify`

Required payload: `profileId`.

| Field       | Type             | Required |
|-------------|------------------|----------|
| `profileId` | string \| number | yes      |
| `firstName` | string           | no       |
| `lastName`  | string           | no       |
| `email`     | string (email)   | no       |
| `avatar`    | string (uri)     | no       |
| `properties`| object           | no       |

### `increment` / `decrement`

Required payload: `profileId`, `property`.

| Field       | Type             | Required |
|-------------|------------------|----------|
| `profileId` | string \| number | yes      |
| `property`  | string (min 1)   | yes      |
| `value`     | number (> 0)     | no (SDK defaults to 1) |

### `group`

Required payload: `id`, `type`, `name`. Plus optional `properties`.

### `assign_group`

Required payload: `groupIds`. Optional `profileId`.

### `alias`

Required payload: `profileId`, `alias` (string, min 1).

## Error semantics

| HTTP status | SDK classification | Behaviour                                  |
|-------------|--------------------|--------------------------------------------|
| 2xx         | success            | Event removed from the queue.              |
| 401 / 403   | fatal              | Flush paused; configuration error reported.|
| 429         | retryable          | Retry after `Retry-After` when present, otherwise backoff. |
| 5xx         | retryable          | Exponential backoff with jitter.           |
| other 4xx   | invalid            | Event dropped (does not block the queue).  |

Network/timeout failures are retryable. Every event has a delivery attempt cap (`maxAttempts`); beyond it the event is dropped and reported.
