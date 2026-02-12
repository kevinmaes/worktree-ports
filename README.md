# conductor-port-setup

Deterministic per-workspace port assignment for [Conductor](https://conductor.build) workspaces.

When Conductor creates multiple workspace clones of the same repo, they all try to use the same dev server port. This script hashes each workspace's directory name to a unique port in the **4000-4999** range and writes it to `.env` as `APP_PORT`.

## Quick start

Add this to your repo's `conductor.json`:

```json
{
  "scripts": {
    "setup": "curl -sSL https://raw.githubusercontent.com/kevinmaes/worktree-ports/main/setup-env.sh | bash && pnpm install"
  }
}
```

Then read `APP_PORT` in your dev server config.

## Framework examples

### Vite (`vite.config.ts`)

```ts
import "dotenv/config";
import { defineConfig } from "vite";

const appPort = Number(process.env.APP_PORT) || 3000;

export default defineConfig({
  server: { port: appPort },
  preview: { port: appPort },
  // ... other config
});
```

### Next.js (`package.json`)

```json
{
  "scripts": {
    "dev": "next dev -p ${APP_PORT:-3000}"
  }
}
```

### Express / Node

```ts
const port = Number(process.env.APP_PORT) || 3000;
app.listen(port);
```

## What it does

1. If `CONDUCTOR_ROOT_PATH` is set (automatically by Conductor), copies `.env` from the root repo into the workspace
2. Hashes the workspace directory name using djb2 to a port in 4000-4999
3. Writes `APP_PORT=<port>` to `.env` (creates or updates the key idempotently)

## How the port is chosen

The script uses the [djb2 hash algorithm](http://www.cse.yorku.ca/~oz/hash.html) on the workspace directory name (e.g., `guangzhou`, `tokyo`, `berlin`), then maps it to the 4000-4999 range. The same directory name always produces the same port, so ports are stable across setup runs.

## Requirements

- Bash 4+
- Runs on macOS and Linux

## License

MIT
