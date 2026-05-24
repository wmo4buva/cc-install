# Skills Installation Guide

How to add pre-installed skills to the Claude Code Docker image.

## Overview

Skills are powerful extensions that give Claude Code additional capabilities. By pre-installing skills in the Docker image, faculty get enhanced functionality immediately without manual setup.

---

## Target Skills for v1.1.0

### 1. Anthropic Official Skills
**Repository:** https://github.com/anthropics/skills  
**Purpose:** Official example skills demonstrating best practices  
**License:** Check repository  

### 2. Andrej Karpathy Guidelines  
**Repository:** https://github.com/multica-ai/andrej-karpathy-skills  
**Specific Skill:** `/skills/karpathy-guidelines`  
**Purpose:** Expert coding guidelines from AI/ML leader  
**License:** Check repository  

### 3. Superpowers by Jesse Vincent
**Repository:** https://github.com/obra/superpowers  
**Purpose:** Enhanced Claude Code capabilities and productivity features  
**License:** Check repository  

---

## Implementation Steps

### Step 1: Update Dockerfile

Add this section after the Claude Code installation:

```dockerfile
# Install Claude Code Skills
USER claudeuser
WORKDIR /home/claudeuser

# Create skills directory
RUN mkdir -p /home/claudeuser/.claude/skills

# Clone skill repositories (temporary)
RUN git clone --depth 1 https://github.com/anthropics/skills /tmp/anthropic-skills && \
    git clone --depth 1 https://github.com/multica-ai/andrej-karpathy-skills /tmp/karpathy-skills && \
    git clone --depth 1 https://github.com/obra/superpowers /tmp/superpowers

# Copy skills to Claude directory
RUN cp -r /tmp/anthropic-skills/skills/* /home/claudeuser/.claude/skills/ 2>/dev/null || true && \
    cp -r /tmp/karpathy-skills/skills/karpathy-guidelines /home/claudeuser/.claude/skills/ 2>/dev/null || true && \
    cp -r /tmp/superpowers/skills/* /home/claudeuser/.claude/skills/ 2>/dev/null || true

# Clean up temporary files
RUN rm -rf /tmp/anthropic-skills /tmp/karpathy-skills /tmp/superpowers

# Verify skills were installed
RUN ls -la /home/claudeuser/.claude/skills/
```

### Step 2: Test the Build

```bash
# Rebuild the image
docker compose build --no-cache

# Start container
docker compose up -d

# Check installed skills
docker compose exec claude-code ls -la ~/.claude/skills/

# Test Claude Code recognizes skills
docker compose exec claude-code claude --help | grep -i skills
```

### Step 3: Update Documentation

Add to README.md under "What's Included":

```markdown
### Pre-Installed Skills

This installation includes the following Claude Code skills:

1. **Anthropic Official Skills** - Example skills and best practices
2. **Karpathy Guidelines** - Expert coding guidelines from Andrej Karpathy
3. **Superpowers** - Enhanced productivity features by Jesse Vincent

Skills are automatically available when you launch Claude Code. Type `/` in Claude Code to see available skills.
```

---

## Alternative: Post-Install Script

If we want to keep the Docker image lighter, we can install skills after container creation:

### Create `scripts/setup/install-skills.sh`:

```bash
#!/usr/bin/env bash
# Install Claude Code skills after container creation

set -euo pipefail

SKILLS_DIR="/home/claudeuser/.claude/skills"

echo "Installing Claude Code skills..."

# Create skills directory
mkdir -p "$SKILLS_DIR"

# Install Anthropic skills
echo "Installing Anthropic official skills..."
git clone --depth 1 https://github.com/anthropics/skills /tmp/anthropic-skills
cp -r /tmp/anthropic-skills/skills/* "$SKILLS_DIR/"
rm -rf /tmp/anthropic-skills

# Install Karpathy guidelines
echo "Installing Karpathy guidelines..."
git clone --depth 1 https://github.com/multica-ai/andrej-karpathy-skills /tmp/karpathy-skills
cp -r /tmp/karpathy-skills/skills/karpathy-guidelines "$SKILLS_DIR/"
rm -rf /tmp/karpathy-skills

# Install Superpowers
echo "Installing Superpowers..."
git clone --depth 1 https://github.com/obra/superpowers /tmp/superpowers
cp -r /tmp/superpowers/skills/* "$SKILLS_DIR/"
rm -rf /tmp/superpowers

echo "✓ Skills installed successfully!"
echo ""
echo "Installed skills:"
ls -1 "$SKILLS_DIR/"
```

