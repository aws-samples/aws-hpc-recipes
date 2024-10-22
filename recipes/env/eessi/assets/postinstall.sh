#!/usr/bin/env bash

set -e

##############################################################################################
# # This script will setup EESSI and use caching on the headnode for optimisation.           #
# # Use as postinstall in AWS ParallelCluster (https://docs.aws.amazon.com/parallelcluster/) #
##############################################################################################

PROGNAME=$(basename $0)
readonly PROGNAME

TEMP_DIR=$(mktemp -d)
readonly TEMP_DIR

readonly EESSI_VERSION_TO_LOAD="2023.06"
readonly EESSI_REPONAME="software.eessi.io"
readonly EESSI_INIT="/cvmfs/${EESSI_REPONAME}/versions/${EESSI_VERSION_TO_LOAD}/init"
readonly AMAZON_PATH="/opt/amazon"
readonly CURL_OPTS="-L --silent --show-error --fail"

# Global associative array with os-release info
declare -A OS_RELEASE

get_os_release() {
    local key
    local value

    while read -r key value; do
	OS_RELEASE[${key}]="${value}"
    done < <(awk -F = 'gsub(/"/, "", $2); {print $1, $2}' /etc/os-release)
}

# Global associative array populated by the function get_cvmfs_stats()
declare -A CVMFS_STATS

get_cvmfs_stats() {
    local stat_key
    local stat_value

    CVMFS_STATS=()
    while read -r stat_key stat_value; do
	CVMFS_STATS[${stat_key}]=${stat_value}
    done < <(cvmfs_config stat ${EESSI_REPONAME} | awk 'NR==1{split($0, keys)} NR==2{for (i=1; i<=NF; i++) {sub(/\(.*\)/, "", keys[i]); print keys[i], $i}}')
}

usage() {
    cat <<EOF
usage: ${PROGNAME} options

Installs EESSI client and performs host customizations

OPTIONS:
  -v		         Set verbose
  -x		         Set xtrace
  -nogpu	         Do not inject host GPU drivers and libraries into EESSI
  -noefa	         Do not inject host EFA and MPI libraries into EESSI
  -nocache	         Do not setup a Squid Proxy cache for CVMFS Stratum 1
  -noptrace              Do not disable ptrace protection if is enabled by default
  -only-eessi	         Install only the EESSI client
  -openmpi4              Choose OpenMPI version 4
  -openmpi5              Choose OpenMPI version 5 (default)
  -aws-ofi-nccl          Install aws-ofi-nccl plugin. Check supported instances types
  -help		         Show this help
EOF
}

err() {
    echo "ERROR: $*" >&2
}

process_cmdline() {
    while (( $# > 0 )); do
	case $1 in
            -v)
		set -v
		shift
		;;
            -x)
		set -x
		shift
		;;
	    -nogpu)
		INJECT_GPU=false
		shift
		;;
	    -noefa)
		INJECT_EFA=false
		shift
		;;
	    -nocache)
		SETUP_CACHE=false
		shift
		;;
	    -noptrace)
		DISABLE_PTRACE_PROTECTION=false
		shift
		;;
	    -only-eessi)
		ONLY_EESSI=true
		shift
		;;
	    -openmpi4)
		OPENMPI_VERSION=4
		shift
		;;
	    -openmpi5)
		OPENMPI_VERSION=5
		shift
		;;
	    -aws-ofi-nccl)
		INSTALL_AWS_OFI_NCCL=true
		shift
		;;
	    -help)
		usage
		shift
		;;
            *)
		err "Unknown argument: $1"
		usage
		exit 1
		;;
	esac
    done

    readonly INJECT_EFA=${INJECT_EFA:=true}
    readonly INJECT_GPU=${INJECT_GPU:=true}
    readonly ONLY_EESSI=${ONLY_EESSI:=false}
    readonly SETUP_CACHE=${SETUP_CACHE:=true}
    readonly DISABLE_PTRACE_PROTECTION=${DISABLE_PTRACE_PROTECTION:=true}
    readonly OPENMPI_VERSION=${OPENMPI_VERSION:=5}
    readonly INSTALL_AWS_OFI_NCCL=${INSTALL_AWS_OFI_NCCL:=false}
}

