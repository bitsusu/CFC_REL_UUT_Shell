#!/bin/bash
# 功能：设置时区上海(东八区UTC+8)、安装配置chrony NTP、强制同步系统硬件时间
# 作者：运维自动化脚本
set -e

echo "==================== 开始配置系统时区与NTP时间同步 ===================="

########################### 1. 设置时区 Asia/Shanghai 东八区 ###########################
echo "[1/4] 配置时区为上海(东八区 UTC+8)"
timedatectl set-timezone Asia/Shanghai
echo "当前时区信息："
timedatectl | grep "Time zone"

########################### 2. 安装 chrony NTP 服务 ###########################
echo -e "\n[2/4] 检测系统包管理器并安装chrony"
if command -v yum &> /dev/null; then
    # CentOS/RHEL/Rocky
    yum install -y chrony
elif command -v apt &> /dev/null; then
    # Ubuntu/Debian
    apt update -y
    apt install -y chrony
else
    echo "不支持的系统包管理器，退出"
    exit 1
fi

########################### 3. 配置国内NTP公服源 ###########################
echo -e "\n[3/4] 写入国内稳定NTP服务器配置"
CHRONY_CONF="/etc/chrony.conf"
# 备份原配置
cp ${CHRONY_CONF} ${CHRONY_CONF}.bak.$(date +%Y%m%d_%H%M%S)

# 清空原有pool/server，写入阿里云+国家授时中心NTP
cat > ${CHRONY_CONF} << EOF
# 国内NTP时间服务器
server ntp.lenovo.com
server ntp.aliyun.com iburst
server ntp1.aliyun.com iburst
server ntp2.aliyun.com iburst
server time1.aliyun.com iburst
server cn.ntp.org.cn iburst
server ntp.sjtu.edu.cn iburst

# 允许本机访问chrony控制端
allow 127.0.0.1
allow ::1

# 同步后写入硬件时钟
rtcsync

# 日志存储
logdir /var/log/chrony
EOF

########################### 4. 重启服务、开机自启、强制同步时间 ###########################
echo -e "\n[4/4] 启用chrony开机自启并重启服务"
systemctl enable --now chronyd

# 等待服务启动
sleep 2

# 强制手动同步时间
echo "正在强制同步系统时间..."
chronyc makestep

# 同步系统时间到硬件RTC时钟
hwclock --systohc

########################### 5. 输出校验信息 ###########################
echo -e "\n==================== 配置完成，校验信息 ===================="
echo "1. 系统时间：$(date "+%Y-%m-%d %H:%M:%S %Z")"
echo "2. 硬件时钟：$(hwclock)"
echo "3. 时区详情："
timedatectl
echo -e "\n4. NTP同步源状态（等待2秒拉取）："
sleep 2
chronyc sources -v
echo -e "\n5. chrony服务状态："
systemctl status chronyd --no-pager -l