### Run During First Container Start

Add to `docker-compose.yml`:

```yaml
services:
  claude-code:
    # ... existing config ...
    entrypoint: ["/bin/bash", "-c"]
    command: |
      if [ ! -f /home/claudeuser/.claude/.skills-installed ]; then
        /scripts/setup/install-skills.sh
        touch /home/claudeuser/.claude/.skills-installed
      fi
      tail -f /dev/null
```

---

## Pros & Cons

### Approach 1: Bake Into Dockerfile

**Pros:**
- Skills immediately available
- No internet needed after install
- Consistent across all installations
- Faster first launch

**Cons:**
- Larger Docker image (~50-100 MB more)
- Longer build time
- Can't update skills without rebuilding image

### Approach 2: Post-Install Script

**Pros:**
- Smaller Docker image
- Can update skills independently
- Can be optional
- Easier to debug

**Cons:**
- Requires internet on first start
- Slightly slower first launch
- Could fail if repositories unavailable

---

## Recommended Approach

**Use Dockerfile approach (Approach 1)** because:
1. Faculty don't need to wait on first launch
2. Works offline after initial install
3. Guaranteed consistent experience
4. Skills are part of the "product"

The image size increase is worth the improved UX.

---

## Skills Management Features (Future)

### v1.1.0+
- List installed skills: `./claude skills list`
- Update skills: `./claude skills update`
- Add new skill: `./claude skills add <repo-url>`
- Remove skill: `./claude skills remove <skill-name>`

### Implementation Ideas

```bash
# scripts/maintenance/manage-skills.sh

case "$1" in
  list)
    docker compose exec claude-code ls -1 ~/.claude/skills/
    ;;
  update)
    docker compose exec claude-code bash -c "cd ~/.claude/skills && git pull"
    ;;
  add)
    # Clone and install new skill
    ;;
  remove)
    # Remove skill directory
    ;;
esac
```

---

## Testing Checklist

Before releasing with pre-installed skills:

- [ ] Verify all skills install without errors
- [ ] Test that skills don't conflict with each other
- [ ] Confirm skills are executable by claude user
- [ ] Check file permissions are correct
- [ ] Test skills actually work in Claude Code
- [ ] Verify no network issues during build
- [ ] Measure final image size
- [ ] Test build time is acceptable
- [ ] Document all included skills
- [ ] Update README with skills information

---

## License Considerations

Before including any skills:

1. **Check License** - Ensure compatible with distribution
2. **Attribution** - Add to ATTRIBUTION.md
3. **Updates** - Track versions being included
4. **Legal Review** - Verify with UVA legal if needed

**Action Items:**
- [ ] Review Anthropic skills license
- [ ] Review Karpathy skills license  
- [ ] Review Superpowers license
- [ ] Add attribution to ATTRIBUTION.md
- [ ] Document skill versions in Dockerfile

---

## Skills Documentation for Faculty

Create `docs/SKILLS_GUIDE.md` with:

### What are Skills?

Skills extend Claude Code's capabilities. Think of them as "apps" for Claude Code.

### How to Use Skills

1. Launch Claude Code: `./claude`
2. Type `/` to see available skills
3. Select a skill to activate it
4. Follow the skill's prompts

### Included Skills

#### Anthropic Official Skills
- **Purpose:** Examples and utilities
- **Use When:** Learning skill patterns
- **Documentation:** [Link]

#### Karpathy Guidelines  
- **Purpose:** Expert coding advice
- **Use When:** Writing Python code
- **Documentation:** [Link]

#### Superpowers
- **Purpose:** Enhanced productivity
- **Use When:** Power user workflows
- **Documentation:** [Link]

---

## Next Steps

1. **Research Licenses** - Check all skill licenses
2. **Test Integration** - Build and test locally
3. **Update Dockerfile** - Add skills installation
4. **Update Documentation** - README and new guides
5. **Test with Faculty** - Pilot with 2-3 users
6. **Release v1.1.0** - Deploy with skills

---

**Questions?** See [ROADMAP.md](../ROADMAP.md) for the full plan.
