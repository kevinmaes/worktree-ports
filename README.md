# worktree-ports

Deterministic per-worktree port assignment for parallel development tools.

When tools like [Conductor](https://conductor.build), [OpenAI Codex](https://openai.com/index/introducing-the-codex-app/), or manual `git worktree` workflows create multiple worktrees of the same repo, they all try to use the same dev server port. This script hashes each worktree's directory name to a unique port in the **4000-4999** range and writes it to `.env` as `APP_PORT`.

## Quick start

```bash
curl -fsSL https://raw.githubusercontent.com/kevinmaes/worktree-ports/main/setup-env.sh | bash
```

The script will:

1. Copy `.env` from your main worktree (preserving API keys, secrets, etc.)
2. Hash the directory name to a deterministic port in 4000-4999
3. Write `APP_PORT=<port>` to `.env`

## Tool-specific setup

### Conductor

Add the script to your `conductor.json` setup hook:

```json
{
  "scripts": {
    "setup": "curl -fsSL https://raw.githubusercontent.com/kevinmaes/worktree-ports/main/setup-env.sh | bash && pnpm install"
  }
}
```

Conductor runs `setup` automatically when creating a new workspace. The script uses `CONDUCTOR_ROOT_PATH` (set by Conductor) to locate the root `.env`.

### OpenAI Codex

Add the script to your environment setup. In your Codex cloud environment config or local setup, run it as part of your project initialization:

```bash
curl -fsSL https://raw.githubusercontent.com/kevinmaes/worktree-ports/main/setup-env.sh | bash
```

You can also mention it in your `AGENTS.md` so Codex knows to run it when creating worktrees:

```markdown
## Environment setup
Run `curl -fsSL https://raw.githubusercontent.com/kevinmaes/worktree-ports/main/setup-env.sh | bash`
after creating a worktree to assign a unique dev server port.
The port is written to `.env` as `APP_PORT`.
```

### Manual git worktrees

Run the script after creating a worktree:

```bash
git worktree add ../my-feature
cd ../my-feature
curl -fsSL https://raw.githubusercontent.com/kevinmaes/worktree-ports/main/setup-env.sh | bash
pnpm install
```

The script auto-detects the main worktree via `git worktree list` and copies `.env` from there.

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

Any tool that creates multiple worktrees of the same repo faces port conflicts. Whether it's Conductor creating workspaces named after cities, Codex spinning up worktrees per task, or a developer manually branching into worktrees, every copy tries to bind to the same default port (3000, 5173, etc.), causing "port already in use" errors.

### The solution

The `setup-env.sh` script runs inside a worktree and:

1. **Copies `.env` from the main worktree** -- Uses `CONDUCTOR_ROOT_PATH` if available (Conductor), otherwise detects the main worktree via `git worktree list`. This preserves your API keys, database URLs, and other environment variables.

2. **Hashes the directory name to a port** -- Uses the [djb2 hash algorithm](http://www.cse.yorku.ca/~oz/hash.html) to deterministically map the worktree directory name (e.g., `tokyo`) to a port in the 4000-4999 range.

3. **Writes `APP_PORT` to `.env`** -- Appends `APP_PORT=<port>` to `.env`, or updates it if the key already exists. This is idempotent, so re-running the script is safe.

### .env copy resolution order

The script looks for a source `.env` in this order:

1. `CONDUCTOR_ROOT_PATH/.env` -- if the Conductor env var is set
2. Main git worktree's `.env` -- detected via `git worktree list`
3. Skip copy -- if neither source exists, the script still assigns a port to any existing `.env`

### Port stability

The same directory name always produces the same port. If you delete and recreate a worktree with the same name, it gets the same port. Bookmarks, proxy configs, and muscle memory all keep working.

### Example port assignments

| Worktree  | Port |
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
| `CONDUCTOR_ROOT_PATH` | Conductor | Path to the original repo clone. Used as the primary source for `.env` copy. |
| `APP_PORT` | This script | The deterministic port number (4000-4999) written to `.env`. |

## Troubleshooting

**"No .env file found, skipping port assignment"**
The script only writes `APP_PORT` if a `.env` file exists. Make sure your main worktree (or root repo) has a `.env` file, even an empty one.

**"No source .env found"**
The script couldn't find an `.env` to copy. Check that your main worktree has a `.env`, and that you're running the script inside a git worktree (not a standalone clone).

**Port conflicts between different repos**
Worktrees from different repos that happen to share a directory name will get the same port. This is rare with tools like Conductor (which uses city names), but if it happens you can rename the directory.

**Dev server ignoring `APP_PORT`**
Make sure your framework config reads `process.env.APP_PORT` and that you've loaded dotenv (or your framework does it automatically). See [framework examples](#framework-examples).

**Script fails on Linux**
Requires Bash 3.2+. Some minimal Docker images only ship `sh`. Install Bash or use a base image that includes it.

## Requirements

- Bash 3.2+
- Git (for automatic main worktree detection)
- Runs on macOS and Linux

## License

MIT
