#!/bin/bash
# RiverOs groq-ask.sh — segunda opinion / dudas / direccion via Groq API
# (equivalente a duck.ai pero directo, sin browser). Usa openai/gpt-oss-120b.
#
# Uso:
#   ./groq-ask.sh 'pregunta' [archivo_contexto]
#   GROQ_MODEL=openai/gpt-oss-20b ./groq-ask.sh 'pregunta'   # otro modelo
#
# La key se lee de GROQ_API_KEY (env) o del .env del perfil Hermes.
# Sin secretos en el repo. No usa pipes a interprete.
set -Eeuo pipefail

KEY="${GROQ_API_KEY:-}"
if [ -z "$KEY" ] && [ -f /root/.hermes/profiles/riveros/.env ]; then
  KEY="$(grep '^GROQ_API_KEY=' /root/.hermes/profiles/riveros/.env | cut -d= -f2- | tr -d '"'"'"' ')"
fi
[ -n "$KEY" ] || { echo "ERROR: GROQ_API_KEY no encontrada (env o .env del perfil)" >&2; exit 1; }

PROMPT="${1:?uso: groq-ask.sh <pregunta> [archivo_contexto]}"
CONTEXT_FILE="${2:-}"
MODEL="${GROQ_MODEL:-openai/gpt-oss-120b}"

GROQ_API_KEY="$KEY" python3 - "$KEY" "$PROMPT" "$CONTEXT_FILE" "$MODEL" <<'PYEOF'
import json, sys, urllib.request
key, prompt, cfile, model = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
context = ""
if cfile and cfile != "-":
    context = open(cfile, encoding="utf-8", errors="replace").read()[:24000]
messages = []
if context:
    messages.append({"role": "system", "content": "Contexto del proyecto RiverOs:\n" + context})
messages.append({"role": "user", "content": prompt})
req = urllib.request.Request(
    "https://api.groq.com/openai/v1/chat/completions",
    data=json.dumps({"model": model, "messages": messages, "max_tokens": 4096}).encode(),
    headers={"Authorization": "Bearer " + key, "Content-Type": "application/json",
             "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"})
try:
    r = json.load(urllib.request.urlopen(req, timeout=180))
    print(r["choices"][0]["message"]["content"])
except urllib.error.HTTPError as e:
    print("ERROR HTTP", e.code, e.read().decode()[:500], file=sys.stderr)
    sys.exit(1)
PYEOF
