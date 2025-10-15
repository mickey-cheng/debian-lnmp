# Debian 13 LNMP 一键安装脚本

适用于 Debian 13 系统的 LNMP（Linux + Nginx + MySQL + PHP）环境一键安装脚本，支持最小化系统安装，包含 phpMyAdmin 数据库管理工具。

## ✨ 功能特点

- 🚀 **一键安装**：自动完成所有组件的安装和配置
- 🔒 **安全增强**：密码输入不回显，配置文件权限保护
- 📊 **完整日志**：详细记录安装过程，便于排查问题
- 🛡️ **错误处理**：完善的错误检测和处理机制
- 🎯 **交互配置**：MySQL 密码、端口、远程访问等可自定义
- 📦 **最小系统支持**：自动安装必要依赖，支持最小化安装的系统
- 🗄️ **phpMyAdmin**：可选安装 Web 数据库管理工具，已修复 Nginx 路由配置

## 📋 系统要求

- **操作系统**：Debian 13（也可能兼容 Debian 11/12）
- **权限**：需要 root 权限
- **网络**：需要联网访问软件源
- **磁盘空间**：至少 2GB 可用空间

## 🔧 安装组件

| 组件 | 版本 | 说明 |
|------|------|------|
| **Nginx** | 最新稳定版 | Web 服务器 |
| **MySQL** | MariaDB 最新版 | 数据库服务器 |
| **PHP** | 系统默认版本 | PHP-FPM + 常用扩展 |
| **phpMyAdmin** | 最新版 | 数据库管理工具（可选）|

### PHP 扩展包括

- php-fpm（FastCGI 进程管理器）
- php-cli（命令行接口）
- php-mysql（MySQL 数据库支持）
- php-curl（HTTP 请求支持）
- php-gd（图像处理）
- php-mbstring（多字节字符串）
- php-xml（XML 解析）
- php-zip（压缩文件处理）
- php-bcmath（高精度数学）
- php-intl（国际化扩展）
- php-json（JSON 支持）
- php-soap（SOAP 协议）
- php-xmlrpc（XML-RPC 支持）

## 🚀 快速开始

### 1. 下载脚本

```bash
# 使用 wget
wget https://raw.githubusercontent.com/你的用户名/仓库名/main/lnmp_install.sh

# 或使用 curl
curl -O https://raw.githubusercontent.com/你的用户名/仓库名/main/lnmp_install.sh

# 或直接克隆仓库
git clone https://github.com/你的用户名/仓库名.git
cd 仓库名
```

### 2. 添加执行权限

```bash
chmod +x lnmp_install.sh
```

### 3. 运行脚本（需要 root 权限）

```bash
# 方式一：使用 sudo（推荐）
sudo bash lnmp_install.sh

# 方式二：切换到 root 用户
su -
./lnmp_install.sh
```

### 4. 按提示配置

脚本会依次询问：
- MySQL root 用户名（默认：root）
- MySQL root 密码（默认：root123456，**强烈建议修改**）
- MySQL 监听端口（默认：3306）
- 是否允许远程访问 MySQL（默认：否）
- 是否安装 phpMyAdmin（默认：是）
- phpMyAdmin 访问路径（默认：/phpmyadmin，**建议修改**）

## 📝 配置说明

### 默认配置

- **网站目录**：`/var/www/html`
- **域名**：`localhost`
- **Nginx 配置**：`/etc/nginx/sites-available/localhost.conf`
- **PHP 配置**：`/etc/php/[版本]/fpm/php.ini`
- **MySQL 配置**：`/etc/mysql/mariadb.conf.d/50-server.cnf`
- **安装报告**：`/root/lnmp_install_report.txt`
- **安装日志**：`/root/lnmp_install.log`

### 访问地址

安装完成后：
- **测试页面**：`http://服务器IP/`
- **phpMyAdmin**：`http://服务器IP/phpmyadmin`（如已安装）

## 🔐 安全建议

1. **修改默认密码**：不要使用默认的 `root123456` 密码
2. **限制远程访问**：如非必要，不要开启 MySQL 远程访问
3. **配置防火墙**：限制对敏感端口的访问
4. **修改 phpMyAdmin 路径**：使用非默认路径增加安全性
5. **定期更新**：及时更新系统和软件包
6. **定期备份**：定期备份数据库和网站文件

