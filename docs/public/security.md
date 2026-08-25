# 安全部署

SimAdminHub 会集中保存短信正文、手机号、ICCID、IMEI、通知通道密钥和设备运行数据，也可以发送短信、修改蜂窝设置和重启设备。系统支持单管理员密码与 Session，但密码保护默认关闭以兼容已有安装，网络边界仍是必要的安全措施。

## 必须遵守的边界

- 不要把 Hub 的 `3001` 端口直接暴露到公网。
- 首次部署后在“系统设置 > 安全”中设置管理员密码并启用密码保护。
- 只允许受信任的管理终端访问 Hub，使用主机防火墙、VLAN、VPN 或反向代理限制来源。
- 需要远程访问时，反向代理必须提供 TLS、来源限制并支持 WebSocket。
- 不要把 `/etc/simadminhub`、`/etc/simadmin-host-agent`、数据库、备份或日志上传到公开位置。

顶部“隐藏敏感信息”按钮只影响浏览器显示，不会加密数据库，也不能代替访问认证。

## 反向代理

Hub 的登录 Session 保护管理 API，前端在未登录或会话失效时跳转到登录页。反向代理必须传递 `X-Forwarded-Proto`；只有识别为 HTTPS 时，Hub 才会为 Cookie 增加 `Secure` 属性。`/health` 与 `/metrics` 不使用浏览器 Session，应仅允许内网监控访问。

设备使用 `/agent` 注册、认领和建立 WebSocket，不能套用需要跳转或输入密码的交互式网页登录。该路径应保留 Agent 自身的 Bearer 认证头，并通过来源网段、VPN、mTLS 或独立入口限制访问。必须允许 `/agent/ws` 的 WebSocket Upgrade，并对注册请求限制频率。

不要在代理访问日志中记录以下内容：

- `Authorization` 请求头。
- Agent 注册、认领和 WebSocket 请求参数。
- 短信正文、通知通道配置和备份下载响应。

## 文件权限

标准安装脚本会使用独立服务账户运行 Hub，并限制环境文件和数据目录权限。人工迁移文件后应恢复所有者：

```bash
sudo chown -R simadminhub:simadminhub /var/lib/simadminhub
sudo chown root:simadminhub /etc/simadminhub/simadminhub.env
sudo chmod 640 /etc/simadminhub/simadminhub.env
```

Host Agent 需要访问蜂窝模组控制端点，默认以 systemd 系统服务运行。不要向不受信任用户开放 `/dev/ttyUSB*`、`/dev/ttyACM*` 或 `/dev/cdc-wdm*`。

标准 Docker 配置使用 host 网络支持局域网 mDNS 自动发现，Hub 会直接监听宿主机的 `3001` 端口；必须使用宿主机防火墙限制可访问网段。为了支持在系统设置中随时一键启用 Host Agent，容器还会预先映射 `/dev` 与只读 `/sys`，并授予 privileged 权限。即使 Host Agent 开关关闭，这些容器权限仍然存在；因此只应在受信任的 Linux 宿主机上运行镜像，并限制 Docker 管理权限。

## 备份与密钥

- 定期下载 Hub 备份到另一台受控设备，并对备份存储启用磁盘加密。
- 通知通道密钥和管理员密码哈希保存在 Hub 数据库中；选择“Hub 配置”的备份也会包含这些内容，数据库和备份应按密钥材料保护。
- 删除设备不会擦除已经下载的备份。
- 对外分享诊断信息前，先检查其中是否包含设备地址、IMEI、手机号和通知目标。

## 密码恢复

忘记密码时应登录 Hub 宿主机重置，操作会使现有 Web 会话全部失效：

```bash
sudo simadminhub --database /var/lib/simadminhub/simadminhub.db auth reset-password
```

`auth clear` 会清除管理员密码并关闭现有会话，Web 界面随后回到可重新设置密码的状态。执行恢复命令需要读取和修改 Hub 数据库的系统权限。

## 上线检查

1. 确认已设置管理员密码、启用密码保护，并配置合理的空闲超时。
2. 确认防火墙只允许预期网段或反向代理访问 `3001`。
3. 从未登录浏览器和未授权网络验证 Hub 管理 API 均不可访问。
4. 创建一次备份并下载到其他存储位置。
5. 测试通知通道时使用非生产接收端，确认不会泄露真实短信。
6. 检查 `journalctl` 和代理日志没有记录令牌或短信正文。

## 漏洞反馈

优先使用 `3899/SimAdminHub` 公开仓库的 GitHub Security Advisory 私密报告入口。不要在公开 Issue 中直接提交可利用细节、令牌、数据库或真实短信。
