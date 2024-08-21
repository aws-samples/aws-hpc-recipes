#!/bin/bash
set -e

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
 [spec]                 "spec" to be installed after initial
                        configuration: e.g., gcc@12.3.0 or "gcc @ 13.0".
                        Multiple specs can be listed, but they need to either
                        be quoted or contain no spaces.

Developer Options:
 --config-branch        Pull configuration (e.g., packages.yaml) from this
                        branch.  Default is "main".
 --config-repo          Pull configuration (e.g., packages.yaml) from this
                        github user/repo.  Default is "spack/spack-configs".
 --spack-branch         Clone spack using this branch.  Default is "develop"
 --spack-repo           Clone spack using this github user/repo. Default is
                        "spack/spack".
EOF
}

# CONFIG_REPO: a the user/repo on github to use for configuration.a custom user/repo/branch in case users wish to
# provide or test their own configurations.
export CONFIG_REPO="spack/spack-configs"
export CONFIG_BRANCH="main"
export SPACK_REPO="spack/spack"
export SPACK_BRANCH="develop"
install_specs=()
export generic_buildcache=""
install_in_foreground=false
while [ $# -gt 0 ]; do
    case $1 in
        --buildcache )
            generic_buildcache=true
            shift
            ;;
        --config-branch )
            CONFIG_BRANCH="$2"
            shift 2
            ;;
        --config-repo )
            CONFIG_REPO="$2"
            shift 2
            ;;
        -fg )
            install_in_foreground=true
            shift
            ;;
        -h|--help )
            print_help
            exit 0
            ;;
        --no-arm-compiler )
            export NO_ARM_COMPILER=1
            shift
            ;;
        --no-buildcache )
            generic_buildcache=false
            shift
            ;;
        --no-intel-compiler )
            export NO_INTEL_COMPILER=1
            shift
            ;;
        --spack-branch )
            SPACK_BRANCH="$2"
            shift 2
            ;;
        --spack-repo )
            SPACK_REPO="$2"
            shift 2
            ;;
        -v )
            set -v
            shift
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
            shift
            ;;
    esac
done

setup_variables() {
    # Install onto first shared storage device
    cluster_config="/opt/parallelcluster/shared/cluster-config.yaml"
    pip3 install pyyaml
    if [ -f "${cluster_config}" ]; then
        os=$(python3 << EOF
#/usr/bin/env python
import yaml
with open("${cluster_config}", 'r') as s:
    print(yaml.safe_load(s)["Image"]["Os"])
EOF
          )

        case "${os}" in
            alinux*)
                cfn_cluster_user="ec2-user"
                ;;
            centos*)
                cfn_cluster_user="centos"
                ;;
            ubuntu*)
                cfn_cluster_user="ubuntu"
                ;;
            *)
                cfn_cluster_user=""
        esac

        cfn_ebs_shared_dirs=$(python3 << EOF
#/usr/bin/env python
import yaml
with open("${cluster_config}", 'r') as s:
    print(yaml.safe_load(s)["SharedStorage"][0]["MountDir"])
EOF
                           )
        scheduler=$(python3 << EOF
#/usr/bin/env python
import yaml
with open("${cluster_config}", 'r') as s:
    print(yaml.safe_load(s)["Scheduling"]["Scheduler"])
EOF
                 )
    elif [ -f /etc/parallelcluster/cfnconfig ]; then
        . /etc/parallelcluster/cfnconfig
    else
        echo "Cannot find ParallelCluster configs"
        cfn_ebs_shared_dirs=""
    fi

    # If we cannot find any shared directory, use $HOME of standard user
    if [ -z "${cfn_ebs_shared_dirs}" ]; then
        for cfn_cluster_user in ec2-user centos ubuntu; do
            [ -d "/home/${cfn_cluster_user}" ] && break
        done
        cfn_ebs_shared_dirs="/home/${cfn_cluster_user}"
    fi

    install_path=${SPACK_ROOT:-"${cfn_ebs_shared_dirs}/spack"}
    echo "Installing Spack into ${install_path}."

    if [ "true" == "${generic_buildcache}" ] && [ "alinux2" != "${os}" ]; then
        echo "Generic buildcache only available for Alinux2."
    fi
    if [ -z "${generic_buildcache}" ] && [ "alinux2" == "${os}" ]; then
        generic_buildcache=true
    else
        generic_buildcache=false
    fi
    # TODO: Turn off generic_buildcache if SPACK_BRANCH is not develop or >v0.21.2
}

