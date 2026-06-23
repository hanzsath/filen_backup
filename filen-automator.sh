#!/bin/bash

# Hardened Bash Settings
set -euo pipefail
IFS=$'\n\t'

# Global Configuration Variables
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_FILE="$USER_SYSTEMD_DIR/filen-sync.service"
TIMER_FILE="$USER_SYSTEMD_DIR/filen-sync.timer"
LOG_DIR="$HOME/.local/state/filen-automator"

# Visual Theme Definitions
BANNER_LINE="===================================================="
SECTION_LINE="----------------------------------------------------"

# Helper print functions for clear UX status
log_info()    { echo -e "💡 \033[1;34mINFO:\033[0m $1"; }
log_success() { echo -e "✅ \033[1;32mSUCCESS:\033[0m $1"; }
log_warn()    { echo -e "⚠️  \033[1;33mWARNING:\033[0m $1"; }
log_error()   { echo -e "❌ \033[1;31mERROR:\033[0m $1" >&2; }

show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup       Run interactive setup wizard to install and configure backup automation"
    echo "  remove      Teardown systemd services, timers, and lingering adjustments cleanly"
    echo "  status      Check active status of the backup manager engine"
    echo "  help        Display this help interface"
}

check_systemd_session() {
    if ! systemctl --user status >/dev/null 2>&1; then
        log_error "systemd user session is unavailable or DBUS is not responding."
        log_error "If on an SSH session, ensure you run 'loginctl enable-linger \$USER' first and re-log."
        exit 1
    fi
}

do_remove() {
    echo "$BANNER_LINE"
    echo "🗑️   TEARDOWN & UNINSTALL AUTOMATION SEQUENCE"
    echo "$BANNER_LINE"
    
    check_systemd_session
    
    if [ -f "$TIMER_FILE" ]; then
        log_info "Stopping and disabling systemd timer..."
        systemctl --user disable --now filen-sync.timer || true
        rm -f "$TIMER_FILE"
    fi
    
    if [ -f "$SERVICE_FILE" ]; then
        log_info "Removing systemd service file..."
        rm -f "$SERVICE_FILE"
    fi
    
    log_info "Reloading systemd manager unit tables..."
    systemctl --user daemon-reload
    
    log_success "Automation infrastructure dropped cleanly."
}

do_status() {
    echo "$BANNER_LINE"
    echo "📊  BACKUP ENGINE METRICS & ENGINE STATUS"
    echo "$BANNER_LINE"
    
    check_systemd_session
    
    if [ ! -f "$TIMER_FILE" ]; then
        log_warn "No systemd timers found deployed for this runtime environment."
        exit 0
    fi
    
    systemctl --user status filen-sync.timer --no-pager
    echo "$SECTION_LINE"
    systemctl --user status filen-sync.service --no-pager || true
}

