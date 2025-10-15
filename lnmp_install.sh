#!/bin/bash
# Debian 13 LNMP 一键安装脚本
# Linux + Nginx + MySQL + PHP + phpMyAdmin
# 支持最小化系统，增强了安全性、错误处理和兼容性

set -e

REPORT_FILE="/root/lnmp_install_report.txt"
LOG_FILE="/root/lnmp_install.log"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error_exit() {
    echo -e "${RED}❌ 错误: $1${NC}" >&2
    log "ERROR: $1"
    exit 1
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
    log "SUCCESS: $1"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    log "WARNING: $1"
}

# 检查命令是否成功执行
check_command() {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

echo "=================================="
echo "  Debian 13 LNMP 一键安装脚本"
echo "  (含 phpMyAdmin 管理工具)"
echo "  版本: v1.0"
echo "=================================="
log "开始 LNMP 安装流程"

# 检查是否为 root
if [[ $EUID -ne 0 ]]; then
   error_exit "请使用 root 用户运行此脚本！"
fi

# 检查系统版本
if [ -f /etc/os-release ]; then
    if ! grep -q "Debian" /etc/os-release; then
        warning "此脚本为 Debian 系统设计，当前系统可能不兼容"
    fi
else
    warning "无法检测系统版本"
fi

# 检查网络连接
echo
log "检查网络连接..."
if ! ping -c 1 8.8.8.8 >/dev/null 2>&1 && ! ping -c 1 114.114.114.114 >/dev/null 2>&1; then
    error_exit "网络连接失败，请检查网络配置"
fi
success "网络连接正常"

# 默认参数
WEB_ROOT="/var/www/html"
DOMAIN="localhost"

# --------------------
# MySQL 配置交互
# --------------------
echo
echo ">>> 配置 MySQL"
read -p "请输入 MySQL root 用户名（默认: root）: " MYSQL_USER
MYSQL_USER=${MYSQL_USER:-root}

# 密码输入（不回显）
while true; do
    read -s -p "请输入 MySQL root 密码（默认: root123456）: " MYSQL_PWD
    echo
    MYSQL_PWD=${MYSQL_PWD:-root123456}
    
    if [ ${#MYSQL_PWD} -lt 8 ]; then
        warning "密码长度少于8位，建议使用更强的密码"
        read -p "是否继续使用此密码？(y/N): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            continue
        fi
    fi
    break
done

read -p "请输入 MySQL 监听端口（默认: 3306）: " MYSQL_PORT
MYSQL_PORT=${MYSQL_PORT:-3306}

# 检查端口是否被占用
if command -v netstat >/dev/null 2>&1; then
    if netstat -tuln 2>/dev/null | grep -q ":$MYSQL_PORT "; then
        error_exit "端口 $MYSQL_PORT 已被占用，请选择其他端口"
    fi
elif command -v ss >/dev/null 2>&1; then
    if ss -tuln 2>/dev/null | grep -q ":$MYSQL_PORT "; then
        error_exit "端口 $MYSQL_PORT 已被占用，请选择其他端口"
    fi
fi

read -p "是否允许远程访问 MySQL？(y/N): " MYSQL_REMOTE
MYSQL_REMOTE=${MYSQL_REMOTE,,}  # 转小写

# --------------------
# 系统更新与软件安装
# --------------------
echo
log "开始更新系统..."
apt update -y || error_exit "apt update 失败，请检查网络和软件源配置"
apt upgrade -y || warning "系统升级遇到问题，继续安装..."
success "系统更新完成"

echo
log "安装基础依赖和必要工具..."
# 最小化系统可能缺少这些基础包
apt install -y apt-utils dialog debconf-utils 2>/dev/null || true
apt install -y ca-certificates gnupg lsb-release software-properties-common 2>/dev/null || true
apt install -y net-tools curl wget openssl sudo
check_command "基础工具安装失败"
success "基础工具安装完成"

echo
log "安装 Nginx..."
apt install -y nginx
check_command "Nginx 安装失败"

# 等待 Nginx 安装完成
sleep 2

# 检查 Nginx 是否成功安装
if ! command -v nginx >/dev/null 2>&1; then
    error_exit "Nginx 安装后未找到，请检查安装过程"
fi
success "Nginx 安装完成"

# 检查 Nginx 80 端口
if command -v netstat >/dev/null 2>&1; then
    if netstat -tuln 2>/dev/null | grep -q ":80 "; then
        warning "端口 80 已被占用，Nginx 可能无法正常启动"
    fi
elif command -v ss >/dev/null 2>&1; then
    if ss -tuln 2>/dev/null | grep -q ":80 "; then
        warning "端口 80 已被占用，Nginx 可能无法正常启动"
    fi
fi

echo
log "安装 MySQL(MariaDB)..."
# 预配置 MySQL 以避免交互提示
echo "mariadb-server mysql-server/root_password password temppassword" | debconf-set-selections 2>/dev/null || true
echo "mariadb-server mysql-server/root_password_again password temppassword" | debconf-set-selections 2>/dev/null || true

DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server mariadb-client
check_command "MySQL 安装失败"

# 等待安装完成
sleep 2

# 检查 MySQL 是否成功安装
if ! command -v mysql >/dev/null 2>&1; then
    error_exit "MySQL 安装后未找到，请检查安装过程"
fi
success "MySQL 安装完成"

# 启动 MySQL 服务
systemctl start mariadb 2>/dev/null || service mariadb start 2>/dev/null || true
sleep 3

# 检查 MySQL 是否启动成功
if ! systemctl is-active --quiet mariadb 2>/dev/null && ! service mariadb status >/dev/null 2>&1; then
    warning "MySQL 服务启动可能有问题，尝试重新启动..."
    systemctl restart mariadb 2>/dev/null || service mariadb restart 2>/dev/null || true
    sleep 3
fi

# 再次检查
if ! pgrep -x mysqld >/dev/null && ! pgrep -x mariadbd >/dev/null; then
    error_exit "MySQL 服务启动失败，请检查日志: journalctl -xeu mariadb"
fi
success "MySQL 服务启动成功"

echo
log "配置 MySQL root 用户..."

# 先尝试无密码连接（新安装的 MariaDB 通常允许 root 无密码连接）
mysql -u root -e "SELECT 1;" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    # 无密码可以连接，设置密码
    mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_PWD');" 2>/dev/null || \
    mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PWD';" 2>/dev/null || \
    mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('$MYSQL_PWD') WHERE User='root'; FLUSH PRIVILEGES;" 2>/dev/null || \
    error_exit "MySQL 密码设置失败"
    mysql -u root -p"$MYSQL_PWD" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
else
    # 尝试使用 unix_socket 插件连接
    mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$MYSQL_PWD');" 2>/dev/null || \
    mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_PWD';" 2>/dev/null || \
    error_exit "MySQL 密码设置失败，请手动配置"
fi

# 验证密码是否设置成功
if mysql -u root -p"$MYSQL_PWD" -e "SELECT 1;" >/dev/null 2>&1; then
    success "MySQL root 用户配置完成"
else
    warning "密码验证失败，但继续执行..."
fi

# 远程访问配置
if [[ "$MYSQL_REMOTE" == "y" ]]; then
    log "配置 MySQL 远程访问..."
    
    # 使用密码连接
    mysql -u root -p"$MYSQL_PWD" -e "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PWD';" 2>/dev/null || \
    mysql -u root -p"$MYSQL_PWD" -e "GRANT ALL PRIVILEGES ON *.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PWD' WITH GRANT OPTION;" 2>/dev/null || \
    warning "远程用户创建可能失败"
    
    mysql -u root -p"$MYSQL_PWD" -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    
    # 修改绑定地址
    if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
        sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mariadb.conf.d/50-server.cnf
    elif [ -f /etc/mysql/my.cnf ]; then
        sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
    elif [ -f /etc/my.cnf ]; then
        sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/my.cnf
    else
        warning "未找到 MySQL 配置文件，请手动配置 bind-address"
    fi
    success "MySQL 远程访问已启用"
    warning "请注意：开启远程访问存在安全风险，建议配置防火墙规则"
fi

# 修改端口
MYSQL_CONF=""
if [ -f /etc/mysql/mariadb.conf.d/50-server.cnf ]; then
    MYSQL_CONF="/etc/mysql/mariadb.conf.d/50-server.cnf"
elif [ -f /etc/mysql/my.cnf ]; then
    MYSQL_CONF="/etc/mysql/my.cnf"
elif [ -f /etc/my.cnf ]; then
    MYSQL_CONF="/etc/my.cnf"
fi

if [ -n "$MYSQL_CONF" ]; then
    if grep -q "^port" "$MYSQL_CONF"; then
        sed -i "s/^port.*/port = $MYSQL_PORT/" "$MYSQL_CONF"
    else
        # 如果没有 port 配置，添加到 [mysqld] 段
        sed -i "/^\[mysqld\]/a port = $MYSQL_PORT" "$MYSQL_CONF"
    fi
else
    warning "未找到 MySQL 配置文件，端口保持默认"
fi

systemctl restart mariadb 2>/dev/null || service mariadb restart
check_command "MySQL 重启失败"
systemctl enable mariadb 2>/dev/null || update-rc.d mariadb defaults 2>/dev/null || true
success "MySQL 服务配置完成"

# --------------------
# 安装 PHP 及常用扩展
# --------------------
echo
log "安装 PHP 及常用扩展..."
apt install -y php-fpm php-cli php-mysql php-curl php-gd php-mbstring \
    php-xml php-zip php-bcmath php-intl php-json php-soap php-xmlrpc 2>/dev/null || \
apt install -y php php-fpm php-cli php-mysql php-curl php-gd php-mbstring \
    php-xml php-zip php-common
check_command "PHP 安装失败"

# 等待 PHP 安装完成
sleep 2

# 检查 PHP 是否成功安装
if ! command -v php >/dev/null 2>&1; then
    error_exit "PHP 安装后未找到，请检查安装过程"
fi
success "PHP 安装完成"

# 获取 PHP 版本
PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null)
if [ -z "$PHP_VERSION" ]; then
    error_exit "无法获取 PHP 版本"
fi
log "PHP 版本: $PHP_VERSION"

# 检查 PHP-FPM socket
PHP_FPM_SOCK="/run/php/php${PHP_VERSION}-fpm.sock"
if [ ! -S "$PHP_FPM_SOCK" ]; then
    log "启动 PHP-FPM 服务..."
    systemctl start php${PHP_VERSION}-fpm 2>/dev/null || service php${PHP_VERSION}-fpm start 2>/dev/null || true
    sleep 3
    if [ ! -S "$PHP_FPM_SOCK" ]; then
        warning "PHP-FPM socket 未找到: $PHP_FPM_SOCK，尝试查找其他版本..."
        # 尝试查找其他 PHP-FPM socket
        for sock in /run/php/php*-fpm.sock; do
            if [ -S "$sock" ]; then
                PHP_FPM_SOCK="$sock"
                log "找到 PHP-FPM socket: $PHP_FPM_SOCK"
                break
            fi
        done
        
        if [ ! -S "$PHP_FPM_SOCK" ]; then
            error_exit "无法找到 PHP-FPM socket，请检查 PHP-FPM 安装"
        fi
    fi
fi
success "PHP-FPM 配置完成"

# --------------------
# 配置 Nginx 与 PHP
# --------------------
echo
log "配置 Nginx"
mkdir -p $WEB_ROOT

# 备份原有配置
if [ -f /etc/nginx/sites-enabled/default ]; then
    mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak.$(date +%s) 2>/dev/null || true
fi

cat > /etc/nginx/sites-available/$DOMAIN.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $WEB_ROOT;
    index index.php index.html index.htm;

    # 日志配置
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log /var/log/nginx/${DOMAIN}_error.log;

    # 字符集
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # phpMyAdmin 配置
    location ^~ /phpmyadmin {
        alias /usr/share/phpmyadmin;
        index index.php;
        
        location ~ ^/phpmyadmin/(.+\.php)$ {
            alias /usr/share/phpmyadmin/\$1;
            fastcgi_pass unix:$PHP_FPM_SOCK;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$request_filename;
            include fastcgi_params;
        }
        
        location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
            alias /usr/share/phpmyadmin/\$1;
        }
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:$PHP_FPM_SOCK;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_intercept_errors on;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF

ln -sf /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/$DOMAIN.conf
check_command "Nginx 配置链接失败"

echo
log "创建测试页面..."
cat > $WEB_ROOT/index.php <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>LNMP 测试页面</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .success { color: green; font-weight: bold; }
        .info { background: #f0f0f0; padding: 10px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1 class="success">✅ LNMP 安装成功！</h1>
    <div class="info">
        <p><strong>PHP 版本:</strong> <?php echo PHP_VERSION; ?></p>
        <p><strong>服务器时间:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
    </div>
    <hr>
    <h2>PHP 配置信息</h2>
    <?php phpinfo(); ?>
</body>
</html>
EOF

# 设置权限
chown -R www-data:www-data $WEB_ROOT 2>/dev/null || chown -R nginx:nginx $WEB_ROOT 2>/dev/null || true
chmod -R 755 $WEB_ROOT

# 测试 Nginx 配置
nginx -t
check_command "Nginx 配置测试失败"

# 重启服务
systemctl restart nginx 2>/dev/null || service nginx restart
check_command "Nginx 重启失败"

systemctl restart php${PHP_VERSION}-fpm 2>/dev/null || service php${PHP_VERSION}-fpm restart
check_command "PHP-FPM 重启失败"

# 启用开机自启
systemctl enable nginx php${PHP_VERSION}-fpm 2>/dev/null || \
{
    update-rc.d nginx defaults 2>/dev/null || true
    update-rc.d php${PHP_VERSION}-fpm defaults 2>/dev/null || true
}
success "Nginx 和 PHP 配置完成"

# --------------------
# 安装 phpMyAdmin
# --------------------
echo
read -p "是否安装 phpMyAdmin？(Y/n): " INSTALL_PMA
INSTALL_PMA=${INSTALL_PMA:-y}
INSTALL_PMA=${INSTALL_PMA,,}

if [[ "$INSTALL_PMA" == "y" ]]; then
    log "开始安装 phpMyAdmin..."
    
    # 安装 phpMyAdmin
    DEBIAN_FRONTEND=noninteractive apt install -y phpmyadmin
    check_command "phpMyAdmin 安装失败"
    
    # 配置 phpMyAdmin 访问路径
    PMA_PATH="/phpmyadmin"
    read -p "请输入 phpMyAdmin 访问路径（默认: /phpmyadmin）: " PMA_CUSTOM_PATH
    if [ -n "$PMA_CUSTOM_PATH" ]; then
        PMA_PATH="$PMA_CUSTOM_PATH"
    fi
    
    # 创建符号链接
    PMA_DIR="/usr/share/phpmyadmin"
    ln -sf $PMA_DIR $WEB_ROOT$PMA_PATH
    
    # 配置 phpMyAdmin Blowfish secret
    if [ -f /etc/phpmyadmin/config.inc.php ]; then
        BLOWFISH_SECRET=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
        sed -i "s/\$cfg\['blowfish_secret'\] = ''/\$cfg['blowfish_secret'] = '$BLOWFISH_SECRET'/" /etc/phpmyadmin/config.inc.php 2>/dev/null || \
        echo "\$cfg['blowfish_secret'] = '$BLOWFISH_SECRET';" >> /etc/phpmyadmin/config.inc.php
    fi
    
    # 设置权限
    chown -R www-data:www-data $PMA_DIR 2>/dev/null || chown -R nginx:nginx $PMA_DIR 2>/dev/null || true
    chmod -R 755 $PMA_DIR
    
    # 重启 Nginx
    systemctl restart nginx 2>/dev/null || service nginx restart
    check_command "Nginx 重启失败"
    
    success "phpMyAdmin 安装完成"
    log "phpMyAdmin 访问路径: $PMA_PATH"
else
    log "跳过 phpMyAdmin 安装"
fi

# --------------------
# 验证服务状态
# --------------------
echo
log "验证服务状态..."

check_service() {
    if systemctl is-active --quiet $1 2>/dev/null; then
        success "$1 服务运行正常"
        return 0
    elif service $1 status >/dev/null 2>&1; then
        success "$1 服务运行正常"
        return 0
    else
        warning "$1 服务未运行"
        return 1
    fi
}

check_service nginx
check_service mariadb
check_service php${PHP_VERSION}-fpm

# --------------------
# 生成报告
# --------------------
cat > $REPORT_FILE <<EOF
===================================
 LNMP 一键安装完成报告
 (含 phpMyAdmin 管理工具)
===================================
安装时间: $(date '+%Y-%m-%d %H:%M:%S')

【基本信息】
网站目录: $WEB_ROOT
访问地址: http://$DOMAIN
PHP 版本: $PHP_VERSION
phpMyAdmin: $([ "$INSTALL_PMA" == "y" ] && echo "已安装 - 访问地址: http://$DOMAIN$PMA_PATH" || echo "未安装")

【MySQL 配置】
MySQL 用户: $MYSQL_USER
MySQL 端口: $MYSQL_PORT
远程访问: $([ "$MYSQL_REMOTE" == "y" ] && echo "已启用" || echo "未启用")

【配置文件位置】
Nginx 配置: /etc/nginx/sites-available/$DOMAIN.conf
PHP-FPM 配置: /etc/php/$PHP_VERSION/fpm/php.ini
MySQL 配置: /etc/mysql/mariadb.conf.d/50-server.cnf

【日志文件】
Nginx 访问日志: /var/log/nginx/${DOMAIN}_access.log
Nginx 错误日志: /var/log/nginx/${DOMAIN}_error.log
安装日志: $LOG_FILE

【安全建议】
1. 请妥善保管 MySQL 密码，不要泄露
2. 建议修改 MySQL 默认端口 3306
3. 如开启远程访问，请配置防火墙规则限制 IP
4. 建议配置 SSL 证书启用 HTTPS
5. 定期更新系统和软件包
6. $([ "$INSTALL_PMA" == "y" ] && echo "phpMyAdmin 建议修改访问路径，并设置访问 IP 白名单" || echo "如需要数据库管理工具，可以安装 phpMyAdmin")

【防火墙配置参考】
# 允许 HTTP
ufw allow 80/tcp

# 允许 HTTPS（如需要）
ufw allow 443/tcp

# 允许 MySQL 远程访问（如需要）
ufw allow $MYSQL_PORT/tcp

【常用命令】
# 重启 Nginx
systemctl restart nginx

# 重启 PHP-FPM
systemctl restart php${PHP_VERSION}-fpm

# 重启 MySQL
systemctl restart mariadb

# 查看服务状态
systemctl status nginx
systemctl status php${PHP_VERSION}-fpm
systemctl status mariadb

========================
报告文件: $REPORT_FILE
日志文件: $LOG_FILE
===================================
EOF

# 设置报告文件权限（只有 root 可读）
chmod 600 $REPORT_FILE

echo
success "LNMP 一键安装完成！"
echo
echo "📄 详细信息请查看: $REPORT_FILE"
echo "📋 安装日志位置: $LOG_FILE"
echo
SERVER_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    SERVER_IP=$(ip addr show 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -n1)
fi
if [ -n "$SERVER_IP" ]; then
    echo "🌐 测试访问: http://$SERVER_IP"
else
    echo "🌐 测试访问: http://$DOMAIN"
fi
echo "   或访问: http://$DOMAIN"
if [[ "$INSTALL_PMA" == "y" ]]; then
    echo
    if [ -n "$SERVER_IP" ]; then
        echo "🗄️  phpMyAdmin: http://$SERVER_IP$PMA_PATH"
    fi
    echo "   或访问: http://$DOMAIN$PMA_PATH"
    echo "   用户名: $MYSQL_USER"
fi
echo

log "LNMP 安装流程完成"