### 防火墙配置示例（使用 ufw）

```bash
# 安装 ufw
apt install ufw

# 允许 SSH（重要！先设置这个，避免被锁在外面）
ufw allow 22/tcp

# 允许 HTTP
ufw allow 80/tcp

# 允许 HTTPS
ufw allow 443/tcp

# 如需 MySQL 远程访问（谨慎开启，建议限制 IP）
ufw allow from 你的IP地址 to any port 3306

# 启用防火墙
ufw enable

# 查看防火墙状态
ufw status
```

## 🛠️ 常用命令

### 服务管理

```bash
# 重启 Nginx
systemctl restart nginx

# 重启 PHP-FPM（根据实际 PHP 版本，如 8.2）
systemctl restart php8.2-fpm

# 重启 MySQL
systemctl restart mariadb

# 查看服务状态
systemctl status nginx
systemctl status php8.2-fpm
systemctl status mariadb

# 停止服务
systemctl stop nginx
systemctl stop php8.2-fpm
systemctl stop mariadb

# 启动服务
systemctl start nginx
systemctl start php8.2-fpm
systemctl start mariadb
```

### 查看日志

```bash
# Nginx 访问日志
tail -f /var/log/nginx/localhost_access.log

# Nginx 错误日志
tail -f /var/log/nginx/localhost_error.log

# PHP-FPM 错误日志
tail -f /var/log/php8.x-fpm.log

# MySQL 错误日志
tail -f /var/log/mysql/error.log

# 安装日志
cat /root/lnmp_install.log

# 查看最近 50 行日志
tail -50 /root/lnmp_install.log
```

### MySQL 管理

```bash
# 登录 MySQL
mysql -u root -p

# 创建数据库
mysql -u root -p -e "CREATE DATABASE mydb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 创建用户并授权
mysql -u root -p -e "CREATE USER 'username'@'localhost' IDENTIFIED BY 'password';"
mysql -u root -p -e "GRANT ALL PRIVILEGES ON mydb.* TO 'username'@'localhost';"
mysql -u root -p -e "FLUSH PRIVILEGES;"

# 查看所有数据库
mysql -u root -p -e "SHOW DATABASES;"

# 查看所有用户
mysql -u root -p -e "SELECT User, Host FROM mysql.user;"

# 备份数据库
mysqldump -u root -p mydb > mydb_backup.sql

# 恢复数据库
mysql -u root -p mydb < mydb_backup.sql
```

## 📂 目录结构

```
/var/www/html/              # 网站根目录
├── index.php               # 测试页面
└── phpmyadmin/             # phpMyAdmin（符号链接）

/etc/nginx/
├── sites-available/
│   └── localhost.conf      # Nginx 站点配置
└── sites-enabled/
    └── localhost.conf      # 启用的站点（符号链接）

/etc/php/8.x/
├── fpm/
│   ├── php.ini            # PHP 配置文件
│   └── pool.d/
│       └── www.conf       # PHP-FPM 进程池配置
└── cli/
    └── php.ini            # PHP CLI 配置

/etc/mysql/
└── mariadb.conf.d/
    └── 50-server.cnf      # MySQL 配置文件
```

## 🐛 故障排查

### Nginx 无法启动

```bash
# 测试配置文件
nginx -t

# 查看错误日志
tail -50 /var/log/nginx/error.log

# 检查端口占用
netstat -tuln | grep :80
# 或
ss -tuln | grep :80

# 查看 Nginx 进程
ps aux | grep nginx

# 检查 Nginx 服务状态
systemctl status nginx
```

### PHP-FPM 无法启动

```bash
# 检查配置（根据实际版本）
php-fpm8.2 -t

# 查看 socket 文件
ls -la /run/php/

# 检查进程
ps aux | grep php-fpm

# 查看服务状态
systemctl status php8.2-fpm

# 查看日志
journalctl -u php8.2-fpm -n 50
```

### MySQL 无法连接

```bash
# 检查服务状态
systemctl status mariadb

# 查看错误日志
tail -50 /var/log/mysql/error.log

# 检查端口
netstat -tuln | grep :3306
# 或
ss -tuln | grep :3306

# 测试连接
mysql -u root -p

# 检查 MySQL 进程
ps aux | grep mysql
```