install_eessi_client() {
    local url=https://raw.githubusercontent.com/EESSI/eessi-demo/main/scripts/install_cvmfs_eessi.sh

    # Create directory linked by host_injections
    [[ ! -d /opt/eessi ]] && sudo mkdir -p /opt/eessi

    if command -v cvmfs_config &>/dev/null; then
	if cvmfs_config probe ${EESSI_REPONAME} &> /dev/null; then
	    echo "EESSI client is already installed"
	    return 0
	fi
    fi

    if ! curl ${url} ${CURL_OPTS} -o ${TEMP_DIR}/install_cvmfs_eessi.sh; then
	echo "Download of the EESSI installation script failed"
	exit 1
    fi
    chmod +x ${TEMP_DIR}/install_cvmfs_eessi.sh
    sudo ${TEMP_DIR}/install_cvmfs_eessi.sh

    # Sanity check EESSI installation
    if command -v cvmfs_config &>/dev/null; then
	cvmfs_config probe ${EESSI_REPONAME}
	if (( $? != 0 )); then
	    err "CVMFS REPO ${EESSI_REPONAME} is not accesible"
	    return 1
	fi
    else
	err "CVMFS was not correctly installed"
	return 1
    fi
}

# ****Warning: patchelf v0.18.0 (currently shipped with EESSI) does not work.****
# We get v0.17.2
download_patchelf() {
    local patchelf_version="0.17.2"
    local url

    url="https://github.com/NixOS/patchelf/releases/download/${patchelf_version}/"
    url+="patchelf-${patchelf_version}-${EESSI_CPU_FAMILY}.tar.gz"

    curl ${url} ${CURL_OPTS} -o ${TEMP_DIR}/patchelf.tar.gz
    tar -xf ${TEMP_DIR}/patchelf.tar.gz -C ${TEMP_DIR}
    PATCHELF_BIN=${TEMP_DIR}/bin/patchelf
}

install_aws_ofi_nccl_plugin() {
    if [ -d /opt/aws-ofi-nccl ]; then
	echo "aws-ofi-nccl plugin already installed"
	return 0
    fi

    local url=https://github.com/aws/aws-ofi-nccl/releases/download/v1.9.2-aws/aws-ofi-nccl-1.9.2-aws.tar.gz
    if ! curl ${url} ${CURL_OPTS} -o ${TEMP_DIR}/aws-ofi-nccl.tar.gz; then
	err "Download of aws-ofi-nccl plugin failed"
	return 1
    fi

    mkdir ${TEMP_DIR}/aws-ofi-nccl && tar -xf ${TEMP_DIR}/aws-ofi-nccl.tar.gz -C ${TEMP_DIR}/aws-ofi-nccl --strip-component=1
    local configure_opts="--prefix=/opt/aws-ofi-nccl --with-mpi=/opt/amazon/openmpi --with-libfabric=/opt/amazon/efa --with-cuda=/usr/local/cuda --enable-platform-aws"
    if ! (cd ${TEMP_DIR}/aws-ofi-nccl && ./configure ${configure_opts} && make && sudo make install); then
	err "Compilation and installation of aws-ofi-nccl plugin failed"
	return 1
    fi
    echo "Successful installation of aws-ofi-nccl plugin"
}

