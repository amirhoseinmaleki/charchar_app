# Leaderboard API

`GET /leaderboard` — the single endpoint that powers the in-app leaderboard screen
(همه‌زمان‌ها / این هفته / این ماه tabs), including the "شما #N هستید" row for the
signed-in player.

- Source: [`src/routes/leaderboard.ts`](../src/routes/leaderboard.ts)
- Queries: [`src/db/playerRepository.ts`](../src/db/playerRepository.ts) →
  `getLeaderboard(scope)`, `getPlayerRank(scope, playerId)`, `LEADERBOARD_SIZE`
- Smoke test: [`scripts/smoke-test-leaderboard.js`](../scripts/smoke-test-leaderboard.js)

---

## Request

```
GET /leaderboard?scope=<allTime|weekly|monthly>
```

| Part | Value |
| --- | --- |
| Method | `GET` |
| Auth | **Optional.** `Authorization: Bearer <session JWT>` (the token from `POST /auth/verify-otp`). Sent → response includes `myRank`. Omitted / invalid → `myRank` is `null`. |
| Query `scope` | `allTime` (default), `weekly`, or `monthly`. Any other or missing value falls back to `allTime`. |
| Other query params | **None.** There is deliberately no `limit` / `offset` / `page` — the board is always the fixed top 100 (see [Why no pagination](#why-no-pagination)). Unknown params are ignored. |

The endpoint sits behind the global API rate limiter (120 req/min/IP,
[`src/middleware/rateLimit.ts`](../src/middleware/rateLimit.ts)); no
leaderboard-specific limit.

### Examples

```bash
# Public view, all-time
curl 'http://localhost:4000/leaderboard'

# This week
curl 'http://localhost:4000/leaderboard?scope=weekly'

# This month, with the caller's own rank included
curl 'http://localhost:4000/leaderboard?scope=monthly' \
  -H "Authorization: Bearer $TOKEN"
```

---

## Response

`200 OK`, `application/json`:

```jsonc
{
  "scope": "weekly",              // the validated scope actually used
  "size": 100,                    // fixed board length (LEADERBOARD_SIZE) — always 100
  "entries": [                    // 0..100 rows, best score first
    {
      "playerId": "b1f2…",        // opaque id (real player uuid, or "npc:<name>" for a bot)
      "nickname": "علی",          // display name; "بازیکن" if the player never set one
      "score": 430,               // see Scoring per scope
      "rank": 1,                  // 1..N, dense and unique (no ties)
      "nameColorHex": "#F5C542",  // equipped name color, or null → client uses theme default
      "avatarUrl": "/assets/avatar/avatar_default_2.png"  // absolute path on this host
    }
    // …
  ],
  "myRank": { "score": 50, "rank": 137 }   // the caller's true position, or null
}
```

### Field reference

| Field | Type | Notes |
| --- | --- | --- |
| `scope` | `"allTime" \| "weekly" \| "monthly"` | Echoes the scope after validation, so the client can confirm a bad `?scope=` was coerced to `allTime`. |
| `size` | `number` | Always `100`. Present so the client can render "Top 100" without hard-coding it. |
| `entries` | `Entry[]` | Length is `0` to `100`. Fewer than 100 simply means fewer than 100 players have a positive score in this scope. Ordered by `score` descending; **players with an equal score are ordered by `nickname` A→Z** (Persian collation, case-insensitive), then by `playerId` for identical names — so the order within a tie is stable and alphabetical. |
| `entries[].playerId` | `string` | Not a phone number and not the JWT subject in any guessable way for other players — just an id for React keys / "is this me" checks. Bots appear as `"npc:<persian name>"`. |
| `entries[].nickname` | `string` | Never null — falls back to `"بازیکن"`. |
| `entries[].score` | `number` | Integer ≥ 1. See [Scoring per scope](#scoring-per-scope). |
| `entries[].rank` | `number` | 1-based position in the list. **Dense and unique** — the first row is `1`, the last is `entries.length`, every value in between appears exactly once. Equal scores do **not** share a rank; they're separated by the alphabetical tie-break. See [Ranking](#ranking). |
| `entries[].nameColorHex` | `string \| null` | `"#RRGGBB"` when the player has a name-color cosmetic equipped; `null` otherwise (client falls back to the theme's default text color). Resolved server-side via `nameColorHexFor`. |
| `entries[].avatarUrl` | `string` | Root-relative path served by this backend (`/assets/avatar/…png`). Players with no custom avatar get the shared default (`DEFAULT_AVATAR_PATH`, default `/assets/avatar/defultavatar.png`). Prefix with the API base URL to load it. |
| `myRank` | `{ score, rank } \| null` | See [myRank](#myrank). |

There is **no `error` shape** on the happy path; malformed `scope` is not an
error, it is silently defaulted.

---

## myRank

`myRank` answers "چندم شدم؟" for the authenticated caller.

- **Only present when** the request carries a valid `Authorization: Bearer` token.
  No token, expired token, or a token whose player row was deleted → `myRank: null`.
- **`{ score, rank }`** gives the caller's **true** position in the chosen scope —
  **even if `rank > 100`** and the player is nowhere in `entries`. Use this to
  render a pinned "شما: #137" row under the top-100 list.
- **`null`** when the caller has **no score in this scope yet** (a brand-new
  player, or someone who hasn't played in the last 7 / 30 days for
  `weekly` / `monthly`). Render "بدون رتبه" / hide the row.
- `rank` here is the caller's 1-based index in the **same total order** used
  for `entries` (score DESC → nickname A→Z → playerId), so when the caller *is*
  in `entries`, `myRank.rank` equals their row's `rank` and `myRank.score`
  equals their row's `score`. The client can always highlight the row where
  `entry.rank === myRank.rank`, and only fall back to a separate pinned row
  when `myRank.rank > entries.length`.

### Client rendering sketch

```
list      = response.entries                       // the top 100
me        = response.myRank                         // may be null

if me == null:
    show list; footer = "شما هنوز رتبه‌ای ندارید"
else:
    inList = list.find(e => e.rank === me.rank && e.score === me.score)
    show list (highlight inList if present)
    if not inList:
        pin a row: "#{me.rank} — شما — {me.score} امتیاز"
```

---

## Scoring per scope

| Scope | Ranked by | Window |
| --- | --- | --- |
| `allTime` | `players.total_score` (the running lifetime total maintained on every `recordGameResult`) | all history |
| `weekly` | `SUM(game_results.score)` for that player | rows with `played_at` in the last **7 days** |
| `monthly` | `SUM(game_results.score)` for that player | rows with `played_at` in the last **30 days** |

So `weekly` / `monthly` reflect only games *played in that window* — a dormant
top-10 all-time player can be absent from the weekly board entirely. Windows are
rolling (now − 7d / now − 30d), computed per request, not calendar weeks/months.

Players (and bots) with a **0 score in the scope are excluded** from `entries`
and get `myRank: null` — consistent across all three scopes.

NPCs used to fill "بازی آنلاین" lobbies persist as ordinary `players` rows
(id `npc:<name>`) and **do appear on the board** under their lobby name, by
design (they are meant to look like real opponents). NPCs from the free
"بازی سریع" solo mode are *not* persisted and never appear.

---

## Ranking

Ranks are **dense and unique**: `1, 2, 3, … N` straight down the list, every
number appearing exactly once. There is **no rank sharing** — two players on the
same score get two consecutive ranks, ordered between themselves by the
tie-break.

The list is built by this total order:

1. **score**, descending
2. **nickname**, A→Z — Persian collation (`Intl.Collator('fa')`), case-insensitive
3. **playerId** — only reached when two players have the same score *and* the
   same nickname (e.g. several unnamed "بازیکن")

A player's `rank` is simply their 1-based position in that ordered list.
`myRank.rank` is computed with the same comparator, so it matches the player's
row in `entries` whenever they're in the top 100.

Example — players tied on 50 points are numbered consecutively in name order:

```
#35  بازیکن      50
#36  بازیکن      50
#37  بازیکن      50
#38  پروانه      50
#39  داریوش      50
#40  وحید        50
#41  ژاله        45
```

---

## Why no pagination

The board is a product-fixed "Top 100". The client never needs page 2, and
`myRank` already covers "where am I if I'm not in the top 100". Keeping it a
single fixed query:

- makes the response a predictable size (≤ ~100 small objects),
- lets the rank math stay a simple offset/count with no cursor bookkeeping,
- avoids a client sending `limit=100000` to scrape the whole player table.

If a future screen needs "the 20 players around me", add a separate
`GET /leaderboard/around-me` rather than reintroducing `limit`/`offset` here.

---

## Edge cases & guarantees

| Situation | Behaviour |
| --- | --- |
| `?scope` missing or unknown (`daily`, `all`, `""`, …) | Treated as `allTime`; `scope` in the response tells you what was used. |
| No token / bad token / deleted player | `myRank: null`, `entries` unaffected. |
| Caller has a score but is rank 5000 | `myRank: { score, rank: 5000 }`, not in `entries`. |
| Caller's score is 0 in this scope | `myRank: null`. |
| Fewer than 100 scored players | `entries` shorter than 100; `size` still `100`. |
| Two players on the same score | Different, consecutive ranks — ordered by nickname A→Z, then playerId. Ranks never repeat. |
| Equal score straddling the 100th place | The candidate rows are ordered by (score, nickname, playerId) and cut at 100, so which players make the cut is deterministic — the alphabetically-earlier names get in. `myRank` for someone just outside is still correct (e.g. `rank: 101`). |
| Phone numbers | Never in the response — only `playerId`, `nickname`, `score`, `rank`, cosmetics. |

---

## Related

- `GET /auth/me` — the caller's own coin balance / nickname / avatar (not rank).
- `GET /auth/me/games` — the caller's recent game history.
- Admin/dev only: `resetLeaderboard()` in `playerRepository.ts` wipes
  `game_results` + every `total_score`/`games_played` and deletes `npc:%` rows.
  Not exposed as a route.
