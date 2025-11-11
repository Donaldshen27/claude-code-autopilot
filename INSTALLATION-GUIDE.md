# Installation Guide

## For Users: Installing Claude Code Autopilot

### Quick Installation (Recommended)

Install to any project with a single command:

```bash
curl -sL https://raw.githubusercontent.com/donaldshen27/claude-code-autopilot/main/install.sh | bash -s /path/to/your/project
```

### What Gets Installed

- `.claude/` - Complete autopilot system
  - 26 production skills
  - 11 specialized agents
  - 6 slash commands
  - 8 automation hooks
  - Settings and configuration
- `dev/` - Dev docs pattern templates
- `AUTOPILOT-README.md` - Full documentation
- `LICENSE` - MIT license

### What the Installer Does

1. **Pre-flight Checks** - Verifies required tools (curl, tar, npm)
2. **Backup** - Creates timestamped backups of existing files
3. **Download** - Fetches latest template from GitHub
4. **Install** - Copies all template files to your project
5. **Dependencies** - Runs `npm install` in `.claude/hooks`
6. **Permissions** - Makes all hooks executable
7. **Verify** - Validates installation integrity

### After Installation

```bash
cd /path/to/your/project
claude
```

Skills will auto-activate based on your prompts!

### Troubleshooting

**npm not found:**
```bash
# Install Node.js first, then run:
cd .claude/hooks && npm install
```

**Permission denied:**
```bash
# Make hooks executable:
chmod +x .claude/hooks/*.sh .claude/hooks/*.py
```

**Rollback to backup:**
```bash
# If you have a backup:
rm -rf .claude
mv .claude.backup.TIMESTAMP .claude
```

## For Maintainers: Updating the Template

### Testing Locally

```bash
# Test in a temporary directory
./install.sh /tmp/test-project

# Verify installation
ls -la /tmp/test-project/.claude
```

### Deploying Changes

1. Make changes to `.claude/`, skills, agents, etc.
2. Test locally: `./install.sh /tmp/test`
3. Commit changes: `git commit -am "description"`
4. Push to GitHub: `git push origin main`

Users will automatically get the latest version when they run the installer.

### Updating GitHub Username

If forking this project, update in two places:

**1. install.sh:**
```bash
GITHUB_USER="your-username"
GITHUB_REPO="claude-code-autopilot"
```

**2. README.md:**
```bash
curl -sL https://raw.githubusercontent.com/your-username/claude-code-autopilot/main/install.sh | bash -s /path/to/project
```

### Script Architecture

The installer follows a phased approach:

1. **Preflight** - Check dependencies, validate target
2. **Plan** - Display what will be installed, get confirmation
3. **Download** - Fetch template from GitHub as tarball
4. **Backup** - Preserve existing files with timestamps
5. **Copy** - Install all template files
6. **Setup** - Install dependencies, set permissions
7. **Verify** - Validate installation, count components
8. **Report** - Display success message and next steps

**Error Handling:**
- Automatic rollback on any failure
- Restores all backups
- Cleans up temporary files
- Clear error messages

### Version Management

Current approach: Always installs from `main` branch.

**Future enhancement:**
```bash
# Allow version selection
curl -sL <url> | bash -s /path/to/project v1.2.3
```

This would require tagging releases and updating the download URL logic.

### File Conflict Strategy

**Current:** Backup and overwrite

Existing files are renamed:
- `.claude` → `.claude.backup.TIMESTAMP`
- `dev` → `dev.backup.TIMESTAMP`
- `LICENSE` → `LICENSE.backup.TIMESTAMP`

**Alternative strategies considered:**
- Skip existing (too conservative)
- Interactive prompts (too slow)
- Smart merge (too complex)

Backup approach provides best balance of safety and simplicity.

## Advanced Usage

### Install Specific Branch

Edit the script temporarily:
```bash
curl -sL <url> | sed 's/main/your-branch/' | bash -s /path/to/project
```

### Dry Run (Check Only)

The script doesn't currently support dry-run, but you can:
```bash
# Clone and inspect first
git clone https://github.com/donaldshen27/claude-code-autopilot.git temp
cd temp
ls -la .claude
./install.sh /path/to/project
```

### Uninstall

```bash
# Remove installed files
cd /path/to/your/project
rm -rf .claude AUTOPILOT-README.md

# Restore from backup if needed
mv .claude.backup.TIMESTAMP .claude
```

## Security Notes

- Script requires only user permissions (no sudo)
- Downloads only from official GitHub repository
- No arbitrary code execution
- All operations are reversible (backups created)
- Source is fully inspectable before running

## Support

- **Issues:** https://github.com/donaldshen27/claude-code-autopilot/issues
- **Discussions:** https://github.com/donaldshen27/claude-code-autopilot/discussions
- **Documentation:** See AUTOPILOT-README.md after installation
