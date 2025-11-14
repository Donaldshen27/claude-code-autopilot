#!/bin/bash

# Claude Code Autopilot - Installation Script
# Usage: curl -sL https://raw.githubusercontent.com/donaldshen27/claude-code-autopilot/main/install.sh | bash -s -- /path/to/target/project
# Usage (skip confirmations): curl -sL https://raw.githubusercontent.com/donaldshen27/claude-code-autopilot/main/install.sh | bash -s -- -y /path/to/target/project

set -e  # Exit on error

# Parse flags
SKIP_CONFIRM=false
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes)
      SKIP_CONFIRM=true
      shift
      ;;
    *)
      TARGET_DIR="$1"
      shift
      ;;
  esac
done

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub repository info
GITHUB_USER="donaldshen27"
GITHUB_REPO="claude-code-autopilot"
GITHUB_BRANCH="main"

# Track what we've done for rollback
BACKUPS_CREATED=()
TEMP_DIR=""

# Cleanup function
function cleanup() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

trap cleanup EXIT

# Error handler with rollback
function cleanup_on_error() {
  echo ""
  echo -e "${RED}❌ Installation failed: $1${NC}"
  echo -e "${BLUE}🔄 Rolling back changes...${NC}"

  # Restore backups
  for backup in "${BACKUPS_CREATED[@]}"; do
    original="${backup%.backup.*}"
    if [ -e "$original" ]; then
      rm -rf "$original"
    fi
    mv "$backup" "$original"
    echo -e "  ${GREEN}✓${NC} Restored $(basename "$original")"
  done

  cleanup

  echo ""
  echo "Installation cancelled. Your project is unchanged."
  exit 1
}

trap 'cleanup_on_error "unexpected error"' ERR

# Print banner
function print_banner() {
  echo ""
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║                                                           ║"
  echo "║          Claude Code Autopilot Installer                 ║"
  echo "║                                                           ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo ""
}

# Phase 1: Pre-flight checks
function preflight_checks() {
  echo -e "${BLUE}🔍 Running pre-flight checks...${NC}"

  # Check for required tools
  for tool in curl tar; do
    if ! command -v "$tool" &> /dev/null; then
      cleanup_on_error "Required tool not found: $tool"
    fi
  done
  echo -e "  ${GREEN}✓${NC} Required tools available"

  # Check for Node.js/npm
  if ! command -v npm &> /dev/null; then
    echo -e "  ${YELLOW}⚠️  npm not found - hook dependencies won't be installed${NC}"
    echo -e "     Install Node.js later and run: ${BLUE}cd .claude/hooks && npm install${NC}"
  else
    echo -e "  ${GREEN}✓${NC} npm available"
  fi

  # Validate target directory
  if [ -z "$TARGET_DIR" ]; then
    echo -e "${RED}❌ Error: No target directory specified${NC}"
    echo ""
    echo "Usage:"
    echo "  curl -sL <script-url> | bash -s -- /path/to/target/project"
    echo "  curl -sL <script-url> | bash -s -- -y /path/to/target/project  # Skip confirmations"
    exit 1
  fi

  # Create target directory if it doesn't exist
  if [ ! -d "$TARGET_DIR" ]; then
    if [ "$SKIP_CONFIRM" = true ]; then
      mkdir -p "$TARGET_DIR"
      echo -e "  ${GREEN}✓${NC} Created directory: $TARGET_DIR"
    else
      echo ""
      echo -e "${YELLOW}Directory doesn't exist: $TARGET_DIR${NC}"
      read -p "Create it? (y/n) " -n 1 -r < /dev/tty
      echo ""
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$TARGET_DIR"
        echo -e "  ${GREEN}✓${NC} Directory created"
      else
        echo "Installation cancelled."
        exit 1
      fi
    fi
  fi

  # Convert to absolute path
  TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

  echo -e "  ${GREEN}✓${NC} Target directory: $TARGET_DIR"
}

