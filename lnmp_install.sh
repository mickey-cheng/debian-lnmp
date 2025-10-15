#!/bin/bash

# Debian 12 一键安装 LNMP + phpMyAdmin 脚本
# 作者: Assistant
# 日期: $(date +%Y-%m-%d)

# 设置错误处理
set -e  # 遇到错误时退出
set -u  # 使用未定义变量时退出
set -o pipefail  # 管道中命令失败时退出

# 错误处理函数
handle_error() {
    local line_number=$1
    print_error "脚本在第 $line_number 行发生错误"
    print_error "安装过程失败，请检查错误信息并手动修复问题"
    exit 1
}

# 设置错误陷阱
trap 'handle_error $LINENO' ERR

# 中断处理函数
handle_interrupt() {
    print_warn "安装过程被用户中断"
    print_info "可能需要手动清理部分安装的组件"
    exit 1
}

# 设置中断陷阱
trap 'handle_interrupt' INT

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
if [[ $EUID -eq 0 ]]; then
    print_info "以 root 身份运行脚本"
else
    print_error "请使用 root 权限运行此脚本 (sudo ./install_lnmp.sh)"
    exit 1
fi

# 检查系统兼容性
if ! command -v lsb_release &> /dev/null; then
    print_error "lsb_release 命令不可用，请确保系统已安装 lsb-release 包"
    exit 1
fi

if [[ $(lsb_release -si) != "Debian" ]]; then
    print_error "此脚本仅支持 Debian 系统，检测到的系统是: $(lsb_release -si)"
    exit 1
fi

if [[ $(lsb_release -sr) != "12"* ]]; then
    print_warn "此脚本为 Debian 12 设计，检测到的版本是: $(lsb_release -sr)"
    print_warn "继续运行可能会出现问题"
    read -p "是否继续? (y/N): " continue_install
    if [[ $continue_install != "y" && $continue_install != "Y" ]]; then
        exit 0
    fi
fi

# 检查可用磁盘空间（至少需要 500MB）
available_space=$(df / | awk 'NR==2 {print $4}')
if [[ $available_space -lt 500000 ]]; then
    print_error "磁盘空间不足，至少需要 500MB，当前可用空间: $(($available_space/1024))MB"
    exit 1
fi

# 更新系统
print_info "更新系统包列表..."
apt update -y

# 安装必要的工具
print_info "安装必要工具..."
apt install -y curl wget gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates

# 检查网络连接
print_info "检查网络连接..."
if ! curl -s --connect-timeout 5 https://www.debian.org > /dev/null; then
    print_error "网络连接失败，请检查网络设置"
    exit 1
fi

# 提示用户输入自定义配置
echo
print_info "请输入以下配置信息（直接回车使用默认值）："
echo

read -p "请输入 MySQL root 密码 (留空将自动生成随机密码): " mysql_root_pass
if [ -z "$mysql_root_pass" ]; then
    mysql_root_pass=$(openssl rand -base64 12)
    print_warn "已生成随机 MySQL root 密码: $mysql_root_pass"
fi

print_info "phpMyAdmin 可以配置一个控制用户来实现更多功能，"
read -p "是否创建 phpMyAdmin 控制用户？(y/N，默认: n): " create_pma_user
create_pma_user=${create_pma_user:-n}

if [ "$create_pma_user" = "y" ] || [ "$create_pma_user" = "Y" ]; then
    read -p "请输入 phpMyAdmin 控制用户名 (默认: pma): " pma_user
    pma_user=${pma_user:-pma}
    
    read -p "请输入 phpMyAdmin 控制用户密码 (留空将自动生成随机密码): " pma_pass
    if [ -z "$pma_pass" ]; then
        pma_pass=$(openssl rand -base64 12)
        print_warn "已生成随机 phpMyAdmin 控制用户密码: $pma_pass"
    fi
else
    print_info "跳过 phpMyAdmin 控制用户创建"
    pma_user=""
    pma_pass=""
fi

read -p "请输入 phpMyAdmin 访问路径 (默认: /phpmyadmin): " pma_path
pma_path=${pma_path:-/phpmyadmin}

