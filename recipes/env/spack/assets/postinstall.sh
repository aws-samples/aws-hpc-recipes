#!/bin/bash
set -euo posix

##############################################################################################
# # This script will setup Spack and best practices for a few applications.                  #
# # Use as postinstall in AWS ParallelCluster (https://docs.aws.amazon.com/parallelcluster/) #
##############################################################################################

print_help() {
    cat <<EOF
Usage: postinstall.sh [-fg] [-v] [spec] [spec...]

Installs spack on a parallel cluster with recommended configurations.
Spack directory is cloned into a shared directory and recommended packages are
configured.

As the install can take more than an hour (especially on smaller instances), the
default is to run the script in the background so that it can be used as
pcluster's postinstall CloudFormation script without timing out during cluster
initialization.  Output can be monitored in /var/log/spack-postinstall.log

Options:
 -h|--help              Print this help message.
 -fg                    Run in foreground, without logs, blocking until
                        complete.
                        Ensure ssh connection is stable.
 -v                     Be verbose during execution
 --[no-]buildcache      Use the generic target buildcache provided by the
                        aws-pcluster-[x86_64_v4,neoverse_v1] stacks. Enabled by
                        default for Amazon Linux2, disabled for other OSs.
 --no-arm-compiler      Don't install ARM compilers (ACFL)
 --no-intel-compiler    Don't install Intel compilers
 --prefix <path>        This script will install Spack into the first shared drive
                        found on ParallelCluster or $HOME if no shared drive can be
                        found. Override the location with <path>.
 [spec]                 "spec" to be installed after initial
                        configuration: e.g., gcc@12.3.0 or "gcc @ 13.0".
                        Multiple specs can be listed, but they need to either
                        be quoted or contain no spaces.

Developer Options:
 --config-branch        Pull configuration (e.g., packages.yaml) from this
                        branch.  Default is "main".
 --config-repo          Pull configuration (e.g., packages.yaml) from this
                        github user/repo.  Default is "spack/spack-configs".
 --spack-branch         Clone spack using this branch.  Default is "v0.23.1"
 --spack-repo           Clone spack using this github user/repo. Default is
                        "spack/spack".
EOF
}

# By default we run in the background.  Accomplish this by calling ourselves
# with all the same args and adding -fg and nohup-ing the new process.
install_in_foreground=no
BG_ARGS=()
for ARG in "${@}"; do
    # Main argument processing loop is below.
    # This one only cares about -h and -fg
    case $ARG in
        -h|--help )
            print_help
            exit 0
            ;;
        -fg|--foreground )
            install_in_foreground=yes
            ;;
        *)
            BG_ARGS+=("$ARG")
            ;;
    esac
done

if [ $install_in_foreground == "no" ]; then
    echo "Continuing in background.  Watch /var/log/spack-postinstall.log"
    nohup bash $(realpath $0) -fg "${BG_ARGS[@]:-}" &> /var/log/spack-postinstall.log &
    disown -a
    exit 0
fi


# CONFIG_REPO: a the user/repo on github to use for configuration.a custom user/repo/branch in case users wish to
# provide or test their own configurations.
export CONFIG_REPO="spack/spack-configs"
export CONFIG_BRANCH="main"
export SPACK_REPO="spack/spack"
export SPACK_BRANCH="v0.23.1"
export PREFIX=""
install_specs=()
export generic_buildcache=""
export EXTERNAL_SPACK="false"

NO_INTEL_COMPILER=""
NO_ARM_COMPILER=""
install_path=""
default_user=""

# These variables can be overriden from the environment:
export SPACK_ROOT="${SPACK_ROOT:-}"
SLURM_ROOT="${SLURM_ROOT:-}"
SLURM_VERSION="${SLURM_VERSION:-}"
LIBFABRIC_ROOT="${LIBFABRIC_ROOT:-}"
LIBFABRIC_VERSION="${LIBFABRIC_VERSION:-}"

# undocumented
spack_commit="${spack_commit:-}"


