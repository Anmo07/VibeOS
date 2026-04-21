%post
# ---------------------------------------------------------
# AI System Integration — VibeOS AI Layer
# ---------------------------------------------------------
# This module installs Ollama as a local AI inference engine
# and integrates it with the shell, file manager, and desktop.
# ---------------------------------------------------------

# ---------------------------------------------------------
# 1. Install Ollama (local LLM inference engine)
# ---------------------------------------------------------
dnf install -y zstd || true
export PATH=$PATH:/usr/sbin:/sbin && curl -fsSL https://ollama.com/install.sh | sh || true

# ---------------------------------------------------------
# 2. Create vibe-ai systemd service
# ---------------------------------------------------------
cat <<'EOF' > /etc/systemd/system/vibe-ai.service
[Unit]
Description=VibeOS AI Engine (Ollama)
After=network-online.target
Wants=network-online.target

[Service]
Type=exec
ExecStart=/usr/local/bin/ollama serve
Restart=on-failure
RestartSec=5
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="HOME=/var/lib/vibe-ai"

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/var/lib/vibe-ai

[Install]
WantedBy=multi-user.target
EOF

# Create data directory for AI models
mkdir -p /var/lib/vibe-ai
systemctl enable vibe-ai.service || true

# ---------------------------------------------------------
# 3. First-boot model pull service
# ---------------------------------------------------------
cat <<'SCRIPT' > /usr/local/bin/vibeos-ai-setup.sh
#!/bin/bash
LOG="/var/log/vibeos-ai-setup.log"
echo "$(date): VibeOS AI Setup starting..." | tee -a "$LOG"

# Wait for Ollama to be ready
for i in $(seq 1 30); do
    curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1 && break
    echo "Waiting for Ollama... ($i/30)" | tee -a "$LOG"
    sleep 5
done

# Pull a small, fast default model
echo "Pulling default AI model (tinyllama)..." | tee -a "$LOG"
ollama pull tinyllama 2>&1 | tee -a "$LOG" || true

echo "$(date): AI setup complete" | tee -a "$LOG"
systemctl disable vibeos-ai-setup.service
SCRIPT
chmod +x /usr/local/bin/vibeos-ai-setup.sh

cat <<'EOF' > /etc/systemd/system/vibeos-ai-setup.service
[Unit]
Description=VibeOS AI First-Boot Model Setup
After=vibe-ai.service network-online.target
Wants=vibe-ai.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/vibeos-ai-setup.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
systemctl enable vibeos-ai-setup.service || true

# ---------------------------------------------------------
# 4. CLI Wrapper: /usr/local/bin/vibe-ai
# ---------------------------------------------------------
cat <<'SCRIPT' > /usr/local/bin/vibe-ai
#!/bin/bash
# vibe-ai — VibeOS AI assistant CLI
# Usage:
#   vibe-ai "What does this error mean?"
#   echo "some text" | vibe-ai summarize
#   vibe-ai explain <file>
#   vibe-ai models          — list available models
#   vibe-ai pull <model>    — download a new model

set -e
OLLAMA_HOST="${OLLAMA_HOST:-http://127.0.0.1:11434}"
MODEL="${VIBE_AI_MODEL:-tinyllama}"

case "${1:-}" in
    models)
        ollama list 2>/dev/null || echo "AI daemon not running. Start with: systemctl start vibe-ai"
        ;;
    pull)
        shift
        ollama pull "$@"
        ;;
    explain)
        shift
        if [ -f "$1" ]; then
            CONTENT=$(head -200 "$1")
            PROMPT="Explain this file concisely:\n\n${CONTENT}"
            ollama run "$MODEL" "$PROMPT"
        else
            echo "File not found: $1"
            exit 1
        fi
        ;;
    summarize)
        INPUT=$(cat)
        ollama run "$MODEL" "Summarize this concisely: ${INPUT}"
        ;;
    "")
        echo "vibe-ai — VibeOS AI Assistant"
        echo ""
        echo "Usage:"
        echo "  vibe-ai \"your question\"        Ask a question"
        echo "  vibe-ai explain <file>          Explain a file"
        echo "  echo text | vibe-ai summarize   Summarize piped input"
        echo "  vibe-ai models                  List installed models"
        echo "  vibe-ai pull <model>            Download a model"
        echo ""
        echo "Environment:"
        echo "  VIBE_AI_MODEL=$MODEL"
        ;;
    *)
        # Direct question mode
        ollama run "$MODEL" "$*"
        ;;
