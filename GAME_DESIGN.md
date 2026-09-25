# 🎯 Egg Heist — O'yin Dizayn Hujjati (GDD)

## G'oya
Roblox'ning 2026 trendi — **"Steal an Egg / Steal a Brainrot Egg"** uslubidagi
o'yin. O'yinchi tuxum o'g'irlaydi, bazasida ochadi, pet pul ishlab beradi,
o'yinchi kuchayadi va boshqalardan o'g'irlaydi.

## Asosiy sikl (Core Loop)
```
   ┌─────────────────────────────────────────────────┐
   │  Tuxum o'g'irla → Bazaga topshir → Hatch qil     │
   │        ↑                                ↓         │
   │   Kuchaytir  ←  Pulni sarfla  ←  Pet pul ishlaydi│
   └─────────────────────────────────────────────────┘
```

## Mexanikalar

### 1. Tuxum o'g'irlash (PvE)
- Markazda 10 ta "egg pad" — vaqti-vaqti bilan tuxum tug'iladi.
- Tuxum yoniga kelib ProximityPrompt (E) bilan o'g'irlanadi.
- O'yinchi cheklangan sonda tuxum ko'tara oladi (sumka = Capacity upgrade).
- Ko'p ko'targanda yurish tezligi biroz pasayadi.

### 2. Hatch (ochish)
- Tuxumni bazadagi Hatch Pad'ga topshirasan.
- Belgilangan vaqtdan keyin (Hatch upgrade tezlashtiradi) pet paydo bo'ladi.

### 3. Daromad
- Har pet har sekund o'z qiymati miqdorida pul beradi.
- Rebirth ko'paytmasi: `daromad × (1 + rebirths × 0.5)`.

### 4. PvP o'g'irlash
- Pet qo'yilgach 45 sekund himoyalangan.
- Himoya tugagach, boshqa o'yinchi kelib pet'ni o'g'irlab, o'z bazasiga
  olib ketishi mumkin.

### 5. Shop (upgrade)
| Upgrade | Ta'siri | Boshlang'ich narx |
|---------|---------|-------------------|
| 🏃 Tezlik | Yurish tezligi +2/lvl | $100 |
| 🎒 Sumka | Ko'tarish hajmi +1/lvl | $150 |
| 🥚 Hatch | Ochish vaqti -1s/lvl | $120 |

Narx formulasi: `base × (mult ^ level)`.

### 6. Rebirth
- Narx: `1000 × (rebirths+1)²`.
- Pulni va bazani nolga qaytaradi, doimiy daromad ko'paytmasini beradi.

## Nodir darajalar (Rarity)
| Daraja | Weight (%) | Daromad |
|--------|-----------|---------|
| Common | 50 | $1/s |
| Uncommon | 25 | $3/s |
| Rare | 14 | $8/s |
| Epic | 8 | $22/s |
| Legendary | 3 | $65/s |

## Texnik yechim
- **Butun xarita kod orqali quriladi** (hand-built model shart emas).
- **ProximityPrompt** — o'g'irlash/topshirish uchun (custom input kerak emas).
- **Attributlar** — upgrade darajalari, stand holati.
- **DataStore** — o'yinchi ma'lumotini saqlash.

## Keyingi bosqichlar (kelajakda qo'shsa bo'ladi)
- [ ] Turli pet modellari (mesh)
- [ ] Ovoz effektlari
- [ ] Kunlik mukofot / quest
- [ ] Reyting (top boylar) taxtasi
- [ ] Gamepass (VIP, x2 daromad) — monetizatsiya
- [ ] Xarita bezaklari, effektlar
