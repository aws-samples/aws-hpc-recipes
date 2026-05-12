#!/bin/bash
# install-relion.sh — Relion installation script for PCS DCV workstation
#
# Installs Relion and its dependencies on a shared filesystem using system
# packages for all runtime libraries and building Relion from source.
#
# Usage: sudo ./install-relion.sh [OPTIONS]
#
# Exit codes:
#   0 = success
#   1 = dependency/environment failure (package install failed, CUDA not found)
#   2 = build failure (clone, cmake, make)

set -euo pipefail

###############################################################################
# Defaults
###############################################################################
INSTALL_DIR="/shared/relion"
RELION_VERSION="ver5.0"
CUDA_ARCH=""
JOBS="$(nproc)"
CURRENT_PHASE=""

###############################################################################
# Usage
###############################################################################
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Install Relion with GPU/MPI support on a shared filesystem.

Options:
  --install-dir DIR       Relion installation directory (default: /shared/relion)
  --relion-version TAG    Git branch/tag to checkout (default: ver5.0)
  --cuda-arch ARCH        CUDA compute capability (default: auto-detect from nvidia-smi)
  --jobs N                Parallel build jobs (default: \$(nproc))
  -h, --help              Show this help message

CUDA architecture values by instance type:
  g4dn (T4):   75
  g5 (A10G):   86
  g6 (L4):     89

Examples:
  sudo ./install-relion.sh
  sudo ./install-relion.sh --cuda-arch 75 --relion-version ver5.0
  sudo ./install-relion.sh --install-dir /opt/relion --jobs 8
EOF
    exit 0
}

###############################################################################
# CLI Argument Parsing
###############################################################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir)
            INSTALL_DIR="$2"
            shift 2
            ;;
        --relion-version)
            RELION_VERSION="$2"
            shift 2
            ;;
        --cuda-arch)
            CUDA_ARCH="$2"
            shift 2
            ;;
        --jobs)
            JOBS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "ERROR: Unknown option: $1"
            usage
            ;;
    esac
done

###############################################################################
# EXIT Trap — cleanup on failure
###############################################################################
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "=========================================="
        echo "ERROR: Installation failed during: ${CURRENT_PHASE:-unknown phase}"
        echo "Exit code: ${exit_code}"
        echo "=========================================="
        echo ""
        echo "Check the output above for details."
        if [[ -d "${INSTALL_DIR}/build" ]]; then
            echo "Build directory preserved at: ${INSTALL_DIR}/build"
        fi
    fi
}
trap cleanup EXIT

###############################################################################
# Phase 1/5: Install system dependencies
###############################################################################
CURRENT_PHASE="Phase 1/5: Installing system dependencies"
echo "${CURRENT_PHASE}..."

# Detect package manager
if command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
else
    echo "ERROR: Neither dnf nor yum found. Cannot install system packages."
    exit 1
fi

# Install all build and runtime dependencies via system packages
echo "  Installing build tools and libraries..."
$PKG_MGR install -y \
    gcc gcc-c++ gcc-gfortran \
    cmake3 git \
    openmpi openmpi-devel \
    fftw-devel fftw-libs-single fftw-libs-double \
    libtiff-devel libpng-devel libjpeg-turbo-devel \
    libX11-devel libXft-devel \
    2>&1 | tail -5

# Ensure cmake3 is available as 'cmake' if needed
if ! command -v cmake &>/dev/null && command -v cmake3 &>/dev/null; then
    ln -sf "$(command -v cmake3)" /usr/local/bin/cmake
fi

# Load OpenMPI into environment
if [[ -d /usr/lib64/openmpi/bin ]]; then
    export PATH="/usr/lib64/openmpi/bin:${PATH}"
    export LD_LIBRARY_PATH="/usr/lib64/openmpi/lib:${LD_LIBRARY_PATH:-}"
fi

echo "  System dependencies installed."

###############################################################################
# Phase 2/5: Clone Relion
###############################################################################
CURRENT_PHASE="Phase 2/5: Cloning Relion repository"
echo "${CURRENT_PHASE}..."

RELION_SRC="${INSTALL_DIR}/src"
mkdir -p "${RELION_SRC}"

if [[ -d "${RELION_SRC}/relion" ]]; then
    echo "  Removing existing Relion source directory..."
    rm -rf "${RELION_SRC}/relion"
fi

if ! git clone --branch "${RELION_VERSION}" --depth 1 \
    https://github.com/3dem/relion.git "${RELION_SRC}/relion"; then
    echo "ERROR: Failed to clone Relion repository."
    echo ""
    echo "Verify:"
    echo "  - Network connectivity to github.com"
    echo "  - Branch/tag '${RELION_VERSION}' exists at https://github.com/3dem/relion"
    exit 2
fi
echo "  Relion source cloned (branch: ${RELION_VERSION})."