major_version() {
    pcluster_version=$(grep -oE '[0-9]*\.[0-9]*\.[0-9]*' /opt/parallelcluster/.bootstrapped)
    echo "${pcluster_version/\.*}"
}

# Make first user owner of Spack installation when script exits.
fix_owner() {
    rc=$?
    if [ ${downloaded} -eq 0 ]
    then
        chown -R ${cfn_cluster_user}:${cfn_cluster_user} "${install_path}"
    fi
    exit $rc
}

download_spack() {
    if [ -z "${SPACK_ROOT}" ]
    then
        [ -d "${install_path}" ] || \
            if [ -n "${SPACK_BRANCH}" ]
            then
                git clone -c feature.manyFiles=true "https://github.com/${SPACK_REPO}" -b "${SPACK_BRANCH}" "${install_path}"
            elif [ -n "${spack_commit}" ]
            then
                git clone -c feature.manyFiles=true "https://github.com/${SPACK_REPO}" "${install_path}"
                cd "${install_path}" && git checkout "${spack_commit}"
            fi
        return 0
    else
        # Let the script know we did not download spack, so the owner will not be fixed on exit.
        return 1
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
        for target in $(spack-python -c 'print(" ".join(spack.platforms.host().target("'"${target}"'").microarchitecture.to_dict()["parents"]))'); do
            if [ -z "${target}" ] ; then
                echo "Cannot find suitable packages.yaml"
                exit 1
            fi
            download_packages_yaml "${target}"
        done
    else
        # Exit "for target in ..." loop.
        break &>/dev/null
    fi
}

set_modules() {
    mkdir -p "${install_path}/etc/spack"
    curl -Ls "https://raw.githubusercontent.com/${CONFIG_REPO}/${CONFIG_BRANCH}/AWS/parallelcluster/modules.yaml" \
         -o "${install_path}/etc/spack/modules.yaml"
}

set_pcluster_defaults() {
    # Set versions of pre-installed software in packages.yaml
    [ -z "${SLURM_VERSION}" ] && SLURM_VERSION=$(strings /opt/slurm/lib/libslurm.so | grep  -e '^VERSION'  | awk '{print $2}'  | sed -e 's?"??g')
    [ -z "${LIBFABRIC_VERSION}" ] && LIBFABRIC_VERSION=$(awk '/Version:/{print $2}' "$(find /opt/amazon/efa/ -name libfabric.pc | head -n1)" | sed -e 's?~??g' -e 's?amzn.*??g')
    export SLURM_VERSION LIBFABRIC_VERSION

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

    # `gcc@12.3.0` is created as part of building the containers in https://github.com/spack/gitlab-runners
    # and mirrored onto `$bootstrap_gcc_cache`:
    bootstrap_gcc_cache="https://bootstrap.spack.io/pcluster/$(spack arch -o)/$(arch)"
    if curl -sf "${bootstrap_gcc_cache}/build_cache/index.json" >/dev/null; then
        spack mirror add --scope=site bootstrap-gcc-cache "${bootstrap_gcc_cache}"
    fi

    # Newer gpg2 versions on Ainux2 will not be able to validate the key. This allows spack to accept the buildcache keys.
    if [ "$(gpg --version | awk '/gpg/{print $3}')" == "2.0.22" ]; then
        mkdir -m 700 -p ${SPACK_ROOT}/opt/spack/gpg
        echo "openpgp" >> ${SPACK_ROOT}/opt/spack/gpg/gpg.conf
    fi
    spack buildcache keys -it
}

