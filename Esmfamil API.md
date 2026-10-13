# API بک‌اند اسم‌فامیل‌یار

- **آدرس پایه:** `https://api.woundai.ir`
- **پنل ادمین:** `https://api.woundai.ir/panel`
- **پیاده‌سازی:** NestJS در `nest/` با خروجی build در `dist-nest/` (پورت 4100)، با همان قرارداد سرور قدیم `src/index.ts` (پورت 4000). build با `npm run build:nest` و تست قرارداد با `npm run test:contract`.
- **بدنه‌ها:** JSON (حداکثر 32kb).
- **خطاها:** `{ "error": "<CODE>", "message": "<متن فارسی>" }`. مسیر ناموجود: 404 با کد `NOT_FOUND`؛ خطای داخلی: 500 با کد `INTERNAL`.

## احراز هویت

| نوع | هدر | توضیح |
|---|---|---|
| بازیکن | `Authorization: Bearer <JWT>` | JWT با الگوریتم HS256 از `POST /auth/verify-otp`؛ نامعتبر بودن: 401 با کد `UNAUTHORIZED` |
| ادمین | `X-Admin-Key: <ADMIN_API_KEY>` | بدون تنظیم کلید روی سرور: 503 با کد `ADMIN_DISABLED` |

**Rate limit (به ازای هر IP):**
- سراسری: ۱۲۰ درخواست در دقیقه
- `request-otp`: ۵ درخواست در ۱۰ دقیقه
- `verify-otp`: ۲۰ درخواست در ۱۰ دقیقه
- در صورت عبور: 429 با کد `RATE_LIMITED`

## عمومی

| متد | مسیر | توضیح |
|---|---|---|
| GET | `/health` | `{ status, uptime, timestamp }` |
| GET | `/config/client` | کلیدهای SDK (تپسل، بازار، مایکت)، `economy`، `onlineGame`، `scoring`، `timing`، `leveling` |
| GET | `/leaderboard?scope=allTime\|weekly\|monthly` | `{ scope, size: 100, entries[], myRank }`؛ `myRank` فقط با توکن |
| GET | `/assets/avatar/<id>.png` | تصویر آواتار (کش ۱ روز) |

## ورود (`/auth`)

| متد | مسیر | بدنه / خروجی |
|---|---|---|
| POST | `/request-otp` | `{ phone }` → `{ ok: true }`؛ خطاها: `INVALID_PHONE`، `RATE_LIMITED`، 500 `INTERNAL` (ارسال پیامک) |
| POST | `/verify-otp` | `{ phone, code, nickname? }` → `{ token, isNewUser, player }`؛ خطاها: `WRONG_CODE`، `EXPIRED`، `NO_PENDING_OTP`، `TOO_MANY_ATTEMPTS` |
| POST | `/set-nickname` 🔒 | `{ nickname (2..20) }` → `{ ok, nickname, coinBalance, nicknameChanges, nicknameChangesRemaining, charged }`؛ خطاها: `INVALID_NICKNAME`، `NICKNAME_NOT_ALLOWED`، 403 `NICKNAME_LOCKED`، 409 `NICKNAME_TAKEN`، `INSUFFICIENT_COINS` |
| GET | `/me` 🔒 | پروفایل کامل: سکه، آواتار، رنگ نام، `totalScore`، `level`، `levelProgress` |
| GET | `/me/games` 🔒 | `{ games }` (۱۰ بازی آخر) |

## فروشگاه (`/shop`) 🔒

| متد | مسیر | توضیح |
|---|---|---|
| GET | `/items` | `{ coinBalance, equippedAvatarId, equippedNameColorId, items[] }` |
| POST | `/purchase` | `{ itemId }` خرید cosmetic با سکه؛ خطاها: `ITEM_NOT_FOUND`، `NOT_PURCHASABLE`، `ALREADY_OWNED`، `INSUFFICIENT_COINS` |
| POST | `/purchase/coins` | `{ purchaseData, dataSignature, store?: bazaar\|myket }`؛ تأیید امضای RSA و واریز idempotent → `{ ok, coinBalance, coinsGranted, alreadyProcessed, productId }`؛ خطاها: `BAD_SIGNATURE`، `BAD_PAYLOAD`، `PURCHASE_CANCELED`، `UNKNOWN_PRODUCT`، `BAZAAR_NOT_CONFIGURED` |
| POST | `/equip` | `{ category: avatar\|nameColor, itemId \| null }`؛ خطاها: `BAD_CATEGORY`، 403 `NOT_OWNED` |

## تبلیغ جایزه‌دار (`/ads`) 🔒

| متد | مسیر | توضیح |
|---|---|---|
| GET | `/reward-status` | `{ canWatch, viewsRemainingToday, maxPerDay, cooldownEndsAt, coinAmount }` |
| POST | `/reward` | واریز سکه؛ خطا `AD_REWARD_NOT_AVAILABLE` (همراه با وضعیت) |
| GET | `/rescue-status` | تبلیغ «نجات» وقتی سکه کم است، به‌علاوهٔ `eligibleByBalance`، `balanceThreshold`، `coinBalance` |
| POST | `/reward/rescue` | خطاها: `AD_RESCUE_NOT_ELIGIBLE`، `AD_REWARD_NOT_AVAILABLE` |

## اعلان‌ها (`/notifications`)

| متد | مسیر | توضیح |
|---|---|---|
| GET | `/?limit=&before=` 🔒 | `{ items, unreadCount, total, nextBefore }`؛ صفحه‌بندی keyset |
| GET | `/unread-count` 🔒 | `{ unreadCount }` |
| POST | `/read-all` 🔒 | `{ ok, marked, unreadCount: 0 }` |
| POST | `/:id/read` 🔒 | `{ ok, unreadCount }`؛ 404 با کد `NOT_FOUND` |
| POST | `/push-token` 🔒 | `{ token, platform?: android\|ios\|web }`؛ خطاها: `INVALID_TOKEN`، `INVALID_PLATFORM` |
| DELETE | `/push-token` 🔒 | `{ token }` → `{ ok, removed }` |
| GET | `/admin/player?phone=` 🛡 | `{ player: { id, nickname, pushDevices } }`؛ خطاها: `INVALID_PHONE`، 404 `PLAYER_NOT_FOUND` |
| POST | `/` 🛡 | `{ title (≤120), body (≤2000), phone?, inApp?=true, push?=true }` → 201 `{ ok, notification, recipient, push, pushError? }`؛ خطاها: `INVALID_TITLE`، `INVALID_BODY`، `NO_CHANNEL`، 503 `PUSH_DISABLED` |

## ضدتقلب (`/admin-api`) 🛡

| متد | مسیر | توضیح |
|---|---|---|
| GET | `/suspects` | `{ rules, players[] }` با پرچم‌های `coin_mismatch`، `ad_over_cap`، `high_win_rate`، `fast_earn` و یک `score` |
| GET | `/player?q=<موبایل یا id>` | `{ player, transactions, games, purchases }` |

## Socket.io

آدرس همان دامنه (`/socket.io`). توکن در `auth.token` فرستاده می‌شود؛ بدون توکن معتبر، اتصال با خطای `UNAUTHORIZED` رد می‌شود. حداکثر اندازهٔ هر پیام 64KB است. رویدادهای اتاق، بازی آنلاین و چت سراسری در `src/socket/events.ts` تعریف شده‌اند.

🔒 توکن بازیکن لازم است · 🛡 کلید ادمین لازم است
