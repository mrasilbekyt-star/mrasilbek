// Hudud: phone-number sign-in through Telegram, free of charge.
//
// 1. The app opens t.me/<bot>?start=<nonce>.
// 2. This bot answers with a "Send my number" button (request_contact).
// 3. Telegram sends the runner's own, verified number; the worker turns it
//    into a Firebase custom token and keeps it under the nonce for 5 minutes.
// 4. The app polls /auth/poll?nonce=... and signs in with the token.
//
// Runs on Cloudflare Workers (free plan). Needs:
//   secrets  BOT_TOKEN        from @BotFather
//            WEBHOOK_SECRET   any long random string
//            FIREBASE_SA      the Firebase service-account JSON (one line)
//   KV       AUTH             a KV namespace binding
// See README.md in this folder.

const TOKEN_AUD =
  'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit';

const TEXT = {
  ask: 'Hudud ilovasiga kirish uchun pastdagi tugmani bosing va raqamingizni yuboring.\n\n' +
    'Чтобы войти в Hudud, нажмите кнопку ниже и отправьте свой номер.',
  button: '📱 Raqamni yuborish / Отправить номер',
  done: '✅ Tasdiqlandi! Endi Hudud ilovasiga qayting.\n✅ Готово! Вернитесь в приложение Hudud.',
  notYours: "Iltimos, o'zingizning raqamingizni tugma orqali yuboring.\nОтправьте, пожалуйста, свой номер кнопкой.",
  expired: 'Vaqt tugadi. Ilovada qaytadan "Telegram" tugmasini bosing.\n' +
    'Время вышло. Снова нажмите «Telegram» в приложении.',
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'POST' && url.pathname === '/telegram') return telegram(request, env);
    if (request.method === 'GET' && url.pathname === '/auth/poll') return poll(url, env);
    return new Response('Hudud auth', { status: 404 });
  },
};

async function telegram(request, env) {
  if (request.headers.get('X-Telegram-Bot-Api-Secret-Token') !== env.WEBHOOK_SECRET) {
    return new Response('forbidden', { status: 403 });
  }
  const update = await request.json();
  const msg = update.message;
  if (!msg || !msg.from) return new Response('ok');
  const chat = msg.chat.id;

  const start = /^\/start\s+([A-Za-z0-9_-]{16,64})$/.exec(msg.text || '');
  if (start) {
    await env.AUTH.put(`chat:${chat}`, start[1], { expirationTtl: 600 });
    await send(env, chat, TEXT.ask, {
      keyboard: [[{ text: TEXT.button, request_contact: true }]],
      resize_keyboard: true,
      one_time_keyboard: true,
    });
    return new Response('ok');
  }

  if (msg.contact) {
    // Only the runner's own number counts, not a forwarded contact.
    if (msg.contact.user_id !== msg.from.id) {
      await send(env, chat, TEXT.notYours);
      return new Response('ok');
    }
    const nonce = await env.AUTH.get(`chat:${chat}`);
    if (!nonce) {
      await send(env, chat, TEXT.expired, { remove_keyboard: true });
      return new Response('ok');
    }
    const phone = msg.contact.phone_number.startsWith('+')
      ? msg.contact.phone_number
      : `+${msg.contact.phone_number}`;
    const name = [msg.from.first_name, msg.from.last_name].filter(Boolean).join(' ');
    const token = await customToken(JSON.parse(env.FIREBASE_SA), `tg_${msg.from.id}`, {
      phone,
      telegram: msg.from.id,
    });
    await env.AUTH.put(`done:${nonce}`, JSON.stringify({ token, phone, name }), { expirationTtl: 300 });
    await env.AUTH.delete(`chat:${chat}`);
    await send(env, chat, TEXT.done, { remove_keyboard: true });
    return new Response('ok');
  }

  return new Response('ok');
}

async function poll(url, env) {
  const nonce = url.searchParams.get('nonce') || '';
  if (!/^[A-Za-z0-9_-]{16,64}$/.test(nonce)) return new Response('bad nonce', { status: 400 });
  const done = await env.AUTH.get(`done:${nonce}`);
  if (!done) return new Response(null, { status: 204 });
  // A token is handed out once.
  await env.AUTH.delete(`done:${nonce}`);
  return new Response(done, { headers: { 'Content-Type': 'application/json' } });
}

async function send(env, chat, text, replyMarkup) {
  await fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chat, text, reply_markup: replyMarkup }),
  });
}

// ------------------------------------------------------------------ Firebase

/** A Firebase custom token for [uid], signed with the service account. */
export async function customToken(serviceAccount, uid, claims) {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };
  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: TOKEN_AUD,
    iat: now,
    exp: now + 3600,
    uid,
    claims,
  };
  const body = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(body));
  return `${body}.${b64url(signature)}`;
}

function pemToDer(pem) {
  const base64 = pem.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const bytes = atob(base64);
  const der = new Uint8Array(bytes.length);
  for (let i = 0; i < bytes.length; i++) der[i] = bytes.charCodeAt(i);
  return der.buffer;
}

function b64url(data) {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : new Uint8Array(data);
  let s = '';
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
