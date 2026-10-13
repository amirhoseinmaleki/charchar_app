# In-App Notifications API

Broadcast notifications with a **title** and **body**. An operator sends one; it
becomes visible (unread) to every player at once. Each player then reads/marks
notifications independently, and the API reports read state and unread count.

- Routes: [`src/routes/notifications.ts`](../src/routes/notifications.ts)
- Storage: [`src/db/notificationRepository.ts`](../src/db/notificationRepository.ts),
  tables `notifications` + `notification_reads` in [`src/db/schema.ts`](../src/db/schema.ts)
- Tests: [`src/__tests__/notifications.test.ts`](../src/__tests__/notifications.test.ts)

Base URL in production: `https://api.woundai.ir`

---

## Model

- **`notifications`** — one row per broadcast: `id`, `title`, `body`, `createdAt`.
  There is no per-recipient row; every notification goes to everyone.
- **`notification_reads`** — one row per `(notification, player)` the moment that
  player marks it read. **No row ⇒ unread.** A player's `unreadCount` is
  "notifications with no matching read row".

Marking read is idempotent (repeat calls are harmless no-ops).

---

## Auth

| Who | How |
| --- | --- |
| **Operator** (send) | `X-Admin-Key: <ADMIN_API_KEY>` request header. If `ADMIN_API_KEY` is empty server-side, the send endpoint returns `503 ADMIN_DISABLED`. |
| **Player** (read) | `Authorization: Bearer <session JWT>` — the token from `POST /auth/verify-otp`. |

---

## `POST /notifications` — send (operator)

```
POST /notifications
X-Admin-Key: <ADMIN_API_KEY>
Content-Type: application/json
```

| Field | Type | Rules |
| --- | --- | --- |
| `title` | string, required | Trimmed. 1–120 chars (`NOTIFICATION_TITLE_MAX_LENGTH`). |
| `body` | string, required | Trimmed. 1–2000 chars (`NOTIFICATION_BODY_MAX_LENGTH`). |

### Response `201`

```json
{
  "ok": true,
  "notification": {
    "id": "e03cf35d-4d86-4657-8299-fb298d70d615",
    "title": "بروزرسانی جدید",
    "body": "نسخه جدید بازی منتشر شد!",
    "createdAt": 1788902727515
  }
}
```

### Errors

| HTTP | `error` | When |
| --- | --- | --- |
| `503` | `ADMIN_DISABLED` | No `ADMIN_API_KEY` configured on the server. |
| `401` | `UNAUTHORIZED` | Missing/wrong `X-Admin-Key`. |
| `400` | `INVALID_INPUT` | `title` or `body` missing / not a string. |
| `400` | `INVALID_TITLE` | Title empty after trim, or too long. |
| `400` | `INVALID_BODY` | Body empty after trim, or too long. |

### Example

```bash
curl -X POST https://api.woundai.ir/notifications \
  -H "X-Admin-Key: $ADMIN_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"title":"بروزرسانی جدید","body":"نسخه جدید بازی منتشر شد!"}'
```

---

## `GET /notifications` — list (player)

Newest first, each annotated with **this player's** `read` state.

```
GET /notifications?limit=30&before=<createdAt ms>
Authorization: Bearer <token>
```

| Query | Default | Notes |
| --- | --- | --- |
| `limit` | 30 | Clamped to 100 (`NOTIFICATION_MAX_PAGE_SIZE`). |
| `before` | — | Keyset cursor. Pass the previous page's `nextBefore` (or the last item's `createdAt`) to get older notifications. |

### Response `200`

```json
{
  "items": [
    {
      "id": "5f324f7e-…",
      "title": "جایزه ورود",
      "body": "امروز وارد شو و ۱۰۰ سکه هدیه بگیر.",
      "createdAt": 1788902800000,
      "read": false,
      "readAt": null
    },
    {
      "id": "e03cf35d-…",
      "title": "بروزرسانی جدید",
      "body": "نسخه جدید بازی منتشر شد!",
      "createdAt": 1788902727515,
      "read": true,
      "readAt": 1788902750000
    }
  ],
  "unreadCount": 1,
  "total": 2,
  "nextBefore": null
}
```

- `unreadCount` — this player's total unread (across all pages, not just this one).
- `total` — total broadcast notifications.
- `nextBefore` — cursor for the next (older) page, or `null` when this page
  wasn't full (no more pages).

### Paging

```bash
# page 1
curl 'https://api.woundai.ir/notifications?limit=20' -H "Authorization: Bearer $T"
# -> take nextBefore from the response, then:
curl 'https://api.woundai.ir/notifications?limit=20&before=1788902727515' -H "Authorization: Bearer $T"
```

---

## `GET /notifications/unread-count` — badge (player)

Cheap endpoint for the notification-bell badge.

```json
{ "unreadCount": 3 }
```

---

## `POST /notifications/:id/read` — mark one read (player)

Idempotent. Marking an already-read notification is a no-op success.

### Response `200`

```json
{ "ok": true, "unreadCount": 2 }
```

| HTTP | `error` | When |
| --- | --- | --- |
| `404` | `NOT_FOUND` | No notification with that id. |
| `401` | `UNAUTHORIZED` | Missing/invalid session token. |

---

## `POST /notifications/read-all` — mark all read (player)

```json
{ "ok": true, "marked": 5, "unreadCount": 0 }
```

- `marked` — how many were still unread before this call.

---

## Push notifications (Firebase Cloud Messaging)

Every `POST /notifications` is **also pushed** to every registered device via
FCM, so players see it in the Android notification tray even with the app
closed. Pass `"push": false` in the body to store it in-app only.