read -p "是否限制 phpMyAdmin 访问来源 (y/N，默认: n): " restrict_pma_access
restrict_pma_access=${restrict_pma_access:-n}

if [ "$restrict_pma_access" = "y" ] || [ "$restrict_pma_access" = "Y" ]; then
    read -p "请输入允许访问 phpMyAdmin 的 IP 地址或网段 (用空格分隔多个地址): " pma_allowed_ips
    print_info "将限制 phpMyAdmin 访问权限到以下地址: $pma_allowed_ips"
else
    print_info "phpMyAdmin 将允许所有 IP 访问 (请确保在生产环境中配置适当的安全措施)"
fi

# 安装 Nginx
print_info "安装 Nginx..."
apt install -y nginx
systemctl enable nginx
systemctl start nginx

# 安装 MariaDB (Debian 12 的默认 MySQL 替代品)
print_info "安装 MariaDB..."
apt install -y mariadb-server mariadb-client

print_info "安装 PHP 及相关扩展..."
# 使用 Debian 官方仓库安装 PHP
apt install -y php php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-bz2 php-intl

# 检查安装的 PHP 版本
PHP_VERSION=$(php --version | head -n1 | cut -d " " -f 2 | cut -d "." -f 1,2)
print_info "已安装 PHP 版本: $PHP_VERSION"

# 检查 PHP-FPM 服务名称
if systemctl list-units --type=service | grep -q "php${PHP_VERSION}-fpm"; then
    PHP_FPM_SERVICE="php${PHP_VERSION}-fpm"
elif systemctl list-units --type=service | grep -q "php-fpm"; then
    PHP_FPM_SERVICE="php-fpm"
else
    print_error "无法找到 PHP-FPM 服务"
    exit 1
fi

print_info "PHP-FPM 服务名称: $PHP_FPM_SERVICE"

# 配置 PHP-FPM
print_info "配置 PHP-FPM..."
sed -i "s/;*expose_php = .*/expose_php = Off/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/;*allow_url_fopen = .*/allow_url_fopen = Off/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/display_errors = .*/display_errors = Off/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/display_startup_errors = .*/display_startup_errors = Off/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/log_errors = .*/log_errors = On/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/file_uploads = .*/file_uploads = On/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 64M/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/post_max_size = .*/post_max_size = 64M/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/max_execution_time = .*/max_execution_time = 300/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/max_input_vars = .*/max_input_vars = 3000/" "/etc/php/$PHP_VERSION/fpm/php.ini"
sed -i "s/;*cgi.fix_pathinfo = .*/cgi.fix_pathinfo = 0/" "/etc/php/$PHP_VERSION/fpm/php.ini"

# 启动 PHP-FPM
systemctl enable "$PHP_FPM_SERVICE"
systemctl start "$PHP_FPM_SERVICE"

# 验证 PHP-FPM 是否正常运行
sleep 2
if ! systemctl is-active --quiet "$PHP_FPM_SERVICE"; then
    print_error "PHP-FPM 未能正常启动"
    systemctl status "$PHP_FPM_SERVICE"
    exit 1
fi
print_info "PHP-FPM 运行正常"

# 配置 Nginx 以使用 PHP-FPM
print_info "配置 Nginx..."
cat > /etc/nginx/sites-available/default << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.php index.html index.htm;
    server_name _;

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline';" always;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/$PHP_FPM_SERVICE.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
    
    # 防止访问敏感文件
    location ~* \.(ini|log|conf)$ {
        deny all;
    }
}
EOF

# 重启 Nginx 以应用 PHP 配置
systemctl restart nginx

# 验证 Nginx 是否正常运行
sleep 2
if ! systemctl is-active --quiet nginx; then
    print_error "Nginx 未能正常启动"
    systemctl status nginx
    exit 1
fi
print_info "Nginx 运行正常"

# 启动 MariaDB 服务
systemctl enable mariadb
systemctl start mariadb

# 验证 MariaDB 是否正常运行
sleep 5
if ! systemctl is-active --quiet mariadb; then
    print_error "MariaDB 未能正常启动"
    systemctl status mariadb
    exit 1