while [ $# -gt 0 ]; do
    case $1 in
        --buildcache )
            generic_buildcache=true
            ;;
        --config-branch )
            CONFIG_BRANCH="$2"
            shift
            ;;
        --config-repo )
            CONFIG_REPO="$2"
            shift
            ;;
        -fg|--foreground )
            ;;
        -h|--help )
            print_help
            exit 0
            ;;
        --no-arm-compiler )
            export NO_ARM_COMPILER=1
            ;;
        --no-buildcache )
            generic_buildcache=false
            ;;
        --no-intel-compiler )
            export NO_INTEL_COMPILER=1
            ;;
        --prefix )
            PREFIX="$2"
            shift
            ;;
        --spack-branch )
            SPACK_BRANCH="$2"
            shift
            ;;
        --spack-repo )
            SPACK_REPO="$2"
            shift
            ;;
        -v )
            set -v
            ;;
        -* )
            print_help
            echo
            echo "ERROR: Unknown option: $1"
            exit 1
            ;;
        * )
            echo "Going to install: $1"
            install_specs+=("${1}")
            ;;
    esac
    shift
done

download_yq() {
    if [ "x86_64" == "$(arch)" ]; then
        ext="amd64"
        md5sum="b94ae33c93edce5b8ca5b3034bd78049"
    elif [ "aarch64" == "$(arch)" ]; then
        ext="arm64"
        md5sum="0434fe534ea262510c0122a3ccf2c60f"
    fi
    tmpdir="$(mktemp -d)"
    curl -sL "https://github.com/mikefarah/yq/releases/download/v4.44.5/yq_linux_${ext}" -o $tmpdir/yq
    if [ "$(md5sum ${tmpdir}/yq | cut -d' ' -f1)" != "${md5sum}" ]; then
        echo "Could not verify yq."
        exit 1
    else
        chmod +x ${tmpdir}/yq
        PATH="${tmpdir}:$PATH"
    fi
}

install_os_dependencies() {
    # if user isn't starting with parallel cluster, make sure a few required
    # packages are installed.
    [ -f /etc/os-release ] && . /etc/os-release
    case "$ID" in
        amzn|rhel|centos|rocky)
            yum install -y git gcc-c++ make cmake unzip
            yum install -y --allowerasing gnupg2 || yum install -y gnupg2
            ;;
        ubuntu)
            apt-get update
            apt-get install -y git g++ make cmake unzip
            ;;
        *)
            echo "Operating system ${ID} not recognized. Could not automatically install system prerequisites."
            echo "Attempting to continue anyways."
            ;;
    esac
}

setup_variables() {
    # Determine default user
    [ -f /etc/os-release ] && . /etc/os-release
    case "$ID" in
        amzn|rhel)
            default_user="ec2-user"
            ;;
        centos|ubuntu|rocky)
            default_user="${ID}"
            ;;
        *)
            default_user=""
            ;;
    esac

    # Install onto first shared storage device
    cluster_config="/opt/parallelcluster/shared/cluster-config.yaml"
    if [ -f "${cluster_config}" ]; then
        cfn_ebs_shared_dirs=$(yq ".SharedStorage[0].MountDir" $cluster_config)
        scheduler=$(yq ".Scheduling.Scheduler" $cluster_config)
    elif [ -f /etc/parallelcluster/cfnconfig ]; then
        . /etc/parallelcluster/cfnconfig
    else
        echo "Cannot find ParallelCluster configs"
        cfn_ebs_shared_dirs=""
        scheduler=""
    fi

    # If no shared drives are configured, try finding a Lustre, then an EFS
    [ -z "${cfn_ebs_shared_dirs}" ] && cfn_ebs_shared_dirs="$(mount -t lustre | cut -d\  -f 3 | head -n1)"
    [ -z "${cfn_ebs_shared_dirs}" ] && cfn_ebs_shared_dirs="$(mount -t efs | cut -d\  -f 3 | head -n1)"

    # If we cannot find any shared directory, use default_user's $HOME
    [ -z "${cfn_ebs_shared_dirs}" ] && cfn_ebs_shared_dirs=$(awk -F: '/'"${default_user}"'/{print $6}' /etc/passwd)

    # Override install location with PREFIX if set
    cfn_ebs_shared_dirs="${PREFIX:-${cfn_ebs_shared_dirs}}"

    # Use external Spack if $SPACK_ROOT is already set
    install_path=${SPACK_ROOT:-"${cfn_ebs_shared_dirs}/spack"}
    tmp_path="$(mktemp -d -p "${cfn_ebs_shared_dirs}")" && export TMPDIR="${tmp_path}"

    echo "Installing Spack into ${install_path}."

    if [ "true" == "${generic_buildcache}" ] && [ "Amazon Linux 2" != "${PRETTY_NAME}" ]; then
        echo "Generic buildcache only tested on Alinux2. You might experience issues with \"modules\" on other OSs. Use \"spack load\" in those cases."
    fi
    if [ -z "${generic_buildcache}" ]; then
        if [ "Amazon Linux 2" == "${PRETTY_NAME}" ]; then
            generic_buildcache=true
        else
            generic_buildcache=false
        fi
    fi
}

