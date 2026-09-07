# Deploying to Railway

This repo can run as a remote, HTTPS-reachable MCP server on
[Railway](https://railway.app). Railway builds the container, terminates TLS
at its edge, and reverse-proxies plain HTTP to the container over its
internal network — so the container itself never needs to handle TLS.

## What's included

- **`Dockerfile.railway`** — same multi-stage build as the main `Dockerfile`,
  but the final stage is a small Debian image (not distroless) so it has a
  shell, and it's started via `docker-entrypoint.railway.sh`.
- **`docker-entrypoint.railway.sh`** — maps Railway's dynamic `$PORT` onto the
  server's `--port` flag, binds to `0.0.0.0`, and passes
  `--trust-proxy-headers` so the server advertises `https://` URLs (used in
  OAuth resource metadata) based on the `X-Forwarded-Proto` /
  `X-Forwarded-Host` headers Railway's edge sets — this is safe because
  Railway's proxy is the only thing that can reach the container.
- **`railway.json`** — tells Railway to build from `Dockerfile.railway`.

The original `Dockerfile` (distroless, `stdio` by default) is untouched and
still used for the official Docker Hub / GHCR images.

## Deploy steps

1. Push this repo to GitHub (or use Railway's CLI) and create a new Railway
   project from it. Railway will detect `railway.json` and build
   `Dockerfile.railway` automatically.
2. Set environment variables on the Railway service (Project → Variables):

   | Variable | Required | Purpose |
   | --- | --- | --- |
   | `GITHUB_PERSONAL_ACCESS_TOKEN` | Yes (unless using GitHub App auth) | PAT used to call the GitHub API. Create a [fine-grained PAT](https://github.com/settings/personal-access-tokens/new) with only the scopes you need. |
   | `GITHUB_TOOLSETS` | No | Comma-separated toolsets to enable, e.g. `repos,issues,pull_requests`. Defaults to the default toolset if unset. |
   | `GITHUB_READ_ONLY` | No | Set to `1` to restrict the server to read-only operations. |
   | `GITHUB_HOST` | No | Set for GitHub Enterprise Server / ghe.com, e.g. `https://github.example.com`. |
   | `GITHUB_MCP_SERVER_MRTR_STATE_KEY` | No | Required only to expose `delete_repository`. Generate with `openssl rand -base64 32`. |

   Do not set `PORT` yourself — Railway injects it automatically and the
   entrypoint script picks it up.

   Instead of a PAT you can use [GitHub App
   auth](./github-app-auth.md) (`GITHUB_APP_ID`,
   `GITHUB_APP_INSTALLATION_ID`, `GITHUB_APP_PRIVATE_KEY`) for
   server-to-server auth without per-user OAuth.

3. Once deployed, Railway gives you a public HTTPS domain (Project →
   Settings → Networking → Generate Domain), e.g.
   `https://your-service.up.railway.app`. That URL is your MCP server
   endpoint — configure MCP clients with:

   ```json
   {
     "type": "http",
     "url": "https://your-service.up.railway.app"
   }
   ```

   Path-based toolset selection also works, e.g.
   `https://your-service.up.railway.app/x/issues/readonly` — see
   [remote-server.md](./remote-server.md#url-path-parameters).

4. (Optional) If you plan to advertise OAuth discovery metadata for browser
   clients, also set `GITHUB_HOST`/`GITHUB_AUTHORIZATION_SERVER` as described
   in [streamable-http.md](./streamable-http.md#with-an-oauth-proxy-ghes--non-standard-authorization-server).
   For the default github.com host this isn't needed — the server derives
   correct `https://` URLs on its own via `--trust-proxy-headers` plus
   Railway's forwarded headers.

## Verifying the deployment

```bash
curl -i https://your-service.up.railway.app/ \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <a-github-pat-or-leave-unset-if-GITHUB_PERSONAL_ACCESS_TOKEN-is-set>' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"0"}}}'
```

A JSON-RPC response (not a connection error or TLS warning) confirms the
server is reachable over HTTPS and responding to MCP requests.

## Updating

Push to the branch Railway is tracking; it rebuilds `Dockerfile.railway` and
redeploys automatically.
