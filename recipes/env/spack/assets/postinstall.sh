#!/bin/bash
set -e

##############################################################################################
# # This script will setup Spack and best practices for a few applications.                  #
# # Use as postinstall in AWS ParallelCluster (https://docs.aws.amazon.com/parallelcluster/) #
##############################################################################################

install_in_foreground=false
while [ $# -gt 0 ]; do
    case $1 in
        -v )
            set -v
            shift
            ;;
        -fg )
            install_in_foreground=true
            shift
            ;;
        -nointel )
            export NO_INTEL_COMPILER=1
            shift
            ;;
        * )
            echo "Unknown argument: $1"
            exit 1
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
    spack_branch="develop"

    scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
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
        [ -d ${install_path} ] || \
            if [ -n "${spack_branch}" ]
            then
                git clone -c feature.manyFiles=true https://github.com/spack/spack -b ${spack_branch} ${install_path}
            elif [ -n "${spack_commit}" ]
            then
                git clone -c feature.manyFiles=true https://github.com/spack/spack ${install_path}
                cd ${install_path} && git checkout ${spack_commit}
            fi
        return 0
    else
        # Let the script know we did not download spack, so the owner will not be fixed on exit.
        return 1
    fi
}

architecture() {
    lscpu  | grep "Architecture:" | awk '{print $2}'
}

# zen3 EC2 instances (e.g. hpc6a) is misidentified as zen2 so zen3 packages are found under packages-zen2.yaml.
target() {
    (
        . ${install_path}/share/spack/setup-env.sh
        spack arch -t
    )
}

cp_packages_yaml() {
    . ${install_path}/share/spack/setup-env.sh
    target="${1}"
    if [ -f $SPACK_ROOT/share/spack/gitlab/cloud_pipelines/stacks/aws-pcluster-"${target}"/packages.yaml ]; then
        cp $SPACK_ROOT/share/spack/gitlab/cloud_pipelines/stacks/aws-pcluster-"${target}"/packages.yaml /tmp/packages.yaml
    else
        false
    fi
}

