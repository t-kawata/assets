cat <<EOF >> /etc/sysctl.conf
net.core.somaxconn=20480
net.core.netdev_max_backlog=250000
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mem=25600 51200 102400
# rmem_max/wmem_max should be the same as the right side of tcp_rmem/tcp_wmem
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 67108864
net.ipv4.tcp_wmem=4096 65536 67108864
# Recommended for security (Preventing from SYN FLOOD attack ...etc)
net.ipv4.tcp_syncookies=1
net.ipv4.tcp_max_syn_backlog=20480
# [notice] It can be risky.
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
# [notice] Can be used from Ubuntu 18.04 LTS
# net.core.default_qdisc=fq
# net.ipv4.tcp_congestion_control=bbr
kernel.core_pattern=/tmp/core-%e-%t
EOF
sysctl -p