# Phase 2: Display installation plan
function display_plan() {
  echo ""
  echo -e "${BLUE}📦 Installation Plan:${NC}"
  echo -e "   ${GREEN}→${NC} Target: $TARGET_DIR"
  echo -e "   ${GREEN}→${NC} .claude/ (26 skills, 11 agents, 6 commands, hooks)"
  echo -e "   ${GREEN}→${NC} dev/ (dev docs pattern)"
  echo -e "   ${GREEN}→${NC} AUTOPILOT-README.md"
  echo -e "   ${GREEN}→${NC} LICENSE"
  echo ""

  # Check for existing files
  local conflicts=0
  [ -d "$TARGET_DIR/.claude" ] && { echo -e "   ${YELLOW}⚠️  Will backup existing: .claude/${NC}"; conflicts=1; }
  [ -d "$TARGET_DIR/dev" ] && { echo -e "   ${YELLOW}⚠️  Will backup existing: dev/${NC}"; conflicts=1; }
  [ -f "$TARGET_DIR/LICENSE" ] && { echo -e "   ${YELLOW}⚠️  Will backup existing: LICENSE${NC}"; conflicts=1; }

  if [ $conflicts -eq 1 ]; then
    echo -e "   ${BLUE}ℹ️  Backups will be created with timestamp suffix${NC}"
  fi

  if [ "$SKIP_CONFIRM" = false ]; then
    echo ""
    read -p "Continue with installation? (y/n) " -n 1 -r < /dev/tty
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Installation cancelled."
      exit 0
    fi
  else
    echo ""
  fi
}

# Phase 3: Download template
function download_template() {
  echo ""
  echo -e "${BLUE}📥 Downloading template from GitHub...${NC}"

  # Create temp directory
  TEMP_DIR=$(mktemp -d)

  # Download tarball
  local url="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/archive/${GITHUB_BRANCH}.tar.gz"

  if ! curl -sL "$url" | tar xz -C "$TEMP_DIR" 2>/dev/null; then
    cleanup_on_error "Failed to download template from GitHub"
  fi

  # Verify download
  if [ ! -d "$TEMP_DIR/${GITHUB_REPO}-${GITHUB_BRANCH}/.claude" ]; then
    cleanup_on_error "Downloaded archive appears invalid (missing .claude directory)"
  fi

  echo -e "  ${GREEN}✓${NC} Template downloaded"
}

# Phase 4: Backup existing files
function backup_existing_files() {
  local timestamp=$(date +%Y%m%d-%H%M%S)
  local backed_up=0

  echo ""
  echo -e "${BLUE}📂 Checking for existing files...${NC}"

  # Backup .claude/
  if [ -d "$TARGET_DIR/.claude" ]; then
    local backup="$TARGET_DIR/.claude.backup.$timestamp"
    mv "$TARGET_DIR/.claude" "$backup"
    BACKUPS_CREATED+=("$backup")
    echo -e "  ${GREEN}✓${NC} Backed up .claude/ → .claude.backup.$timestamp"
    backed_up=1
  fi

  # Backup dev/
  if [ -d "$TARGET_DIR/dev" ]; then
    local backup="$TARGET_DIR/dev.backup.$timestamp"
    mv "$TARGET_DIR/dev" "$backup"
    BACKUPS_CREATED+=("$backup")
    echo -e "  ${GREEN}✓${NC} Backed up dev/ → dev.backup.$timestamp"
    backed_up=1
  fi

  # Backup LICENSE
  if [ -f "$TARGET_DIR/LICENSE" ]; then
    local backup="$TARGET_DIR/LICENSE.backup.$timestamp"
    mv "$TARGET_DIR/LICENSE" "$backup"
    BACKUPS_CREATED+=("$backup")
    echo -e "  ${GREEN}✓${NC} Backed up LICENSE → LICENSE.backup.$timestamp"
    backed_up=1
  fi

  if [ $backed_up -eq 0 ]; then
    echo -e "  ${BLUE}ℹ️  No existing files to backup${NC}"
  fi
}

# Phase 5: Copy template files
function copy_template_files() {
  echo ""
  echo -e "${BLUE}📋 Installing files...${NC}"

  local source="$TEMP_DIR/${GITHUB_REPO}-${GITHUB_BRANCH}"

  # Copy .claude/
  cp -r "$source/.claude" "$TARGET_DIR/"
  echo -e "  ${GREEN}✓${NC} Copied .claude/"

  # Copy dev/
  cp -r "$source/dev" "$TARGET_DIR/"
  echo -e "  ${GREEN}✓${NC} Copied dev/"

  # Copy LICENSE
  cp "$source/LICENSE" "$TARGET_DIR/"
  echo -e "  ${GREEN}✓${NC} Copied LICENSE"

  # Copy README as AUTOPILOT-README.md (don't overwrite existing README)
  cp "$source/README.md" "$TARGET_DIR/AUTOPILOT-README.md"
  echo -e "  ${GREEN}✓${NC} Copied README → AUTOPILOT-README.md"
}

