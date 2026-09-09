mkdir -p /run/secrets
cat $OPENROUTER_API_KEY_FILE > /run/secrets/OPENROUTER_API_KEY #emulates the way my `pi` conig gets its key

mkdir -p /workspace 
cd /workspace
$pi -p --model openrouter/z-ai/glm-5.3-flash --no-session $(cat $PROMPT)

# Make every file pi created world-readable on the host share.
chmod -R a+rX /workspace 2>/dev/null || true

systemctl poweroff
