# cc-install Runbook

Operational procedures for a running install — the commands, what each one does,
and how to change things later.

For getting installed in the first place, see
[docs/INSTALL_GUIDE.md](docs/INSTALL_GUIDE.md). For signing in, see
[docs/CREDENTIALS.md](docs/CREDENTIALS.md). For the one-line command cheat sheet,
see [docs/QUICK_REFERENCE.md](docs/QUICK_REFERENCE.md).

## Contents

- [Changing which folder holds your files](#changing-which-folder-holds-your-files) (`ccpath`)
- [Choosing which models appear in the picker](#choosing-which-models-appear-in-the-picker) (Bedrock)
- [Available Bedrock Model IDs](#available-bedrock-model-ids)
- [Troubleshooting](#troubleshooting)

---

## Changing which folder holds your files

By default your files live in the `workspace` folder inside the install. `ccpath`
points that at any folder on your computer instead.

```bash
ccpath ~/Dev/projects     # point your workspace there
ccpath --show             # where is it now?
ccpath --reset            # back to ./workspace
ccpath                    # show current, then prompt
```

**What it does:** writes `CC_WORKSPACE` into `.env`, which `docker-compose.yml`
uses as the source of the workspace mount. Inside the container your files stay at
`/home/claudeuser/workspace`, so nothing moves around in the browser IDE.

**What it handles for you:**

- Offers to copy your existing files over. It copies rather than moves, and never
  deletes the originals.
- Recreates the container. A bind mount is fixed when the container is created, so
  a plain restart would silently keep using the old folder. It then reads the mount
  back out of Docker to confirm the change actually took.
- Warns if Docker Desktop may not be able to reach the folder. On macOS it shares
  `/Users`, `/Volumes`, `/private` and `/tmp` by default; a folder outside those
  mounts as **empty with no error at all**, which is miserable to diagnose. Add the
  path under Docker Desktop → Settings → Resources → File sharing.
- Warns on cloud-synced folders (Dropbox, OneDrive, iCloud, Google Drive). The sync
  client and the container both write the same files, which can corrupt saves
  mid-write. Keep the workspace local and sync a backup instead.

`ccbackup`, `ccrestore` and `ccdiagnose` all follow the new location automatically.

**One caution:** `ccrestore` clears the workspace before extracting a backup. It
refuses to run if your workspace is set to your home directory or a filesystem
root, but don't point `ccpath` at a folder containing anything you aren't happy to
have replaced by a restore.

---

## Choosing which models appear in the picker

Applies when you're signed in with AWS Bedrock (`CLAUDE_CODE_USE_BEDROCK=1`).

### Understanding the Model Picker

The Claude Code VS Code extension shows a built-in model picker with these entries:

- **Default** - Set via `ANTHROPIC_DEFAULT_OPUS_MODEL` (fallback if not set)
- **Fable** - Hardcoded to latest Fable version
- **Custom Sonnet** - Set via `ANTHROPIC_DEFAULT_SONNET_MODEL`
- **Custom Opus** - Set via `ANTHROPIC_DEFAULT_OPUS_MODEL`
- **Custom Haiku** - Set via `ANTHROPIC_DEFAULT_HAIKU_MODEL`

**Important limitation:** You can only customize **three models** (Sonnet, Opus, Haiku) via environment variables. The extension does not support adding multiple versions of each to the picker.

### Configuration File Location

Settings are stored in **`~/.claude/settings.json`** inside the Docker container. This file controls:
- AWS Bedrock credentials
- Model defaults for the picker
- Theme and other preferences

### How to Update the Model List

#### Step 1: Access the Container

```bash
docker compose exec claude-code bash
```

**What this does:** Opens a shell inside the running container where Claude Code and VS Code are running.

#### Step 2: Edit the Settings File

```bash
cat > ~/.claude/settings.json << 'EOF'
{
  "env": {
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "us-east-1",
    "AWS_ACCESS_KEY_ID": "YOUR_ACCESS_KEY_HERE",
    "AWS_SECRET_ACCESS_KEY": "YOUR_SECRET_KEY_HERE",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "us.anthropic.claude-sonnet-5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "us.anthropic.claude-opus-5",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "us.anthropic.claude-haiku-4-5-20251001-v1:0"
  },
  "model": "sonnet",
  "theme": "dark"
}
EOF
```

**What this does:** 
- Overwrites the settings file with new model IDs
- The three `ANTHROPIC_DEFAULT_*_MODEL` variables control which models appear in the picker
- Replace `YOUR_ACCESS_KEY_HERE` and `YOUR_SECRET_KEY_HERE` with your actual credentials

**What each environment variable does:**
- `CLAUDE_CODE_USE_BEDROCK`: Tells Claude to use AWS Bedrock instead of Anthropic API
- `AWS_REGION`: The AWS region where your Bedrock models are available (usually `us-east-1`)
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: Your AWS credentials
- `ANTHROPIC_DEFAULT_SONNET_MODEL`: Model ID that appears as "Custom Sonnet model" in picker
- `ANTHROPIC_DEFAULT_OPUS_MODEL`: Model ID that appears as "Custom Opus model" and "Default"
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`: Model ID that appears as "Custom Haiku model" in picker

#### Step 3: Verify the Settings

```bash
cat ~/.claude/settings.json
```

**What this does:** Displays the contents of your settings file so you can verify the changes were saved correctly.

#### Step 4: Exit the Container

```bash
exit
```

**What this does:** Returns you to your host machine's terminal.

#### Step 5: Restart the Claude Extension

In your VS Code browser tab:
1. **Reload the browser page** (Cmd/Ctrl + R)
2. Or **close and reopen the Claude panel** (click the Claude icon in the sidebar)

**What this does:** Forces the VS Code extension to reload and read the new model settings from `~/.claude/settings.json`.

## Available Bedrock Model IDs

Every ID below was confirmed present in this account with
`aws bedrock list-inference-profiles`, and confirmed to actually return a
completion with `aws bedrock-runtime converse` (verified 2026-08-27, `us-east-1`).

| Model | Bedrock inference profile ID | Context | Verified |
|---|---|---|---|
| Opus 5 | `us.anthropic.claude-opus-5` | 1M | ✅ works |
| Opus 4.8 | `us.anthropic.claude-opus-4-8` | 1M | ✅ works |
| Sonnet 5 | `us.anthropic.claude-sonnet-5` | 1M | ✅ works |
| Sonnet 4.6 | `us.anthropic.claude-sonnet-4-6` | 1M | ✅ works |
| Haiku 4.5 | `us.anthropic.claude-haiku-4-5-20251001-v1:0` | **200K** | ✅ works |
| Fable 5 | `us.anthropic.claude-fable-5` | 1M | ⚠️ blocked — see below |

#### Two things that trip people up

**Current model IDs carry no date suffix.** `us.anthropic.claude-opus-5` is the
complete ID. There is no `us.anthropic.claude-opus-5-20251201-v1:0`. Only the
older-generation profiles (Haiku 4.5, Sonnet 4.5, the Claude 3 family) keep the
dated `...-v1:0` form. Don't pattern-match a date onto a newer model — the ID
simply won't resolve.

**Haiku 4.5 has no 1M variant.** It is 200K, full stop. Every other model in the
table above is 1M natively — there's no separate "1M version" to select and no
suffix to add. If you want a 1M context window, you want anything other than Haiku.

#### Fable 5 is blocked on this AWS account

The profile exists and appears in the picker, but invoking it fails:

```
ValidationException: data retention mode 'default' is not available for this model
```

Fable 5 requires 30-day data retention and is not available under zero data
retention. This is an org-level AWS/Bedrock configuration, not something the
settings file can fix — talk to Batten IT if you need it. Until then, treat the
**Fable** entry in the picker as non-functional and use Opus 5 instead.

Note that `Fable` is hardcoded into the extension's picker, so it appears whether
or not it works. You cannot remove it via the settings file.

### Complete Update Workflow Example

Here's a complete example of updating to the latest models:

```bash
# 1. Access the container
docker compose exec claude-code bash

# 2. Backup existing settings (optional but recommended)
cp ~/.claude/settings.json ~/.claude/settings.json.backup

# 3. Change ONLY the model IDs, leaving credentials alone.
#
# Use jq rather than rewriting the whole file. settings.json holds your AWS keys,
# and a `cat > ` heredoc would need you to retype them — which is how secrets end
# up pasted into notes, chat messages and documentation by accident.
jq '.env.ANTHROPIC_DEFAULT_SONNET_MODEL = "us.anthropic.claude-sonnet-5"
  | .env.ANTHROPIC_DEFAULT_OPUS_MODEL   = "us.anthropic.claude-opus-5"
  | .env.ANTHROPIC_DEFAULT_HAIKU_MODEL  = "us.anthropic.claude-haiku-4-5-20251001-v1:0"' \
  ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json

# 4. Verify the model IDs took, without printing your keys
jq '.env | with_entries(select(.key | startswith("ANTHROPIC_")))' ~/.claude/settings.json

# 5. Exit container
exit

# 6. Reload VS Code in your browser (Cmd/Ctrl + R)
```

### Alternative: Edit from Host Machine

You can also edit the settings from your host machine without entering the container:

```bash
# View current settings
docker compose exec claude-code cat ~/.claude/settings.json

# Update a specific model (example: change Sonnet to version 5)
docker compose exec claude-code bash -c "jq '.env.ANTHROPIC_DEFAULT_SONNET_MODEL = \"us.anthropic.claude-sonnet-5\"' ~/.claude/settings.json > /tmp/settings.json && mv /tmp/settings.json ~/.claude/settings.json"

# Verify the change
docker compose exec claude-code cat ~/.claude/settings.json
```

**What this does:** Uses `jq` (JSON processor) to update a specific field without manually editing the entire file.

### Using Models Not in the Picker

The picker has only three customisable slots, so the "one version prior" models
(Opus 4.8, Sonnet 4.6) can't all live in it at once. Reach them directly instead:

#### Option 1: Use Claude CLI Directly

Open a terminal in VS Code and specify the model:

```bash
claude --model us.anthropic.claude-opus-4-8      # prior Opus
claude --model us.anthropic.claude-sonnet-4-6    # prior Sonnet
```

Or switch mid-session with `/model us.anthropic.claude-opus-4-8`.

#### Option 2: Temporarily Change the Default

Follow the steps above but change `ANTHROPIC_DEFAULT_SONNET_MODEL` to the older version, then reload the extension.

### Verifying Available Models in Your AWS Account

To check which Bedrock models are actually available in your AWS region:

```bash
# From your host machine (requires AWS CLI)
aws bedrock list-foundation-models \
  --region us-east-1 \
  --by-provider anthropic \
  --query 'modelSummaries[*].[modelId,modelName]' \
  --output table
```

**What this does:** Queries AWS Bedrock API to list all Anthropic models available in your region and account.

**Important:** Some models require opt-in through the AWS Console:
1. Go to AWS Console → Bedrock → Model access
2. Request access for the models you want to use
3. Wait for approval (usually instant for most models)

## Troubleshooting

### Picker Still Shows Old Models

**Solution:**
1. Verify settings were saved: `docker compose exec claude-code cat ~/.claude/settings.json`
2. Hard refresh VS Code browser tab: Cmd/Ctrl + Shift + R
3. Restart the container: `ccrestart`

### Model Not Working Despite Being in Picker

**Possible causes:**
1. **Model doesn't exist in your AWS region** - Run the `aws bedrock list-foundation-models` command above
2. **No access to the model** - Check AWS Console → Bedrock → Model access
3. **Wrong model ID format** - Current models take no date suffix
   (`us.anthropic.claude-opus-5`). Appending one is the most common cause of a
   model that shows in the picker but fails on use. Check it against the verified
   table above, or list what your account actually has:
   `aws bedrock list-inference-profiles --region us-east-1 --query 'inferenceProfileSummaries[?contains(inferenceProfileId, \`claude\`)].inferenceProfileId' --output text | tr '\t' '\n' | sort`
4. **IAM permissions missing** - Your AWS credentials need `bedrock:InvokeModel` permission

### Settings Keep Reverting

The `~/.claude` directory is a Docker volume that persists across container restarts. Settings should survive:
- Container restarts (`ccrestart`)
- Host machine reboots
- Docker updates

Settings are **lost** if you:
- Delete the `claude-config` volume: `docker volume rm cc-install_claude-config`
- Run `ccuninstall` (which removes all volumes)

To preserve settings across reinstalls, backup before uninstalling:
```bash
docker compose exec claude-code cat ~/.claude/settings.json > claude-settings-backup.json
```

## File Locations Reference

| What | Where | Persists? |
|------|-------|-----------|
| Claude settings | `~/.claude/settings.json` (in container) | ✅ Yes (Docker volume) |
| VS Code settings | `~/.local/share/code-server/User/settings.json` | ✅ Yes (Docker volume) |
| AWS credentials | In `~/.claude/settings.json` `env` block | ✅ Yes |
| Model picker list | Hardcoded in extension + overrides from settings | ⚠️ Only 3 customizable |

## Security Note

⚠️ **Your `~/.claude/settings.json` contains AWS credentials in plain text.** 

This file is:
- Inside the Docker volume (not visible on host filesystem by default)
- Not copied to host machine
- Only accessible via `docker compose exec`

**Best practices:**
- Use IAM credentials with minimal permissions (only `bedrock:InvokeModel`)
- Consider using temporary credentials with `AWS_SESSION_TOKEN`
- Never commit this file to git
- Use `ccbackup` to back up your workspace (it doesn't include `.claude` by default)

## See Also

- [docs/CREDENTIALS.md](CREDENTIALS.md) - Setting up Bedrock authentication
- [.env.example](../.env.example) - Example Bedrock configuration for host environment
- [docs/QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Command cheat-sheet
- AWS Bedrock Model IDs: https://docs.aws.amazon.com/bedrock/latest/userguide/model-ids.html
- Claude Code CLI documentation: https://code.claude.com/docs

## Quick Reference Commands

```bash
# View current model settings
docker compose exec claude-code bash -c "cat ~/.claude/settings.json | jq .env"

# Change to Sonnet 5
docker compose exec claude-code bash -c 'jq '\''.env.ANTHROPIC_DEFAULT_SONNET_MODEL = "us.anthropic.claude-sonnet-5"'\'' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json'

# Change to Opus 5
docker compose exec claude-code bash -c 'jq '\''.env.ANTHROPIC_DEFAULT_OPUS_MODEL = "us.anthropic.claude-opus-5"'\'' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json'

# Change to Haiku 4.5
docker compose exec claude-code bash -c 'jq '\''.env.ANTHROPIC_DEFAULT_HAIKU_MODEL = "us.anthropic.claude-haiku-4-5-20251001-v1:0"'\'' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json'

# Backup settings
docker compose exec claude-code cat ~/.claude/settings.json > claude-settings-backup.json

# Restore settings
cat claude-settings-backup.json | docker compose exec -T claude-code bash -c 'cat > ~/.claude/settings.json'
```
