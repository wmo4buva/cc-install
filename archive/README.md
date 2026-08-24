# Archive

Superseded files, kept for reference. **Nothing in here is current — do not
follow any instructions in these documents.** They are retained so past decisions
and wording stay findable without digging through git history.

Current documentation lives in [../README.md](../README.md) and [../docs/](../docs/).

## Why these were retired

All of these were removed in **v1.3.0** (2026-08-24). They were point-in-time
snapshots that had drifted out of step with the software, and several actively
contradicted it — most importantly they told users to type Amazon Bedrock
credentials at a Claude Code prompt, which does not persist. That path was
replaced by `ccauth`; see [../docs/CREDENTIALS.md](../docs/CREDENTIALS.md).

## `v1.2-docs/`

| File | What it was | Superseded by |
|---|---|---|
| `INDEX.md` | Root file-tree map. Referenced `install-shortcut.sh` and a layout that no longer exists. | The "How it works" section of [../README.md](../README.md) |
| `PROJECT_STATUS.md` | Status report frozen at v1.2.1. | [../CHANGELOG.md](../CHANGELOG.md) |
| `ROADMAP.md` | Roadmap through v2.0.0, with most items either shipped or abandoned. | [../ROADMAP.md](../ROADMAP.md) (rewritten) |
| `SECURITY_AUDIT.md` | v1.2.0 audit. Its two live findings (passwordless sudo, piped installers) were carried forward; its "missing Windows diagnostics" finding was fixed. | [../SECURITY.md](../SECURITY.md) |
| `README.md` | A second docs index that duplicated the root README. | [../README.md](../README.md) |
| `PROJECT_SUMMARY.md` | Implementation summary with file counts. | [../docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md) |
| `SKILLS_INSTALLATION.md` | How skills were added to the image. Describes baking them into `~/.claude/skills`, which is **wrong now** — that path froze skills at each user's first build. | "Bundled skills" in [../docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md) |
| `TEST_RESULTS.md` | A single manual test run. | The pre-release checklist in [../docs/DEVELOPMENT.md](../docs/DEVELOPMENT.md) |
| `WINDOWS_FIX_2026-05-28.md` | The v1.2.1 PowerShell line-ending writeup. Its conclusion was incomplete: `.gitattributes eol=crlf` only applies on checkout, so it never fixed installed users. Genuinely fixed in v1.3.0 by switching to archive downloads. | The 1.2.1 and 1.3.0 entries in [../CHANGELOG.md](../CHANGELOG.md) |

## `scripts/`

| File | Why it went |
|---|---|
| `install-shortcut.sh` | Created an undocumented `cc` command. Dead code — superseded by `setup-shortcuts.sh`, which creates the whole `cc*` family. |

## Deleting this folder

Nothing depends on it. It is excluded from the Docker build context and is not
downloaded by the installers, so removing it has no effect on users:

```bash
git rm -r archive/
```