setup_pcluster_buildcache_stack() {
    . "${install_path}/share/spack/setup-env.sh"
    # Make sure the subshell which install the Intel compiler find the correct installation prefix
    echo -e "config:\n  install_tree:\n    root: ${SPACK_ROOT}/opt/spack\n" > $SPACK_ROOT/etc/spack/config.yaml
    export SPACK_CI_STACK_NAME="aws-pcluster-$(stack_arch)"
    bash "${SPACK_ROOT}/share/spack/gitlab/cloud_pipelines/scripts/pcluster/setup-pcluster.sh"
    rm -f $SPACK_ROOT/etc/spack/config.yaml
}

setup_spack() {
    . "${install_path}/share/spack/setup-env.sh"
    spack compiler add --scope site
    # Do not add  autotools/buildtools packages. These versions need to be managed by spack or it will
    # eventually end up in a version mismatch (e.g. when compiling gmp).
    spack external find --scope site --tag core-packages

    # Remove gcc-12 if identified in ubuntu2204. There is no g++ for gfortran that goes with it and this will cause problems.
    for compiler in $(spack compiler list | grep -v '-' |grep -v '=>' | xargs); do
        spack compiler info --scope=site ${compiler} 2>/dev/null | grep -q " None" && spack compiler rm --scope=site ${compiler}
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
    if [ -d "${binutils_path}" ] && [ -n "${spack_gcc_version}" ]; then python3 <<EOF
import yaml

with open("${compilers_yaml}",'r') as f:
    compilers=yaml.safe_load(f)

for c in compilers["compilers"]:
    if "aocc" in c["compiler"]["spec"] or "arm" in c["compiler"]["spec"] or "intel" in c["compiler"]["spec"] or "oneapi" in c["compiler"]["spec"] \
       or "${spack_gcc_version}" in c["compiler"]["spec"]:
           if "prepend_path" in compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["environment"]:
               compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["environment"]["prepend_path"]["PATH"] = "${binutils_path}/bin"
           else:
               compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["environment"] = {"prepend_path":{"PATH":"${binutils_path}/bin"}}

with open("${compilers_yaml}",'w') as f:
    yaml.dump(compilers, f)
EOF
    fi

    # Oneapi needs extra_rpath to gcc libstdc++.so.6
    if oneapi_gcc_version=$(spack find --format '{compiler}' intel-oneapi-compilers 2>/dev/null | sed -e 's/=//g') && \
            [ -n "${oneapi_gcc_version}" ] && oneapi_gcc_path=$(spack find -p "${oneapi_gcc_version}" | grep "${oneapi_gcc_version}" | awk '{print $2}' | head -n1) && \
            [ -d "${oneapi_gcc_path}" ]; then  python3 <<EOF
import yaml

with open("${compilers_yaml}",'r') as f:
    compilers=yaml.safe_load(f)

for c in compilers["compilers"]:
    if "oneapi" in c["compiler"]["spec"]:
        compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["extra_rpaths"] = ["${oneapi_gcc_path}/lib64"]

with open("${compilers_yaml}",'w') as f:
    yaml.dump(compilers, f)
EOF
    fi

    # TODO: Who needs this? WRF? gromacs will not build when this is active.
    # Armclang needs to find its own libraries
    if acfl_path=$(spack find -p acfl 2>/dev/null | awk '/acfl/ {print $2}') && \
            [ -d "${acfl_path}" ] && cpp_include_path=$(dirname "$(find "${acfl_path}" -name cassert)") && \
            [ -d "${cpp_include_path}" ]; then python3 <<EOF
import yaml

with open("${compilers_yaml}",'r') as f:
    compilers=yaml.safe_load(f)

for c in compilers["compilers"]:
    if "arm" in c["compiler"]["spec"]:
        if "prepend_path" in compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["environment"]:
            compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["environment"]["prepend_path"]["CPATH"] = "${cpp_include_path}:${cpp_include_path}/aarch64-linux-gnu"
        else:
            compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["environment"] = {"prepend_path":{"CPATH":"${cpp_include_path}:${cpp_include_path}/aarch64-linux-gnu"}}

with open("${compilers_yaml}",'w') as f:
    yaml.dump(compilers, f)
EOF
    fi

    # Armclang needs extra_rpath to libstdc++.so
    # TODO: FYI ACFL installer does this by adding libstdc++.so.6 path to LD_LIBRARY_PATH
    if acfl_path=$(spack find -p acfl 2>/dev/null | awk '/acfl/ {print $2}') && \
            acfl_libstdcpp_path=$(dirname "$(find "${acfl_path}" -name libstdc++.so | head -n1)") && \
            [ -d "${acfl_libstdcpp_path}" ]; then python3 <<EOF
import yaml

with open("${compilers_yaml}",'r') as f:
    compilers=yaml.safe_load(f)

for c in compilers["compilers"]:
    if "arm" in c["compiler"]["spec"]:
        compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["extra_rpaths"] = ["${acfl_libstdcpp_path}"]

with open("${compilers_yaml}",'w') as f:
    yaml.dump(compilers, f)
EOF
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
    mirrors_entry=$(grep bootstrap-gcc-cache $SPACK_ROOT/etc/spack/mirrors.yaml)
    if [ -n "${mirrors_entry}" ]; then
        # Make sure we select the gcc from the cache we just added (temporarily override all mirrors.yaml configuration files):
        tmpdir=$(mktemp -d)
        echo -e "mirrors::\n${mirrors_entry}" > "${tmpdir}/mirrors.yaml"
        gcc_hash=$(spack --config-scope ${tmpdir} buildcache list -a -v -l gcc | grep -v -- "----" | tail -n1 | awk '{print $1}')
    fi

    # Try to install from bootstrap-gcc-buildcache, fall back to generic version.
    spack install /${gcc_hash} 2>/dev/null || spack install gcc
    (
        spack load gcc
        spack compiler add --scope site
    )

    if [ -z "${NO_INTEL_COMPILER}" ] && [ "x86_64" == "$(arch)" ]
    then
        # Add oneapi@latest & intel@latest
        spack install intel-oneapi-compilers-classic
        bash -c ". "$(spack location -i intel-oneapi-compilers)/setvars.sh"; spack compiler add --scope site"
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

    if [ -z "${NO_ARM_COMPILER}" ] && [ "aarch64" == "$(arch)" ]
    then
        spack install acfl
        (
            spack load acfl
            spack compiler add --scope site
        )
    fi
}

