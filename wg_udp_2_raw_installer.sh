#!/bin/bash
#=====================================================
# WireGuard + udp2raw 一键安装脚本
# 支持：Ubuntu/Debian
#=====================================================

set -e

# 默认参数
default_server_ip="8.134.111.223"
default_server_port=51820
default_wg_server_ip="10.0.0.1"
default_wg_client_ip="10.0.0.2"
default_udp2raw_port=4096

# 提示用户输入
echo "=== WireGuard + udp2raw 安装脚本 ==="
read -p "请输入本机角色 (server/client) [server]: " role
role=${role:-server}

read -p "请输入公网服务器IP [$default_server_ip]: " server_ip
server_ip=${server_ip:-$default_server_ip}

read -p "请输入WireGuard服务端端口 [$default_server_port]: " wg_port
wg_port=${wg_port:-$default_server_port}

read -p "请输入udp2raw监听端口 [$default_udp2raw_port]: " udp2raw_port
udp2raw_port=${udp2raw_port:-$default_udp2raw_port}

read -p "请输入WireGuard服务端虚拟IP [$default_wg_server_ip]: " wg_server_ip
wg_server_ip=${wg_server_ip:-$default_wg_server_ip}

read -p "请输入WireGuard客户端虚拟IP [$default_wg_client_ip]: " wg_client_ip
wg_client_ip=${wg_client_ip:-$default_wg_client_ip}

# 安装依赖
echo "[1/5] 安装依赖..."
apt update -y
apt install -y wireguard-tools iptables curl wget net-tools

# 下载 udp2raw
echo "[2/5] 安装 udp2raw..."
mkdir -p /usr/local/bin
if [ ! -f /usr/local/bin/udp2raw ]; then
  wget -O /usr/local/bin/udp2raw https://github.com/wangyu-/udp2raw-tunnel/releases/download/20230206.0/udp2raw_amd64
  chmod +x /usr/local/bin/udp2raw
fi

# 生成密钥（如果不存在）
mkdir -p /etc/wireguard
if [ ! -f /etc/wireguard/server_private.key ]; then
  wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
fi
if [ ! -f /etc/wireguard/client_private.key ]; then
  wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
fi

server_private_key=$(cat /etc/wireguard/server_private.key)
server_public_key=$(cat /etc/wireguard/server_public.key)
client_private_key=$(cat /etc/wireguard/client_private.key)
client_public_key=$(cat /etc/wireguard/client_public.key)

if [ "$role" = "server" ]; then
  echo "[3/5] 配置 WireGuard 服务端..."
  cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $wg_server_ip/24
ListenPort = $wg_port
PrivateKey = $server_private_key
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $client_public_key
AllowedIPs = $wg_client_ip/32
EOF

  echo "[4/5] 配置 udp2raw 服务端..."
  cat > /etc/systemd/system/udp2raw.service <<EOF
[Unit]
Description=udp2raw server
After=network.target

[Service]
ExecStart=/usr/local/bin/udp2raw -s -l0.0.0.0:$udp2raw_port -r127.0.0.1:$wg_port -a
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable wg-quick@wg0
  systemctl enable udp2raw
  systemctl start wg-quick@wg0
  systemctl start udp2raw

  echo "=== 服务端安装完成 ==="
  echo "服务端公钥: $server_public_key"
  echo "客户端公钥: $client_public_key"
  echo "请将以上信息保存好，并配置到客户端。"

else
  echo "[3/5] 配置 WireGuard 客户端..."
  cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = $wg_client_ip/24
PrivateKey = $client_private_key
DNS = 8.8.8.8

[Peer]
PublicKey = $server_public_key
Endpoint = 127.0.0.1:$wg_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

  echo "[4/5] 配置 udp2raw 客户端..."
  cat > /etc/systemd/system/udp2raw.service <<EOF
[Unit]
Description=udp2raw client
After=network.target

[Service]
ExecStart=/usr/local/bin/udp2raw -c -l127.0.0.1:$wg_port -r$server_ip:$udp2raw_port -a
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable wg-quick@wg0
  systemctl enable udp2raw
  systemctl start udp2raw
  systemctl start wg-quick@wg0

  echo "=== 客户端安装完成 ==="
fi
