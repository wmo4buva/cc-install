# Attribution

## Inspiration: DAAF Project

This project is **heavily inspired by** the [DAAF (Data Analysis Agent Framework)](https://github.com/DAAF-Contribution-Community/daaf) project.

### What We Borrowed from DAAF

We adapted several excellent design patterns and approaches from DAAF:

1. **Docker-based Installation Approach**
   - Single-command installation via curl/irm piped to bash/PowerShell
   - Automated Docker image building and container setup
   - Persistent volumes for user data and configuration

2. **Installation Script Structure**
   - Preflight checks (Docker installed, daemon running)
   - Step-by-step installation flow with progress indicators
   - Colored terminal output for better user experience
   - Dry-run mode for testing without Docker
   - Interactive mode detection and exit traps

3. **Launcher Script Patterns**
   - Simple wrapper scripts to start containers and launch applications
   - Automatic container startup if not running
   - Support for multiple commands (bash shell, logs, stop, restart)
   - User-friendly error messages

4. **Project Structure**
   - Separation of host scripts and container environment
   - Helper scripts for common operations (update, backup, uninstall)
   - Clear documentation with usage examples

### Key Differences

While inspired by DAAF, `cc-install` is simplified and focused specifically on Claude Code:

| Aspect | DAAF | cc-install |
|--------|------|------------|
| **Purpose** | Data analysis with Python/Claude | Claude Code only |
| **Included Tools** | Claude Code, Python data science stack, marimo, code-server | Claude Code, code-server |
| **Target Audience** | Data scientists and analysts | Faculty members (all disciplines) |
| **Python Libraries** | 50+ data science packages | Minimal (for basic scripting) |
| **Repository Cloning** | Clones DAAF repo during installation | Creates empty workspace |
| **Configuration** | environment_settings.txt | Uses Claude Code's built-in config |
| **Complexity** | Full data analysis environment | Lightweight, focused on Claude Code |

### DAAF License

DAAF is licensed under the **GNU General Public License v3.0 (GPL-3.0)**.

- **DAAF Repository**: https://github.com/DAAF-Contribution-Community/daaf
- **License**: GPL-3.0 (https://www.gnu.org/licenses/gpl-3.0.html)
- **Copyright**: DAAF Contributors

### Our Gratitude

We are deeply grateful to the DAAF project contributors for:
- Creating an excellent reference implementation for Docker-based AI tool distribution
- Providing clear, well-documented installation scripts
- Demonstrating how to make powerful AI tools accessible to non-technical users
- Open-sourcing their work for the community

The DAAF project solved the "last mile" problem of getting AI tools into the hands of researchers and faculty. Their approach made it possible for us to create this simplified version for Claude Code users.

## Third-Party Software

This project bundles or installs the following third-party software:

### Claude Code
- **Developer**: Anthropic
- **Purpose**: AI-powered coding assistant
- **Website**: https://claude.ai/code
- **License**: Proprietary (Anthropic Terms of Service)
- **Installation**: Via official script from https://console.anthropic.com/install.sh

### code-server
- **Developer**: Coder
- **Purpose**: VS Code running in a web browser
- **Website**: https://coder.com/docs/code-server/
- **License**: MIT License
- **Repository**: https://github.com/coder/code-server

### Docker
- **Developer**: Docker, Inc.
- **Purpose**: Containerization platform
- **Website**: https://www.docker.com/
- **License**: Apache 2.0 (Docker Engine), proprietary (Docker Desktop)
- **Requirement**: Must be installed separately by the user

### Debian Linux
- **Purpose**: Base operating system for the container
- **Website**: https://www.debian.org/
- **License**: Various open-source licenses (see Debian Free Software Guidelines)
- **Version Used**: Debian Bookworm (12)

### Node.js
- **Developer**: OpenJS Foundation
- **Purpose**: JavaScript runtime (required for code-server)
- **Website**: https://nodejs.org/
- **License**: MIT License
- **Version Used**: v20 LTS

## License for This Project

This project (`cc-install`) is provided as-is for educational and research purposes.

- The installation scripts and documentation in this repository are provided freely for use and modification
- Claude Code itself is subject to Anthropic's terms of service
- code-server is subject to its MIT License
- DAAF patterns used are subject to GPL-3.0

## Questions or Concerns?

If you have questions about attribution or licensing, please open an issue in this repository's issue tracker.

## Acknowledgments

Special thanks to:
- **DAAF Contributors** for the excellent Docker installation patterns
- **Anthropic** for Claude Code
- **Coder** for code-server
- **Docker, Inc.** for Docker containerization technology
- **Faculty members** who provided feedback on installation usability

---

*This attribution document was created in the spirit of open source collaboration and proper credit to those who came before us.*
