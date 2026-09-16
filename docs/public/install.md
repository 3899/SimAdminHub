# 安装与部署

本文面向 SimAdminHub 使用者，覆盖安装、访问后台、设备接入、升级和卸载。

## 安装前确认

### 部署位置

Hub 可以部署在独立 Linux 服务器、软路由、NAS、虚拟机，或其中一台 SimAdmin 设备所在的 Linux 主机。主机需要持续运行，并能与被管理设备互通。

Hub 可以直接安装在 UFI003 等完整 Linux 蜂窝设备本机。发布包内置独立 Device Service，检测到本机平台蜂窝硬件后自动通过回环地址接入 Hub，并提供完整 SimAdmin 能力；普通服务器上该服务保持沉寂。若同机已经安装或运行 SimAdmin，安装器会保持 Device Service 停止并优先复用现有 SimAdmin，避免两个服务争用 ModemManager、QMI 或 APDU；SimAdmin 使用 `3000`、Hub 使用 `3001`，两者继续使用各自的数据目录。现有 SimAdmin 在 Hub 中按完整 SimAdmin 和网络接入语义管理，继续保留设备自己的备份与 OTA。现有 SimAdmin 仍处于单设备模式时，需要先明确切换到集中管理模式，Hub 不会静默修改其工作模式。

### 支持架构与发布包

公开 Release 提供三个固定名称的归档：

| 主机架构                      | 发布包                         |
| ----------------------------- | ------------------------------ |
| `x86_64` / `amd64`            | `simadminhub-x86_64.tar.gz`    |
| `aarch64` / `arm64`           | `simadminhub-aarch64.tar.gz`   |
| `armv7` / `armv7l` / `armhf`  | `simadminhub-armv7.tar.gz`     |

主机与浏览器要求

- 正式安装仅支持带 systemd 的 Linux。
- 主机需要 `bash`、`curl`、`tar`、`sha256sum` 和可用的 root 或 `sudo` 权限。
- 建议启用 NTP 时间同步；错误的系统时间会影响短信排序、自动化调度、心跳和通知日志。
- 数据库、短信和备份共享数据盘空间，应根据短信量与保留策略持续监控 `/var/lib/simadminhub`。
- 管理后台使用当前稳定版 Chrome、Edge 或 Firefox；移动浏览器适合查看和轻量操作。

### 网络要求

- 浏览器需要能够访问 Hub 的 TCP `3001` 端口。
- 网络设备接入时，Hub 和 SimAdmin 至少需要有一个方向可以建立连接。
- 局域网自动发现依赖 mDNS，通常只能在同一二层网络使用。
- 接入完成后，由 SimAdmin 主动维持到 Hub 的 WebSocket。
- 宿主机直连模组需要在实际连接模组的 Linux 主机运行 Host Agent。

### 版本兼容

**安装 Hub 前，请先将所有子设备升级到最新版 SimAdmin。** SimAdminHub 依赖新版 SimAdmin 内置的 Hub Agent、接入接口和通信协议；旧版 SimAdmin 即使单设备后台工作正常，也无法完成 Hub 接入，常见表现是“请求的接口不存在”、自动发现后无法连接等。

Hub 与 SimAdmin Agent 使用明确的协议版本，不兼容时会拒绝 WebSocket 会话，不能只根据页面能否打开判断兼容。应使用同一发布周期明确支持 SimAdminHub 的最新版 SimAdmin。

升级后如果设备无法连接，先比较 Hub 与设备版本并查看双方日志。不要通过删除设备反复接入来规避协议不兼容。

## 快速安装

在支持 systemd 的 Linux 主机执行：

```bash
curl -fsSL https://raw.githubusercontent.com/3899/SimAdminHub/main/install.sh | sh
```

### 国内网络环境

官方 Raw 地址无法访问时，可以通过首选加速地址获取脚本：

```bash
curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/3899/SimAdminHub/main/install.sh | sh
```

脚本内部下载自身和 Release 归档时，会依次尝试以下三个前缀，最后回退 GitHub 官方地址：

```text
https://gh-proxy.com/
https://ghproxy.net/
https://githubproxy.cc/
```

可以通过 `GH_PROXY` 和 `GH_PROXY_FALLBACKS` 环境变量覆盖。第三方加速地址不由 SimAdminHub 控制；安全要求较高时应使用官方地址。

脚本会在需要时自动通过 `sudo` 取得 root 权限，识别主机架构，下载对应的最新归档并安装。默认行为是：

