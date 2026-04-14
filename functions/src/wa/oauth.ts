import { onRequest } from 'firebase-functions/v2/https';
import type { Request, Response } from 'express';

import { REGION } from './runtime';

function sendLegacyDisabledJson(response: Response): void {
  response.status(410).json({
    success: false,
    code: 'reconnect_required',
    error:
      'Il flow OAuth legacy di WhatsApp e stato disattivato. Riconfigura il salone con il setup manuale dal pannello admin web.',
  });
}

function sendLegacyDisabledHtml(response: Response): void {
  response.status(410).send(
    `
<!DOCTYPE html>
<html lang="it">
  <head>
    <meta charset="utf-8" />
    <title>Ricollega WhatsApp</title>
    <style>
      body {
        font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        margin: 0;
        padding: 32px;
        background: #f5f5f5;
        color: #111827;
      }
      .card {
        max-width: 460px;
        margin: auto;
        background: white;
        padding: 24px;
        border-radius: 14px;
        box-shadow: 0 12px 36px rgba(15, 23, 42, 0.08);
      }
      h1 {
        margin: 0 0 12px;
        font-size: 22px;
      }
      p {
        line-height: 1.5;
      }
    </style>
  </head>
  <body>
    <div class="card">
      <h1>Flow legacy disattivato</h1>
      <p>Questo collegamento OAuth non e piu supportato.</p>
      <p>Apri il modulo WhatsApp nel pannello admin web e completa la nuova configurazione manuale.</p>
    </div>
  </body>
</html>
    `.trim(),
  );
}

export const startWhatsappOAuth = onRequest(
  { region: REGION, cors: true },
  async (request: Request, response: Response) => {
    if (request.method === 'OPTIONS') {
      response.set('Access-Control-Allow-Origin', '*');
      response.set(
        'Access-Control-Allow-Headers',
        'Content-Type, Authorization',
      );
      response.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
      response.status(204).send('');
      return;
    }

    sendLegacyDisabledJson(response);
  },
);

export const handleWhatsappOAuthCallback = onRequest(
  { region: REGION, cors: true },
  async (_request: Request, response: Response) => {
    sendLegacyDisabledHtml(response);
  },
);