do_setup() {
    clear
    echo "$BANNER_LINE"
    echo "   🚀 HARDENED FILEN AUTOMATED BACKUP ENGINE"
    echo "$BANNER_LINE"
    echo ""

    # Pre-flight Check: Validate systemd usability before doing anything
    check_systemd_session

    # 1. ENVIRONMENT PROFILE PRE-INITIALIZATION (Fixes Race Conditions)
    echo "🖥️  STEP 1: Target Architecture Profile"
    echo "$SECTION_LINE"
    echo "1) Desktop/Laptop Environment (Fires when logged into interactive UI session)"
    echo "2) Headless Server/VPS Environment (Requires service persistence when disconnected)"
    read -rp "Select environment target [1 or 2, Default: 1]: " ENV_CHOICE
    ENV_CHOICE=${ENV_CHOICE:-1}

    if [ "$ENV_CHOICE" -eq 2 ]; then
        log_info "Server Mode Selected. Ordering Linger invocation to stabilize DBUS user space..."
        sudo loginctl enable-linger "$USER"
    fi
    echo ""

    # 2. AUTO-INSTALL CURL IF MISSING
    log_info "Evaluating core system dependencies..."
    if ! command -v curl &> /dev/null; then
        log_warn "'curl' binary missing. Attempting privilege elevation package capture..."
        if command -v dnf &> /dev/null; then
            sudo dnf install -y curl
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm curl
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        else
            log_error "Unsupported package manager. Please manually map 'curl' dependency."
            exit 1
        fi
    else
        log_success "'curl' dependency verified."
    fi

    # 3. SECURE FILEN CLI INGESTION PIPELINE
    if ! command -v filen &> /dev/null; then
        log_info "Filen CLI execution target not in path. Downloading binary asset stream..."
        TMP_SH=$(mktemp /tmp/filen-installer.XXXXXX.sh)
        curl -fsSL https://filen.io/cli.sh -o "$TMP_SH"
        bash "$TMP_SH"
        rm -f "$TMP_SH"
        
        # Immediate session path re-binding
        export PATH="$HOME/.filen-cli/bin:$PATH"
    fi

    # Dynamically track absolute binary path to protect systemd from runtime mapping failures
    FILEN_BIN=$(command -v filen || echo "$HOME/.filen-cli/bin/filen")
    log_success "Filen execution pointer mapped to: $FILEN_BIN"
    echo ""

    # 4. SECURE INTERACTIVE CREDENTIALS GATEWAY
    echo "🔐 STEP 2: Cloud Account Authorization"
    echo "$SECTION_LINE"
    log_warn "Spawning nested Filen interactive context."
    log_info "Complete login / credential verification inside the subshell container."
    
    if ! "$FILEN_BIN"; then
        log_error "Filen CLI session execution failed or registration rejected."
        exit 1
    fi
    log_success "Session configuration validated successfully."
    echo ""

    # 5. PATH RESOLUTION AND DATA STRUCTURING
    echo "📂 STEP 3: Source and Cloud Destination Targets"
    echo "$SECTION_LINE"
    read -rp "Enter local folder path to secure [Default: $HOME/Documents]: " USER_LOCAL_PATH
    USER_LOCAL_PATH=${USER_LOCAL_PATH:-$HOME/Documents}
    USER_LOCAL_PATH="${USER_LOCAL_PATH/#\~/$HOME}" # Expand raw tilde text strings safely

    if [ -e "$USER_LOCAL_PATH" ] && [ ! -d "$USER_LOCAL_PATH" ]; then
        log_error "Specified route exists but path target is not a standard directory architecture."
        exit 1
    fi
    mkdir -p "$USER_LOCAL_PATH"

    read -rp "Enter target destination path in Cloud (e.g., /Linux, /Backups/VPS) [Default: /Linux]: " USER_REMOTE_PATH
    USER_REMOTE_PATH=${USER_REMOTE_PATH:-/Linux}
    [[ ! "$USER_REMOTE_PATH" =~ ^/ ]] && USER_REMOTE_PATH="/$USER_REMOTE_PATH" # Enforce relative root syntax
    echo ""

    # 6. SCHEDULER MATRIX DEFINITION
    echo "⏰ STEP 4: Scheduler Matrix Definition"
    echo "$SECTION_LINE"
    read -rp "Specify Daily Execution Window (24h format HH:MM) [Default: 23:00]: " USER_TIME
    USER_TIME=${USER_TIME:-23:00}

    if [[ ! "$USER_TIME" =~ ^([0-1][0-9]|2[0-3]):[0-5][0-9]$ ]]; then
        log_error "Datetime string configuration rejection. Format structure must match HH:MM."
        exit 1
    fi
    echo ""

    # 7. IDEMPOTENT ATOMIC DEPLOYMENT
    echo "⚙️  STEP 5: Systemd Engine Compilation"
    echo "$SECTION_LINE"
    mkdir -p "$USER_SYSTEMD_DIR"
    mkdir -p "$LOG_DIR"

    # Backup any collision hazards
    [ -f "$SERVICE_FILE" ] && cp "$SERVICE_FILE" "$SERVICE_FILE.bak"
    [ -f "$TIMER_FILE" ] && cp "$TIMER_FILE" "$TIMER_FILE.bak"

    log_info "Writing unit manifest models to disk using macro definitions (%h)..."
    
    # Write Service utilizing precise flock lockups & systemd %h macro path expansions
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Filen Daily Backup Sync
Documentation=https://github.com/%u

[Service]
Type=oneshot
ExecStartPre=/usr/bin/flock -n /tmp/filen-sync.lock true
ExecStart=$FILEN_BIN sync $USER_LOCAL_PATH:ltc:$USER_REMOTE_PATH
StandardOutput=journal
StandardError=journal
EOF

    # Write Timer
    cat << EOF > "$TIMER_FILE"
[Unit]
Description=Run Filen sync daily at $USER_TIME

[Timer]
OnCalendar=*-*-* $USER_TIME:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    log_info "Synchronizing service configurations changes..."
    systemctl --user daemon-reload
    
    log_info "Activating automation clocks..."
    systemctl --user enable --now filen-sync.timer

    echo ""
    echo "$BANNER_LINE"
    log_success "DEPLOYMENT PIPELINE COMPLETE!"
    echo "$BANNER_LINE"
    systemctl --user status filen-sync.timer --no-pager
}

# Command Router Array
case "${1:-help}" in
    setup)  do_setup ;;
    remove) do_remove ;;
    status) do_status ;;
    help|*) show_usage ;;
esac