fi
print_info "MariaDB 运行正常"

# 安全配置 MariaDB
print_info "安全配置 MariaDB..."
mysql_secure_installation << EOF

y
$mysql_root_pass
$mysql_root_pass
y
y
y
y
EOF

# 创建 phpMyAdmin 控制用户（如果需要）
if [ -n "$pma_user" ] && [ -n "$pma_pass" ]; then
    print_info "配置 MariaDB phpMyAdmin 控制用户..."
    mysql -u root -p"$mysql_root_pass" << EOF
CREATE DATABASE IF NOT EXISTS phpmyadmin;
CREATE USER '$pma_user'@'localhost' IDENTIFIED BY '$pma_pass';
GRANT ALL PRIVILEGES ON phpmyadmin.* TO '$pma_user'@'localhost';
FLUSH PRIVILEGES;
EOF
else
    print_info "跳过 phpMyAdmin 控制用户配置"
fi

# 安装 phpMyAdmin
PMA_VERSION="5.2.1"

# 尝试使用国内镜像源，如果失败则使用官方源
MIRRORS=(
    "https://mirrors.aliyun.com/phpmyadmin/phpMyAdmin/$PMA_VERSION/phpMyAdmin-$PMA_VERSION-all-languages.tar.gz"
    "https://cdn.mysqlmomu.com/phpmyadmin/phpMyAdmin/$PMA_VERSION/phpMyAdmin-$PMA_VERSION-all-languages.tar.gz"
    "https://files.phpmyadmin.net/phpMyAdmin/$PMA_VERSION/phpMyAdmin-$PMA_VERSION-all-languages.tar.gz"
)

print_info "下载 phpMyAdmin $PMA_VERSION..."

cd /tmp
DOWNLOAD_SUCCESS=false

for mirror_url in "${MIRRORS[@]}"; do
    print_info "尝试从 $mirror_url 下载..."
    if wget --tries=3 --timeout=30 "$mirror_url" -O "phpMyAdmin-$PMA_VERSION-all-languages.tar.gz"; then
        print_info "下载成功"
        DOWNLOAD_SUCCESS=true
        break
    else
        print_warn "从 $mirror_url 下载失败，尝试下一个源..."
        rm -f "phpMyAdmin-$PMA_VERSION-all-languages.tar.gz"
    fi
done

if [ "$DOWNLOAD_SUCCESS" = false ]; then
    print_error "所有源都无法下载 phpMyAdmin，请检查网络连接"
    exit 1
fi

print_info "验证下载的文件..."
if [[ ! -f "phpMyAdmin-$PMA_VERSION-all-languages.tar.gz" ]]; then
    print_error "phpMyAdmin 下载失败"
    exit 1
fi

print_info "解压 phpMyAdmin..."
tar -xzf phpMyAdmin-$PMA_VERSION-all-languages.tar.gz
if [[ ! -d "phpMyAdmin-$PMA_VERSION-all-languages" ]]; then
    print_error "phpMyAdmin 解压失败"
    exit 1
fi

mv phpMyAdmin-$PMA_VERSION-all-languages /usr/share/phpmyadmin
ln -s /usr/share/phpmyadmin /var/www/html/phpmyadmin

# 创建 phpMyAdmin 配置目录
mkdir -p /usr/share/phpmyadmin/config
chown -R www-data:www-data /usr/share/phpmyadmin
chmod -R 755 /usr/share/phpmyadmin

print_info "phpMyAdmin 目录结构设置完成"

# 创建 phpMyAdmin 配置文件
print_info "配置 phpMyAdmin..."
if [ -n "$pma_user" ] && [ -n "$pma_pass" ]; then
    # 创建带控制用户的配置
    cat > /usr/share/phpmyadmin/config.inc.php << EOF
<?php
\$cfg['blowfish_secret'] = '$(openssl rand -hex 32)';

\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;

