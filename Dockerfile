FROM nvidia/cuda:13.0.0-cudnn-runtime-ubuntu24.04

ARG COMFY_VERSION=v0.38.0
ENV DEBIAN_FRONTEND=noninteractive PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 python3-venv python3-dev git curl ca-certificates ffmpeg \
      build-essential libgl1 libglib2.0-0 openssh-server rsync nano openssl \
 && rm -rf /var/lib/apt/lists/*

# ComfyUI environment (torch built for CUDA 13.0)
RUN python3 -m venv /opt/venv
ENV PATH=/opt/venv/bin:$PATH
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir torch torchvision torchaudio \
      --index-url https://download.pytorch.org/whl/cu130

RUN git clone --branch ${COMFY_VERSION} --depth 1 \
      https://github.com/Comfy-Org/ComfyUI.git /opt/ComfyUI \
 && pip install --no-cache-dir -r /opt/ComfyUI/requirements.txt
RUN pip install --no-cache-dir -U --pre comfyui-manager

# Custom nodes (examples; add yours, ideally pinned to a tag or commit).
# The constraint file stops node requirements from replacing torch.
WORKDIR /opt/ComfyUI/custom_nodes
RUN pip freeze | grep -E '^(torch|torchvision|torchaudio)==' > /tmp/torch-constraint.txt \
 && git clone https://github.com/ltdrdata/ComfyUI-Manager \
 && git clone https://github.com/Lightricks/ComfyUI-LTXVideo \
 && git clone https://github.com/kijai/ComfyUI-KJNodes \
 && git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite \
 && git clone https://github.com/rgthree/rgthree-comfy \
 && git clone https://github.com/yolain/ComfyUI-Easy-Use \
 && git clone https://github.com/warfy5/ComfyUI-RandomNumbers ComfyUI-RandomNumber \
 && git clone https://github.com/hlibr/ComfyUI-GGUF-Prompt-Rewriter \
 && git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts \
&& git clone https://github.com/M1kep/ComfyLiterals \
 && for d in */; do [ -f "$d/requirements.txt" ] && pip install --no-cache-dir -r "$d/requirements.txt" -c /tmp/torch-constraint.txt; done; true

# JupyterLab in its own venv, File Browser as a single binary
RUN python3 -m venv /opt/jupyter && /opt/jupyter/bin/pip install --no-cache-dir jupyterlab
RUN curl -fsSL https://raw.githubusercontent.com/filebrowser/get/master/get.sh | bash

COPY start.sh /start.sh
RUN chmod +x /start.sh
WORKDIR /workspace
EXPOSE 8188 8888 8080 22
CMD ["/start.sh"]