# Phase 6: Install dependencies
function install_dependencies() {
  echo ""
  echo -e "${BLUE}📦 Setting up dependencies...${NC}"

  if command -v npm &> /dev/null; then
    echo -e "  ${BLUE}→${NC} Installing hook dependencies..."

    cd "$TARGET_DIR/.claude/hooks"

    # Install dependencies quietly
    if npm install --silent 2>&1 | grep -v "npm WARN" > /dev/null; then
      echo -e "  ${GREEN}✓${NC} Hook dependencies installed"
    else
      echo -e "  ${GREEN}✓${NC} Hook dependencies installed (with warnings)"
    fi
  else
    echo -e "  ${YELLOW}⚠️  Skipping npm install (npm not found)${NC}"
    echo -e "     Run later: ${BLUE}cd $TARGET_DIR/.claude/hooks && npm install${NC}"
  fi
}

# Phase 7: Set permissions
function set_permissions() {
  echo ""
  echo -e "${BLUE}🔧 Setting permissions...${NC}"

  # Make shell scripts executable
  chmod +x "$TARGET_DIR/.claude/hooks"/*.sh 2>/dev/null || true

  # Make Python scripts executable
  chmod +x "$TARGET_DIR/.claude/hooks"/*.py 2>/dev/null || true

  echo -e "  ${GREEN}✓${NC} Permissions set"
}

# Phase 8: Verify installation
function verify_installation() {
  echo ""
  echo -e "${BLUE}🔍 Verifying installation...${NC}"

  # Count skills
  local skill_count=$(find "$TARGET_DIR/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l)
  echo -e "  ${GREEN}✓${NC} Skills: $skill_count"

  # Count agents
  local agent_count=$(find "$TARGET_DIR/.claude/agents" -name "*.md" 2>/dev/null | wc -l)
  echo -e "  ${GREEN}✓${NC} Agents: $agent_count"

  # Count commands
  local command_count=$(find "$TARGET_DIR/.claude/commands" -name "*.md" 2>/dev/null | wc -l)
  echo -e "  ${GREEN}✓${NC} Commands: $command_count"

  # Check settings.json is valid JSON
  if command -v python3 &> /dev/null; then
    if python3 -m json.tool "$TARGET_DIR/.claude/settings.json" > /dev/null 2>&1; then
      echo -e "  ${GREEN}✓${NC} settings.json is valid"
    else
      echo -e "  ${YELLOW}⚠️  settings.json may be invalid${NC}"
    fi
  fi

  # Check dependencies
  if [ -d "$TARGET_DIR/.claude/hooks/node_modules" ]; then
    echo -e "  ${GREEN}✓${NC} Hook dependencies installed"
  else
    echo -e "  ${YELLOW}⚠️  Hook dependencies not installed${NC}"
  fi
}

# Phase 9: Print success report
function print_success() {
  echo ""
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║                                                           ║"
  echo "║  ✨ Claude Code Autopilot installed successfully!        ║"
  echo "║                                                           ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo ""

  echo -e "${GREEN}📦 Installed:${NC}"
  local skill_count=$(find "$TARGET_DIR/.claude/skills" -name "SKILL.md" 2>/dev/null | wc -l)
  local agent_count=$(find "$TARGET_DIR/.claude/agents" -name "*.md" 2>/dev/null | wc -l)
  local command_count=$(find "$TARGET_DIR/.claude/commands" -name "*.md" 2>/dev/null | wc -l)

  echo "  ✓ $skill_count skills"
  echo "  ✓ $agent_count agents"
  echo "  ✓ $command_count slash commands"

  if [ -d "$TARGET_DIR/.claude/hooks/node_modules" ]; then
    echo "  ✓ Hook dependencies"
  fi

  if [ ${#BACKUPS_CREATED[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}📂 Backups created:${NC}"
    for backup in "${BACKUPS_CREATED[@]}"; do
      echo "  • $(basename "$backup")"
    done
  fi

  echo ""
  echo -e "${BLUE}🚀 Next steps:${NC}"
  echo "  1. cd $TARGET_DIR"
  echo "  2. claude"
  echo "  3. Start coding - skills auto-activate!"
  echo ""
  echo -e "${BLUE}📖 Documentation:${NC}"
  echo "  • ./AUTOPILOT-README.md - Complete guide"
  echo "  • ./dev/README.md - Dev docs pattern"
  echo "  • ./.claude/skills/ - Browse available skills"
  echo ""
  echo -e "${BLUE}💡 Try these commands:${NC}"
  echo "  • /brainstorm - Interactive idea refinement"
  echo "  • /write-plan - Create implementation plans"
  echo "  • @code-reviewer - Review your code"
  echo ""
  echo -e "Need help? ${BLUE}https://github.com/${GITHUB_USER}/${GITHUB_REPO}/issues${NC}"
  echo ""
}

# Main installation flow
function main() {
  print_banner

  preflight_checks
  display_plan
  download_template
  backup_existing_files
  copy_template_files
  install_dependencies
  set_permissions
  verify_installation
  print_success
}

# Run main (arguments already parsed above)
main
