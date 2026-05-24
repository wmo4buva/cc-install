# Project Roadmap

## Current Status: v1.0.0 (Pre-Release)

**Last Updated:** May 24, 2026

---

## 🎯 Vision

Make Claude Code accessible to faculty members with zero technical friction, pre-configured with powerful skills for research, teaching, and administrative work.

---

## 🚀 High Priority (Next Release - v1.1.0)

### 1. Pre-Install Claude Code Skills ⭐ TOP PRIORITY

**Goal:** Include essential skills in the Docker image so faculty have them immediately.

**Skills to Include:**

1. **[Anthropic Official Skills](https://github.com/anthropics/skills)**
   - Example skills demonstrating best practices
   - Core utilities for common tasks
   - Well-tested, production-ready

2. **[Andrej Karpathy Guidelines](https://github.com/multica-ai/andrej-karpathy-skills/tree/main/skills/karpathy-guidelines)**
   - Expert coding guidelines from AI/ML leader
   - Best practices for Python development
   - Research-oriented workflow patterns

3. **[Superpowers by Jesse Vincent](https://github.com/obra/superpowers)**
   - Enhanced Claude Code capabilities
   - Advanced productivity features
   - Power user utilities

**Implementation Plan:**

```dockerfile
# In Dockerfile, after Claude Code installation:

# Install skills
USER claudeuser
WORKDIR /home/claudeuser

# Clone skills repositories
RUN git clone https://github.com/anthropics/skills /tmp/anthropic-skills && \
    git clone https://github.com/multica-ai/andrej-karpathy-skills /tmp/karpathy-skills && \
    git clone https://github.com/obra/superpowers /tmp/superpowers

# Install to Claude Code skills directory
RUN mkdir -p ~/.claude/skills && \
    cp -r /tmp/anthropic-skills/skills/* ~/.claude/skills/ && \
    cp -r /tmp/karpathy-skills/skills/* ~/.claude/skills/ && \
    cp -r /tmp/superpowers/skills/* ~/.claude/skills/ && \
    rm -rf /tmp/anthropic-skills /tmp/karpathy-skills /tmp/superpowers
```

**Benefits:**
- Faculty get powerful skills immediately
- No manual installation needed
- Consistent experience across all users
- Skills work out-of-the-box

**Testing Requirements:**
- Verify skills load correctly
- Test that skills don't conflict
- Ensure no permission issues
- Document included skills in README

---

### 2. Auto-Update Mechanism

**Goal:** Keep Claude Code and skills up-to-date automatically.

**Features:**
- Check for updates on container start (optional)
- Notify user of available updates
- One-command update: `./claude update`
- Preserve workspace and settings

**Implementation:**
- Add update check to launcher script
- Create update notification system
- Version tracking in container

---

### 3. Windows PowerShell Testing

**Goal:** Verify all PowerShell scripts work on Windows.

**Tasks:**
- [ ] Test install.ps1 on Windows 10/11
- [ ] Test run_claude.ps1
- [ ] Test run_vscode.ps1
- [ ] Test all maintenance scripts
- [ ] Fix any Windows-specific issues
- [ ] Document Windows-specific notes

---

## 📋 Medium Priority (v1.2.0)

### 4. FBS-Specific Skills

**Goal:** Create custom skills for Frank Batten School workflows.

**Potential Skills:**
- **Policy Analysis Toolkit** - Tools for policy research
- **Teaching Assistant** - Syllabus creation, assignment templates
- **Data Analysis Helpers** - Common statistical operations
- **Research Workflow** - Literature review, citation management
- **Grant Writing Assistant** - Grant proposal templates and helpers

**Process:**
1. Survey faculty for most-wanted features
2. Develop custom skills
3. Test with pilot faculty
4. Include in default installation

---

### 5. Enhanced Documentation

**Features:**
- Video tutorials for faculty
- Common use-case examples
- Troubleshooting flowcharts
- Quick-start guide (1-page PDF)

**Content to Create:**
- 5-minute installation video
- "First Steps with Claude Code" tutorial
- "Using Skills" guide
- Faculty success stories

---

### 6. Usage Analytics (Privacy-Respecting)

**Goal:** Help IT understand usage patterns for support.

**Features:**
- Opt-in analytics
- Anonymous usage statistics
- Container health monitoring
- Error reporting

**Privacy-First:**
- No personal data collected
- No workspace content analyzed
- Opt-out anytime
- Transparent data collection

---

### 7. Improved Error Messages

**Goal:** Better user feedback when things go wrong.

**Improvements:**
- Detect common issues automatically
- Provide solution suggestions
- Link to relevant documentation
- Friendly, non-technical language

**Examples:**
- "Docker not running" → "Please start Docker Desktop"
- "Port conflict" → "Here's how to change the port"
- "Out of memory" → "Here's how to adjust resources"

---

## 🔮 Future Ideas (v2.0.0+)

### 8. UVA Single Sign-On Integration

**Goal:** Seamless authentication for faculty.

**Benefits:**
- No separate API key management
- Centralized access control
- Easier for IT to manage

**Challenges:**
- Requires UVA IT coordination
- SSO integration with Anthropic API
- Security considerations

---

### 9. Fleet Management Dashboard

**Goal:** Central management for IT staff.

**Features:**
- View all installed instances
- Push updates to all users
- Monitor usage across faculty
- Troubleshoot remotely

**Use Cases:**
- Mass update rollout
- License management
- Support ticket integration

---

### 10. Canvas/Collab Integration

**Goal:** Connect Claude Code with UVA's learning management systems.

**Features:**
- Import course materials
- Export assignments
- Grade integration
- Student collaboration tools

---

### 11. Pre-Configured Templates

**Goal:** Domain-specific starting points.

**Templates:**
- **Research Project** - Literature review, data analysis, writing
- **Course Development** - Syllabus, assignments, rubrics
- **Grant Proposal** - NSF, NIH templates
- **Policy Brief** - Standard policy analysis format

---

### 12. Jupyter Notebook Support

**Goal:** Add Jupyter for faculty who need notebooks.

**Implementation:**
- Add Jupyter to Docker image
- Include common data science libraries
- Keep optional (don't bloat base image)

---

### 13. Multi-User Support

**Goal:** Share installations across teams.

**Features:**
- Separate workspaces per user
- Shared skills and templates
- Permission management
- Collaboration features

---

### 14. Cloud Backup Integration

**Goal:** Automatic workspace backup to cloud storage.

**Options:**
- OneDrive (UVA standard)
- Google Drive
- Dropbox
- S3-compatible storage

---

### 15. Custom Branding

**Goal:** FBS-branded experience.

**Elements:**
- FBS logo in VS Code Server
- Custom welcome message
- School colors in terminal
- UVA/FBS documentation links

---

## 🛠️ Technical Debt & Maintenance

### Code Quality
- [ ] Add automated testing for installation scripts
- [ ] Set up GitHub Actions CI/CD
- [ ] Create test suite for Docker builds
- [ ] Add script linting (shellcheck)

### Documentation
- [ ] Keep CLAUDE.md updated with architecture changes
- [ ] Update screenshots when UI changes
- [ ] Maintain version compatibility matrix
- [ ] Document breaking changes

### Security
- [ ] Regular security audits
- [ ] Update base images regularly
- [ ] Monitor CVEs in dependencies
- [ ] Implement security best practices

---

## 📅 Release Schedule

### v1.1.0 - "Skills Edition" (Target: June 2026)
**Focus:** Pre-installed skills, auto-updates

**Must Have:**
- ✅ Pre-installed Anthropic skills
- ✅ Pre-installed Karpathy guidelines
- ✅ Pre-installed Superpowers
- ✅ Auto-update mechanism
- ✅ Windows testing complete

**Nice to Have:**
- Skills documentation
- Video tutorial

---

### v1.2.0 - "Faculty Edition" (Target: August 2026)
**Focus:** FBS-specific features, enhanced UX

**Must Have:**
- FBS custom skills (2-3 minimum)
- Enhanced error messages
- Usage analytics (opt-in)

**Nice to Have:**
- Custom branding
- Additional documentation

---

### v2.0.0 - "Enterprise Edition" (Target: 2027)
**Focus:** IT management, integration

**Must Have:**
- Fleet management basics
- SSO integration (if feasible)
- Advanced monitoring

**Nice to Have:**
- Canvas integration
- Multi-user support

---

## 🎓 Community & Adoption

### Faculty Feedback Loop
1. **Pilot Program** (5-10 faculty) - v1.0.0
2. **Early Adopters** (20-30 faculty) - v1.1.0
3. **Department Rollout** - v1.2.0
4. **School-Wide** - v2.0.0

### Success Metrics
- Installation success rate (target: 95%)
- Faculty satisfaction (target: 4/5 stars)
- Support ticket volume (target: <5/month)
- Active usage (target: 60% monthly active)

---

## 🤝 Contribution Guidelines

### How to Suggest Features
1. Open GitHub issue with label `enhancement`
2. Describe the problem it solves
3. Propose implementation (optional)
4. Link to examples (if applicable)

### How to Contribute Code
1. Fork repository
2. Create feature branch
3. Follow existing code style
4. Add tests if applicable
5. Update documentation
6. Submit pull request

---

## 📞 Feedback & Contact

**Feature Requests:** GitHub Issues  
**Bug Reports:** GitHub Issues  
**General Questions:** FBS IT Support  
**Contributions:** Pull Requests Welcome!

---

## 🔄 Update Process

This roadmap is reviewed:
- **Monthly** during active development
- **Quarterly** after v1.0.0 release
- **After feedback** from faculty pilots

Last Review: May 24, 2026  
Next Review: June 24, 2026

---

## 📝 Notes

### Design Principles
1. **Simplicity First** - Faculty should never see Docker
2. **Works Out-of-Box** - Minimal configuration required
3. **Safe by Default** - Can't break their system
4. **Privacy-Respecting** - No data collection without consent
5. **Well-Documented** - Self-service support

### Non-Goals
- ❌ Replace existing UVA tools
- ❌ Become a system administration tool
- ❌ Support enterprise features faculty don't need
- ❌ Complicate the installation process

---

**Remember:** The goal is to make Claude Code accessible to faculty, not to build a complex enterprise system. Keep it simple, keep it useful.
