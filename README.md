# conductor-port-setup

Deterministic per-workspace port assignment for [Conductor](https://conductor.build) workspaces.

When Conductor creates multiple workspace clones of the same repo, they all try to use the same dev server port. This script hashes each workspace's directory name to a unique port in the **4000-4999** range and writes it to `.env` as `APP_PORT`.

## Setup guide

### 1. Add the setup script to `conductor.json`

In your project's `conductor.json`, add a `setup` script that curls and runs the script before installing dependencies:

```json
{
  "scripts": {
    "setup": "curl -sSL https://raw.githubusercontent.com/kevinmaes/worktree-ports/main/setup-env.sh | bash && pnpm install"
  }
}
```

Conductor runs the `setup` script automatically when creating a new workspace. The script will:

1. Copy your root repo's `.env` into the workspace (preserving API keys, secrets, etc.)
2. Append or update `APP_PORT=<port>` in the workspace's `.env`

### 2. Configure your dev server to use `APP_PORT`

Your app needs to read `APP_PORT` from the environment and use it as the dev server port. See [framework examples](#framework-examples) below.

### 3. Add `.env` to `.gitignore`

Make sure `.env` is in your `.gitignore` so workspace-specific ports aren't committed:

```
.env
```

### 4. Verify it works

After Conductor creates a workspace, check the `.env` file:

```bash
cat .env | grep APP_PORT
# APP_PORT=4732
```

Each workspace gets a different port based on its directory name (e.g., `tokyo` -> `4237`, `berlin` -> `4891`).

## Framework examples

### Vite (`vite.config.ts`)

```ts
import "dotenv/config";
import { defineConfig } from "vite";

const appPort = Number(process.env.APP_PORT) || 3000;

export default defineConfig({
  server: { port: appPort },
  preview: { port: appPort },
});
```

### Next.js

Use the environment variable directly in your `dev` script (`package.json`):

```json
{
  "scripts": {
    "dev": "next dev -p ${APP_PORT:-3000}"
  }
}
```

Or in `next.config.js` if you need it at config time:

```js
// Load .env manually if not using Next.js built-in env loading
require("dotenv").config();
```

Next.js automatically loads `.env` files, so `APP_PORT` is available via `process.env.APP_PORT` in your config and server code.

### Express / Node

```ts
import "dotenv/config";

const port = Number(process.env.APP_PORT) || 3000;
app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});
```

### Remix

In `vite.config.ts` (Remix uses Vite):

```ts
import "dotenv/config";
import { vitePlugin as remix } from "@remix-run/dev";
import { defineConfig } from "vite";

const appPort = Number(process.env.APP_PORT) || 3000;

export default defineConfig({
  plugins: [remix()],
  server: { port: appPort },
});
```

## How it works

### The problem

Conductor creates workspaces as git worktrees of your repo. Each workspace is a full clone in its own directory (e.g., `tokyo/`, `berlin/`, `denver/`). When you run `pnpm dev` in multiple workspaces, they all try to bind to the same port (typically 3000 or 5173), causing "port already in use" errors.

### The solution

The `setup-env.sh` script runs during workspace creation and:

1. **Copies `.env` from the root repo** -- If `CONDUCTOR_ROOT_PATH` is set (Conductor sets this automatically), the script copies `.env` from your original repo clone into the workspace. This preserves your API keys, database URLs, and other environment variables.

2. **Hashes the workspace directory name to a port** -- Uses the [djb2 hash algorithm](http://www.cse.yorku.ca/~oz/hash.html) to deterministically map the workspace directory name (e.g., `tokyo`) to a port in the 4000-4999 range.

3. **Writes `APP_PORT` to `.env`** -- Appends `APP_PORT=<port>` to `.env`, or updates it if the key already exists. This is idempotent, so re-running the script is safe.

### Port stability

The same directory name always produces the same port. If you delete and recreate a workspace with the same name, it gets the same port. This means bookmarks, proxy configs, and muscle memory all keep working.

### Example port assignments

| Workspace | Port |
|-----------|------|
| tokyo     | 4237 |
| berlin    | 4891 |
| denver    | 4732 |
| guangzhou | 4045 |
| mumbai    | 4358 |

*Ports are illustrative. Actual values depend on the djb2 hash output.*

## Environment variables

| Variable | Set by | Description |
|----------|--------|-------------|
| `CONDUCTOR_ROOT_PATH` | Conductor | Path to the original repo clone. Used to copy `.env` into the workspace. |
| `APP_PORT` | This script | The deterministic port number (4000-4999) written to `.env`. |

## Troubleshooting

**"No .env file found, skipping port assignment"**
The script only writes `APP_PORT` if a `.env` file exists. Either your root repo doesn't have a `.env`, or `CONDUCTOR_ROOT_PATH` isn't set. Create a `.env` in your root repo (even an empty one) before creating workspaces.

**Port conflicts between different repos**
If you use Conductor with multiple repos that happen to have workspaces with the same directory name, they'll get the same port. This is rare since Conductor uses city names, but if it happens you can rename the workspace directory.

**Dev server ignoring `APP_PORT`**
Make sure your framework config reads `process.env.APP_PORT` and that you've loaded dotenv (or your framework does it automatically). See [framework examples](#framework-examples).

**Script fails on Linux**
Requires Bash 4+. Some minimal Docker images ship with Bash 3 or only `sh`. Install Bash 4+ or use a base image that includes it.

## Requirements

- Bash 4+
- Runs on macOS and Linux

## License

MIT
