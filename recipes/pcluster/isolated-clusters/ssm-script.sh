sed -i '/options timeout:2 attempts:5/d' /etc/resolv.conf

cat <<EOF > /etc/security/access.conf
+ : root : ALL
+ : ec2-user : ALL
+ : ssm-user : ALL
+ : (cluster-admins) : ALL
+ : user000 : ALL
- : ALL : ALL
EOF

cat << EOF >> /etc/hosts
10.0.0.100 corp.pcluster.com
10.0.1.100 corp.pcluster.com
EOF