# 🥚 Egg Heist — Roblox o'yini

**"Steal an Egg"** uslubidagi to'liq, ishlaydigan Roblox o'yini. Butun o'yin
kod orqali quriladi — hech qanday pullik asset ishlatilmaydi, hammasi tekin.

Hozirgi Roblox trendiga asoslangan: tuxum o'g'irla → bazangga olib bor →
och (hatch) → pet pul ishlab beradi → kuchay → boshqalardan o'g'irla.

---

## 🚀 Roblox'ga yuklash (eng oson yo'l)

1. **Roblox Studio**'ni oching (kompyuterga bepul o'rnatiladi: https://create.roblox.com/).
2. Yuqoridan **File → Open from File...** ni bosing.
3. Shu papkadagi **`EggHeist.rbxlx`** faylini tanlang.
4. O'yin ochiladi. **Play** (▶️) tugmasini bosib sinab ko'ring.
5. Yoqsa: **File → Publish to Roblox As...** → nom bering → **Create**.
6. Tayyor! O'yiningiz endi Roblox'da. 🎉

> ⚠️ **Muhim:** Pul saqlanishi (DataStore) faqat o'yin **publish qilingandan**
> keyin ishlaydi. Studio'da sinaganda saqlash ishlamasligi normal holat.
> Publish qilgach: **Game Settings → Security → "Enable Studio Access to
> API Services"** ni yoqib qo'ying.

---

## 🎮 Qanday o'ynaladi

| Qadam | Nima qilinadi |
|-------|---------------|
| 1️⃣ | Markazdagi **tuxum maydoni**ga bor, tuxum yoniga kelib **E** ni bosib o'g'irla |
| 2️⃣ | Tuxumni **bazangga** (yashil Hatch Pad) olib borib topshir |
| 3️⃣ | Tuxum ochiladi va **pet** paydo bo'ladi — u har sekund pul ishlaydi 💰 |
| 4️⃣ | Pastdagi **Shop**'dan tezlik, sumka, hatch tezligini oshir |
| 5️⃣ | Boshqa o'yinchilar bazasidan **pet o'g'irla** (himoya tugagach) |
| 6️⃣ | Yetarli pul yig'ib **Rebirth** qil → doimiy daromad ko'paytmasi |

### Tuxum darajalari
| Daraja | Rang | Daromad |
|--------|------|---------|
| Common | Kulrang | $1/s |
| Uncommon | Yashil | $3/s |
| Rare | Ko'k | $8/s |
| Epic | Binafsha | $22/s |
| Legendary | Oltin | $65/s |

---

## 🧩 Loyiha tuzilishi

```
mrasilbek/
├── EggHeist.rbxlx                 ← Studio'da shuni oching!
├── build_rbxlx.py                 ← .rbxlx faylni qayta yasovchi skript
├── default.project.json           ← Rojo uchun (ixtiyoriy, tajribali uchun)
├── GAME_DESIGN.md                 ← o'yin g'oyasi va rejasi
└── src/
    ├── ServerScriptService/
    │   └── EggHeistServer.server.lua   ← server logikasi (xarita, o'g'irlash, pul, saqlash)
    └── StarterPlayer/StarterPlayerScripts/
        └── EggHeistClient.client.lua   ← interfeys (GUI, shop, statistika)
```

---

## 🔧 Kodni o'zgartirsangiz

`src/` ichidagi `.lua` fayllarni tahrirlagach, `.rbxlx` faylni yangilash uchun:

```bash
python3 build_rbxlx.py
```

Keyin Studio'da faylni qayta oching.

### Oson sozlamalar (`EggHeistServer.server.lua` yuqorisida)
- `RARITIES` — tuxum darajalari, ranglari, daromadi, tushish ehtimoli
- `UPGRADES` — shop narxlari
- `PET_PROTECT_TIME` — pet o'g'irlashdan himoya vaqti
- `NUM_PLOTS` — bazalar soni
- `STANDS_PER_PLOT` — har bazadagi pet joylari

---

## ✅ Nimalar bor
- Kod orqali quriladigan to'liq xarita (baseplate, bazalar, tuxum maydoni)
- ProximityPrompt orqali o'g'irlash mexanikasi
- Tuxum ochish (hatch) + pet daromadi tizimi
- PvP: boshqa bazadan pet o'g'irlash (himoya taymeri bilan)
- leaderstats: Cash + Rebirths
- Shop: 3 xil upgrade + Rebirth
- DataStore orqali saqlash
- To'liq GUI (o'zbekcha)

Yaxshi o'yin bo'lsin! 🎮
