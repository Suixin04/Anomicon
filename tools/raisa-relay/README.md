# Anomicon RAISA 工单中转服务部署指南

该服务是一个**零第三方依赖**的 Node.js（>= 20）极简中转进程，专门负责保管你的 GitHub App 私钥、对客户端提交的工单做校验/去重/限流，并代为在 `Suixin04/Anomicon` 创建 Issue 返回给格异录客户端。

> [!IMPORTANT]
> GitHub App 的 `.pem` 私钥**绝不能**打包进客户端 HAP；它只存放在你的海外服务器上。客户端只保存你绑定后的 HTTPS 域名（如 `https://raisa.你的域名`）。

---

## 步骤一：在 GitHub 创建并安装专用 GitHub App

1. 打开浏览器登录你的 GitHub 账号，进入右上角头像 **Settings** → 最下方 **Developer settings** → 左侧 **GitHub Apps** → 点击 **New GitHub App**。
2. 按以下内容填写（未提及项留空或保持默认）：
   - **GitHub App name**：填一个全局唯一名称，例如 `Anomicon RAISA Relay`（如重名可加后缀）。
   - **Homepage URL**：`https://github.com/Suixin04/Anomicon`
   - **Webhook**：**取消勾选 `Active`**（本服务只需主动调 API 建 Issue，不需要接收 Webhook）。
3. 展开 **Permissions** → **Repository permissions**：
   - 找到 **Issues**，将下拉框改为 **`Read and write`**（只需要这一个仓库权限，其余全部保持 `No access`）。
4. **Where can this GitHub App be installed?**：选择 **`Only on this account`**。
5. 点击底部的 **Create GitHub App**。
6. 创建完成后在 **General** 页面记录两样东西：
   - 顶部的 **App ID**（一串纯数字，例如 `1122334`，对应 `GITHUB_APP_ID`）。
   - 向下滚动到 **Private keys** → 点击 **Generate a private key**，浏览器会自动下载一个 `.pem` 文件（妥善保存，后面传到服务器）。
7. 点击左侧栏 **Install App**：
   - 点击你账号旁边的 **Install**。
   - 选择 **`Only select repositories`** → 下拉选中 **`Suixin04/Anomicon`** → 点击 **Install**。
8. 安装完成后注意浏览器地址栏 URL，形如：
   `https://github.com/settings/installations/12345678`
   其中末尾的 **`12345678`** 就是 `GITHUB_INSTALLATION_ID`。
9. *(可选，建议)* 在 `Suixin04/Anomicon` 仓库 **Issues → Labels** 中预先创建以下 5 个标签以便视觉区分（不提前建 GitHub 也会自动创建，只是默认灰色）：
   - `raisa-feedback`
   - `type:render`（档案解析异常）
   - `type:bug`（终端运行故障）
   - `type:3d`（三维收容异常）
   - `type:feature`（系统演进提案）

---

## 步骤二：在 Cloudflare 配置子域名解析

