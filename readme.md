# Debian 12 LNMP + phpMyAdmin 一键安装脚本

一键安装脚本，用于在 Debian 12 系统上部署完整的 LNMP (Linux, Nginx, MySQL/MariaDB, PHP) 环境，并集成 phpMyAdmin 数据库管理工具。

## 功能特点

- 安装最新的 Nginx、MariaDB、PHP 8.2
- 集成 phpMyAdmin 数据库管理工具
- 支持自定义配置（MySQL 密码、phpMyAdmin 访问路径等）
- 可选的 phpMyAdmin 控制用户配置
- 可选的访问来源限制
- 包含安全配置和生产环境建议
- 安装后服务验证和错误处理

## 系统要求

- Debian 12 (推荐精简安装)
- 至少 500MB 可用磁盘空间
- root 或 sudo 权限
- 稳定的网络连接

## 安装步骤

1. 下载脚本
   ```bash
   wget https://raw.githubusercontent.com/mickey-cheng/debian-lnmp/refs/heads/main/lnmp_install.sh 
   # 或者从本地获取
   ```

2. 给脚本赋予执行权限
   ```bash
   chmod +x lnmp_install.sh 
   ```

3. 以 root 权限运行脚本
   ```bash
   sudo ./lnmp_install.sh
   ```

4. 按提示输入自定义配置信息

## 配置选项

安装过程中，脚本会提示您配置以下选项：

- **MySQL root 密码**：数据库管理员密码（可自动生成）
- **phpMyAdmin 控制用户**：是否创建用于高级功能的控制用户
- **phpMyAdmin 访问路径**：自定义访问路径（默认 /phpmyadmin）
- **访问来源限制**：是否限制 phpMyAdmin 访问仅允许特定 IP

## 安装后信息

安装完成后，脚本会显示以下信息：

- **访问 phpMyAdmin**：`http://<服务器IP>/phpmyadmin`（或自定义路径）
- **访问 PHP 信息页面**：`http://<服务器IP>/info.php`
- **数据库信息**：MySQL root 密码等
- **安全提示**：生产环境建议

## 安全建议

1. 安装完成后，请删除测试页面：
   ```bash
   sudo rm /var/www/html/info.php
   ```

2. 考虑配置 SSL/TLS 证书启用 HTTPS 访问

3. 定期更新系统和软件包

4. 配置适当的防火墙规则

5. 限制对服务器的 SSH 访问

6. 定期备份数据库和重要文件

## 服务管理

- **Nginx**：
  - 启动：`sudo systemctl start nginx`
  - 停止：`sudo systemctl stop nginx`
  - 重启：`sudo systemctl restart nginx`
  - 状态：`sudo systemctl status nginx`

- **MariaDB**：
  - 启动：`sudo systemctl start mariadb`
  - 停止：`sudo systemctl stop mariadb`
  - 重启：`sudo systemctl restart mariadb`
  - 状态：`sudo systemctl status mariadb`

- **PHP-FPM**：
  - 启动：`sudo systemctl start php8.2-fpm`
  - 停止：`sudo systemctl stop php8.2-fpm`
  - 重启：`sudo systemctl restart php8.2-fpm`
  - 状态：`sudo systemctl status php8.2-fpm`

## 故障排除

1. **Nginx 启动失败**：
   - 检查端口 80 是否被占用：`sudo netstat -tlnp | grep :80`
   - 检查配置文件语法：`sudo nginx -t`

2. **MariaDB 连接问题**：
   - 检查服务状态：`sudo systemctl status mariadb`
   - 重置 root 密码：参考 MariaDB 官方文档

3. **phpMyAdmin 访问问题**：
   - 检查 Nginx 配置：`sudo nginx -t`
   - 确认访问路径是否正确

## 自定义配置文件位置

- **Nginx 配置**：`/etc/nginx/sites-available/default`
- **phpMyAdmin 配置**：`/usr/share/phpmyadmin/config.inc.php`
- **PHP 配置**：`/etc/php/8.2/fpm/php.ini`
- **MariaDB 配置**：`/etc/mysql/mariadb.conf.d/`

## 更新日志

- **v1.0**：初始版本，支持 Debian 12 一键安装 LNMP + phpMyAdmin
- **v1.1**：添加错误处理、服务验证和安全配置
- **v1.2**：增加自定义配置选项和访问限制功能

## 许可证

本脚本为开源项目，仅供学习和参考使用。

## 注意事项

- 建议在干净的 Debian 12 系统上运行此脚本
- 安装过程中会自动重启 Web 服务器
- 请务必妥善保存数据库密码等敏感信息
- 生产环境使用前请进行全面测试