major_version() {
    pcluster_version=$(grep -oE '[0-9]*\.[0-9]*\.[0-9]*' /opt/parallelcluster/.bootstrapped)
    echo "${pcluster_version/\.*}"
}

# Make first user owner of Spack installation when script exits.
cleanup() {
    rc=$?
    if ! ${EXTERNAL_SPACK}
    then
        chown -R ${default_user}:${default_user} "${install_path}"
    fi
    [ -d "${tmp_path}" ] && rm -rf "${tmp_path}"
    exit $rc
}

download_spack() {
    if [ -z "${SPACK_ROOT}" ]
    then
        if [ -n "${spack_commit:-}" ]
        then
            echo "Cloning spack commit ${spack_commit} into $install_path"
            git clone -c feature.manyFiles=true "https://github.com/${SPACK_REPO}" "${install_path}"
            cd "${install_path}" && git checkout "${spack_commit}"
        else
            echo "Cloning spack branch ${SPACK_BRANCH} into $install_path"
            git clone -c feature.manyFiles=true "https://github.com/${SPACK_REPO}" -b "${SPACK_BRANCH}" "${install_path}"
        fi
    else
        echo "Using existing spack found in ${SPACK_ROOT}"
    fi
}

# zen3 EC2 instances (e.g. hpc6a) is misidentified as zen2 so zen3 packages are found under packages-zen2.yaml.
target() {
    (
        . "${install_path}/share/spack/setup-env.sh"
        spack arch -t
    )
}

stack_arch() {
    (
        . "${install_path}/share/spack/setup-env.sh"
        case $(arch) in
            aarch64)
                # neoverse_n1 packages also included in neoverse_v1 stack
                spack arch -t | sed -e 's?neoverse_n1?neoverse_v1?g'
                ;;
            x86_64*)
                # x86_64_v3 packages also included in x86_64_v4 stack
                spack arch -g | sed -e 's?x86_64_v3?x86_64_v4?g'
                ;;
        esac
    )
}

download_packages_yaml() {
    # $1: spack target
    . "${install_path}/share/spack/setup-env.sh"
    target="${1}"
    curl -Ls "https://raw.githubusercontent.com/${CONFIG_REPO}/${CONFIG_BRANCH}/AWS/parallelcluster/packages-${target}.yaml" -o /tmp/packages.yaml
    if [ "$(cat /tmp/packages.yaml)" = "404: Not Found" ]; then
        # Pick up parent if current generation is not available
        for target in $(spack-python -c 'print(" ".join(spack.platforms.host().target("'"${target}"'").to_dict()["parents"]))'); do
            if [ -z "${target}" ] ; then
                echo "Cannot find suitable packages.yaml"
                exit 1
            fi
            download_packages_yaml "${target}"
            # Exit loop if found here or in deeper level.
            [ "$(cat /tmp/packages.yaml)" = "404: Not Found" ] || break &>/dev/null
        done
    fi
}

set_modules() {
    mkdir -p "${install_path}/etc/spack"
    curl -Ls "https://raw.githubusercontent.com/${CONFIG_REPO}/${CONFIG_BRANCH}/AWS/parallelcluster/modules.yaml" \
         -o "${install_path}/etc/spack/modules.yaml"
}

