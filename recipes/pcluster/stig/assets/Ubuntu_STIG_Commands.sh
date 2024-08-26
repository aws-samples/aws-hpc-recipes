#!/bin/bash

#The Ubuntu operating system must not allow unattended or automatic login via SSH. https://www.stigviewer.com/stig/canonical_ubuntu_20.04_lts/2021-03-23/finding/V-238218
cat << EOF >> /etc/ssh/sshd_config
PermitEmptyPasswords no
PermitUserEnvironment no
EOF

#first portion of the Ubuntu operating system must be configured so that three consecutive invalid logon attempts by a user automatically locks the account until released by an administrator. https://www.stigviewer.com/stig/canonical_ubuntu_18.04_lts/2022-08-25/finding/V-219166
#for the Ubuntu operating system must enforce a delay of at least 4 seconds between logon prompts following a failed logon attempt. https://www.stigviewer.com/stig/canonical_ubuntu_20.04_lts/2023-09-08/finding/V-238237
cat << EOF >> /etc/pam.d/common-auth
auth [default=die] pam_faillock.so authfail
auth sufficient pam_faillock.so authsucc
auth required pam_faildelay.so delay=4000000
EOF

#second portion of the Ubuntu operating system must be configured so that three consecutive invalid logon attempts by a user automatically locks the account until released by an administrator. https://www.stigviewer.com/stig/canonical_ubuntu_18.04_lts/2022-08-25/finding/V-219166
cat << EOF >> /etc/security/faillock.conf
audit
silent
deny = 3
fail_interval = 900
unlock_time = 0
EOF