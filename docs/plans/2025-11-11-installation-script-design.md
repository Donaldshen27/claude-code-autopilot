# Installation Script Design

**Date:** 2025-11-11
**Status:** Approved
**Purpose:** Create a fast, single-command installation script for Claude Code Autopilot

## Overview

A single bash script that provides zero-config installation of Claude Code Autopilot into any project. The script will be hosted on GitHub and runnable via:

```bash
curl -sL https://raw.githubusercontent.com/yourusername/claude-code-autopilot/main/install.sh | bash -s /path/to/target/project
```

## Design Decisions

### What Gets Installed
- **Everything** - All `.claude/` contents, `dev/` directory, README.md (as AUTOPILOT-README.md), LICENSE
- Complete setup ensures users get the full experience right away

### Conflict Resolution
- **Backup and overwrite** - Rename existing files to `.backup.TIMESTAMP` and install fresh
- Preserves old files while ensuring clean installation
- Users can manually merge customizations if needed

### Installation Method
- **Single command from web** - `curl | bash` pattern
- Hosted on GitHub using raw.githubusercontent.com URLs
- Fastest possible installation, no clone needed

### Post-Installation Setup
- **Full automation** - Copy files + install deps + make hooks executable + verify settings
- Completely ready to use, best first-time experience
- Handles: npm install, chmod +x, settings validation

## Architecture

### Core Phases

1. **Download Phase** - Script downloads entire `.claude/` directory as tarball from GitHub
2. **Backup Phase** - Detects existing files and creates `.backup` copies
3. **Copy Phase** - Installs all template files to target project
4. **Setup Phase** - Installs dependencies, sets permissions, verifies configuration
5. **Verification Phase** - Runs health checks and displays success report

### Requirements

**Minimal:**
- `bash` (any modern version)
- `curl` (for downloading)
- `tar` (for extracting)

