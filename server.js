const express = require('express');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const path = require('path');
require('dotenv').config();

const app = express();
app.use(express.json({ limit: '10kb' }));
app.use(express.static(__dirname));
const codes = new Map();
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT || 587),
  secure: String(process.env.SMTP_SECURE).toLowerCase() === 'true',
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
});
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const validEmail = value => typeof value === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) && value.length <= 254;

app.post('/api/send-code', async (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  if (!validEmail(email)) return res.status(400).json({ error: 'Проверь адрес электронной почты.' });
  const previous = codes.get(email);
  if (previous && Date.now() - previous.sentAt < 60_000) return res.status(429).json({ error: 'Подожди минуту перед повторной отправкой.' });
  const code = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
  try {
    await transporter.sendMail({
      from: process.env.MAIL_FROM || process.env.SMTP_USER,
      to: email,
      subject: 'Код подтверждения Exxpress',
      text: `Твой код подтверждения Exxpress: ${code}\n\nКод действует 10 минут. Если ты не запрашивал его, просто проигнорируй письмо.`,
      html: `<div style="font-family:Arial,sans-serif;background:#10151d;color:#edf4fa;padding:28px;border-radius:12px"><h1 style="color:#64b5f6">Exxpress</h1><p>Код подтверждения почты:</p><div style="font-size:32px;letter-spacing:8px;font-weight:bold;padding:18px;background:#202e3d;border-radius:8px">${code}</div><p>Код действует 10 минут.</p></div>`
    });
    codes.set(email, { codeHash: hash(code), expiresAt: Date.now() + 10 * 60_000, sentAt: Date.now(), attempts: 0 });
    res.json({ ok: true });
  } catch (error) {
    console.error('Email delivery failed:', error.message);
    res.status(503).json({ error: 'Письмо не отправлено. Проверь SMTP-настройки сервера.' });
  }
});

app.post('/api/verify-code', (req, res) => {
  const email = String(req.body?.email || '').trim().toLowerCase();
  const code = String(req.body?.code || '');
  const record = codes.get(email);
  if (!record || Date.now() > record.expiresAt) { codes.delete(email); return res.status(400).json({ error: 'Код истёк или не запрашивался. Запроси новый.' }); }
  record.attempts++;
  if (record.attempts > 5) { codes.delete(email); return res.status(429).json({ error: 'Слишком много попыток. Запроси новый код.' }); }
  if (!/^\d{6}$/.test(code) || hash(code) !== record.codeHash) return res.status(400).json({ error: 'Неверный код. Попробуй ещё раз.' });
  codes.delete(email);
  res.json({ ok: true, verified: true });
});

const port = Number(process.env.PORT || 8000);
app.listen(port, () => console.log(`Exxpress запущен: http://localhost:${port}`));
