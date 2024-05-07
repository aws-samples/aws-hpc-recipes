
# PCS-managed directories
for D in /opt/aws/pcs/bin /etc/amazon/pcs/
do
    mkdir -p $D && chmod 600 $D
done

# User management
# For beta, Slurm uid must be 401 or there will be constant auth errors in the log
useradd --uid 400 --home-dir /home/pcs-admin --shell /bin/bash --comment "pcs admin user" -U --system --create-home pcs-admin
useradd --uid 401 --home-dir /home/slurm --shell /bin/bash --comment "slurm user" -U --system --create-home slurm
groupadd --gid 405 --system pcs-slurm-share
usermod --append --groups pcs-slurm-share pcs-admin
usermod --append --groups pcs-slurm-share slurm


# Create slurm shell profiles
cat <<EOF > /opt/slurm/etc/slurm.sh
#
# slurm.sh:
#   Setup slurm environment variables
#

PATH=$PATH:/opt/slurm/bin
MANPATH=$MANPATH:/opt/slurm/share/man

export PATH MANPATH
EOF
chown root:root /opt/slurm/etc/slurm.sh
chmod 0755 /opt/slurm/etc/slurm.sh
ln -s /opt/slurm/etc/slurm.sh /etc/profile.d/slurm.sh

cat <<EOF > /opt/slurm/etc/slurm.csh
#
# slurm.csh:
#     Sets the C shell user environment for slurm commands
#
set path = (\$path /opt/slurm/bin)
if ( \${?MANPATH} ) then
  setenv MANPATH \${MANPATH}:/opt/slurm/share/man
else
  setenv MANPATH :/opt/slurm/share/man
endif
EOF
chown root:root /opt/slurm/etc/slurm.csh
chmod 0755 /opt/slurm/etc/slurm.csh
ln -s /opt/slurm/etc/slurm.csh /etc/profile.d/slurm.csh

# Enable pcs-admin limited scope with sudoers
cat << EOF > /etc/sudoers.d/99-pcs-slurm
Cmnd_Alias SLURM_COMMANDS = /opt/slurm/bin/scontrol, /opt/slurm/bin/sinfo
Cmnd_Alias SHUTDOWN = /usr/sbin/shutdown

pcs-admin ALL = (root) NOPASSWD: SLURM_COMMANDS
pcs-admin ALL = (root) NOPASSWD: SHUTDOWN
EOF
chown root:root /etc/sudoers.d/99-pcs-slurm
chmod 0600  /etc/sudoers.d/99-pcs-slurm