- 安装并启动 `simadminhub.service`。
- 安装独立的 `simadmin-host-agent.service`。
- 安装独立的 `simadmin-device-service.service`；仅检测到本机平台蜂窝硬件时运行。
- 安装最小权限的在线更新助手及 systemd Path Unit，用于处理后台提交的正式 Release 更新。
- Host Agent 初始保持关闭，不启动进程，也不占用常驻运行资源。
- 安装 Host Agent 状态控制单元，使其可以在 Hub“系统设置 > 概览”中启用或关闭。

只安装 Hub：

```bash
curl -fsSL https://raw.githubusercontent.com/3899/SimAdminHub/main/install.sh | sh -s -- --component hub
```

只在另一台宿主机安装 Host Agent 时，必须提供可访问的 Hub 地址：

```bash
curl -fsSL https://raw.githubusercontent.com/3899/SimAdminHub/main/install.sh | sh -s -- \
  --component host-agent --hub-url http://HUB地址:3001
```

单独安装的 Host Agent 会直接启用并运行，由目标 Hub 管理；它不依赖同机安装 Hub。安装器会同时部署同包的 `simadmin-device-service` 作为按需 WiFi Calling Worker，但不会安装或启动本机 Device Service 单元。指定版本时增加 `--version 0.0.5`，版本号可以带或不带 `v`。

安装完成后检查：

```bash
systemctl status simadminhub
curl -fsS http://127.0.0.1:3001/health
```

从局域网其他电脑或手机访问：

```text
http://HUB主机IP:3001
```

管理员密码默认关闭以兼容已有安装。首次部署后进入“系统设置 > 安全”，先设置管理员密码，再启用密码保护并按需要调整会话有效期和空闲超时。不要把 `3001` 直接暴露到公网；远程访问应使用 TLS 反向代理、VPN 或其他可信网络方案。

上线前还应完成[安全部署](security.md)中的检查。

## Docker 安装

公开镜像随版本标签构建，支持 `x86_64` 和 `aarch64`。推荐使用 Compose 保存配置：

```yaml
services:
  simadminhub:
    image: ghcr.io/3899/simadminhub:latest
    container_name: simadminhub
    restart: unless-stopped
    network_mode: host
    privileged: true
    environment:
      SIMADMINHUB_JSON_LOG: "true"
      RUST_LOG: simadminhub=info,tower_http=info
    volumes:
      - simadminhub:/app/data
      - /dev:/dev
      - /sys:/sys:ro

volumes:
  simadminhub:
    name: simadminhub
```

在 Compose 文件目录执行：

```bash
docker compose pull
docker compose up -d
docker compose ps
curl -fsS http://127.0.0.1:3001/health
```

也可以直接运行：

```bash
docker volume create simadminhub
docker run -d --name simadminhub --restart unless-stopped \
  --network host \
  --privileged \
  -v simadminhub:/app/data \
  -v /dev:/dev \
  -v /sys:/sys:ro \
  ghcr.io/3899/simadminhub:latest
```

Docker 镜像同时包含 Hub、Host Agent 和 Device Service，三者始终是独立进程。Host Agent 默认关闭且不会创建进程；需要管理当前 Docker 宿主机上的 USB/PCIe 蜂窝模组时，在“系统设置 > 概览”中打开“本机 Host Agent”即可。Device Service 会在容器检测到本机平台蜂窝硬件时自动启动，否则不创建进程。异常退出的可用服务由容器入口按当前状态重新启动。

标准 Docker 安装使用 Linux host 网络，使 Hub 直接加入宿主机网络栈并接收局域网 mDNS 组播，从而支持自动发现 SimAdmin 设备。host 网络没有端口映射，Hub 直接占用宿主机 TCP `3001`；安装前应确认该端口未被其他程序使用。该模式仅适用于 Linux Docker 主机，包括群晖 Container Manager，不适用于 Docker Desktop。

容器同时获得 `/dev`、只读 `/sys` 和 privileged 硬件访问权限。这样即使当前关闭 Host Agent，后续也能在系统设置中一键启用，无需重新创建或修改容器。关闭 Host Agent 只代表不运行硬件控制进程，不会撤销容器已经获得的权限。