set_variables() {
    # Set versions of pre-installed software in packages.yaml
    [ -z "${SLURM_ROOT}" ] && ls /etc/systemd/system/slurm* &>/dev/null && \
        SLURM_ROOT=$(dirname $(dirname "$(awk '/ExecStart=/ {print $1}' /etc/systemd/system/slurm* | sed -e 's?^.*=??1' | head -n1)"))
    # Fallback to default location if SLURM not in systemd
    [ -z "${SLURM_ROOT}" ] && [ -d "/opt/slurm" ] && SLURM_ROOT=/opt/slurm
    if [ -n "${SLURM_ROOT}" ] && [ -z "${SLURM_VERSION}" ]; then
        SLURM_VERSION=$(strings "${SLURM_ROOT}"/lib/libslurm.so | grep -e '^VERSION' | awk '{print $2}' | sed -e 's?"??g')
    fi
    if [ ! -d "${LIBFABRIC_ROOT}" ] && [ -d /opt/amazon/efa/ ]; then
        LIBFABRIC_ROOT=/opt/amazon/efa/
    fi
    if [ -z "${LIBFABRIC_VERSION}" ] && [ -d "${LIBFABRIC_ROOT}" ]; then
        PC_FILE=$(find "${LIBFABRIC_ROOT}" -name libfabric.pc | head -n1)
        if [ -f "$PC_FILE" ]; then
            LIBFABRIC_VERSION=$(awk '/Version:/{print $2}' $PC_FILE | sed -e 's?~??g' -e 's?amzn.*??g')
        fi
    fi
    export SLURM_VERSION SLURM_ROOT LIBFABRIC_VERSION LIBFABRIC_ROOT

    export STACK_DIR="${SPACK_ROOT}/share/spack/gitlab/cloud_pipelines/stacks/aws-pcluster-$(stack_arch)"
    # Turn off generic_buildcache if CI stack does not exist
    # There are two possible places to look for. Either a standalone file packages.yaml or an `packages:` entry in spack.yaml.
    if ! grep -q "packages:" "${STACK_DIR}/spack.yaml" && ! [ -f "${STACK_DIR}/packages.yaml" ]; then
        generic_buildcache=false
        echo "Disabling buildcache.  No stack found for this architecture ($(stack_arch))."
    fi
}

set_pcluster_defaults() {
    # Write the above as actual yaml file and only parse the \$.
    mkdir -p "${install_path}/etc/spack"
    ( download_packages_yaml "$(target)" )

    if [ "$(cat /tmp/packages.yaml)" != "404: Not Found" ]; then
        envsubst < /tmp/packages.yaml > "${install_path}/etc/spack/packages.yaml"
    fi
}

load_spack_at_login() {
    if [ -z "${SPACK_ROOT}" ]
    then
        case "${scheduler}" in
            slurm)
                echo -e "\n# Spack setup from Github repo spack-configs" >> /opt/slurm/etc/slurm.sh
                echo -e "\n# Spack setup from Github repo spack-configs" >> /opt/slurm/etc/slurm.csh
                echo ". ${install_path}/share/spack/setup-env.sh &>/dev/null || true" >> /opt/slurm/etc/slurm.sh
                echo ". ${install_path}/share/spack/setup-env.csh &>/dev/null || true" >> /opt/slurm/etc/slurm.csh
                ;;
            *)
                echo "WARNING: Spack will need to be loaded manually when ssh-ing to compute instances."
                echo ". ${install_path}/share/spack/setup-env.sh" > /etc/profile.d/spack.sh
                echo ". ${install_path}/share/spack/setup-env.csh" > /etc/profile.d/spack.csh
        esac
    fi
}
setup_bootstrap_mirrors() {
    . "${install_path}/share/spack/setup-env.sh"

    # Newer gpg2 versions on Ainux2 will not be able to validate the key. This allows spack to accept the buildcache keys.
    if [ "$(gpg --version | awk '/gpg/{print $3}')" == "2.0.22" ]; then
        mkdir -m 700 -p "${SPACK_ROOT}/opt/spack/gpg"
        echo "openpgp" >> "${SPACK_ROOT}/opt/spack/gpg/gpg.conf"
    fi

    # `gcc@12.4.0` is created as part of building the containers in https://github.com/spack/gitlab-runners
    # and mirrored onto `$bootstrap_gcc_cache`. Since amzn2 has the oldest libc of all OSs supported by Pcluster/PCS
    # we can always use this compiler.
    bootstrap_gcc_cache="https://bootstrap.spack.io/pcluster/amzn2/$(arch)"
    if curl -fIsLo /dev/null "${bootstrap_gcc_cache}/build_cache/index.json"; then
        spack mirror list | grep -q ${bootstrap_gcc_cache} || \
            spack mirror add --scope=site bootstrap-gcc-cache "${bootstrap_gcc_cache}"
        spack buildcache keys -it
    fi
}

