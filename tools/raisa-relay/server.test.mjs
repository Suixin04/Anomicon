import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import http from 'node:http';
import { after, before, describe, it } from 'node:test';
import {
  createRateLimiter,
  createRelayApp,
  signGitHubAppJwt,
  validateAndFormatTicket
} from './server.mjs';

function decodeBase64UrlJson(segment) {
  return JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'));
}

describe('Anomicon RAISA Relay', () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
  const privateKeyPem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();

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
      hourlyLimit: 3,
      burstLimit: 3,
      trustProxy: true
    }, {
      rateLimiter: createRateLimiter({ hourlyLimit: 3, burstLimit: 3, nowFn: () => tick })
    });

    await new Promise((resolve) => relayServer.listen(0, '127.0.0.1', resolve));
    relayBaseUrl = `http://127.0.0.1:${relayServer.address().port}`;
  });

  after(async () => {
    await new Promise((resolve) => relayServer.close(resolve));
    await new Promise((resolve) => mockGitHub.close(resolve));
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

  it('escapes @mentions and raw HTML in ticket formatting', () => {
    const formatted = validateAndFormatTicket({
      category: 'archive_render',
      summary: 'SCP-3125 折叠异常',
      details: '尝试联系 @octocat 并渲染 <script>alert(1)</script>',
      includeDiagnostics: false
    });
    assert.equal(formatted.error, undefined);
    assert.ok(formatted.issueBody.includes('@\u200Boctocat'));
    assert.ok(formatted.issueBody.includes('&lt;script&gt;'));
  });

  it('serves health check, creates GitHub issue, reuses installation token, deduplicates retries, and enforces rate limit', async () => {
    const healthRes = await fetch(`${relayBaseUrl}/health`);
    assert.equal(healthRes.status, 200);
    const healthJson = await healthRes.json();
    assert.equal(healthJson.ok, true);
    assert.equal(healthJson.repo, 'Suixin04/Anomicon');

    const badRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: 'unknown', summary: 'hi', details: 'short' })
    });
    assert.equal(badRes.status, 400);

    const payload = {
      category: 'archive_render',
      summary: 'SCP-3125 折叠块异常',
      details: '点击第 3 个折叠块后无法正确换行，@someone 测试',
      contact: 'archivist',
      includeDiagnostics: true,
      diagnostics: {
        appVersion: '1.2.9',
        appVersionCode: 1020009,
        appVersionLabel: '1.2.9 (1020009)',
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
      }
    };

    const createRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'CF-Connecting-IP': '203.0.113.10',
        'X-Idempotency-Key': 'draft-key-1'
      },
      body: JSON.stringify(payload)
    });
    assert.equal(createRes.status, 201);
    const createJson = await createRes.json();
    assert.equal(createJson.issueNumber, 42);
    assert.equal(createJson.ticketCode, 'RAISA-#42');
    assert.equal(createJson.deduplicated, false);
    assert.equal(createdIssues.length, 1);
    assert.deepEqual(createdIssues[0].labels, ['raisa-feedback', 'type:render']);
    assert.ok(createdIssues[0].body.includes('`1.2.9 (1020009)`'));
    assert.ok(createdIssues[0].body.includes('@\u200Bsomeone'));

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
    assert.equal(dupJson.issueNumber, 42);
    assert.equal(createdIssues.length, 1);

    // Requests 2 and 3 reuse cached installation token; request 4 hits rate limit 429.
    for (const seq of ['2', '3']) {
      const okRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'CF-Connecting-IP': '203.0.113.10',
          'X-Idempotency-Key': `draft-key-${seq}`
        },
        body: JSON.stringify(payload)
      });
      assert.equal(okRes.status, 201);
    }
    assert.equal(tokenRequestCount, 1);
    assert.equal(createdIssues.length, 3);

    const limitedRes = await fetch(`${relayBaseUrl}/v1/raisa/tickets`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'CF-Connecting-IP': '203.0.113.10',
        'X-Idempotency-Key': 'draft-key-4'
      },
      body: JSON.stringify(payload)
    });
    assert.equal(limitedRes.status, 429);
    assert.ok(Number(limitedRes.headers.get('retry-after')) > 0);
  });
});