###############################################################################
# Phase 3/5: Configure with cmake
###############################################################################
CURRENT_PHASE="Phase 3/5: Configuring Relion with cmake"
echo "${CURRENT_PHASE}..."

# Auto-detect CUDA compute capability from GPU if not specified
if [[ -z "${CUDA_ARCH}" ]]; then
    if command -v nvidia-smi &>/dev/null; then
        CUDA_ARCH=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | tr -d '.')
        echo "  Auto-detected CUDA architecture: ${CUDA_ARCH}"
    else
        echo "ERROR: Cannot auto-detect CUDA architecture (nvidia-smi not found)."
        echo "Please specify --cuda-arch manually (e.g., 89 for L4, 86 for A10G, 75 for T4)."
        exit 2
    fi
fi

# Detect CUDA installation path
CUDA_ROOT=""
if [[ -d "/usr/local/cuda" ]]; then
    CUDA_ROOT="/usr/local/cuda"
fi

if [[ ! -d "${CUDA_ROOT}" ]]; then
    echo "ERROR: CUDA installation not found at /usr/local/cuda."
    echo "Ensure the CUDA toolkit is installed."
    exit 2
fi
echo "  Using CUDA at: ${CUDA_ROOT}"

BUILD_DIR="${INSTALL_DIR}/build"
mkdir -p "${BUILD_DIR}"

if ! cmake \
    -S "${RELION_SRC}/relion" \
    -B "${BUILD_DIR}" \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCUDA_TOOLKIT_ROOT_DIR="${CUDA_ROOT}" \
    -DCUDA_ARCH="${CUDA_ARCH}" \
    -DGUI=ON \
    -DFORCE_OWN_FLTK=ON; then
    echo "ERROR: cmake configuration failed."
    echo ""
    echo "Check the cmake output above for details."
    exit 2
fi
echo "  Relion configured successfully."

###############################################################################
# Phase 4/5: Build and install
###############################################################################
CURRENT_PHASE="Phase 4/5: Building and installing Relion"
echo "${CURRENT_PHASE}..."
echo "  Building with ${JOBS} parallel jobs (this may take 20-40 minutes)..."

if ! make -C "${BUILD_DIR}" -j "${JOBS}"; then
    echo "ERROR: Relion build failed."
    echo ""
    echo "Common causes:"
    echo "  - Insufficient disk space (need ~5 GB free)"
    echo "  - Insufficient memory (try reducing --jobs)"
    echo "  - Missing dependencies"
    echo "Build directory: ${BUILD_DIR}"
    exit 2
fi

if ! make -C "${BUILD_DIR}" install; then
    echo "ERROR: Relion installation failed."
    echo "Build directory: ${BUILD_DIR}"
    exit 2
fi
echo "  Relion installed to: ${INSTALL_DIR}"

###############################################################################
# Phase 5/5: Create profile script
###############################################################################
CURRENT_PHASE="Phase 5/5: Creating profile script"
echo "${CURRENT_PHASE}..."

cat > /etc/profile.d/relion.sh <<'PROFILE'
# Relion environment setup — installed by install-relion.sh

# Add Relion binaries to PATH
export PATH="/shared/relion/bin:${PATH}"
export LD_LIBRARY_PATH="/shared/relion/lib:${LD_LIBRARY_PATH:-}"

# Add system OpenMPI to PATH
if [[ -d /usr/lib64/openmpi/bin ]]; then
    export PATH="/usr/lib64/openmpi/bin:${PATH}"
    export LD_LIBRARY_PATH="/usr/lib64/openmpi/lib:${LD_LIBRARY_PATH:-}"
fi

# Ensure PCS Slurm binaries take priority
if [[ -d /opt/aws/pcs/scheduler ]]; then
    PCS_SLURM_DIR=$(ls -d /opt/aws/pcs/scheduler/slurm-* 2>/dev/null | sort -V | tail -1)
    if [[ -n "${PCS_SLURM_DIR}" ]]; then
        export PATH="${PCS_SLURM_DIR}/bin:${PATH}"
    fi
fi
PROFILE

chmod 644 /etc/profile.d/relion.sh
echo "  Profile script created at /etc/profile.d/relion.sh"

###############################################################################
# Done
###############################################################################
CURRENT_PHASE=""
echo ""
echo "=========================================="
echo "Relion installation complete!"
echo "=========================================="
echo ""
echo "Installation directory: ${INSTALL_DIR}"
echo "Relion version/branch: ${RELION_VERSION}"
echo "CUDA architecture:     ${CUDA_ARCH}"
echo ""
echo "To use Relion, either:"
echo "  - Start a new shell session (profile.d script will set PATH)"
echo "  - Or run: source /etc/profile.d/relion.sh"
echo ""
echo "Launch the Relion GUI with: relion"
echo ""
echo "NOTE: For multi-node MPI jobs at scale with EFA networking,"
echo "consider installing the AWS EFA software and using"
echo "/opt/amazon/openmpi/ instead of system OpenMPI."
echo "See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/efa-start.html"