- Sender: [`src/notifications/push.ts`](../src/notifications/push.ts) (`firebase-admin`)
- Token storage: [`src/db/pushTokenRepository.ts`](../src/db/pushTokenRepository.ts), table `push_tokens`
- Tests: [`src/__tests__/push.test.ts`](../src/__tests__/push.test.ts)

### Server setup

`google-services.json` is the **Android app's** config — it goes in the client
(`app/google-services.json`) and **cannot send** pushes. The server needs a
**service account key**:

1. Firebase console → project `esmfamil-87855` → ⚙ Project settings →
   **Service accounts** → **Generate new private key**.
2. Put the file on the server outside the repo, e.g.
   `/home/ubuntu/secrets/firebase-esmfamil.json`, `chmod 600`.
3. In `.env`: `FIREBASE_SERVICE_ACCOUNT_PATH=/home/ubuntu/secrets/firebase-esmfamil.json`
4. Restart the server.

| Env | Default | Notes |
| --- | --- | --- |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | empty | Empty ⇒ push disabled (`push.enabled: false`), in-app still works. |
| `FCM_ANDROID_CHANNEL_ID` | empty | Android notification channel the app creates; empty ⇒ FCM default channel. |
| `PUSH_MAX_TOKENS_PER_PLAYER` | 5 | Older device tokens beyond this are dropped. |

### Send response

`POST /notifications` now also returns push stats:

```json
{
  "ok": true,
  "notification": { "id": "…", "title": "…", "body": "…", "createdAt": 1788902727515 },
  "push": { "enabled": true, "targeted": 120, "sent": 117, "failed": 3, "pruned": 3 }
}
```

- `push` is `null` when `"push": false` was sent.
- `pruned` — tokens FCM reported as unregistered/invalid, deleted from `push_tokens`.
- `pushError` — present only if the push couldn't start (e.g. unreadable service-account file). The in-app notification is still stored.

Each push carries `data: { "type": "notification", "notificationId": "<id>" }`
so the app can open the right notification when tapped.

### `POST /notifications/push-token` — register device (player)

```
POST /notifications/push-token
Authorization: Bearer <token>
Content-Type: application/json

{ "token": "<FCM registration token>", "platform": "android" }
```

`platform` is `android` (default), `ios` or `web`. Idempotent — safe to call
repeatedly. Call it:

- right after a successful login (`POST /auth/verify-otp`),
- on **every app start (splash screen) when the user is already logged in** —
  this keeps the token fresh and re-links it if it changed while the app was closed,
- from `FirebaseMessagingService.onNewToken` (if logged in).

Don't block the splash on it; fire it in the background and ignore failures
(it'll be retried on the next launch). If the same device logs into
another account, the token moves to that player. Response: `{ "ok": true }`.
`400 INVALID_TOKEN` / `400 INVALID_PLATFORM` on bad input.

### `DELETE /notifications/push-token` — unregister device (player)

Body `{ "token": "<FCM token>" }`. Call on logout. Response
`{ "ok": true, "removed": true }` (`false` if the token wasn't this player's).

### Android client checklist

1. `app/google-services.json` (package `com.PardisSaz.game`) + the
   `com.google.gms.google-services` Gradle plugin + `firebase-messaging` dependency.
2. Android 13+: request `POST_NOTIFICATIONS` runtime permission.
3. After login **and on splash when already logged in**: `FirebaseMessaging.getInstance().token` → `POST /notifications/push-token`.
4. In `onNewToken`: re-POST (if logged in). On logout: `DELETE /notifications/push-token`.
5. If you create a custom channel, set `FCM_ANDROID_CHANNEL_ID` to its id.

---

## Typical client flow

```bash
B=https://api.woundai.ir
T='<session JWT>'

# poll the badge
curl "$B/notifications/unread-count" -H "Authorization: Bearer $T"

# open the notifications screen
curl "$B/notifications?limit=30" -H "Authorization: Bearer $T"

# user taps one
curl -X POST "$B/notifications/e03cf35d-…/read" -H "Authorization: Bearer $T"

# "mark all as read" button
curl -X POST "$B/notifications/read-all" -H "Authorization: Bearer $T"
```

---

## Operator form (HTML)

A ready-made Persian (RTL) form for sending a notification is served by the API
itself:

```
https://api.woundai.ir/admin/notifications.html
```

- Files: [`public/admin/notifications.html`](../public/admin/notifications.html) +
  [`public/admin/notifications.js`](../public/admin/notifications.js), served via
  `express.static` mounted at `/admin` in [`src/index.ts`](../src/index.ts).
- It holds **no secret**. The operator pastes the `ADMIN_API_KEY` into a password
  field; it's kept only in that browser's `localStorage` and sent as the
  `X-Admin-Key` header. Every send still goes through the same server-side check.
- Directory listing is off (`GET /admin/` → 404); the page is `noindex`.
- Features: live character counters (۱۲۰ / ۲۰۰۰), a live preview, a "this goes to
  everyone" confirmation checkbox, and inline success/error messages. The script
  is a separate file because the API's CSP is `script-src 'self'`.

## Config (`.env`)

| Var | Default | Meaning |
| --- | --- | --- |
| `ADMIN_API_KEY` | `` (empty) | Key for `POST /notifications`. Empty ⇒ endpoint returns `503`. |
| `NOTIFICATION_TITLE_MAX_LENGTH` | `120` | Max title chars. |
| `NOTIFICATION_BODY_MAX_LENGTH` | `2000` | Max body chars. |
| `NOTIFICATION_PAGE_SIZE` | `30` | Default `GET /notifications` page size. |
| `NOTIFICATION_MAX_PAGE_SIZE` | `100` | Hard cap on `?limit=`. |
