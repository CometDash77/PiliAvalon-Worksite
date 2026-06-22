---
audience: agent-facing
type: reasonix-cli-repair-record
created: "2026-06-21"
status: repaired-and-memory-updated
---

# Reasonix Next CLI Repair Record

## User Policy

The user explicitly requested the npm `next` train, not `latest`.

## Broken State

After a Reasonix update, these commands exited `0` but produced no output:

- `reasonix --help`
- `reasonix --version`
- `reasonix doctor`
- `reasonix run --dir /home/mo/Documents/piliavalon --model deepseek-pro --max-steps 1 "Reply exactly REASONIX_RELAUNCH_OK"`

Direct Node execution exposed the underlying error:

- `node .../reasonix/bin/reasonix.js --help`
- Error: `ERR_INVALID_PACKAGE_CONFIG`

Filesystem evidence showed the global npm package was corrupted:

- `package.json`: `0` bytes
- `README.md`: `0` bytes
- `bin/reasonix.js`: `0` bytes
- `npm ls -g reasonix --depth=0` showed `reasonix@` with no version.

## Registry And Cache Evidence

Initial npm metadata queries against `registry.npmmirror.com` failed with
cache/registry integrity symptoms:

- `EINTEGRITY`
- `ENOENT` under `~/.npm/_cacache`

Using official npm registry and a temporary cache succeeded:

```text
npm view reasonix dist-tags --json --registry=https://registry.npmjs.org --cache /tmp/reasonix-npm-cache
```

Returned:

```json
{
  "latest": "0.53.2",
  "canary": "1.8.0-canary.9",
  "next": "1.10.0-rc.1"
}
```

`reasonix@next` metadata:

```json
{
  "version": "1.10.0-rc.1",
  "dist.tarball": "https://registry.npmjs.org/reasonix/-/reasonix-1.10.0-rc.1.tgz",
  "bin": {
    "reasonix": "bin/reasonix.js"
  }
}
```

## Repair

Installed only the requested next train:

```text
npm install -g reasonix@next --registry=https://registry.npmjs.org --cache /tmp/reasonix-npm-cache
```

The package content was restored:

- `package.json`: `957` bytes
- `bin/reasonix.js`: `709` bytes

The installed package version:

```text
reasonix@1.10.0-rc.1
```

The npm package installed `bin/reasonix.js` without executable permission in
this environment. Shell execution initially failed with:

```text
Permission denied
```

Fixed by:

```text
chmod +x /home/mo/.nvm/versions/node/v22.22.3/lib/node_modules/reasonix/bin/reasonix.js
```

## Verified Behavior

`reasonix --version` returned:

```text
reasonix npm-v1.10.0-rc.1
```

`reasonix doctor` completed and reported:

- config: `~/.reasonix/config.toml`
- warning: legacy `~/.config/reasonix/config.toml` exists but is ignored
- providers: `deepseek-flash` and `deepseek-pro` key present
- plugin list present
- permissions mode: `ask`

`reasonix run --help` showed supported flags:

- `-c`
- `--continue`
- `--dir`
- `--max-steps`
- `--metrics`
- `--model`
- `--resume`
- `--show-thinking`

Minimal real run:

```text
reasonix run --dir /home/mo/Documents/piliavalon --model deepseek-pro --max-steps 1 "Reply exactly REASONIX_NEXT_OK"
```

Returned:

```text
REASONIX_NEXT_OK
```

The minimal run also printed unrelated third-party MCP/plugin warnings. Treat
those warnings as non-core failures unless the task requires those plugins.

## Updated Worksite Files

- `.reasonix/skills/worksite-reasonix-harness.md`
- `.reasonix/memory/2026-06-08-reasonix-operating-memory.md`
- `REASONIX.md`

## Non-Claims

This record does not claim Task-075 CI green, APK availability, prerelease
publication, manual acceptance, or stable release approval.