1. 登录 [Cloudflare 控制台](https://dash.cloudflare.com/) → 点进你购买的域名 → 左侧 **DNS → Records** → **Add record**。
2. 添加一条 `A` 记录（假设主域名为 `example.com`，希望接口域名为 `raisa.example.com`）：
   - **Type**：`A`
   - **Name**：`raisa`
   - **IPv4 address**：填你海外服务器的公网 IP
   - **Proxy status**：**强烈建议先关闭橙云，设为「仅 DNS / 灰云」**
   - 点击 **Save**。

> [!TIP]
> **为什么先用灰云（仅 DNS）？**
> 1. Caddy 需要先直连验证端口来申请免费的 Let's Encrypt HTTPS 证书；开启橙云时若 TLS 模式不当会导致重定向死循环。
> 2. **只有确认你的海外服务器自身线路国内直连很慢时**，才建议在证书签好后把 Cloudflare 改为「橙云代理」+ Cloudflare 后台 **SSL/TLS → Overview** 设为 **`Full (strict)`**。保持灰云时，服务器直连稳定性完全可测。

---

## 步骤三：在海外 Linux 服务器部署中转服务与 HTTPS

以下命令以常见的 Ubuntu / Debian 为例（先 SSH 登录你的海外服务器）。

### 1. 检查 Node.js 版本（要求 >= 20）

```bash
node -v
```

如果未安装或低于 v20（Ubuntu 22/24 可用 NodeSource 或 nvm）：

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
node -v
```

### 2. 上传服务脚本与私钥

```bash
sudo mkdir -p /opt/anomicon-raisa-relay /etc/anomicon
```

从你的 Mac 本地把仓库里的 `tools/raisa-relay/` 文件和第 1 步下载的 `.pem` 私钥传到服务器（或者直接 `scp`）：

```bash
# 在你的 Mac 本机执行：
scp tools/raisa-relay/server.mjs tools/raisa-relay/.env.example root@你的服务器IP:/opt/anomicon-raisa-relay/
scp ~/Downloads/你的密钥文件.pem root@你的服务器IP:/etc/anomicon/github-app.pem
```

回到服务器，锁紧私钥权限并生成 `.env`：

```bash
sudo chmod 600 /etc/anomicon/github-app.pem
cd /opt/anomicon-raisa-relay
cp .env.example .env
nano .env
```

把 `.env` 中的 `GITHUB_APP_ID` 和 `GITHUB_INSTALLATION_ID` 改成步骤一记下的真实数字，保存退出。

### 3. 配置 `systemd` 开机自启与守护

将 `tools/raisa-relay/raisa-relay.service.example` 的内容写入 `/etc/systemd/system/raisa-relay.service`（确认里面 `which node` 路径与 `/usr/bin/node` 一致）：

```bash
which node
sudo tee /etc/systemd/system/raisa-relay.service > /dev/null <<'EOF'
[Unit]
Description=Anomicon RAISA Feedback Relay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/anomicon-raisa-relay
Environment=RAISA_ENV_FILE=/opt/anomicon-raisa-relay/.env
ExecStart=/usr/bin/node /opt/anomicon-raisa-relay/server.mjs
Restart=always
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadOnlyPaths=/etc/anomicon

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now raisa-relay
sudo systemctl status raisa-relay
```

### 4. 安装 Caddy 并自动开启 HTTPS

> 如果服务器上**尚未占用了 80 / 443 端口**，直接用 Caddy 最省事（自动申请并续签证书）：

```bash
sudo apt-get update && sudo apt-get install -y caddy
```

编辑 `/etc/caddy/Caddyfile`（把 `raisa.你的域名.com` 换成你的真实域名，参考 `Caddyfile.example`）：

```bash
sudo tee /etc/caddy/Caddyfile > /dev/null <<'EOF'
raisa.你的域名.com {
    encode zstd gzip
    request_body {
        max_size 64KB
    }
    reverse_proxy 127.0.0.1:8787 {
        header_up X-Real-IP {remote_host}
    }
}
EOF

sudo systemctl reload caddy
```

同时确保服务器防火墙 / 云厂商安全组已放行 **TCP `80` 和 `443`** 端口（80 用于 Let's Encrypt 证书校验，443 用于 HTTPS 业务流量；**8787 不需要对公网开放**，只监听 `127.0.0.1`）。

> 若你的服务器上**已经在运行 Nginx** 占用 443 端口，只需在对应 `server {}` 块增加一条：
> ```nginx
> location / {
>     client_max_body_size 64k;
>     proxy_pass http://127.0.0.1:8787;
>     proxy_set_header Host $host;
>     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
> }
> ```

---

## 步骤四：验证接口联调

1. 测试 HTTPS 与健康检查（在任意设备终端执行）：

```bash
curl -fsS https://raisa.你的域名.com/health
```

预期返回：

```json
{"ok":true,"service":"anomicon-raisa-relay","repo":"Suixin04/Anomicon","time":"..."}
```

2. 测试签发一条真实 Issue（成功后记得去 GitHub Issues 关闭这条测试单）：

```bash
curl -X POST https://raisa.你的域名.com/v1/raisa/tickets \
  -H 'Content-Type: application/json' \
  -H 'X-Idempotency-Key: manual-smoke-test-1' \
  -d '{
    "category": "system_proposal",
    "summary": "RAISA 中转联调冒烟测试",
    "details": "验证海外中转服务与专用 GitHub App 是否可正常创建 Issue。",
    "includeDiagnostics": true,
    "diagnostics": {
      "appVersionLabel": "1.2.9 (1020009)",
      "deviceType": "phone",
      "osLabel": "HarmonyOS (API 26)",
      "windowWidthVp": 412,
      "themeMode": "深色",
      "immersiveMaterial": true,
      "entrySource": "settings"
    }
  }'
```

预期返回 HTTP 201 及真实 Issue 编号：

```json
{"ticketCode":"RAISA-#1","issueNumber":1,"issueUrl":"https://github.com/Suixin04/Anomicon/issues/1","createdAt":"...","deduplicated":false}
```

### 常见排查命令
- 查看中转服务实时日志：`sudo journalctl -u raisa-relay -f`
- 查看 Caddy TLS 证书与反代日志：`sudo journalctl -u caddy -n 50`
- 若报 `HTTP 401` / `Bad credentials`：检查 `.pem` 私钥路径与 `GITHUB_APP_ID` 是否对应同一 App。
- 若报 `HTTP 404` / `Resource not accessible by integration`：确认该 App 已安装到 `Suixin04/Anomicon`，且 Repository Permissions 中 **Issues** 为 `Read and write`。

---

## 步骤五：接入格异录客户端

当上面 `curl` 联调返回真实 Issue 编号后，在代码仓库中打开：
`features/library/src/main/ets/domain/RaisaFeedbackContracts.ets`

将第 7 行的常量修改为你的真实 HTTPS 地址即可（**不要带末尾斜杠 `/`**）：

```ts
export const RAISA_RELAY_BASE_URL: string = 'https://raisa.你的域名.com';
```

修改后重新构建即可生效，设置页、基金会中心页与文章「更多 → 上报档案异常」三处入口会自动从「离线复制兜底模式」切换为「直连通道在线」。
