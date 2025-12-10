#!/usr/bin/env bash

set -euo pipefail

# Define environment name
ENV_NAME="NavRL"

# Version pins for the upgraded toolchain
TORCH_VERSION=${TORCH_VERSION:-2.7.0}
ISAAC_SIM_VERSION=${ISAAC_SIM_VERSION:-5.0.0}
ISAAC_LAB_VERSION=${ISAAC_LAB_VERSION:-2.3.0}

# Location of the installed Isaac Sim 5.0 and Isaac Lab 2.3 checkout
ISAACSIM_PATH=${ISAACSIM_PATH:-"$HOME/.local/share/ov/pkg/isaac-sim-${ISAAC_SIM_VERSION}"}
ISAACLAB_PATH=${ISAACLAB_PATH:-"$HOME/IsaacLab"}

if [ ! -d "$ISAACSIM_PATH" ]; then
    echo "Isaac Sim ${ISAAC_SIM_VERSION} not found at '$ISAACSIM_PATH'."
    echo "Please install Isaac Sim 5.0 and set ISAACSIM_PATH before running this script."
    exit 1
fi

if [ ! -d "$ISAACLAB_PATH" ]; then
    echo "Isaac Lab ${ISAAC_LAB_VERSION} checkout not found at '$ISAACLAB_PATH'."
    echo "Clone the Isaac Lab 2.3 repo (or adjust ISAACLAB_PATH) before running this script."
    exit 1
fi

# Load Conda environment handling
eval "$(conda shell.bash hook)"

echo "Creating conda env ${ENV_NAME} for Isaac Sim ${ISAAC_SIM_VERSION} / Isaac Lab ${ISAAC_LAB_VERSION}..."
conda create -y -n $ENV_NAME python=3.10 -c conda-forge
conda activate $ENV_NAME

pip install --upgrade pip
pip install "torch==${TORCH_VERSION}" "torchvision==${TORCH_VERSION}" "torchaudio==${TORCH_VERSION}"
pip install numpy==1.26.4 hydra-core einops pyyaml rospkg matplotlib
pip install imageio-ffmpeg==0.4.9 moviepy==1.0.3
pip install "pydantic!=1.7,!=1.7.1,!=1.7.2,!=1.7.3,!=1.8,!=1.8.1,<2.0.0,>=1.6.2"

# Expose Isaac Sim and Isaac Lab to the environment
export ISAACSIM_PATH
export ISAACLAB_PATH
export PYTHONPATH="${ISAACSIM_PATH}/python:${ISAACSIM_PATH}/exts:${ISAACLAB_PATH}:${PYTHONPATH:-}"
export LD_LIBRARY_PATH="${ISAACSIM_PATH}:${LD_LIBRARY_PATH:-}"

# If the Isaac Lab helper exists, use it to register the extension into the env
if [ -x "${ISAACLAB_PATH}/isaaclab.sh" ]; then
    echo "Registering Isaac Lab ${ISAAC_LAB_VERSION}..."
    "${ISAACLAB_PATH}/isaaclab.sh" --conda $ENV_NAME --skip-kit-install || true
elif [ -f "${ISAACLAB_PATH}/setup.py" ] || [ -f "${ISAACLAB_PATH}/pyproject.toml" ]; then
    echo "Installing Isaac Lab from source checkout at ${ISAACLAB_PATH}..."
    pip install -e "${ISAACLAB_PATH}"
fi

python - <<'PY'
import importlib
import sys

for module in ("omni.isaac.core", "omni.isaac.lab"):
    try:
        importlib.import_module(module)
    except Exception as exc:  # pragma: no cover - environment check
        sys.exit(f"Failed to import {module}: {exc}")

print("Isaac Sim/Lab imports verified")
PY

echo "Setup completed successfully!"

