#!/bin/bash
# install-relion.sh — Spack-based Relion installation script
#
# Installs Relion and its dependencies on a shared filesystem using Spack
# for dependency management and building Relion from source.
#
# Usage: sudo ./install-relion.sh [OPTIONS]
#
# Exit codes:
#   0 = success
#   1 = dependency/environment failure (Spack not found, package install failed)
#   2 = build failure (clone, cmake, make)

set -euo pipefail

###############################################################################
# Defaults
###############################################################################
SPACK_PREFIX="/shared"
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

Install Relion with GPU/MPI support using Spack for dependency management.

Options:
  --spack-prefix DIR      Spack installation prefix (default: /shared)
  --install-dir DIR       Relion installation directory (default: /shared/relion)
  --relion-version TAG    Git branch/tag to checkout (default: ver5.0)
  --cuda-arch ARCH        CUDA compute capability (default: auto-detect from nvidia-smi)
  --jobs N                Parallel build jobs (default: \$(nproc))
  -h, --help              Show this help message

Examples:
  sudo ./install-relion.sh
  sudo ./install-relion.sh --cuda-arch 89 --relion-version ver5.0
  sudo ./install-relion.sh --spack-prefix /opt/spack --install-dir /opt/relion
EOF
    exit 0
}

###############################################################################
# CLI Argument Parsing
###############################################################################
while [[ $# -gt 0 ]]; do
    case "$1" in
        --spack-prefix)
            SPACK_PREFIX="$2"
            shift 2
            ;;
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
# Phase 1/7: Verify Spack installation and system prerequisites
###############################################################################
CURRENT_PHASE="Phase 1/7: Verifying Spack installation and system prerequisites"
echo "${CURRENT_PHASE}..."

# Install Fortran compiler (required by OpenMPI)
if ! command -v gfortran &>/dev/null; then
    echo "  Installing gcc-gfortran (required by OpenMPI)..."
    if command -v dnf &>/dev/null; then
        dnf install -y gcc-gfortran >/dev/null 2>&1
    else
        yum install -y gcc-gfortran >/dev/null 2>&1
    fi
fi

SPACK_SETUP="${SPACK_PREFIX}/spack/share/spack/setup-env.sh"
if [[ ! -f "${SPACK_SETUP}" ]]; then
    echo "ERROR: Spack not found at ${SPACK_SETUP}"
    echo ""
    echo "Spack must be installed before running this script."
    echo "Use the pcs/spack_for_pcs recipe to install Spack:"
    echo "  https://github.com/aws-samples/aws-hpc-recipes/tree/main/recipes/pcs/spack_for_pcs"
    exit 1
fi
echo "  Spack found at: ${SPACK_SETUP}"

# Ensure Spack detects the Fortran compiler
# shellcheck disable=SC1090
source "${SPACK_SETUP}"
spack compiler find >/dev/null 2>&1

###############################################################################
# Phase 2/7: Install dependencies via Spack
###############################################################################
CURRENT_PHASE="Phase 2/7: Installing Spack dependencies"
echo "${CURRENT_PHASE}..."

# shellcheck source=/dev/null
source "${SPACK_SETUP}"

SPACK_PACKAGES=(openmpi fftw cmake libtiff libpng)
for pkg in "${SPACK_PACKAGES[@]}"; do
    echo "  Installing ${pkg}..."
    if ! spack install "${pkg}"; then
        echo "ERROR: Failed to install Spack package: ${pkg}"
        echo ""
        echo "Try running with verbose output for more details:"
        echo "  spack install --verbose ${pkg}"
        exit 1
    fi
done
echo "  All Spack dependencies installed successfully."

###############################################################################
# Phase 3/7: Load Spack dependencies
###############################################################################
CURRENT_PHASE="Phase 3/7: Loading Spack dependencies"
echo "${CURRENT_PHASE}..."

for pkg in "${SPACK_PACKAGES[@]}"; do
    echo "  Loading ${pkg}..."
    spack load "${pkg}"
done
echo "  All dependencies loaded into environment."

###############################################################################
# Phase 4/7: Clone Relion
###############################################################################
CURRENT_PHASE="Phase 4/7: Cloning Relion repository"
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
# Phase 5/7: Configure with cmake
###############################################################################
CURRENT_PHASE="Phase 5/7: Configuring Relion with cmake"
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
elif command -v nvidia-smi &>/dev/null; then
    # Try to find CUDA from nvidia-smi driver path
    CUDA_ROOT=$(dirname "$(dirname "$(command -v nvidia-smi)")")/cuda
    if [[ ! -d "${CUDA_ROOT}" ]]; then
        CUDA_ROOT="/usr/local/cuda"
    fi
fi

if [[ ! -d "${CUDA_ROOT}" ]]; then
    echo "ERROR: CUDA installation not found."
    echo "Expected at /usr/local/cuda or detected via nvidia-smi."
    echo "Ensure the GPU drivers and CUDA toolkit are installed."
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
    echo "Verify that Spack-provided libraries are loaded (openmpi, fftw, cmake, libtiff, libpng)."
    exit 2
fi
echo "  Relion configured successfully."

###############################################################################
# Phase 6/7: Build and install
###############################################################################
CURRENT_PHASE="Phase 6/7: Building and installing Relion"
echo "${CURRENT_PHASE}..."
echo "  Building with ${JOBS} parallel jobs..."

if ! make -C "${BUILD_DIR}" -j "${JOBS}"; then
    echo "ERROR: Relion build failed."
    echo ""
    echo "Common causes:"
    echo "  - Insufficient disk space"
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
# Phase 7/7: Create profile script
###############################################################################
CURRENT_PHASE="Phase 7/7: Creating profile script"
echo "${CURRENT_PHASE}..."

cat > /etc/profile.d/relion.sh <<PROFILE
# Relion environment setup — installed by install-relion.sh
export PATH="${INSTALL_DIR}/bin:\${PATH}"
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib:\${LD_LIBRARY_PATH:-}"
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