setup_pcluster_buildcache_stack() {
    if grep -q "packages:" "${STACK_DIR}/spack.yaml"; then
        # Overwrite all packages in merge-stack-{x86_64_v4,neoverse_v1}.yaml with the build cache entries, but deep merge "all:"
        yq '.spack| with_entries(select(.key | test("packages")))' "${STACK_DIR}/spack.yaml" > "${SPACK_ROOT}"/etc/spack/packages.yaml
        curl -Ls "https://raw.githubusercontent.com/${CONFIG_REPO}/${CONFIG_BRANCH}/AWS/parallelcluster/merge-stack-$(stack_arch).yaml" \
             -o "/tmp/merge.yaml" && \
            yq -i -P eval-all "select(fi == 1) * select(fi == 0) | sort_keys(..) | .packages.all *=+ load(\"/tmp/merge.yaml\").packages.all" \
               "${SPACK_ROOT}"/etc/spack/packages.yaml /tmp/merge.yaml
    else
        cp "${STACK_DIR}/packages.yaml" "${SPACK_ROOT}"/etc/spack/packages.yaml
    fi
    # Patch packages.yaml
    [ -z "${SLURM_VERSION}" ] || yq -i ".packages.slurm.externals[0].spec = \"slurm@${SLURM_VERSION} +pmix\"" "${SPACK_ROOT}"/etc/spack/packages.yaml
    [ ! -d "${SLURM_ROOT}" ] || yq -i ".packages.slurm.externals[0].prefix = \"${SLURM_ROOT}\"" "${SPACK_ROOT}"/etc/spack/packages.yaml
    [ -z "${LIBFABRIC_VERSION}" ] || yq -i ".packages.libfabric.externals[0].spec = \"libfabric@${LIBFABRIC_VERSION}\"" "${SPACK_ROOT}"/etc/spack/packages.yaml
}

remove_missing_packages() {
    if [ -z "${SLURM_ROOT}" -o ! -d "${SLURM_ROOT}" ]; then
        echo "No slurm found, removing from packages.yaml"
        yq -i "del(.packages.slurm)" "${SPACK_ROOT}"/etc/spack/packages.yaml
    fi
    if [ -z "${LIBFABRIC_ROOT}" -o ! -d "${LIBFABRIC_ROOT}" ]; then
        echo "No libfabric found, removing from packages.yaml"
        yq -i "del(.packages.libfabric)" "${SPACK_ROOT}"/etc/spack/packages.yaml
    fi
}

setup_spack() {
    . "${install_path}/share/spack/setup-env.sh"
    spack compiler find --scope site
    # Do not add  autotools/buildtools packages. These versions need to be managed by spack or it will
    # eventually end up in a version mismatch (e.g. when compiling gmp).
    spack external find --scope site --tag core-packages

    # Remove system installed `gcc` if there is no matching `g++`. Missing `gfortran` is OK,
    # since gcc & g++ are sufficient for `spack install gcc@gcc`.
    for compiler in $(spack compiler list | grep -v '-' |grep -v '=>' | xargs); do
        compiler_ok=no
        spack compiler info --scope=site ${compiler} 2>/dev/null | grep -E 'cc =|cxx =' | grep -q " None" || compiler_ok=yes
        if [ "$compiler_ok" == no ]; then
            spack compiler rm --scope=site ${compiler}
        fi
    done
}

