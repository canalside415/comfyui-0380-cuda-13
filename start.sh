#!/bin/bash
set -e

export SHELL=/bin/bash

# ============================================================
# Persistent storage
# ============================================================

DATA="${COMFY_DATA:-/workspace/ComfyUI-data}"

mkdir -p "$DATA"/{models,input,output,user}
mkdir -p /workspace/ollama/models
mkdir -p /workspace/logs

# Seed ComfyUI models only when persistent model directory is empty.
if [ -z "$(ls -A "$DATA/models" 2>/dev/null)" ]; then
  cp -a /opt/ComfyUI/models/. "$DATA/models/"
fi

# Link persistent ComfyUI directories.
for d in models input output user; do
  rm -rf "/opt/ComfyUI/$d"
  ln -s "$DATA/$d" "/opt/ComfyUI/$d"
done


# ============================================================
# JupyterLab
# ============================================================

JUPYTER_PASSWORD="${JUPYTER_PASSWORD:-$(openssl rand -hex 16)}"

echo "Jupyter token: $JUPYTER_PASSWORD"

/opt/jupyter/bin/jupyter lab \
  --allow-root \
  --no-browser \
  --ip=0.0.0.0 \
  --port=8888 \
  --ServerApp.token="$JUPYTER_PASSWORD" \
  --ServerApp.allow_origin='*' \
  --ServerApp.root_dir=/workspace \
  > /workspace/logs/jupyter.log 2>&1 &


# ============================================================
# File Browser
# ============================================================

FB_DB=/workspace/.filebrowser.db
FB_PASS="${FILEBROWSER_PASSWORD:-$(openssl rand -hex 8)}"

if [ ! -f "$FB_DB" ]; then
  filebrowser config init -d "$FB_DB"
  filebrowser users add admin "$FB_PASS" --perm.admin -d "$FB_DB"

  echo "File Browser login: admin / $FB_PASS"
fi

filebrowser \
  -r /workspace \
  -a 0.0.0.0 \
  -p 8080 \
  -d "$FB_DB" \
  > /workspace/logs/filebrowser.log 2>&1 &


# ============================================================
# Ollama
#
# Listen on all interfaces so RunPod's HTTP proxy can reach it.
# Keep models on persistent /workspace storage.
# ============================================================

if command -v ollama >/dev/null 2>&1; then

  export OLLAMA_HOST=0.0.0.0:11434
  export OLLAMA_MODELS=/workspace/ollama/models

  echo "Starting Ollama..."

  ollama serve \
    > /workspace/logs/ollama.log 2>&1 &

  OLLAMA_PID=$!

  echo "Ollama PID: $OLLAMA_PID"
  echo "Waiting for Ollama API..."

  OLLAMA_READY=0

  for i in $(seq 1 30); do

    if curl -fsS \
      http://127.0.0.1:11434/api/version \
      >/dev/null 2>&1; then

      OLLAMA_READY=1
      echo "Ollama API ready on port 11434."
      break
    fi

    # Detect an Ollama process that died during startup.
    if ! kill -0 "$OLLAMA_PID" 2>/dev/null; then
      echo "ERROR: Ollama exited during startup."
      echo "----- Ollama log -----"
      cat /workspace/logs/ollama.log || true
      echo "----------------------"
      exit 1
    fi

    sleep 1
  done

  if [ "$OLLAMA_READY" -ne 1 ]; then
    echo "ERROR: Ollama did not become ready within 30 seconds."
    echo "----- Ollama log -----"
    cat /workspace/logs/ollama.log || true
    echo "----------------------"
    exit 1
  fi

else

  echo "ERROR: Ollama is not installed in this image."
  exit 1

fi


# ============================================================
# ComfyUI
#
# Keep this last. exec makes ComfyUI the main container process.
# ============================================================

cd /opt/ComfyUI

exec python main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --enable-cors-header \
  --enable-manager \
  $COMFY_ARGS
