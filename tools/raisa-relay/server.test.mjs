import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { after, before, describe, it } from 'node:test';
import {
  createRateLimiter,
  createRelayApp,
  detectAttachmentType,
  signGitHubAppJwt,
  validateAndDecodeAttachments,
  validateAndFormatTicket
} from './server.mjs';

function decodeBase64UrlJson(segment) {
  return JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
}

const VALID_1PX_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aF9sAAAAASUVORK5CYII=',
  'base64'
);

describe('Anomicon RAISA Relay', () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  const privateKeyPem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  const tempAttachmentsDir = fs.mkdtempSync(path.join(os.tmpdir(), 'anomicon-raisa-att-'));

  let mockGitHub;
  let mockGitHubBaseUrl = '';
  let tokenRequestCount = 0;
  let createdIssues = [];

  let relayServer;
  let relayBaseUrl = '';

  before(async () => {
    mockGitHub = http.createServer((req, res) => {
      const url = req.url || '';
      if (req.method === 'POST' && url === '/app/installations/998877/access_tokens') {
        tokenRequestCount++;
        const auth = String(req.headers.authorization || '');
        assert.ok(auth.startsWith('Bearer '), 'must send bearer JWT');
        const jwt = auth.slice('Bearer '.length);
        const parts = jwt.split('.');
        assert.equal(parts.length, 3);
        const verifier = crypto.createVerify('RSA-SHA256');
        verifier.update(`${parts[0]}.${parts[1]}`);
        assert.equal(verifier.verify(publicKey, parts[2], 'base64url'), true, 'JWT signature must verify');
        const payload = decodeBase64UrlJson(parts[1]);
        assert.equal(payload.iss, '123456');

        res.writeHead(201, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
          token: `ghs_mock_token_${tokenRequestCount}`,
          expires_at: new Date(Date.now() + 60 * 60 * 1000).toISOString()
        }));
        return;
      }

      if (req.method === 'POST' && url === '/repos/Suixin04/Anomicon/issues') {
        assert.equal(req.headers.authorization, 'Bearer ghs_mock_token_1');
        const chunks = [];
        req.on('data', (chunk) => chunks.push(chunk));
        req.on('end', () => {
          const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
          const number = 42 + createdIssues.length;
          createdIssues.push(body);
          res.writeHead(201, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({
            number,
            html_url: `https://github.com/Suixin04/Anomicon/issues/${number}`,
            created_at: '2026-11-25T05:30:00Z'
          }));
        });
        return;
      }

      res.writeHead(404);
      res.end();
    });

    await new Promise((resolve) => mockGitHub.listen(0, '127.0.0.1', resolve));
    mockGitHubBaseUrl = `http://127.0.0.1:${mockGitHub.address().port}`;

    let tick = 1000000;
    relayServer = createRelayApp({
      appId: '123456',
      installationId: '998877',
      privateKeyPem,
      owner: 'Suixin04',
      repo: 'Anomicon',
      githubApiBase: mockGitHubBaseUrl,
      attachmentsDir: tempAttachmentsDir,
      hourlyLimit: 4,
      burstLimit: 4,
      trustProxy: true
    }, {
      rateLimiter: createRateLimiter({ hourlyLimit: 4, burstLimit: 4, nowFn: () => tick })
    });

    await new Promise((resolve) => relayServer.listen(0, '127.0.0.1', resolve));
    relayBaseUrl = `http://127.0.0.1:${relayServer.address().port}`;
  });

  after(async () => {
    await new Promise((resolve) => relayServer.close(resolve));
    await new Promise((resolve) => mockGitHub.close(resolve));
    fs.rmSync(tempAttachmentsDir, { recursive: true, force: true });
  });

  it('signs valid RS256 GitHub App JWTs', () => {
    const token = signGitHubAppJwt('123456', privateKeyPem, 1700000000);
    const [head, body, sig] = token.split('.');
    assert.deepEqual(decodeBase64UrlJson(head), { alg: 'RS256', typ: 'JWT' });
    assert.deepEqual(decodeBase64UrlJson(body), { iat: 1699999940, exp: 1700000540, iss: '123456' });
    const verifier = crypto.createVerify('RSA-SHA256');
    verifier.update(`${head}.${body}`);
    assert.equal(verifier.verify(publicKey, sig, 'base64url'), true);
  });

  it('escapes @mentions and raw HTML and validates attachment magic bytes', () => {
    const formatted = validateAndFormatTicket({
      category: 'archive_render',
      summary: 'SCP-3125 折叠异常',
      details: '尝试联系 @octocat 并渲染 <script>alert(1)</script>',
      includeDiagnostics: false
    });
    assert.equal(formatted.error, undefined);
    assert.ok(formatted.issueBody.includes('@\u200Boctocat'));
    assert.ok(formatted.issueBody.includes('&lt;script&gt;'));

    // Spoofed PNG (ASCII text pretending to be image/png) must be rejected
    assert.equal(detectAttachmentType(Buffer.from('not really a png'), 'image/png', 'fake.png'), null);
    const badBatch = validateAndDecodeAttachments([
      { fileName: 'fake.png', mimeType: 'image/png', base64Data: Buffer.from('hello').toString('base64') }
    ]);
    assert.ok(badBatch.error);

    // >3 attachments must be rejected
    const tooMany = validateAndDecodeAttachments([1, 2, 3, 4].map((n) => ({
      fileName: `${n}.png`,
      mimeType: 'image/png',
      base64Data: VALID_1PX_PNG.toString('base64')
    })));
    assert.ok(tooMany.error);
  });

  it('serves health check, stores verified attachments, embeds links in GitHub issues, deduplicates retries, and enforces rate limit', async () => {
    const healthRes = await fetch(`${relayBaseUrl}/health`);
    assert.equal(healthRes.status, 200);
    const healthJson = await healthRes.json();
    assert.equal(healthJson.ok, true);
    assert.equal(healthJson.repo, 'Suixin04/Anomicon');
    assert.equal(healthJson.attachmentsEnabled, true);

    const badRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: 'unknown', summary: 'hi', details: 'short' })
    });
    assert.equal(badRes.status, 400);

    const logContent = Buffer.from('[INFO] SCP-3125 fold mismatch\n', 'utf8');
    const payload = {
      category: 'archive_render',
      summary: 'SCP-3125 折叠块异常',
      details: '点击第 3 个折叠块后无法正确换行，@someone 测试',
      contact: 'archivist',
      includeDiagnostics: true,
      diagnostics: {
        appVersion: '1.2.10',
        appVersionCode: 1020010,
        appVersionLabel: '1.2.10 (1020010)',
        deviceType: 'phone',
        osLabel: 'HarmonyOS 6.0 (API 26)',
        windowWidthVp: 412,
        themeMode: '深色',
        immersiveMaterial: true,
        entrySource: 'article',
        articleId: 'scp-3125',
        articleTitle: 'SCP-3125',
        articleUrl: 'https://scp-wiki-cn.wikidot.com/scp-3125',
        renderMode: 'native',
        revealHiddenText: true
      },
      attachments: [
        {
          fileName: 'evidence-[1].png',
          mimeType: 'image/png',
          base64Data: VALID_1PX_PNG.toString('base64')
        },
        {
          fileName: 'crash.log',
          mimeType: 'text/plain',
          base64Data: logContent.toString('base64')
        }
      ]
    };

    const createRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Host': new URL(relayBaseUrl).host,
        'X-Forwarded-Proto': 'http',
        'CF-Connecting-IP': '203.0.113.10',
        'X-Idempotency-Key': 'draft-key-1'
      },
      body: JSON.stringify(payload)
    });
    assert.equal(createRes.status, 201);
    const createJson = await createRes.json();
    assert.equal(createJson.issueNumber, 42);
    assert.equal(createJson.ticketCode, 'RAISA-#42');
    assert.equal(createJson.attachmentsCount, 2);
    assert.equal(createJson.deduplicated, false);
    assert.equal(createdIssues.length, 1);
    assert.deepEqual(createdIssues[0].labels, ['raisa-feedback', 'type:render']);
    assert.ok(createdIssues[0].body.includes('`1.2.10 (1020010)`'));
    assert.ok(createdIssues[0].body.includes('@\u200Bsomeone'));
    assert.ok(createdIssues[0].body.includes('### 现场附件'));

    const imageLinkMatch = createdIssues[0].body.match(/!\[[^\]]*\]\((http[^)]+\.png)\)/);
    assert.ok(imageLinkMatch, 'Issue body should embed uploaded image URL');
    const logLinkMatch = createdIssues[0].body.match(/- \[[^\]]+\]\((http[^)]+\.log)\)/);
    assert.ok(logLinkMatch, 'Issue body should link uploaded log URL');

    const imgGet = await fetch(imageLinkMatch[1]);
    assert.equal(imgGet.status, 200);
    assert.equal(imgGet.headers.get('content-type'), 'image/png');
    assert.equal(imgGet.headers.get('x-content-type-options'), 'nosniff');
    assert.equal(imgGet.headers.get('content-disposition'), 'inline');
    assert.deepEqual(Buffer.from(await imgGet.arrayBuffer()), VALID_1PX_PNG);

    const logGet = await fetch(logLinkMatch[1]);
    assert.equal(logGet.status, 200);
    assert.ok(logGet.headers.get('content-disposition').startsWith('attachment;'));
    assert.deepEqual(Buffer.from(await logGet.arrayBuffer()), logContent);

    // Path traversal must be rejected
    const traversalGet = await fetch(`${relayBaseUrl}/v1/raisa/attachments/../../package.json`);
    assert.equal(traversalGet.status, 404);

    // Same idempotency key returns deduplicated response without calling GitHub again.
    const dupRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'CF-Connecting-IP': '203.0.113.10',
        'X-Idempotency-Key': 'draft-key-1'
      },
      body: JSON.stringify(payload)
    });
    assert.equal(dupRes.status, 200);
    const dupJson = await dupRes.json();
    assert.equal(dupJson.deduplicated, true);
    assert.equal(dupJson.attachmentsCount, 2);
    assert.equal(createdIssues.length, 1);

    // Next 3 requests consume remaining rate limit (limit=4), 5th returns 429.
    for (const seq of ['2', '3', '4']) {
      const okRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'CF-Connecting-IP': '203.0.113.10',
          'X-Idempotency-Key': `draft-key-${seq}`
        },
        body: JSON.stringify({ ...payload, attachments: undefined })
      });
      assert.equal(okRes.status, 201);
    }
    assert.equal(tokenRequestCount, 1);
    assert.equal(createdIssues.length, 4);

    const limitedRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'CF-Connecting-IP': '203.0.113.10',
        'X-Idempotency-Key': 'draft-key-5'
      },
      body: JSON.stringify({ ...payload, attachments: undefined })
    });
    assert.equal(limitedRes.status, 429);
    assert.ok(Number(limitedRes.headers.get('retry-after')) > 0);
  });
});