download_packages_yaml() {
    # $1: spack target
    . ${install_path}/share/spack/setup-env.sh
    target="${1}"
    curl -Ls https://raw.githubusercontent.com/spack/spack-configs/main/AWS/parallelcluster/packages-"${target}".yaml -o /tmp/packages.yaml
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

set_pcluster_defaults() {
    # Set versions of pre-installed software in packages.yaml
    [ -z "${SLURM_VERSION}" ] && SLURM_VERSION=$(strings /opt/slurm/lib/libslurm.so | grep  -e '^VERSION'  | awk '{print $2}'  | sed -e 's?"??g')
    [ -z "${LIBFABRIC_MODULE_VERSION}" ] && LIBFABRIC_MODULE_VERSION=$(grep 'Version:' "$(find /opt/amazon/efa/ -name libfabric.pc | head -n1)" | awk '{print $2}' | sed -e 's?~??g')
    [ -z "${LIBFABRIC_MODULE}" ] && LIBFABRIC_MODULE="libfabric-aws/${LIBFABRIC_MODULE_VERSION}"
    [ -z "${LIBFABRIC_VERSION}" ] && LIBFABRIC_VERSION=${LIBFABRIC_MODULE_VERSION//amzn*}
    [ -z "${GCC_VERSION}" ] && GCC_VERSION=$(gcc -v 2>&1 |tail -n 1| awk '{print $3}' )

    # Write the above as actual yaml file and only parse the \$.
    mkdir -p ${install_path}/etc/spack

    # Find suitable packages.yaml. If not for this architecture then for its parents.
    ( cp_packages_yaml "$(echo $(target) | sed -e 's?_avx512??1')" || download_packages_yaml "$(target)" )
    eval "echo \"$(cat /tmp/packages.yaml)\"" > ${install_path}/etc/spack/packages.yaml

    curl -Ls https://raw.githubusercontent.com/spack/spack-configs/main/AWS/parallelcluster/modules.yaml -o ${install_path}/etc/spack/modules.yaml
}

setup_spack() {
    cd "${install_path}"

    # Load spack at login
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

    . "${install_path}/share/spack/setup-env.sh"
    spack compiler add --scope site
    spack external find --scope site

    # Remove all autotools/buildtools packages. These versions need to be managed by spack or it will
    # eventually end up in a version mismatch (e.g. when compiling gmp).
    spack tags build-tools | xargs -I {} spack config --scope site rm packages:{}
    [ -z "${CI_PROJECT_DIR}" ] && spack mirror add --scope site "aws-pcluster" "https://binaries.spack.io/develop/aws-pcluster-$(target | sed -e 's?_avx512??1')"
    spack buildcache keys --install --trust
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
    spack_gcc_version=$(spack find --format '{version}' gcc)
    binutils_path=$(spack find -p binutils | awk '/binutils/ {print $2}')
    if [ -d "${binutils_path}" ] && [ -n "${spack_gcc_version}" ]; then python3 <<EOF
import yaml

with open("${compilers_yaml}",'r') as f:
    compilers=yaml.safe_load(f)

for c in compilers["compilers"]:
    if "arm" in c["compiler"]["spec"] or "intel" in c["compiler"]["spec"] or "oneapi" in c["compiler"]["spec"] \
       or "${spack_gcc_version}" in c["compiler"]["spec"]:
        compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["environment"] = {"prepend_path":{"PATH":"${binutils_path}/bin"}}

with open("${compilers_yaml}",'w') as f:
    yaml.dump(compilers, f)
EOF
    fi

    # Oneapi needs extra_rpath to gcc libstdc++.so.6
    if oneapi_gcc_version=$(spack find --format '{compiler}' intel-oneapi-compilers | sed -e 's/=//g') && \
            [ -n "${oneapi_gcc_version}" ] && oneapi_gcc_path=$(spack find -p "${oneapi_gcc_version}" | grep "${oneapi_gcc_version}" | awk '{print $2}') && \
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

    # Armclang needs to find its own libraries
    if acfl_path=$(spack find -p acfl | awk '/acfl/ {print $2}') && \
            [ -d "${acfl_path}" ] && cpp_include_path=$(dirname "$(find "${acfl_path}" -name cassert)") && \
            [ -d "${cpp_include_path}" ]; then  python3 <<EOF
import yaml

with open("${compilers_yaml}",'r') as f:
    compilers=yaml.safe_load(f)

for c in compilers["compilers"]:
    if "arm" in c["compiler"]["spec"]:
        compilers["compilers"][compilers["compilers"].index(c)]["compiler"]["environment"] = {"prepend_path":{"CPATH":"${cpp_include_path}:${cpp_include_path}/aarch64-linux-gnu"}}

with open("${compilers_yaml}",'w') as f:
    yaml.dump(compilers, f)
EOF
    fi

    # Armclang needs extra_rpath to libstdc++.so
    if acfl_path=$(spack find -p acfl | awk '/acfl/ {print $2}') && \
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

install_packages() {
    if [ -z "${SPACK_ROOT}" ]; then
        if [ -f /opt/slurm/etc/slurm.sh ]; then
            . /opt/slurm/etc/slurm.sh
        else
            . /etc/profile.d/spack.sh
        fi
    fi

    # Compiler needed for all kinds of codes. It makes no sense not to install it.
    # Get gcc from buildcache
    cache_zip=$(mktemp)
    # TODO: Enable. It runs without error right now, but needs to be changed once bootstrap-gcc-cache is available
    # [ -z "${CI_PROJECT_DIR}" ] && curl -L "" -o "${cache_zip}"
    # `gcc@12.3.0%gcc@7.3.1` is created as part of building the pipeline containers.
    # https://github.com/spack/gitlab-runners/pkgs/container/pcluster-amazonlinux-2/106126845?tag=v2023-07-01 produced the following hashes.
    if [ "x86_64" == "$(architecture)" ]; then
        gcc_hash="yyvkvlgimaaxjhy32oa5x5eexqekrevc"
    else
        gcc_hash="jttj24nibqy5jsqf34as5m63umywfa3d"
    fi
    if file -b "${cache_zip}"  | grep -q "Zip archive"; then
        pushd "$(dirname "${cache_zip}")"
        unzip -uq "${cache_zip}"
        spack mirror add --scope=site bootstrap-gcc-cache file://"$PWD"/bootstrap-gcc-cache && \
            spack buildcache update-index bootstrap-gcc-cache
        popd
    fi

    spack install --no-check-signature /${gcc_hash} || spack install gcc

    if spack mirror list | grep -q "bootstrap-gcc-cache"; then
        pushd "$(dirname "${cache_zip}")"
        spack mirror rm --scope=site bootstrap-gcc-cache
        rm -rf bootstrap-gcc-cache "${cache_zip}"
        popd
    fi

    (
        spack load gcc
        spack compiler add --scope site
    )

    if [ -z "${NO_INTEL_COMPILER}" ] && [ "x86_64" == "$(architecture)" ]
    then
        # Add oneapi@latest & intel@latest
        spack install intel-oneapi-compilers-classic
        bash -c ". "$(spack location -i intel-oneapi-compilers)/setvars.sh"; spack compiler add --scope site"
    fi

    # TODO: Handle this compiler in pipeline once WRF package gets added
    if [ -z "${CI_PROJECT_DIR}" ] && [ "aarch64" == "$(architecture)" ]
    then
        spack install acfl
        (
            spack load acfl
            spack compiler add --scope site
        )
    fi

    patch_compilers_yaml

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
    set_pcluster_defaults
    setup_spack
    install_packages \"$@\"
    echo \"*** Spack setup completed ***\"
    rm -f ${tmpfile}
" > ${tmpfile}

if ${install_in_foreground}; then
    bash ${tmpfile}
else
    nohup bash ${tmpfile} &> /var/log/spack-postinstall.log &
    disown -a
fi