### phpMyAdmin 问题

#### 403 Forbidden 错误（已修复）

**v1.0 版本已修复此问题**，脚本现在会自动在 Nginx 配置中添加正确的 phpMyAdmin 路由配置：

```nginx
# phpMyAdmin 配置
location ^~ /phpmyadmin {
    alias /usr/share/phpmyadmin;
    index index.php;
    
    location ~ ^/phpmyadmin/(.+\.php)$ {
        alias /usr/share/phpmyadmin/$1;
        fastcgi_pass unix:/run/php/phpX.X-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $request_filename;
        include fastcgi_params;
    }
    
    location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
        alias /usr/share/phpmyadmin/$1;
    }
}
```

如仍遇到问题，可手动检查：

```bash
# 检查目录权限
ls -la /var/www/html/phpmyadmin
ls -la /usr/share/phpmyadmin

# 检查符号链接
ls -la /var/www/html/ | grep phpmyadmin

# 检查 Nginx 配置
cat /etc/nginx/sites-available/localhost.conf | grep -A 20 "phpmyadmin"

# 修复权限
chown -R www-data:www-data /usr/share/phpmyadmin
chmod -R 755 /usr/share/phpmyadmin

# 测试并重启 Nginx
nginx -t
systemctl restart nginx
```

### 网站显示 502 Bad Gateway

```bash
# 检查 PHP-FPM 是否运行
systemctl status php8.x-fpm

# 检查 PHP-FPM socket
ls -la /run/php/

# 重启 PHP-FPM
systemctl restart php8.x-fpm

# 查看 Nginx 错误日志
tail -50 /var/log/nginx/localhost_error.log
```

## 📊 安装报告

安装完成后，详细信息保存在 `/root/lnmp_install_report.txt`，包含：

- 安装时间
- 网站目录和访问地址
- MySQL 配置信息
- phpMyAdmin 访问地址
- 配置文件位置
- 日志文件位置
- 安全建议
- 防火墙配置参考
- 常用命令

**查看安装报告**：
```bash
cat /root/lnmp_install_report.txt
```

## ⚠️ 注意事项

1. **备份数据**：如果系统已有数据，请先备份
2. **最小化系统**：脚本会自动安装必要依赖，但仍需确保网络正常
3. **内存要求**：建议至少 512MB RAM，推荐 1GB 以上
4. **生产环境**：使用前请在测试环境验证
5. **密码安全**：安装报告包含敏感信息，权限已设置为 600（仅 root 可读）
6. **端口冲突**：确保 80、3306 端口未被占用
7. **系统更新**：建议先更新系统再运行脚本

## 🔄 版本历史

### v1.0 (2025-10-15)
- ✅ 修复 phpMyAdmin 403 错误：添加正确的 Nginx location 配置
- ✅ 使用 `alias` 指令替代符号链接方式
- ✅ 添加 phpMyAdmin PHP 文件和静态资源的独立处理规则
- ✅ 完善错误处理和日志记录
- ✅ 支持最小化 Debian 系统安装

## 🔄 卸载

如需卸载 LNMP 环境：

```bash
# 停止服务
systemctl stop nginx mariadb
systemctl stop php*-fpm

# 卸载软件包
apt remove --purge nginx php* mariadb-server mariadb-client phpmyadmin

# 删除配置文件
rm -rf /etc/nginx
rm -rf /etc/php
rm -rf /etc/mysql
rm -rf /var/lib/mysql
rm -rf /var/www/html

# 清理依赖
apt autoremove
apt autoclean
```

**⚠️ 警告**：卸载会删除所有数据库和网站文件，请务必提前备份！

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

如果你发现 bug 或有改进建议，请：
1. Fork 本仓库
2. 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交你的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开一个 Pull Request

## 📄 许可证

MIT License

## 📧 支持

如遇问题，请：
1. 查看 `/root/lnmp_install.log` 日志文件
2. 查看本文档的故障排查部分
3. 提交 Issue 并附上错误信息和日志

## 🙏 致谢

感谢所有为开源社区做出贡献的开发者！

---

**最后更新**：2025-10-15  
**脚本版本**：v1.0  
**作者**：Your Name  
**仓库地址**：https://github.com/你的用户名/仓库名
