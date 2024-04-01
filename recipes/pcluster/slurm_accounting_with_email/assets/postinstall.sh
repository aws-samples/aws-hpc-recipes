#!/usr/bin/bash

#
# Post install script for Slurm-Mail on AWS Parallel Cluster head node
#

# Exit on error
set -e

function check_exe {
    if [ ! -x $1 ]; then
        die "$1 does not exist or is not executable"
    fi
}

function die {
    echo "$1"
    exit 0 
}

function usage {
    echo "Usage: $0 -c SLURM_config_file -d SLURM_bin_dir -e from_email -n port -u username -p password -s server" 1>&2
    echo "  -c                  SLURM config file"
    echo "  -d                  bin directory for SLURM binaries"
    echo "  -e                  from e-mail address"
    echo "  -n                  SMTP port"
    echo "  -s                  SMTP server"
    echo "  -u                  SMTP user"
    echo "  -p                  SMTP password"
    exit 0 
}

while getopts ":c:d:e:n:p:s:u:" options; do
    case "${options}" in
    c)
      SLURM_CONF=${OPTARG}
      ;;
    d)
      SLURM_BIN_DIR=${OPTARG}
      ;;
    e)
      FROM_EMAIL=${OPTARG}
      ;;
    n)
      SMTP_PORT=${OPTARG}
      ;;
    p)
      SMTP_PASS=${OPTARG}
      ;;
    s)
      SMTP_SERVER=${OPTARG}
      ;;
    u)
      SMTP_USER=${OPTARG}
      ;;
    :)
      echo "Error: -${OPTARG} requires a value"
      usage
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z $FROM_EMAIL ] || [ -z $SLURM_BIN_DIR ] || [ -z $SLURM_CONF ] || [ -z $SMTP_PORT ] || [ -z $SMTP_SERVER ] || [ -z $SMTP_PASS ] || [ -z $SMTP_USER ]; then
    usage
fi

echo "FROM_EMAIL = $FROM_EMAIL"
echo "SLURM_BIN_DIR = $SLURM_BIN_DIR"
echo "SLURM_CONF = $SLURM_CONF"
echo "SMTP_SERVER = $SMTP_SERVER"
echo "SMTP_PORT = $SMTP_PORT"
echo "SMTP_USER = $SMTP_USER"
echo "SMTP_PASS = $SMTP_PASS"

SACCT_EXE="${SLURM_BIN_DIR}/sacct"
SCONTROL_EXE="${SLURM_BIN_DIR}/scontrol"

check_exe $SACCT_EXE
check_exe $SCONTROL_EXE

if [ ! -f /etc/os-release ]; then
    die "/etc/os-release does not exist - cannot determine OS version"
fi

if [ ! -f $SLURM_CONF ]; then
    die "$SLURM_CONF does not exist"
fi

OS_ID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OS_VERSION=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
OS_ID_LIKE=$(grep -oP '(?<=^ID_LIKE=).+' /etc/os-release | tr -d '"')

if [[ $OS_ID_LIKE != *"rhel"* ]]; then  
    die "Unsupported OS"
fi

echo "RHEL based OS"
OS_RELEASE=$(rpm -qf --qf "%{RELEASE}" /etc/os-release | awk '{n=split($1,A,"."); print A[n]}')

echo $OS_RELEASE

echo "Installing required packages"
yum install -y wget which

echo "Downloading Slurm-Mail repo file"
wget -O /etc/yum.repos.d/slurm-mail.repo "https://neilmunday.github.io/slurm-mail/repo/slurm-mail.${OS_RELEASE}.repo"

echo "Installing Slurm-Mail"
yum install -y slurm-mail

SLURM_MAIL_CONF="/etc/slurm-mail/slurm-mail.conf"

# Update slurm-mail config
if [ ! -f $SLURM_MAIL_CONF ]; then
    die "$SLURM_MAIL_CONF does not exist"
fi

echo "Updating $SLURM_MAIL_CONF"
sed -i -r "s#emailFromUserAddress =(.*?)#emailFromUserAddress = ${FROM_EMAIL}#" $SLURM_MAIL_CONF
sed -i -r "s#scontrolExe =(.*?)#scontrolExe = ${SCONTROL_EXE}#" $SLURM_MAIL_CONF
sed -i -r "s#sacctExe =(.*?)#sacctExe = ${SACCT_EXE}#" $SLURM_MAIL_CONF
sed -i -r "s#smtpUseTls =(.*?)#smtpUseTls = yes#" $SLURM_MAIL_CONF
sed -i -r "s#smtpPort =(.*?)#smtpPort = ${SMTP_PORT}#" $SLURM_MAIL_CONF
sed -i -r "s#smtpUserName =(.*?)#smtpUserName = ${SMTP_USER}#" $SLURM_MAIL_CONF
sed -i -r "s#smtpPassword =(.*?)#smtpPassword = ${SMTP_PASS}#" $SLURM_MAIL_CONF
sed -i -r "s#smtpServer =(.*?)#smtpServer = ${SMTP_SERVER}#" $SLURM_MAIL_CONF

echo "Updating $SLURM_CONF"
if grep -q MailProg $SLURM_CONF; then
   sed -i -r "s#MailProg=(.*?)#MailProg=/usr/bin/slurm-spool-mail#" $SLURM_CONF
else
   echo "MailProg=/usr/bin/slurm-spool-mail" >> $SLURM_CONF
fi

echo "Restarting slurmctld"
systemctl restart slurmctld

echo "Done"
exit 0

