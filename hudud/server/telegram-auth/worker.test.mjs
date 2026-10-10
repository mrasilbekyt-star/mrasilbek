// node --test hudud/server/telegram-auth/worker.test.mjs
import assert from 'node:assert/strict';
import { generateKeyPairSync, createVerify } from 'node:crypto';
import test from 'node:test';

import worker, { customToken } from './worker.js';

const { privateKey, publicKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const serviceAccount = {
  client_email: 'firebase-adminsdk@hudud.iam.gserviceaccount.com',
  private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }),
};

function decode(part) {
  return JSON.parse(Buffer.from(part, 'base64url').toString());
}

test('custom tokens are valid RS256 JWTs for Firebase', async () => {
  const token = await customToken(serviceAccount, 'tg_42', { phone: '+998901234567' });
  const [h, p, sig] = token.split('.');
  assert.deepEqual(decode(h), { alg: 'RS256', typ: 'JWT' });
  const payload = decode(p);
  assert.equal(payload.uid, 'tg_42');
  assert.equal(payload.iss, serviceAccount.client_email);
  assert.equal(payload.claims.phone, '+998901234567');
  assert.ok(payload.exp - payload.iat === 3600);
  const verify = createVerify('RSA-SHA256');
  verify.update(`${h}.${p}`);
  assert.ok(verify.verify(publicKey, Buffer.from(sig, 'base64url')));
});

/** An in-memory KV and a fake Telegram, enough to walk the whole flow. */
function setup() {
  const kv = new Map();
  const sent = [];
  globalThis.fetch = async (url, init) => {
    sent.push({ url, body: JSON.parse(init.body) });
    return new Response('{}');
  };
  const env = {
    BOT_TOKEN: 'bot-token',
    WEBHOOK_SECRET: 'secret',
    FIREBASE_SA: JSON.stringify(serviceAccount),
    AUTH: {
      get: async (k) => kv.get(k) ?? null,
      put: async (k, v) => void kv.set(k, v),
      delete: async (k) => void kv.delete(k),
    },
  };
  const update = (message) =>
    worker.fetch(
      new Request('https://auth.example/telegram', {
        method: 'POST',
        headers: { 'X-Telegram-Bot-Api-Secret-Token': 'secret' },
        body: JSON.stringify({ message }),
      }),
      env,
    );
  const pollFor = (nonce) => worker.fetch(new Request(`https://auth.example/auth/poll?nonce=${nonce}`), env);
  return { kv, sent, env, update, pollFor };
}

const from = { id: 42, first_name: 'Asilbek' };
const nonce = 'abcdefghijklmnopqrstuvwx';

test('start, share own contact, poll once', async () => {
  const { sent, update, pollFor } = setup();
  assert.equal((await pollFor(nonce)).status, 204);
  await update({ chat: { id: 7 }, from, text: `/start ${nonce}` });
  assert.equal(sent[0].body.reply_markup.keyboard[0][0].request_contact, true);
  await update({ chat: { id: 7 }, from, contact: { user_id: 42, phone_number: '998901234567' } });
  const first = await pollFor(nonce);
  assert.equal(first.status, 200);
  const body = await first.json();
  assert.equal(body.phone, '+998901234567');
  assert.equal(body.name, 'Asilbek');
  assert.equal(decode(body.token.split('.')[1]).uid, 'tg_42');
  assert.equal((await pollFor(nonce)).status, 204, 'tokens are single use');
});

test("someone else's contact is refused", async () => {
  const { update, pollFor } = setup();
  await update({ chat: { id: 7 }, from, text: `/start ${nonce}` });
  await update({ chat: { id: 7 }, from, contact: { user_id: 99, phone_number: '998900000000' } });
  assert.equal((await pollFor(nonce)).status, 204);
});

test('webhook calls without the secret are rejected', async () => {
  const { env } = setup();
  const res = await worker.fetch(
    new Request('https://auth.example/telegram', { method: 'POST', body: '{}' }),
    env,
  );
  assert.equal(res.status, 403);
});