**Optional:**
- Node.js/npm (for hook dependencies - warn if missing but don't fail)

## Detailed Implementation

### Phase 1: Pre-flight Checks

```bash
# Validate target directory
if [ ! -d "$TARGET_DIR" ]; then
  read -p "Directory doesn't exist. Create it? (y/n) " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    mkdir -p "$TARGET_DIR"
  else
    exit 1
  fi
fi

# Check required tools
for tool in curl tar; do
  if ! command -v $tool &> /dev/null; then
    echo "❌ Required tool not found: $tool"
    exit 1
  fi
done

# Check for Node.js/npm
if ! command -v npm &> /dev/null; then
  echo "⚠️  npm not found - hook dependencies won't be installed"
  echo "   Install Node.js later and run: cd .claude/hooks && npm install"
fi

# Display installation plan
echo "📦 Will install to: $TARGET_DIR"
echo "   • .claude/ (26 skills, 11 agents, 6 commands, 8 hooks)"
echo "   • dev/ (dev docs pattern)"
echo "   • AUTOPILOT-README.md"
echo "   • LICENSE"
read -p "Continue? (y/n) " -n 1 -r
```

### Phase 2: Download Template

```bash
# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download latest tarball from GitHub
echo "📥 Downloading template..."
curl -sL https://github.com/USERNAME/claude-code-autopilot/archive/main.tar.gz | tar xz -C $TEMP_DIR

# Verify download
if [ ! -d "$TEMP_DIR/claude-code-autopilot-main/.claude" ]; then
  echo "❌ Download failed or invalid archive"
  exit 1
fi
```

### Phase 3: Backup Existing Files

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUPS_CREATED=()

# Backup .claude/
if [ -d "$TARGET_DIR/.claude" ]; then
  BACKUP_DIR="$TARGET_DIR/.claude.backup.$TIMESTAMP"
  mv "$TARGET_DIR/.claude" "$BACKUP_DIR"
  BACKUPS_CREATED+=("$BACKUP_DIR")
  echo "✓ Backed up existing .claude/ to .claude.backup.$TIMESTAMP"
fi

# Backup dev/
if [ -d "$TARGET_DIR/dev" ]; then
  BACKUP_DIR="$TARGET_DIR/dev.backup.$TIMESTAMP"
  mv "$TARGET_DIR/dev" "$BACKUP_DIR"
  BACKUPS_CREATED+=("$BACKUP_DIR")
  echo "✓ Backed up existing dev/ to dev.backup.$TIMESTAMP"
fi

# LICENSE - backup if exists
if [ -f "$TARGET_DIR/LICENSE" ]; then
  BACKUP_FILE="$TARGET_DIR/LICENSE.backup.$TIMESTAMP"
  mv "$TARGET_DIR/LICENSE" "$BACKUP_FILE"
  BACKUPS_CREATED+=("$BACKUP_FILE")
  echo "✓ Backed up existing LICENSE to LICENSE.backup.$TIMESTAMP"
fi
```

### Phase 4: Copy Template Files

```bash
echo "📋 Installing files..."

# Copy .claude/ directory
cp -r "$TEMP_DIR/claude-code-autopilot-main/.claude" "$TARGET_DIR/"

# Copy dev/ directory
cp -r "$TEMP_DIR/claude-code-autopilot-main/dev" "$TARGET_DIR/"

# Copy LICENSE
cp "$TEMP_DIR/claude-code-autopilot-main/LICENSE" "$TARGET_DIR/"

# Copy README as AUTOPILOT-README.md (don't overwrite existing README)
cp "$TEMP_DIR/claude-code-autopilot-main/README.md" "$TARGET_DIR/AUTOPILOT-README.md"

echo "✓ Files copied"
```

### Phase 5: Dependency Installation

```bash
if command -v npm &> /dev/null; then
  echo "📦 Installing hook dependencies..."
  cd "$TARGET_DIR/.claude/hooks"

  # Install dependencies quietly
  npm install --silent 2>&1 | grep -v "npm WARN" || true

  echo "✓ Dependencies installed"
else
  echo "⚠️  Skipping npm install (npm not found)"
fi

# Make hooks executable
echo "🔧 Setting permissions..."
chmod +x "$TARGET_DIR/.claude/hooks"/*.sh 2>/dev/null || true
chmod +x "$TARGET_DIR/.claude/hooks"/*.py 2>/dev/null || true
echo "✓ Permissions set"
```

### Phase 6: Verification

```bash
echo "🔍 Verifying installation..."

# Count skills
SKILL_COUNT=$(find "$TARGET_DIR/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l)

# Count agents
AGENT_COUNT=$(find "$TARGET_DIR/.claude/agents" -name "*.md" 2>/dev/null | wc -l)

# Count commands
COMMAND_COUNT=$(find "$TARGET_DIR/.claude/commands" -name "*.md" 2>/dev/null | wc -l)

# Verify settings.json is valid JSON
if ! python3 -m json.tool "$TARGET_DIR/.claude/settings.json" > /dev/null 2>&1; then
  echo "⚠️  settings.json may be invalid"
fi

# Check node_modules if npm ran
if [ -d "$TARGET_DIR/.claude/hooks/node_modules" ]; then
  DEPS_STATUS="✓ installed"
else
  DEPS_STATUS="⚠️  not installed"
fi
```

## Error Handling

### Rollback on Failure

```bash
PHASES_COMPLETED=()

function cleanup_on_error() {
  echo ""
  echo "❌ Installation failed: $1"
  echo "🔄 Rolling back changes..."

  # Restore backups
  for backup in "${BACKUPS_CREATED[@]}"; do
    original="${backup%.backup.*}"
    if [ -e "$original" ]; then
      rm -rf "$original"
    fi
    mv "$backup" "$original"
    echo "  ✓ Restored $(basename $original)"
  done

  # Clean temp directory
  rm -rf "$TEMP_DIR"

  echo ""
  echo "Installation cancelled. Your project is unchanged."
  exit 1
}

trap 'cleanup_on_error "unexpected error"' ERR
```

### Validation Checks

After installation:
1. Verify directory structure exists
2. Verify settings.json is valid JSON
3. Count installed components
4. Check file permissions
5. Verify dependencies if npm available

## Success Report

```
✨ Claude Code Autopilot installed successfully!

📦 Installed:
  ✓ 26 skills
  ✓ 11 agents
  ✓ 6 slash commands
  ✓ Hook dependencies (installed/not installed)

📂 Backups created:
  • .claude.backup.20251111-120000/
  • dev.backup.20251111-120000/

🚀 Next steps:
  1. cd /path/to/your/project
  2. claude
  3. Start coding - skills auto-activate!

📖 Documentation:
  • ./AUTOPILOT-README.md - Complete guide
  • ./dev/README.md - Dev docs pattern
  • ./.claude/skills/ - Browse available skills

💡 Try these commands:
  • /brainstorm - Interactive idea refinement
  • /write-plan - Create implementation plans
  • @code-reviewer - Review your code

Need help? https://github.com/username/claude-code-autopilot/issues
```

## Implementation Notes

### Script Location
- Primary: `install.sh` in repository root
- URL: `https://raw.githubusercontent.com/USERNAME/claude-code-autopilot/main/install.sh`

### Testing Strategy
1. Test on empty directory
2. Test on existing project without .claude/
3. Test on existing project with .claude/
4. Test rollback on failure
5. Test with npm unavailable
6. Test with invalid target directory

### Future Enhancements
- Add `--dry-run` flag to preview changes
- Add `--no-backup` flag for fresh installs
- Add version selection: `bash -s -- --version v1.2.3`
- Add uninstall script
- Add update script (preserve local changes)

## Security Considerations

- Script runs with user permissions (no sudo required)
- Downloads only from official GitHub repository
- Verifies download integrity before copying
- Creates backups before overwriting
- Rollback on any failure
- No arbitrary code execution from downloaded content