patch_compilers_yaml() {
    # Graceful exit if package not found by spack
    set -o pipefail
    compilers_yaml="${SPACK_ROOT}/etc/spack/compilers.yaml"
    [ -f "${compilers_yaml}" ] || {
        echo "Cannot find ${compilers_yaml}, compiler setup might now be optimal."
        return
    }

    # System ld is too old for amzn linux2
    spack_gcc_version=$(spack find --format '{version}' gcc | xargs -n1 | tail -n1)
    binutils_path=$(spack find -p binutils | awk '/binutils/ {print $2}' | head -n1)
    if [ -d "${binutils_path}" ] && [ -n "${spack_gcc_version}" ]; then
        yq -i "(.compilers[] | select(.compiler.spec == \"aocc*\" or .compiler.spec == \"arm*\" or .compiler.spec == \"gcc*${spack_gcc_version}*\" or .compiler.spec == \"intel*\" or .compiler.spec == \"oneapi*\") | .compiler.environment.prepend_path.PATH) = \"${binutils_path}/bin\"" "${compilers_yaml}"
    fi

    # Oneapi needs extra_rpath to gcc libstdc++.so.6
    if oneapi_gcc_version=$(spack find --format '{compiler}' intel-oneapi-compilers 2>/dev/null | sed -e 's/=//g') && \
            [ -n "${oneapi_gcc_version}" ] && oneapi_gcc_path=$(spack find -p "${oneapi_gcc_version}" | grep "${oneapi_gcc_version}" | awk '{print $2}' | head -n1) && \
            [ -d "${oneapi_gcc_path}" ]; then
        yq -i "(.compilers[] | select(.compiler.spec == \"oneapi*\") | .compiler.extra_rpaths) = [\"${oneapi_gcc_path}/lib64\"]" "${compilers_yaml}"
    fi

    # TODO: Who needs this? WRF? gromacs will not build when this is active.
    # Armclang needs to find its own libraries
    if acfl_path=$(spack find -p acfl 2>/dev/null | awk '/acfl/ {print $2}') && \
            [ -d "${acfl_path}" ] && cpp_include_path=$(dirname "$(find "${acfl_path}" -name cassert)") && \
            [ -d "${cpp_include_path}" ]; then
        yq -i "(.compilers[] | select(.compiler.spec == \"arm*\") | .compiler.environment.prepend_path.CPATH) = \"${cpp_include_path}:${cpp_include_path}/aarch64-linux-gnu\"" "${compilers_yaml}"
    fi

    # Armclang needs extra_rpath to libstdc++.so
    # TODO: FYI ACFL installer does this by adding libstdc++.so.6 path to LD_LIBRARY_PATH
    if acfl_path=$(spack find -p acfl 2>/dev/null | awk '/acfl/ {print $2}') && \
            acfl_libstdcpp_path=$(dirname "$(find "${acfl_path}" -name libstdc++.so | head -n1)") && \
            [ -d "${acfl_libstdcpp_path}" ]; then
        yq -i "(.compilers[] | select(.compiler.spec == \"arm*\") | .compiler.extra_rpaths) = [\"${acfl_libstdcpp_path}\"]" "${compilers_yaml}"
    fi
}

install_compilers() {
    if [ -z "${SPACK_ROOT}" ]; then
        if [ -f /opt/slurm/etc/slurm.sh ]; then
            . /opt/slurm/etc/slurm.sh
        else
            . /etc/profile.d/spack.sh
        fi
    fi

    # Compiler needed for all kinds of codes. It makes no sense not to install it.
    mirrors_entry=$(grep -s bootstrap-gcc-cache "$SPACK_ROOT/etc/spack/mirrors.yaml")
    if [ -n "${mirrors_entry}" ]; then
        # Make sure we select the gcc from the cache we just added (temporarily override all mirrors.yaml configuration files):
        tmpdir=$(mktemp -d)
        echo -e "mirrors::\n${mirrors_entry}" > "${tmpdir}/mirrors.yaml"
        gcc_hash=$(spack --config-scope "${tmpdir}" buildcache list -a -v -l gcc | grep -v -- "----" | tail -n1 | awk '{print $1}')
    fi

    # Try to install from bootstrap-gcc-buildcache, fall back to generic version.
    spack install /${gcc_hash} 2>/dev/null || spack install gcc
    spack compiler find --scope site "$(spack find -p --no-groups gcc | tail -n 1 | awk '{print $2}')"/bin

    if [ -z "${NO_INTEL_COMPILER}" ] && [ "x86_64" == "$(arch)" ]
    then
        if ${generic_buildcache}; then
            # Build cache uses oneapi@2024.1.0 since this is the latest compatible with amzn linux2.
            spack install intel-oneapi-compilers@2024.1.0
        else
            # Add oneapi@2023.2.4 & intel@2021.10.0 as they have the full Intel C compiler
            spack install intel-oneapi-compilers@2023.2.4
        fi
        spack compiler find --scope site \
              "$(spack find -p --no-groups intel-oneapi-compilers | tail -n 1 | awk '{print $2}')"/compiler/latest/{,linux}/bin/{,intel64}
    fi
}

