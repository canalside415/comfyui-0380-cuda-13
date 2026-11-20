FROM nvidia/cuda:13.0.0-cudnn-runtime-ubuntu24.04

ARG COMFY_VERSION=v0.45.3

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    SHELL=/bin/bash


# -------------------------------------------------------------------
# Base system packages
# -------------------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 \
      python3-venv \
      python3-dev \
      git \
      curl \
      ca-certificates \
      ffmpeg \
      build-essential \
      libgl1 \
      libglib2.0-0 \
      rsync \
      nano \
      openssl \
      zstd \
 && rm -rf /var/lib/apt/lists/*


# -------------------------------------------------------------------
# Node.js 22 LTS
# -------------------------------------------------------------------

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y nodejs \
 && rm -rf /var/lib/apt/lists/* \
 && node -v \
 && npm -v


# -------------------------------------------------------------------
# Ollama
#
# Ollama is installed here but started by start.sh.
#
# OLLAMA_HOST allows RunPod's HTTP proxy to reach the API.
# Models are stored on the persistent /workspace volume.
# -------------------------------------------------------------------

RUN curl -fsSL https://ollama.com/install.sh | sh \
 && ollama --version

ENV OLLAMA_HOST=0.0.0.0:11434 \
    OLLAMA_MODELS=/workspace/ollama/models


# -------------------------------------------------------------------
# ComfyUI Python environment
# -------------------------------------------------------------------

RUN python3 -m venv /opt/venv

ENV PATH=/opt/venv/bin:$PATH

RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir \
      torch \
      torchvision \
      torchaudio \
      --index-url https://download.pytorch.org/whl/cu130


# -------------------------------------------------------------------
# ComfyUI
# -------------------------------------------------------------------

RUN git clone \
      --branch ${COMFY_VERSION} \
      --depth 1 \
      https://github.com/Comfy-Org/ComfyUI.git \
      /opt/ComfyUI \
 && pip install --no-cache-dir \
      -r /opt/ComfyUI/requirements.txt

RUN pip install --no-cache-dir -U --pre comfyui-manager


# -------------------------------------------------------------------
# ComfyUI custom nodes
#
# Torch constraint prevents custom-node requirements from replacing
# the CUDA 13 PyTorch installation.
# -------------------------------------------------------------------

WORKDIR /opt/ComfyUI/custom_nodes

RUN pip freeze | grep -E '^(torch|torchvision|torchaudio)==' \
      > /tmp/torch-constraint.txt \
 && git clone https://github.com/Lightricks/ComfyUI-LTXVideo \
 && git clone https://github.com/kijai/ComfyUI-KJNodes \
 && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
 && git clone https://github.com/rgthree/rgthree-comfy \
 && git clone https://github.com/yolain/ComfyUI-Easy-Use \
 && git clone \
      https://github.com/warfy5/ComfyUI-RandomNumbers \
      ComfyUI-RandomNumber \
 && git clone https://github.com/hlibr/ComfyUI-GGUF-Prompt-Rewriter \
 && git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts \
 && git clone https://github.com/M1kep/ComfyLiterals

RUN for d in */; do \
      if [ -f "$d/requirements.txt" ]; then \
        pip install \
          --no-cache-dir \
          -r "$d/requirements.txt" \
          -c /tmp/torch-constraint.txt; \
      fi; \
    done; \
    true


# -------------------------------------------------------------------
# JupyterLab
# -------------------------------------------------------------------

RUN python3 -m venv /opt/jupyter \
 && /opt/jupyter/bin/pip install \
      --no-cache-dir \
      jupyterlab


# -------------------------------------------------------------------
# File Browser
# -------------------------------------------------------------------

RUN curl -fsSL \
      https://raw.githubusercontent.com/filebrowser/get/master/get.sh \
      | bash


# -------------------------------------------------------------------
# Interactive shell convenience
# -------------------------------------------------------------------

RUN echo 'source /opt/venv/bin/activate' >> /root/.bashrc


# -------------------------------------------------------------------
# Startup
# -------------------------------------------------------------------

COPY start.sh /start.sh

RUN chmod +x /start.sh

WORKDIR /workspace


# -------------------------------------------------------------------
# HTTP services
#
# 8080  FileBrowser
# 8188  ComfyUI
# 8888  JupyterLab
# 11434 Ollama API
#
# No SillyTavern.
# No SSH server.
# -------------------------------------------------------------------

EXPOSE 8080 8188 8888 11434


CMD ["/start.sh"]
