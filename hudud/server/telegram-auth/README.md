# Telegram orqali kirish (tekin)

Foydalanuvchi telefon raqami bilan SMS'siz kiradi:
1. Ilova Telegram'da botni ochadi.
2. Foydalanuvchi bitta tugma bilan o'z raqamini yuboradi.
3. Bu kichik server (Cloudflare Worker) Firebase uchun kirish tokenini yaratadi.
4. Ilova shu token bilan kiradi.

Hammasi tekin:
- Telegram Bot API pul olmaydi.
- Cloudflare Workers tekin tarifi kuniga 100 000 so'rovgacha ishlaydi.
- Firebase'da custom token bilan kirish ham tekin.

## O'rnatish (bir marta, ~15 daqiqa)

1. **Bot yaratish:** Telegram'da @BotFather → `/newbot` buyrug'ini yuboring. Nom bering, masalan `HududRunBot`.
   Bot bergan **token**ni saqlang.
2. **Firebase xizmat kaliti:** Firebase Console → ⚙️ Project settings → Service accounts →
   **Generate new private key**. JSON fayl yuklanadi. ⚠️ U maxfiy: hech kimga bermang va git'ga qo'ymang.
3. **Cloudflare:** https://dash.cloudflare.com da tekin hisob oching. Shu papkada quyidagilarni bajaring:
   ```bash
   npx wrangler login
   npx wrangler kv namespace create AUTH        # chiqqan id'ni wrangler.toml ga yozing
   npx wrangler secret put BOT_TOKEN            # bot tokeni
   npx wrangler secret put WEBHOOK_SECRET       # istalgan uzun tasodifiy so'z
   npx wrangler secret put FIREBASE_SA          # Firebase JSON faylining butun matni
   npx wrangler deploy                          # manzil chiqadi: https://hudud-auth.<siz>.workers.dev
   ```
4. **Botni serverga ulash** (brauzerda bir marta oching, `<...>` larni almashtiring):
   ```
   https://api.telegram.org/bot<BOT_TOKEN>/setWebhook?url=https://hudud-auth.<siz>.workers.dev/telegram&secret_token=<WEBHOOK_SECRET>
   ```
5. **Ilovaga ulash:** GitHub → repo → Settings → Secrets and variables → Actions → **Variables**:
   - `HUDUD_TELEGRAM_BOT` = bot nomi, `@` belgisisiz (masalan `HududRunBot`);
   - `HUDUD_AUTH_SERVER` = `https://hudud-auth.<siz>.workers.dev`.

   Keyingi APK'da "Telefon raqam bilan (Telegram)" tugmasi ishlaydi.

Test: `node --test worker.test.mjs`
