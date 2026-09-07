#!/bin/bash
set -euo pipefail
runtime_root="$1"
mkdir -p "$runtime_root"
export UV_PYTHON_INSTALL_DIR="$runtime_root/python"
export UV_CACHE_DIR="$runtime_root/cache"
export UV_TOOL_DIR="$runtime_root/tools"
export MEM0_TELEMETRY=false
uv_bin="$runtime_root/uv-aarch64-apple-darwin/uv"
if [ ! -x "$uv_bin" ]; then
    /usr/bin/curl --fail --location --silent --show-error https://github.com/astral-sh/uv/releases/download/0.8.22/uv-aarch64-apple-darwin.tar.gz -o "$runtime_root/uv.tar.gz"
    (cd "$runtime_root" && printf '%s  uv.tar.gz\n' '3f61099e261e449527141dbf125629fab33ad696468c8c90cebbac40185a306c' | /usr/bin/shasum -a 256 -c -)
    /usr/bin/tar -xzf "$runtime_root/uv.tar.gz" -C "$runtime_root"
fi
if [ ! -x "$runtime_root/venv/bin/python" ]; then "$uv_bin" venv --python-preference only-managed --python 3.11 "$runtime_root/venv"; fi
"$uv_bin" pip install --python "$runtime_root/venv/bin/python" 'mem0ai==1.0.1' 'fastembed==0.7.4' 'https://github.com/oraios/serena/archive/13ac8c5b1d51873bd148aea440dcb22f85d3a439.zip'
if [ ! -x "$runtime_root/opencode" ]; then
    /usr/bin/curl --fail --location --silent --show-error https://github.com/anomalyco/opencode/releases/download/v1.18.21/opencode-darwin-arm64.zip -o "$runtime_root/opencode.zip"
    (cd "$runtime_root" && printf '%s  opencode.zip\n' '72f4b6029af185eb030995cfa062d038914e3142c9aa38f714fe56448e6e87d2' | /usr/bin/shasum -a 256 -c -)
    /usr/bin/unzip -oq "$runtime_root/opencode.zip" -d "$runtime_root"
fi
chmod +x "$runtime_root/opencode"
"$uv_bin" pip freeze --python "$runtime_root/venv/bin/python" > "$runtime_root/requirements.lock"
printf 'Local tools ready.\n'