// 控制用户设置（用于配置存储等高级功能）
\$cfg['Servers'][\$i]['controlhost'] = 'localhost';
\$cfg['Servers'][\$i]['controlport'] = '';
\$cfg['Servers'][\$i]['controluser'] = '$pma_user';
\$cfg['Servers'][\$i]['controlpass'] = '$pma_pass';
\$cfg['Servers'][\$i]['pmadb'] = 'phpmyadmin';
\$cfg['Servers'][\$i]['bookmarktable'] = 'pma__bookmark';
\$cfg['Servers'][\$i]['relation'] = 'pma__relation';
\$cfg['Servers'][\$i]['table_info'] = 'pma__table_info';
\$cfg['Servers'][\$i]['table_coords'] = 'pma__table_coords';
\$cfg['Servers'][\$i]['pdf_pages'] = 'pma__pdf_pages';
\$cfg['Servers'][\$i]['column_info'] = 'pma__column_info';
\$cfg['Servers'][\$i]['history'] = 'pma__history';
\$cfg['Servers'][\$i]['table_uiprefs'] = 'pma__table_uiprefs';
\$cfg['Servers'][\$i]['tracking'] = 'pma__tracking';
\$cfg['Servers'][\$i]['userconfig'] = 'pma__userconfig';
\$cfg['Servers'][\$i]['recent'] = 'pma__recent';
\$cfg['Servers'][\$i]['favorite'] = 'pma__favorite';
\$cfg['Servers'][\$i]['users'] = 'pma__users';
\$cfg['Servers'][\$i]['usergroups'] = 'pma__usergroups';
\$cfg['Servers'][\$i]['navigationhiding'] = 'pma__navigationhiding';
\$cfg['Servers'][\$i]['savedsearches'] = 'pma__savedsearches';
\$cfg['Servers'][\$i]['central_columns'] = 'pma__central_columns';
\$cfg['Servers'][\$i]['designer_settings'] = 'pma__designer_settings';
\$cfg['Servers'][\$i]['export_templates'] = 'pma__export_templates';

\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';

// 额外的安全配置
\$cfg['CheckConfigurationPermissions'] = false;
?>
EOF
else
    # 创建基本配置
    cat > /usr/share/phpmyadmin/config.inc.php << EOF
<?php
\$cfg['blowfish_secret'] = '$(openssl rand -hex 32)';

\$i = 0;
\$i++;
\$cfg['Servers'][\$i]['auth_type'] = 'cookie';
\$cfg['Servers'][\$i]['host'] = 'localhost';
\$cfg['Servers'][\$i]['compress'] = false;
\$cfg['Servers'][\$i]['AllowNoPassword'] = false;

\$cfg['UploadDir'] = '';
\$cfg['SaveDir'] = '';

// 额外的安全配置
\$cfg['CheckConfigurationPermissions'] = false;
?>
EOF
fi

# 设置 phpMyAdmin 配置文件权限
if [[ -f /usr/share/phpmyadmin/config.inc.php ]]; then
    chown www-data:www-data /usr/share/phpmyadmin/config.inc.php
    chmod 644 /usr/share/phpmyadmin/config.inc.php
    print_info "phpMyAdmin 配置文件权限设置完成"
else
    print_warn "phpMyAdmin 配置文件未找到，跳过权限设置"
fi

# 配置 Nginx 以支持 phpMyAdmin
print_info "配置 Nginx 支持 phpMyAdmin..."
if [ "$restrict_pma_access" = "y" ] || [ "$restrict_pma_access" = "Y" ]; then
    # 创建带访问限制的配置
    cat > /etc/nginx/conf.d/phpmyadmin.conf << EOF
location ~ ^$pma_path {
    # 限制访问来源
    deny all;
$(echo "$pma_allowed_ips" | tr ' ' '\n' | sed 's/^/    allow /')
    allow 127.0.0.1;
    allow ::1;
    return 403;
}

location $pma_path {
    alias /usr/share/phpmyadmin;
    index index.php;
    
    location ~ ^$pma_path/(.+\.php)$ {
        alias /usr/share/phpmyadmin/\$1;
        if (!-f \$request_filename) {
            return 404;
        }
        fastcgi_pass unix:/run/php/$PHP_FPM_SERVICE.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
        # 安全头
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        root /usr/share/phpmyadmin;
        expires 1y;
        add_header Cache-Control "public";
        add_header X-Content-Type-Options "nosniff";
        log_not_found off;
    }
}
EOF
else
    # 创建基本配置
    cat > /etc/nginx/conf.d/phpmyadmin.conf << EOF