# TODO: Handle this compiler in buildcache stack once wrf%acfl package gets added
install_acfl() {
    if [ -z "${SPACK_ROOT}" ]; then
        if [ -f /opt/slurm/etc/slurm.sh ]; then
            . /opt/slurm/etc/slurm.sh
        else
            . /etc/profile.d/spack.sh
        fi
    fi

    if [ "${NO_ARM_COMPILER}" == 1 ] || [ "aarch64" != "$(arch)" ]; then
        # Requested to not install, or wrong CPU arch.
        # Nothing to do.
        return 0
    fi

    # ACfL is not supported by all OS's.
    # See https://github.com/spack/spack/blob/develop/var/spack/repos/builtin/packages/acfl/package.py#L37
    [ -f /etc/os-release ] && . /etc/os-release
    case "$ID-$VERSION_ID" in
        amzn-2023|amzn-2)
            ;;
        ubuntu-20.04|ubuntu-22.04)
            ;;
        *)
            echo "Not installing ACfL for $ID $VERSION_ID"
            return 0
            ;;
    esac

    spack install acfl
    spack compiler find --scope site "$(spack location -i acfl)"/arm-linux-compiler-"$(spack find --format '{version}' acfl)"_*/bin
}

setup_mirrors() {
    . "${install_path}/share/spack/setup-env.sh"

    if ${generic_buildcache}; then
        # $SPACK_BRANCH can point to an existing release, e.g. v0.23.0: In this case there exists a versioned buildcache.
        # Or it points to a development branch. In this case we want use the "v0.23.1" build cache.
        if curl -sfLI "https://binaries.spack.io/${SPACK_BRANCH}/aws-pcluster-$(stack_arch)/build_cache/index.json" -o /dev/null; then
            spack mirror add --scope site "aws-pcluster-$(stack_arch)" "https://binaries.spack.io/${SPACK_BRANCH}/aws-pcluster-$(stack_arch)"
        else
            spack mirror add --scope site "aws-pcluster-$(stack_arch)" "https://binaries.spack.io/v0.23.1/aws-pcluster-$(stack_arch)"
        fi
    fi

    # Add older specific target mirrors if they exist
    mirror_url="https://binaries.spack.io/v0.23.1/aws-pcluster-$(target | sed -e 's?_avx512??1')"
    if curl -fIsLo /dev/null "${mirror_url}/build_cache/index.json"; then
        spack mirror list | grep -q $mirror_url || \
            spack mirror add --scope site "aws-pcluster-legacy" "${mirror_url}"
    fi

    # add keys if we added any binary buildcaches.
    spack mirror list | grep -qE '\[.*b.*\]' && spack buildcache keys -it
    return 0
}

install_packages() {
    # Install any specs provided to the script.
    for spec in "$@"
    do
        [ -z "${spec}" ] || spack install -U "${spec}"
    done
}

if [ -f "/opt/parallelcluster/.bootstrapped" ] && [ "3" != "$(major_version)" ]; then
    echo "ParallelCluster version $(major_version) not supported."
    exit 1
fi

[ -n "${SPACK_ROOT}" ] && EXTERNAL_SPACK="true"


trap "cleanup" SIGINT EXIT
install_os_dependencies
setup_variables
[ -d "${install_path}" ] && EXTERNAL_SPACK="true"
download_spack
download_yq
set_modules
load_spack_at_login
setup_bootstrap_mirrors
set_variables
if ${generic_buildcache}; then
    setup_pcluster_buildcache_stack
else
    set_pcluster_defaults
fi
remove_missing_packages
echo "now setting up spack"
setup_spack
echo "now installing compilers"
install_compilers
install_acfl
patch_compilers_yaml
setup_mirrors
install_packages "${install_specs[@]:-}"
echo "*** Spack setup completed ***"
