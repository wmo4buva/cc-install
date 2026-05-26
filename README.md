# Claude Code Faculty Installer (cc-install)

A simple, Docker-based installer for Claude Code designed to help faculty members get started with Claude Code quickly and easily, without dealing with complex technical setup.

**Inspired by the [DAAF project](https://github.com/DAAF-Contribution-Community/daaf)** — credit to their excellent Docker-based installation approach.

---

## ✨ What This Does

This project provides a one-line installation command that:
- ✅ Creates an isolated Docker environment with Claude Code CLI
- ✅ Includes VS Code Server for browser-based code editing
- ✅ Handles all dependencies automatically
- ✅ Sets up easy launcher commands (`ccdocker`, `ccvscode`)
- ✅ Persists your work in a local `workspace/` directory
- ✅ Pre-installs powerful Claude Code skills for productivity

---

## 📋 What Happens During Installation?

The installer will:
1. ✅ Check that Docker is installed and running
2. ⬇️ Download required files
3. 🐳 Build a Docker image with Claude Code and VS Code Server (~5-10 minutes)
4. 🚀 Start the container
5. 📁 Create a `workspace/` directory for your files
6. ⚡ Set up easy launch shortcuts

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Docker Desktop

**Required:** Install Docker Desktop from https://www.docker.com/products/docker-desktop/

✅ Make sure Docker Desktop is **running** before continuing.

**⚠️ Windows Users:** If this is your first time using Docker on this machine, you may need to update WSL first. Open PowerShell as Administrator and run:
```powershell
wsl --update
```
Then restart your computer before installing Docker Desktop.

---

### Step 2: Run One Command

#### 🍎 **macOS / Linux**

Open **Terminal** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.sh | bash
```

#### 🪟 **Windows**

**Open PowerShell** (NOT Command Prompt):
- Press **Windows + X** → click **Terminal** or **Windows PowerShell**
- Or: Press **Windows key**, type `powershell`, press Enter

Then paste this command:

```powershell
irm https://raw.githubusercontent.com/wmo4buva/cc-install/main/scripts/installers/install.ps1 | iex
```

**Note:** This command won't work in Command Prompt (cmd.exe) - you must use PowerShell.

⏱️ **Installation takes 5-10 minutes** • ☕ Grab a coffee while it builds!

---

### Step 3: Launch Claude Code

After installation completes, **close and reopen PowerShell** (Windows) or restart your terminal (macOS/Linux), then you can launch from anywhere:

```bash
ccdocker    # Launch Claude Code CLI
```

Or use VS Code Server:

```bash
ccvscode    # Opens http://localhost:8080
```

**⚠️ Important:** The shortcuts (`ccdocker`, `ccvscode`) only work after you **restart your PowerShell/Terminal window**. If they don't work, make sure you opened a fresh window after installation.

---

## More Usage Options

After installation, navigate to the `cc-install` directory:

```bash
cd cc-install
```

### Option 1: Claude Code CLI

Launch Claude Code in your terminal:

**macOS / Linux:**
```bash
./claude
```

**Windows:**
```cmd
claude.cmd
```

**Or use full path:**
```bash
./scripts/launchers/run_claude.sh    # macOS/Linux
.\scripts\launchers\run_claude.ps1   # Windows
```

### Option 2: VS Code Server (Browser-Based IDE)

Open VS Code Server in your web browser:

**macOS / Linux:**
```bash
./vscode
```

**Windows:**
```cmd
vscode.cmd
```

**Or use full path:**
```bash
./scripts/launchers/run_vscode.sh    # macOS/Linux
.\scripts\launchers\run_vscode.ps1   # Windows
```

This will:
- Start VS Code Server in the container
- Automatically open http://localhost:8080 in your browser
- Give you a full IDE experience for editing files

### Additional Commands

#### View Container Logs
**macOS / Linux:**
```bash
./scripts/launchers/run_claude.sh logs
```

**Windows:**
```powershell
.\scripts\launchers\run_claude.ps1 logs
```

#### Stop the Container
**macOS / Linux:**
```bash
./scripts/launchers/run_claude.sh stop
```

**Windows:**
```powershell
.\scripts\launchers\run_claude.ps1 stop
```

#### Restart the Container
**macOS / Linux:**
```bash
./scripts/launchers/run_claude.sh restart
```

**Windows:**
```powershell
.\scripts\launchers\run_claude.ps1 restart
```

#### Open a Bash Shell in the Container
**macOS / Linux:**
```bash
./scripts/launchers/run_claude.sh bash
```

**Windows:**
```powershell
.\scripts\launchers\run_claude.ps1 bash
```

## Pre-Installed Skills

This installation comes with powerful Claude Code skills pre-installed for enhanced productivity:

- **Anthropic Official Skills** - Official skill collection from Anthropic
- **Andrej Karpathy Guidelines** - AI/ML best practices and coding patterns
- **Superpowers by Jesse Vincent** - Advanced workflow and productivity skills

These skills are automatically available when you launch Claude Code. You can list them with `/skills` or invoke them with `/<skill-name>`.

---

## First-Time Setup

When you first launch Claude Code, you'll be prompted to configure it:

### 🎯 **Recommended: Amazon Bedrock (for UVA/FBS Users)**

1. **AWS Credentials**: Use your university Amazon Bedrock account
   - **Access Key ID** and **Secret Access Key** from your AWS account
   - **Region**: Typically `us-east-1` or your organization's region
   - **Benefits**: 
     - ✅ Organization billing
     - ✅ Better cost management
     - ✅ Compliance with university policies

Configure Bedrock by setting these environment variables or during Claude Code setup:
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

### 💳 **Alternative: Anthropic API (Personal Use)**

2. **Anthropic API Key**: For personal accounts
   - Get one at: https://console.anthropic.com/
   - **Note**: This will bill to your personal account
   - The key will be securely stored in the Docker volume

### ⚙️ **Preferences**

Claude Code will guide you through setting:
- Your preferred model (Opus, Sonnet, or Haiku)
- Thinking level
- Other preferences

These settings are stored in the persistent `claude-config` Docker volume and will be remembered across container restarts.

## Workspace

All your files are stored in:
```
cc-install/workspace/
```

This directory:
- Is directly accessible on your host machine (no Docker knowledge needed)
- Persists across container restarts
- Can be backed up like any normal folder
- Is automatically synced between your host and the container

## Troubleshooting

### Docker Not Running
```
[ERROR] Docker daemon is not running
```

**Solution**: Start Docker Desktop and wait for it to fully load, then try again.

### Port 8080 Already in Use
```
Error: port 8080 is already allocated
```

**Solution**: 
1. Stop any other applications using port 8080, or
2. Edit `docker-compose.yml` to change `"8080:8080"` to a different port like `"8081:8080"`

### Container Won't Start
```
[ERROR] Container failed to start properly
```

**Solution**:
1. Check Docker Desktop is running
2. View logs: `docker compose logs`
3. Try rebuilding: `./update.sh` (macOS/Linux) or `.\update.ps1` (Windows)

### Claude Code Command Not Found
```
claude: command not found
```

**Solution**: The container may need a moment to fully start. Wait 10 seconds and try again. If it persists, rebuild with `./update.sh`

### Installation Fails During Build

**Solution**:
1. Ensure you have a stable internet connection
2. Ensure you have enough disk space (~2GB)
3. Try running the installation again
4. Check Docker Desktop has enough resources allocated (Settings → Resources)

## Updating

To update to the latest versions of Claude Code and VS Code Server:

**macOS / Linux:**
```bash
./update.sh
```

**Windows:**
```powershell
.\update.ps1
```

This will rebuild the Docker image with the latest versions while preserving your workspace and settings.

## Backup and Restore

### Create a Backup

**macOS / Linux:**
```bash
./backup.sh
```

**Windows:**
```powershell
.\backup.ps1
```

This creates a timestamped backup of your workspace directory.

### Restore from Backup

**macOS / Linux:**
```bash
./restore.sh <backup-file.tar.gz>
```

**Windows:**
```powershell
.\restore.ps1 <backup-file.zip>
```

## Uninstalling

To completely remove the installation:

**macOS / Linux:**
```bash
./uninstall.sh
```

**Windows:**
```powershell
.\uninstall.ps1
```

This will:
- Stop and remove the container
- Remove the Docker image
- Remove Docker volumes (with confirmation)
- Optionally remove the installation directory

**Note**: Your `workspace/` directory will NOT be deleted unless you explicitly confirm.

## Architecture

This project uses Docker to create a containerized environment with:

- **Base OS**: Debian Bookworm (lightweight Linux)
- **Claude Code**: Latest version installed via official script
- **VS Code Server**: Browser-based VS Code (code-server v4.117.0)
- **Node.js**: v20 LTS (required for code-server)
- **User**: Non-root user `claudeuser` for security

### File Structure

```
cc-install/
├── docker-compose.yml    # Container orchestration
├── Dockerfile            # Image definition
├── workspace/            # Your files (persisted)
├── run_claude.sh         # Claude Code launcher (macOS/Linux)
├── run_claude.ps1        # Claude Code launcher (Windows)
├── run_vscode.sh         # VS Code Server launcher (macOS/Linux)
├── run_vscode.ps1        # VS Code Server launcher (Windows)
├── update.sh/.ps1        # Update scripts
├── backup.sh/.ps1        # Backup scripts
├── uninstall.sh/.ps1     # Uninstall scripts
└── README.md             # This file
```

## FAQ

### Do I need to know Docker to use this?

**No!** The installation and launcher scripts handle all Docker operations for you. You never need to run `docker` commands directly.

### Where is my data stored?

Your files are in `workspace/` on your computer and `/home/claudeuser/workspace` in the container. They're automatically synced.

Your Claude Code settings are in a Docker volume named `claude-config` that persists across container restarts.

### Can I use my existing Claude Code installation?

This is a separate, containerized installation that won't conflict with any existing Claude Code installation on your host machine. They use different configuration directories.

### What happens if I delete the container?

Your workspace files and Claude Code settings are safe — they're stored in persistent locations outside the container. You can rebuild the container with `./update.sh` and everything will still be there.

### Can I customize the environment?

Yes! You can edit the `Dockerfile` to add additional packages or tools, then run `./update.sh` to rebuild with your changes.

### How much disk space does this use?

The Docker image is approximately **1.5-2 GB**. Your workspace will grow based on the files you create.

### Can multiple people use this on the same computer?

Yes, but each user should run the installation in their own user directory. Each installation will have its own workspace and settings.

### Is this secure?

- The container runs as a non-root user (`claudeuser`)
- VS Code Server runs without authentication (localhost only by default)
- Your API keys are stored securely in Docker volumes
- The container is isolated from your host system

For production or shared environments, you may want to add authentication to code-server.

## Support

- **Claude Code Documentation**: https://docs.anthropic.com/
- **Code-Server Documentation**: https://coder.com/docs/code-server/
- **DAAF Project** (inspiration): https://github.com/DAAF-Contribution-Community/daaf

## Attribution

This project is inspired by the [DAAF (Data Analysis Agent Framework)](https://github.com/DAAF-Contribution-Community/daaf) project. We've adapted their excellent Docker-based installation approach for Claude Code. See [ATTRIBUTION.md](ATTRIBUTION.md) for full details.

## License

This project is provided as-is for educational and research purposes. Claude Code is a product of Anthropic. See Anthropic's terms of service for Claude Code usage.

---

**Made with ❤️ for faculty members who want to explore AI-assisted coding without the technical setup hassle.**