location $pma_path {
    alias /usr/share/phpmyadmin;
    index index.php;

    location ~ ^$pma_path/(.+\.php)$ {
        alias /usr/share/phpmyadmin/\$1;
        if (!-f \$request_filename) {
            return 404;
        }
        fastcgi_pass unix:/run/php/$PHP_FPM_SERVICE.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$request_filename;
        # 安全头
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        root /usr/share/phpmyadmin;
        expires 1y;
        add_header Cache-Control "public";
        add_header X-Content-Type-Options "nosniff";
        log_not_found off;
    }
}
EOF
fi

# 重启 Nginx
systemctl restart nginx

# 验证 Nginx 配置语法
if ! nginx -t; then
    print_error "Nginx 配置文件语法错误"
    exit 1
fi

# 验证 Nginx 服务状态
sleep 2
if ! systemctl is-active --quiet nginx; then
    print_error "Nginx 未能正常运行"
    systemctl status nginx
    exit 1
fi
print_info "Nginx 配置验证通过且运行正常"

# 创建测试页面
print_info "创建 PHP 测试页面..."
cat > /var/www/html/info.php << EOF
<?php
phpinfo();
?>
EOF

# 验证测试页面可访问性 (基本检查)
if [[ -f /var/www/html/info.php ]] && [[ -r /var/www/html/info.php ]]; then
    print_info "PHP 测试页面创建成功"
else
    print_warn "PHP 测试页面创建可能存在问题"
fi

# 启用防火墙（如果 UFW 可用）
if command -v ufw &> /dev/null; then
    print_info "配置防火墙..."
    ufw allow OpenSSH
    ufw allow 'Nginx Full'
    ufw --force enable
fi

# 完成安装
print_info "安装完成！"
echo
print_info "=== 安装摘要 ==="
print_info "Nginx 已安装并运行在端口 80"
print_info "MariaDB 已安装 (用户名: root)"
print_info "PHP 8.2 已安装 (FPM 模式)"
print_info "phpMyAdmin 已安装在: $pma_path (默认: /phpmyadmin)"
echo
print_info "访问 phpMyAdmin: http://\$(hostname -I | awk '{print \$1}')$pma_path"
print_info "访问 PHP 信息页面: http://\$(hostname -I | awk '{print \$1}')/info.php (使用后请删除)"
echo
print_info "=== 数据库信息 ==="
print_info "MySQL Root 密码: $mysql_root_pass"
if [ -n "$pma_user" ] && [ -n "$pma_pass" ]; then
    print_info "phpMyAdmin 控制用户: $pma_user"
    print_info "phpMyAdmin 控制用户密码: $pma_pass"
    print_info "(此用户用于 phpMyAdmin 高级功能，如配置存储等)"
else
    print_info "未创建 phpMyAdmin 控制用户"
    print_info "(可使用 MySQL root 用户或其他数据库用户登录 phpMyAdmin)"
fi
echo
print_warn "安全提示: 请在使用 phpMyAdmin 后删除 /var/www/html/info.php 文件"
print_warn "安全提示: 请妥善保存密码信息"
print_info ""
# 清理临时文件
print_info "清理临时文件..."
rm -rf /tmp/phpMyAdmin-5.2.1-all-languages*
print_info "清理完成"

print_info "=== 生产环境安全建议 ==="
print_info "1. 考虑配置 SSL/TLS 证书以启用 HTTPS 访问"
print_info "2. 定期更新系统和软件包"
print_info "3. 配置适当的防火墙规则"
print_info "4. 限制对服务器的 SSH 访问"
print_info "5. 定期备份数据库和重要文件"
print_info "6. 考虑使用 WAF (Web Application Firewall)"
print_info "7. 监控系统日志以发现异常活动"
print_info "8. 定期检查安全漏洞和补丁"

# 完成信息
echo
print_info "安装和验证完成！"
print_info "所有服务已启动并验证正常运行"
print_info "请根据上面显示的信息访问您的服务"

EOF