setup_mirrors() {
    . "${install_path}/share/spack/setup-env.sh"

    if ${generic_buildcache}; then
        spack mirror add --scope site "aws-pcluster-$(stack_arch)" "https://binaries.spack.io/develop/aws-pcluster-$(stack_arch)"
    fi
    # Add older specific target mirrors
    spack mirror add --scope site "aws-pcluster-legacy" "https://binaries.spack.io/develop/aws-pcluster-$(target | sed -e 's?_avx512??1')"
    spack buildcache keys -it
}

install_packages() {
    # Install any specs provided to the script.
    for spec in "$@"
    do
        [ -z "${spec}" ] || spack install -U "${spec}"
    done
}

if [ "3" != "$(major_version)" ]; then
    echo "ParallelCluster version $(major_version) not supported."
    exit 1
fi

tmpfile=$(mktemp)
echo "$(declare -pf)
    trap \"fix_owner\" SIGINT EXIT
    setup_variables
    download_spack | true
    downloaded=\${PIPESTATUS[0]}
    set_modules
    load_spack_at_login
    setup_bootstrap_mirrors
    if \${generic_buildcache}; then
       setup_pcluster_buildcache_stack
    else
        set_pcluster_defaults
        setup_spack
        install_compilers
        install_acfl
        patch_compilers_yaml
    fi
    setup_mirrors
    install_packages \"${install_specs}\"
    echo \"*** Spack setup completed ***\"
    rm -f ${tmpfile}
" > ${tmpfile}

if ${install_in_foreground}; then
    bash ${tmpfile}
else
    nohup bash ${tmpfile} &> /var/log/spack-postinstall.log &
    disown -a
fi
