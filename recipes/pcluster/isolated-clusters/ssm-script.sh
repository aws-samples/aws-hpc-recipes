sed -i '/options timeout:2 attempts:5/d' /etc/resolv.conf

cat <<EOF > /etc/security/access.conf
#this file restricts access to the following users or AD groups to the login nodes and blocks all others
+ : root : ALL
+ : ec2-user : ALL
+ : ssm-user : ALL
+ : (cluster-admins) : ALL
+ : (cluster-users) : ALL
- : ALL : ALL
EOF

cat << EOF >> /etc/hosts
#this file directs traffic to the two NLB IP's that sit in front of AWS Managed AD. This is required for isolated cluster AD authentication
10.0.0.100 corp.pcluster.com
10.0.1.100 corp.pcluster.com
EOF