esac
SCRIPT
chmod +x /usr/local/bin/vibe-ai

# ---------------------------------------------------------
# 5. Zsh Integration — AI command suggestions
# ---------------------------------------------------------
mkdir -p /usr/share/oh-my-zsh/custom/plugins/vibe-ai
cat <<'ZSH' > /usr/share/oh-my-zsh/custom/plugins/vibe-ai/vibe-ai.plugin.zsh
# vibe-ai Zsh plugin — AI-powered command assistance
# Usage: Type a natural language query prefixed with "?" and press Enter
#   Example: ? how to find large files in /tmp

function _vibe_ai_command_not_found_handler() {
    local query="$*"
    # Only trigger on queries starting with "?"
    if [[ "$query" == \?* ]]; then
        query="${query#\?}"  # Strip the leading ?
        query="${query## }"  # Strip leading whitespace
        echo -e "\033[0;36m🤖 Asking AI...\033[0m"
        vibe-ai "You are a Linux shell expert. The user asks: ${query}. Give a single concise command and a one-line explanation. Format: COMMAND: <cmd>\nEXPLAIN: <text>"
        return 0
    fi
    # Fall through to default handler
    return 127
}

# Register the handler
command_not_found_handler() {
    _vibe_ai_command_not_found_handler "$@"
}

# Keybinding: Ctrl+A to ask AI about the current command line
function _vibe_ai_explain_line() {
    local line="$BUFFER"
    if [ -n "$line" ]; then
        echo ""
        echo -e "\033[0;36m🤖 Explaining: $line\033[0m"
        vibe-ai "Explain this shell command concisely: $line"
        zle reset-prompt
    fi
}
zle -N _vibe_ai_explain_line
bindkey '^[a' _vibe_ai_explain_line  # Alt+A to explain current line
ZSH

# ---------------------------------------------------------
# 6. Nautilus "Ask AI" right-click action
# ---------------------------------------------------------
mkdir -p /etc/skel/.local/share/nautilus/scripts
cat <<'SCRIPT' > /etc/skel/.local/share/nautilus/scripts/Ask\ AI
#!/bin/bash
# Nautilus script: Ask AI about selected file(s)
FILE="$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS"

if [ -z "$FILE" ]; then
    zenity --error --text="No file selected" 2>/dev/null
    exit 1
fi

# Get first file
FIRST_FILE=$(echo "$FILE" | head -1)
FILENAME=$(basename "$FIRST_FILE")
FILETYPE=$(file -b "$FIRST_FILE" 2>/dev/null)
PREVIEW=$(head -50 "$FIRST_FILE" 2>/dev/null || echo "[binary file]")

RESULT=$(vibe-ai "File: ${FILENAME}\nType: ${FILETYPE}\nContent preview:\n${PREVIEW}\n\nDescribe this file: what it is, what it does, and any notable content." 2>&1)

zenity --info --title="🤖 AI: ${FILENAME}" --text="$RESULT" --width=500 2>/dev/null || \
    echo "$RESULT"  # Fallback if zenity not available
SCRIPT
chmod +x "/etc/skel/.local/share/nautilus/scripts/Ask AI"

# ---------------------------------------------------------
# 7. Add vibe-ai plugin to default .zshrc
# ---------------------------------------------------------
if [ -f /etc/skel/.zshrc ]; then
    sed -i 's/plugins=(\(.*\))/plugins=(\1 vibe-ai)/' /etc/skel/.zshrc || true
fi

%end
