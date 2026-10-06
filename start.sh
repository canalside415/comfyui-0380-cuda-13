#!/bin/bash
export SHELL=/bin/bash
DATA="${COMFY_DATA:-/workspace/ComfyUI-data}"
mkdir -p "$DATA"/{models,input,output,user}
if [ -z "$(ls -A "$DATA/models")" ]; then cp -a /opt/ComfyUI/models/. "$DATA/models/"; fi
for d in models input output user; do
  rm -rf "/opt/ComfyUI/$d"; ln -s "$DATA/$d" "/opt/ComfyUI/$d"
done

# SSH (optional): set PUBLIC_KEY in the template
if [ -n "$PUBLIC_KEY" ]; then
  mkdir -p ~/.ssh && echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
  chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && service ssh start
fi

# Jupyter (random token if you don't set one)
JUPYTER_PASSWORD="${JUPYTER_PASSWORD:-$(openssl rand -hex 16)}"
echo "Jupyter token: $JUPYTER_PASSWORD"
/opt/jupyter/bin/jupyter lab --allow-root --no-browser --ip=0.0.0.0 --port=8888 \
  --ServerApp.token="$JUPYTER_PASSWORD" --ServerApp.allow_origin='*' \
  --ServerApp.root_dir=/workspace &

# File Browser (password must be 12+ characters)
FB_DB=/workspace/.filebrowser.db
FB_PASS="${FILEBROWSER_PASSWORD:-$(openssl rand -hex 8)}"
if [ ! -f "$FB_DB" ]; then
  filebrowser config init -d "$FB_DB"
  filebrowser users add admin "$FB_PASS" --perm.admin -d "$FB_DB"
  echo "File Browser login: admin / $FB_PASS"
fi
filebrowser -r /workspace -a 0.0.0.0 -p 8080 -d "$FB_DB" &

cd /opt/ComfyUI
exec python main.py --listen 0.0.0.0 --port 8188 --enable-cors-header --enable-manager $COMFY_ARGS