接入设备时应通过宿主机局域网 IP 打开 Hub，例如 `http://192.168.1.10:3001`，不要使用浏览器中的 `127.0.0.1`，否则设备可能获得无法回连的 Hub 地址。host 网络只能解决容器网络隔离问题；Hub 与 SimAdmin 仍需位于允许 mDNS 组播的同一二层网络。不同 VLAN、访客网络或禁用组播时，应直接填写设备地址。Docker Host Agent 默认使用 Direct AT、QMI 或 MBIM；如需复用宿主机 ModemManager，还必须按宿主机发行版额外映射系统 D-Bus。

已经使用 bridge 网络运行旧容器时，不能只拉取新镜像，必须保留 `simadminhub` 命名卷并重新创建容器：

- Compose 用户将配置改为上面的 `network_mode: host`，删除 `ports`，然后执行 `docker compose up -d --force-recreate`。
- `docker run` 用户执行 `docker rm -f simadminhub` 后，重新运行上面的 host 网络命令；命名卷中的数据库和配置不会被删除。
- 群晖 Container Manager 用户删除旧容器时不要删除 `simadminhub` 卷，然后使用“与 Docker Host 相同的网络”重新创建容器并挂载原卷。

升级容器不会删除命名卷：

```bash
docker compose pull
docker compose up -d
```

升级前仍应在 Hub 中创建并下载备份。固定版本部署可把 `latest` 替换为发布标签，例如 `v0.0.5`。

## 手动安装发布包