inject_mpi() {
    local efa_path="${AMAZON_PATH}/efa"
    local openmpi_path="${AMAZON_PATH}/openmpi"
    local pmix_path="/opt/pmix"
    local eessi_ldd="${EESSI_EPREFIX}/usr/bin/ldd"
    local system_ldd="/usr/bin/ldd"

    (( OPENMPI_VERSION == 5 )) && openmpi_path+=5

    local host_injection_mpi_path

    host_injection_mpi_path="${EESSI_CVMFS_REPO}/host_injections/${EESSI_VERSION}"
    host_injection_mpi_path+="/software/${EESSI_OS_TYPE}/${EESSI_SOFTWARE_SUBDIR}"
    host_injection_mpi_path+="/rpath_overrides/OpenMPI/system/lib"

    if [ -d ${host_injection_mpi_path} ]; then
	echo "MPI was already injected"
	return 0
    fi

    sudo mkdir -p ${host_injection_mpi_path}

    local temp_inject_path="${TEMP_DIR}/mpi_inject"
    mkdir ${temp_inject_path}

    # Get all library files from efa and openmpi dirs
    find ${efa_path} ${openmpi_path} ${pmix_path} -maxdepth 2 -type f -name "*.so*" -exec cp {} ${temp_inject_path} \;

    # Copy library links to host injection path
    sudo find ${efa_path} ${openmpi_path} ${pmix_path} -maxdepth 2 -type l -name "*.so*" -exec cp -P {} ${host_injection_mpi_path} \;

    # Get system libefa.so and libibverbs.so
    find /lib/ /lib64/ \( -name "libefa.so*" -or -name "libibverbs.so*" \) -type f -exec cp {} ${temp_inject_path} \;
    sudo find /lib/ /lib64/ \( -name "libefa.so*" -or -name "libibverbs.so*" \) -type l -exec cp -P {} ${host_injection_mpi_path} \;


    # Get MPI libs dependencies from system ldd
    local libname libpath
    local -A libs_arr

    while read -r libname libpath; do
	[[ ${libpath} =~ ${AMAZON_PATH}/.* ]] && libpath=${host_injection_mpi_path}/$(basename ${libpath})
	[[ ${libname} =~ libefa\.so\.?.* ]] && libpath=${host_injection_mpi_path}/$(basename ${libpath})
	[[ ${libname} =~ libibverbs\.so\.?.* ]] && libpath=${host_injection_mpi_path}/$(basename ${libpath})
	libs_arr[${libname}]=${libpath}
    done < <(cat <(${system_ldd} ${temp_inject_path}/*) <(find ${openmpi_path} -mindepth 3 -name "*.so*" -print0 | xargs -0 ${system_ldd}) | awk '/=>/{print $1, $3}' | sort | uniq)

    # Get MPI related lib dependencies not resolved by EESSI ldd
    local lib

    while read -r lib; do
	local dep

	${PATCHELF_BIN} --set-rpath "" ${lib}

	while read -r dep; do
	    if ${PATCHELF_BIN} --print-needed ${lib} | grep -q "${dep}"; then
		${PATCHELF_BIN} --replace-needed ${dep} ${libs_arr[${dep}]} ${lib}
	    fi
	done < <(${eessi_ldd} ${lib} | awk '/not found/ || /libefa/ || /libibverbs/ {print $1}' | sort | uniq)

	# Inject into libmpi.so non resolved dependencies from dlopen libraries that are not already present in libmpi.so
	if [[ ${lib} =~ libmpi\.so ]]; then
	    while read -r dep; do
		${PATCHELF_BIN} --add-needed ${libs_arr[${dep}]} ${lib}
	    done < <(comm -23 <(find ${openmpi_path} -mindepth 3 -name "*.so*" -print0 | xargs -0 ${eessi_ldd} | awk '/not found/ {print $1}' | sort | uniq) <(${PATCHELF_BIN} --print-needed ${lib} | sort))
	fi

    done < <(find ${temp_inject_path} -type f)

    # Sanity check MPI injection
    if ${eessi_ldd} ${temp_inject_path}/* &> /dev/null; then
	sudo cp ${temp_inject_path}/* -t ${host_injection_mpi_path}
	echo "MPI injection was successful"
	return 0
    else
	err "MPI host injection failed. EESSI will use its own MPI libraries"
	return 1
    fi
}

inject_nvidia_drivers() {
    if lspci | grep -qi nvidia ; then
       if command -v nvidia-smi &> /dev/null; then
	   sudo -E ${EESSI_PREFIX}/scripts/gpu_support/nvidia/link_nvidia_host_libraries.sh

	   # Sanity check GPU linking
	   if (module load CUDA-Samples && deviceQuery) &> /dev/null; then
	       echo "NVIDIA GPU injection was successful"
	       echo "EESSI can use the host GPU"
	   else
	       err "NVIDIA GPU injection failed. EESSI cannot use the host GPU"
	   fi
       fi
    else
	err "No GPU available. Did not inject NVIDIA libraries into EESSI"
    fi
}

write_squid_config() {
    local cache_size=$1

    sudo tee /etc/squid/squid.conf <<EOF > /dev/null
# List of local IP addresses (separate IPs and/or CIDR notation) allowed to access your local proxy
acl local_nodes src 0.0.0.0/0

# Destination domains that are allowed
acl stratum_ones dstdomain .eessi.science

# Squid port
http_port 3128

# Deny access to anything which is not part of our stratum_ones ACL.
http_access deny !stratum_ones

# Only allow access from our local machines
http_access allow local_nodes
http_access allow localhost

# Finally, deny all other access to this proxy
http_access deny all

minimum_expiry_time 0
maximum_object_size 1024 MB

# proxy memory cache of 1GB
cache_mem 1024 MB
maximum_object_size_in_memory 128 KB
# disk cache
cache_dir ufs /var/spool/squid ${cache_size} 16 265
EOF
}

install_squid_proxy() {
    if systemctl is-active squid --quiet; then
	echo "Squid service already installed and running"
	return 0
    fi

    if [[ "${OS_RELEASE[ID_LIKE]}" =~ "rhel" ]] \
	   || [[ "${OS_RELEASE[ID_LIKE]}" =~ "fedora" ]] \
	   || [[ "${OS_RELEASE[ID_LIKE]}" =~ "centos" ]]
    then
	sudo yum install -y squid
    elif [[ "${OS_RELEASE[ID_LIKE]}" =~ "debian" ]] || [[ "${OS_RELEASE[ID]}" =~ "debian" ]]; then
	sudo apt-get install -y squid
    else
	err "OS not recognized. Could not install squid proxy server"
	return 1
    fi

    # Get available disk space
    # Assume the avail space at / is of the order of GB
    # Only use 60% of the avail space as cache
    local avail
    local cache_size
    avail=$(df / --output=avail -H --sync | grep -o '[0-9]\+')
    cache_size=$((avail * 60 / 100))

    write_squid_config ${cache_size}

    if sudo squid -k parse &> /dev/null; then
	sudo systemctl start squid
	sudo systemctl enable squid
	if systemctl is-active squid --quiet; then
	    return 0
	else
	    err "Squid service could not run"
	    return 1
	fi
    else
	err "Squid configuration is invalid"
	return 1
    fi
}

setup_cache() {
    local proxy_url

    get_cvmfs_stats
    if (( CVMFS_STATS[ONLINE] == 1 )) && [[ "${CVMFS_STATS[PROXY]}" != "DIRECT" ]]; then
	echo "Squid proxy cache already setup"
	return 0
    fi

    if [ ! -f  /etc/parallelcluster/cfnconfig ]; then
	err "/etc/parallelcluster/cfnconfig does not exist"
	return 1
    fi

    source /etc/parallelcluster/cfnconfig
    if [ ${cfn_node_type} = "HeadNode" ]; then
	install_squid_proxy
	proxy_url="localhost:3128"
    else
	proxy_url="${cfn_head_node_private_ip}:3128"

	# Get stratum 1 servers from cvmfs eessi domain config
	local -a stratum1_servers
	mapfile -t stratum1_servers < <(awk 'match($0, /CVMFS_SERVER_URL="(.*)"/, arr) {print arr[1]}' /etc/cvmfs/domain.d/eessi.io.conf | tr ';' '\n')

	# check if proxy is available in HeadNode
	for stratum1 in "${stratum1_servers[@]}"; do
	    http_proxy=http://${proxy_url} curl ${CURL_OPTS} -I "${stratum1/@fqrn@/${EESSI_REPONAME}}/.cvmfspublished" > /dev/null
	    if (( $? == 0 )); then
		echo "Found HTTP Proxy in HeadNode"
		break
	    fi
	    err "HTTP Proxy in HeadNode is not available"
	    return 1
	done
    fi

    sudo tee -a /etc/cvmfs/default.local <<< "CVMFS_HTTP_PROXY=\"http://${proxy_url}\"" > /dev/null
    sudo cvmfs_config reload

    # Sanity check
    get_cvmfs_stats

    if (( CVMFS_STATS[ONLINE] == 1 )) && [[ "${CVMFS_STATS[PROXY]}" != "DIRECT" ]]; then
	echo "Contacting EESSI via HTTP proxy was successful"
	return 0
    else
	err "Contacting EESSI through HTTP proxy failed"

	sudo sed -i '/CVMFS_HTTP_PROXY/d' /etc/cvmfs/default.local
	echo "HTTP proxy configuration was undone"
	sudo cvmfs_config reload
	return 1
    fi
}

setup_eessi_autoload() {
  echo "Adding EESSI autoload configuration for bash shells"

  # Define the filename for the new script in /etc/profile.d
  local profile_script="/etc/profile.d/zz9-init_eessi.sh"

  # Filename for the BASH_ENV script. Needed to assess if EESSI must be reloaded due to
  local bashenv_script="/etc/bashenv"

  # Create the script to ensure it runs for all bash shells
  sudo bash -c "cat > ${profile_script}" <<EOF
#!/bin/bash
#
# This script is sourced by /etc/profile.d/ and is executed for all bash shells

export EESSI_SILENT=yes
[[ -z \${PRE_EESSI_MODULEPATH} ]] && export PRE_EESSI_MODULEPATH="\${MODULEPATH}"

# Create BASH_ENV variable only for sbatch and srun jobs
export SBATCH_EXPORT="ALL,BASH_ENV=${bashenv_script}"
export SRUN_EXPORT_ENV="ALL,BASH_ENV=${bashenv_script}"

source ${EESSI_INIT}/lmod/bash
export MODULEPATH="\${MODULEPATH}:\${PRE_EESSI_MODULEPATH}"

# lesspipe behaves differently on Ubuntu to Gentoo Prefix, let's just stick to the host
lesspipe() { /usr/bin/lesspipe "\$@" ; }
export -f lesspipe
EOF

  sudo bash -c "cat > ${bashenv_script}" <<EOF
#!/bin/bash
#
# This script is sourced by Slurm when launching a job with SBATCH or SRUN.
# It reloads the module system picking the right microarch

# BASH_ENV must be unset when loading/reloading the EESSI module to avoid infinite loop
unset BASH_ENV
original_MODULEPATH="\${MODULEPATH}"
module -q update
if [[ "\${MODULEPATH}" != "\${original_MODULEPATH}" ]]; then
  echo "Reloading for architecture \${EESSI_SOFTWARE_SUBDIR}"
  module update
  export MODULEPATH="\${MODULEPATH}:\${PRE_EESSI_MODULEPATH}"
fi
unset original_MODULEPATH
EOF
}

disable_ptrace_protection() {
    local ptrace
    ptrace=$(sysctl --values kernel.yama.ptrace_scope)
    if (( ptrace == 0 )); then
	echo "ptrace protection already disabled"
	return 0
    fi
    sudo sysctl -w kernel.yama.ptrace_scope=0
    sudo tee /etc/sysctl.d/10-ptrace.conf <<<"kernel.yama.ptrace_scope = 0" > /dev/null
    echo "ptrace protection has been disabled"
}

main() {
    process_cmdline "$@"
    get_os_release
    install_eessi_client
    setup_eessi_autoload

    if ${INSTALL_AWS_OFI_NCCL}; then
	install_aws_ofi_nccl_plugin
    fi

    if ${SETUP_CACHE}; then
	if ! setup_cache; then
	    err "Could not setup HTTP proxy"
	fi
    fi

    if ${DISABLE_PTRACE_PROTECTION}; then
	disable_ptrace_protection
    fi

    if ! ${ONLY_EESSI}; then
	# Initialize EESSI to get EESSI env vars
	[ -z ${EESSI_SOFTWARE_PATH} ] && source "${EESSI_INIT}/bash"
 
	if ${INJECT_GPU}; then
	    inject_nvidia_drivers
	fi

	if ${INJECT_EFA}; then
	    echo "OpenMPI version to inject: ${OPENMPI_VERSION}"
	    download_patchelf
	    inject_mpi
	fi
    fi
    rm -rf "${TEMP_DIR}"
    echo "EESSI setup completed with success"
}

main "$@"