从 [SimAdminHub Releases](https://github.com/3899/SimAdminHub/releases) 下载与主机架构匹配的归档，然后执行：

```bash
tar -xzf simadminhub-x86_64.tar.gz
cd simadminhub-x86_64
sudo bash install.sh
```

`aarch64` 或 `armv7` 主机将上述文件名和目录名替换为 `simadminhub-aarch64` 或 `simadminhub-armv7`。`install.sh` 默认安装两项服务；也支持：

```bash
sudo bash install.sh --component hub
sudo bash install.sh --component host-agent --hub-url http://HUB地址:3001
```

安装器会检查主机架构和包内文件，保留已有环境文件、数据库、Host Agent 身份与绑定。升级启动或健康检查失败时，会恢复原有程序文件与服务单元。

主要安装位置：

| 内容            | 路径                                   |
| --------------- | -------------------------------------- |
| Hub 程序        | `/usr/local/bin/simadminhub`         |
| Hub 前端        | `/opt/simadminhub/frontend`          |
| Hub 配置        | `/etc/simadminhub/simadminhub.env`   |
| Hub 数据与备份  | `/var/lib/simadminhub`               |
| Host Agent 程序 | `/usr/local/bin/simadmin-host-agent` |
| Host Agent 配置 | `/etc/simadmin-host-agent/agent.env` |
| Host Agent 数据 | `/var/lib/simadmin-host-agent`       |
| Device Service 程序 | `/usr/local/bin/simadmin-device-service` |
| Device Service 配置 | `/etc/simadminhub/device-service.env` |
| Device Service 数据 | `/var/lib/simadminhub/device-service` |
| 在线更新状态与暂存 | `/var/lib/simadminhub/updates` |

## 直接运行 Hub

没有 systemd 或需要临时验证时，可以解压归档并直接启动 Hub：

```bash
mkdir -p data/backups
SIMADMINHUB_PORT=3001 \
SIMADMINHUB_DATABASE="$PWD/data/simadminhub.db" \
SIMADMINHUB_FRONTEND="$PWD/frontend" \
SIMADMINHUB_BACKUP_DIR="$PWD/data/backups" \
./bin/simadminhub
```

进程会随终端关闭而停止，数据保存在当前目录的 `data` 中。直接运行单个 Hub 二进制不会自动启动 Host Agent 或 Device Service；需要验证本机完整设备时应使用正式归档安装，或分别启动包内三个二进制。

## 接入 SimAdmin 设备

开始接入前，先在每台设备的 SimAdmin 后台完成在线更新并确认运行的是最新版。看不到集中管理模式，或切换/接入时提示“请求的接口不存在”，说明设备仍是未包含 Hub Agent 接口的旧版本，应先升级 SimAdmin，而不是反复删除或重新添加设备。

### 从 Hub 接入

1. 在设备 SimAdmin 中将工作模式切换为“集中管理”。
2. 在 Hub 中打开“添加设备”。
3. 同一局域网可选择自动发现的设备并一键接入。
4. 未自动发现时，输入完整设备地址，例如 `http://192.168.68.1:3000`。
5. 等待设备主动连接，并确认 Hub 中显示在线。

自动发现和地址接入会直接发起授权，不需要接入码，也不需要重复批准。

### 从 SimAdmin 主动连接

Hub 无法访问设备、但设备可以访问 Hub 时，可以在 SimAdmin 集中管理设置中填写 Hub 地址。设备主动注册遵循 Hub 系统设置中的授权策略：

- 自动授权：注册完成后直接连接。
- 人工确认：在 Hub“添加设备”的待确认区域批准一次。

连接成功后，SimAdmin 会显示 Hub 地址、版本、连接状态、设备 ID 和最后连接时间。

## 管理本机直连模组

### 完整蜂窝设备本机安装 Hub

正式安装会检测平台内置蜂窝硬件。检测成功且同机没有现有 SimAdmin 时，Device Service 以“本机设备”身份自动接入 Hub，接入方式为“本机设备”，控制执行器为 SimAdmin Agent。它提供完整蜂窝设备能力，但数据、备份和升级均归 Hub 管理，因此设备面板不显示“备份与恢复”和“OTA”。检测到现有 SimAdmin 时不会再启动 Device Service；现有 SimAdmin 作为完整 SimAdmin 设备接入并保留自己的备份与升级能力。

平台内置 modem 不交给 Host Agent。开启 Host Agent 后，只有额外插入的 USB/PCIe/M.2 模组会作为其他设备出现，因此一台本机蜂窝设备可以同时拥有一台完整“本机设备”和多台额外直连模组。

### 额外直连设备与普通模组

默认完整安装已经安装 Host Agent，但不会启动它。需要管理与 Hub 同机连接的 USB/PCIe 蜂窝模组时，在“系统设置 > 概览”启用“本机 Host Agent”。关闭开关后，Hub 会停止并禁用 Host Agent 服务。

Host Agent 始终是独立服务进程。开关只控制服务是否运行，不会把硬件探测或控制逻辑加载到 Hub 进程。

正式发布包和 Docker 镜像不内置 `lpac`。检测到本机蜂窝硬件或首次启用 Host Agent 时，安装器复用 SimAdmin 的兼容选择逻辑，按架构、glibc 和兼容修订号在线安装到 `/opt/simadmin/lpac`；下载失败不会阻断 Hub 和基础短信/蜂窝能力。`libqmi-glib`、`libmbim-glib` 等依赖只保留一个真实文件，其余名称使用链接。Host Agent 只有在 eUICC 只读探测成功且对应 QMI、MBIM 或 AT APDU 驱动可用时，才显示 Profile 管理能力。

WiFi Calling 同样按真实能力开放。Host Agent 会对明确的 QMI、MBIM 或 AT 控制端点执行只读 USIM 应用探测，成功后才在 SIM 卡页面显示功能开关。开启功能后才启动该设备的独立 Worker 并显示 WiFi Calling 页签；关闭功能、设备离线或控制端点失效后自动停止 Worker。多台设备各自使用独立状态、网络接口和短信存储，不会共用第一个 Modem。宿主机还必须具备可用的 WLAN/有线互联网、`/dev/net/tun` 和相应网络管理权限，运营商与套餐本身也必须支持 WiFi Calling。

网络设备和宿主机直连模组的自动发现只在“添加设备”窗口打开期间运行。关闭窗口后，Hub 停止 mDNS 浏览并通知 Host Agent 停止新设备全量扫描；已绑定模组仍保留轻量在线检查，不影响状态和控制。浏览器异常退出时，发现会话会在短租约过期后自动停止。

Host Agent 上报候选设备后会先判断设备内部是否运行 SimAdmin：

- 检测到 SimAdmin：显示“接入完整设备”，一次点击完成设备 Agent 接入、身份合并和控制权切换。Host Agent 只保留 USB 插拔观察，不读取 SIM、不消费短信，也不执行基带命令。
- 未检测到 SimAdmin：显示“配置并添加”，由 Host Agent 根据实际控制端点生成动态能力。完整 Linux 设备和普通模组都不会因为名称或型号而强制显示不支持的功能。

添加普通直连设备时：

1. 选择需要管理的模组。
2. 设置设备名称。
3. 选择硬件绑定或物理槽位绑定。
4. 确认明确的 Direct AT、QMI、MBIM 或 ModemManager 控制端点。

系统不会默认选取扫描到的第一个 modem，避免多模组主机绑定错误。

### Host Agent 后端依赖

安装器不会自动修改发行版的蜂窝网络软件。启用 Host Agent 前，根据所选控制后端准备工具：

| 后端         | 宿主机要求                                                |
| ------------ | --------------------------------------------------------- |
| Direct AT    | 可访问明确的 `/dev/serial/by-id/*`、`/dev/ttyUSB*` 或 `/dev/ttyACM*` 控制端点 |
| QMI          | `qmicli`，通常由 `libqmi-utils` 提供                  |
| MBIM         | `mbimcli`，通常由 `libmbim-utils` 提供                |
| ModemManager | 正常运行的`ModemManager` 和 `mmcli`                   |
| Network Only | 只上报网络能力，不提供短信和基带控制                      |

发现窗口打开时，Host Agent 会优先使用 `/dev/serial/by-id` 稳定路径，执行 `mmcli -L` 全量枚举 ModemManager 对象，并以短超时发送只读 AT 查询识别 IMEI、SIM、短信、数据、APN、USSD、APDU 和温度能力。eSIM 只有在独立逻辑通道成功选择 eUICC 管理应用后才显示；仅支持普通 APDU 不等于支持 eSIM。探测不会切换 Profile、拨号、修改配置或重启基带。`udevadm` 用于热插拔唤醒；缺少时仍会在发现窗口打开期间周期刷新，但设备变化出现得更慢。使用 `auto` 时会根据 ModemManager、驱动和已验证控制端点选择后端；不支持的能力不会显示。可通过以下命令提前检查：

```bash
command -v udevadm
command -v mmcli
command -v qmicli
command -v mbimcli
```

## 管理远程宿主机模组

在连接模组的远程 Linux 主机执行仅安装 Host Agent 的命令，并传入 Hub 地址。安装后检查：

```bash
systemctl status simadmin-host-agent
journalctl -u simadmin-host-agent -f
```

如需修改 Hub 地址，编辑 `/etc/simadmin-host-agent/agent.env` 后重启服务：

```bash
sudoedit /etc/simadmin-host-agent/agent.env
sudo systemctl restart simadmin-host-agent
```

## Hub 常用配置

Hub 环境文件为 `/etc/simadminhub/simadminhub.env`：

```text
SIMADMINHUB_PORT=3001
SIMADMINHUB_DATABASE=/var/lib/simadminhub/simadminhub.db
SIMADMINHUB_FRONTEND=/opt/simadminhub/frontend
SIMADMINHUB_BACKUP_DIR=/var/lib/simadminhub/backups
SIMADMINHUB_HOST_AGENT_CONTROL_FILE=/var/lib/simadminhub/control/host-agent.state
SIMADMINHUB_JSON_LOG=false
RUST_LOG=simadminhub=info,tower_http=info
```

修改后执行：

```bash
sudo systemctl restart simadminhub
```

Hub 会根据当前访问地址或到目标设备的实际路由自动推导 Agent 回连地址，不需要配置宿主机 IP。

## 反向代理

代理必须支持 WebSocket Upgrade，并将页面、`/api` 和 `/agent` 转发到同一个 Hub 实例。Nginx 最小示例：

```nginx
location / {
    proxy_pass http://127.0.0.1:3001;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

反向代理必须传递正确的 `X-Forwarded-Proto`，HTTPS 请求下 Hub 才会为登录 Cookie 增加 `Secure` 属性。页面与 `/api` 使用 Hub 单管理员会话；设备 `/agent` 路径保留 Agent Bearer 认证并单独限制网络来源，不能跳转到网页登录。实际部署仍需 TLS 和来源限制，不要在代理日志中记录 `Authorization` 请求头。

忘记管理员密码时，可登录 Hub 宿主机执行：

```bash
sudo simadminhub --database /var/lib/simadminhub/simadminhub.db auth reset-password
```

如需清除管理员密码并重新进入首次设置状态，执行：

```bash
sudo simadminhub --database /var/lib/simadminhub/simadminhub.db auth clear
```

## 异机灾备恢复

当前页面不支持上传外部备份文件。用于整机灾备的备份必须选择全部组件；下载到其他存储位置的 `.db` 文件需要人工恢复，并且会整体替换目标 Hub 当前数据：

```bash
sudo systemctl stop simadminhub
sudo cp /var/lib/simadminhub/simadminhub.db /var/lib/simadminhub/simadminhub.db.before-restore
sudo install -m600 -o simadminhub -g simadminhub \
  /备份文件路径/simadminhub-YYYYMMDD-HHMMSS.db \
  /var/lib/simadminhub/simadminhub.db
sudo rm -f /var/lib/simadminhub/simadminhub.db-wal /var/lib/simadminhub/simadminhub.db-shm
sudo systemctl start simadminhub
curl -fsS http://127.0.0.1:3001/health
```

恢复文件的数据库版本不能高于当前 Hub。启动后设备在线状态会等待 Agent 重新连接建立。确认数据完整前保留 `simadminhub.db.before-restore`，不要同时运行两个指向同一数据库的 Hub 进程。

## 升级

### systemd 标准安装

进入“系统设置 > 概览”，在“产品与版本”中检查更新。发现新版本后：

1. 选择“下载并准备更新”，Hub 会按当前架构下载正式 Release，并校验 GitHub Asset 摘要、包内 `SHA256SUMS`、版本、架构和必需文件。
2. 校验通过后选择“安装并重启”。Hub 会先创建完整数据库备份，再整体更新 Hub、已安装的 Host Agent、Device Service、前端和 systemd 单元。
3. 页面会持续显示下载、校验、等待安装、安装、重启、成功、失败或已回滚状态。Hub 重启后状态不会丢失。

安装和健康检查失败时会恢复更新前的整套组件。更新时异常断电，systemd 会在下次启动后继续处理尚未完成的正式更新包。仍建议定期把重要备份下载到其他存储位置。

也可以再次执行快速安装命令完成升级：

```bash
curl -fsSL https://raw.githubusercontent.com/3899/SimAdminHub/main/install.sh | sh
```

安装器不会覆盖现有配置、数据库、备份、Host Agent 身份和绑定，也会保留本机 Host Agent 的启用状态。

### Docker 与手动运行

Docker 容器不会挂载 Docker Socket，也不会在容器内部替换镜像。发现新版本时，设置页会显示镜像名称和以下命令：

```bash
docker compose pull && docker compose up -d
```

直接运行发布包中的二进制时，设置页只提供版本信息和 Release 入口，不会尝试提权或替换当前进程。请下载对应架构的正式归档，并按原部署方式完成替换与重启。

## 卸载

一键卸载 Hub、Host Agent 和名为 `simadminhub` 的 Docker 容器：

```bash
curl -fsSL https://raw.githubusercontent.com/3899/SimAdminHub/main/uninstall.sh | sh
```

默认只删除程序、前端、服务单元和容器，保留 systemd 安装的配置、数据库、备份、Host Agent 身份以及 Docker 命名卷，便于以后重新安装。

确认所有数据都不再需要时才使用彻底清理：

```bash
curl -fsSL https://raw.githubusercontent.com/3899/SimAdminHub/main/uninstall.sh | sh -s -- --purge
```

`--purge` 会永久删除集中保存的短信、设备信息、通知与自动化配置、备份、Host Agent 身份和 `simadminhub` Docker 卷。

## 常见问题

### 服务启动失败

```bash
sudo journalctl -u simadminhub -n 200 --no-pager
```

重点检查数据库目录权限、前端目录、监听端口冲突和环境文件格式。

### 设备自动发现不到

先确认设备已经升级到最新版 SimAdmin 并切换到集中管理模式。自动发现只适用于支持 mDNS 的同一二层网络；Docker 部署必须使用文档中的 host 网络。不同 VLAN、访客网络或禁用组播时，直接填写设备完整地址。

### 输入地址后无法接入

在 Hub 主机验证：

```bash
curl -fsS http://设备地址:3000/health
```

如果页面提示“请求的接口不存在”，先升级设备上的 SimAdmin；旧版没有 Hub 所需的接入接口。版本正确后再检查协议、端口、防火墙和路由。Hub 无法访问设备时，改为在 SimAdmin 中填写 Hub 地址主动连接。

### 设备突然离线

默认 30 秒心跳一次，90 秒未收到有效心跳后判定离线。检查设备到 Hub 的网络、反向代理 WebSocket、SimAdmin 工作模式和 Agent 日志。

### 更换 USB 口后设备变化

硬件绑定优先按硬件指纹识别，同一模组更换 USB 口通常仍是原设备。槽位绑定跟随物理拓扑；槽位更换模组会进入身份待确认，需要在 Hub 核实后重新绑定。

功能和系统设置说明见[使用指南](user-guide.md)。
