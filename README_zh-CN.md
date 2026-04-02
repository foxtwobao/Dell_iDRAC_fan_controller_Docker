<div id="top"></div>

# Dell iDRAC 风扇控制器 Docker 镜像

## 目录
<ol>
  <li><a href="#功能特性">功能特性</a></li>
  <li><a href="#容器日志示例">容器日志示例</a></li>
  <li><a href="#环境要求">环境要求</a></li>
  <li><a href="#支持的架构">支持的架构</a></li>
  <li><a href="#下载镜像">下载镜像</a></li>
  <li><a href="#使用方法">使用方法</a></li>
  <li><a href="#配置参数">配置参数</a></li>
  <li><a href="#阶梯式风扇控制说明">阶梯式风扇控制说明</a></li>
  <li><a href="#故障排除">故障排除</a></li>
  <li><a href="#贡献代码">贡献代码</a></li>
  <li><a href="#许可证">许可证</a></li>
</ol>

<!-- FEATURES -->
## 功能特性

本 Docker 容器允许您通过 IPMI 命令控制 Dell PowerEdge 服务器风扇，用更安静的自定义转速配置替换默认的高噪音 Dell 风扇控制。

### 核心功能
- **静态风扇转速控制**：设置固定低转速以降低噪音
- **阶梯式风扇控制**：根据 CPU 温度自动阶梯式调整风扇转速
- **iDRAC 自动重连**：网络中断时不会导致容器崩溃
- **第三方 PCIe 卡支持**：可选控制非 Dell PCIe 卡的散热策略
- **紧急回退**：CPU 过热时自动切换回 Dell 默认风扇控制

### Fork 增强功能
- **阶梯式风扇控制**：不再逐次递增风扇转速，而是根据当前温度计算目标转速。当温度下降时，风扇转速会自动降档，无需等待温度降到阈值以下。
- **iDRAC 自动重连**：iDRAC 网络问题不会导致容器崩溃，控制器会重试失败的命令并在恢复连接后继续运行。

<p align="right">(<a href="#top">返回顶部</a>)</p>

## 容器日志示例

![image](https://user-images.githubusercontent.com/37409593/216442212-d2ad7ff7-0d6f-443f-b8ac-c67b5f613b83.png)

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- REQUIREMENTS -->
## 环境要求

### iDRAC 版本

本 Docker 容器仅适用于支持 IPMI 命令的 Dell PowerEdge 服务器，即 iDRAC 9 固件版本 < 3.30.30.30。

### 通过 LAN 访问 iDRAC（本地模式不需要）：

1. 登录 iDRAC Web 控制台

![001](https://user-images.githubusercontent.com/37409593/210168273-7d760e47-143e-4a6e-aca7-45b483024139.png)

2. 在左侧菜单中，展开 "iDRAC settings"，点击 "Network"，然后点击网页顶部的 "IPMI Settings" 链接。

![002](https://user-images.githubusercontent.com/37409593/210168249-994f29cc-ac9e-4667-84f7-07f6d9a87522.png)

3. 勾选 "Enable IPMI over LAN" 复选框，然后点击 "Apply" 按钮。

![003](https://user-images.githubusercontent.com/37409593/210168248-a68982c4-9fe7-40e7-8b2c-b3f06fbfee62.png)

4. 运行以下命令测试 IPMI over LAN 访问：
```bash
apt -y install ipmitool
ipmitool -I lanplus \
  -H <iDRAC IP 地址> \
  -U <iDRAC 用户名> \
  -P <iDRAC 密码> \
  sdr elist all
```

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- SUPPORTED ARCHITECTURES -->
## 支持的架构

本 Docker 容器目前为以下 CPU 架构构建并提供：
- AMD64
- ARM64

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- DOWNLOAD DOCKER IMAGE -->
## 下载镜像

- [Docker Hub](https://hub.docker.com/r/tigerblue77/dell_idrac_fan_controller)
- [GitHub Packages](https://github.com/tigerblue77/Dell_iDRAC_fan_controller_Docker/pkgs/container/dell_idrac_fan_controller)

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- USAGE -->
## 使用方法

### 快速开始

1. 本地 iDRAC 模式：
```bash
docker run -d \
  --name Dell_iDRAC_fan_controller \
  --restart=unless-stopped \
  -e IDRAC_HOST=local \
  -e FAN_SPEED=10 \
  -e CPU_TEMPERATURE_THRESHOLD=60 \
  -e CPU_TEMPERATURE_THRESHOLD_MAX=80 \
  -e FAN_STEP=20 \
  -e CHECK_INTERVAL=30 \
  --device=/dev/ipmi0:/dev/ipmi0:rw \
  tigerblue77/dell_idrac_fan_controller:latest
```

2. LAN iDRAC 模式：
```bash
docker run -d \
  --name Dell_iDRAC_fan_controller \
  --restart=unless-stopped \
  -e IDRAC_HOST=<iDRAC IP 地址> \
  -e IDRAC_USERNAME=<iDRAC 用户名> \
  -e IDRAC_PASSWORD=<iDRAC 密码> \
  -e FAN_SPEED=10 \
  -e CPU_TEMPERATURE_THRESHOLD=60 \
  -e CPU_TEMPERATURE_THRESHOLD_MAX=80 \
  -e FAN_STEP=20 \
  -e CHECK_INTERVAL=30 \
  tigerblue77/dell_idrac_fan_controller:latest
```

### Docker Compose 示例

#### 静音家用服务器（推荐）
```yml
version: '3.8'

services:
  Dell_iDRAC_fan_controller:
    image: tigerblue77/dell_idrac_fan_controller:latest
    container_name: Dell_iDRAC_fan_controller
    restart: unless-stopped
    environment:
      - IDRAC_HOST=local
      - FAN_SPEED=10
      - CPU_TEMPERATURE_THRESHOLD=60
      - CPU_TEMPERATURE_THRESHOLD_MAX=80
      - FAN_STEP=5
      - CHECK_INTERVAL=30
      - IDRAC_RETRY_COUNT=3
      - IDRAC_RETRY_DELAY=5
    devices:
      - /dev/ipmi0:/dev/ipmi0:rw
```

#### 性能优先散热
```yml
version: '3.8'

services:
  Dell_iDRAC_fan_controller:
    image: tigerblue77/dell_idrac_fan_controller:latest
    container_name: Dell_iDRAC_fan_controller
    restart: unless-stopped
    environment:
      - IDRAC_HOST=<iDRAC IP 地址>
      - IDRAC_USERNAME=<iDRAC 用户名>
      - IDRAC_PASSWORD=<iDRAC 密码>
      - FAN_SPEED=15
      - CPU_TEMPERATURE_THRESHOLD=55
      - CPU_TEMPERATURE_THRESHOLD_MAX=75
      - FAN_STEP=3
      - CHECK_INTERVAL=20
    devices:
      - /dev/ipmi0:/dev/ipmi0:rw
```

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- PARAMETERS -->
## 配置参数

所有参数都是可选的，都有默认值。

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `IDRAC_HOST` | `local` | iDRAC 连接方式：`local` 或 IP 地址 |
| `IDRAC_USERNAME` | `root` | iDRAC 用户名（LAN 连接时使用） |
| `IDRAC_PASSWORD` | `calvin` | iDRAC 密码（LAN 连接时使用） |
| `FAN_SPEED` | `10` | 基础风扇转速 (%)，低于温度阈值时使用 |
| `CPU_TEMPERATURE_THRESHOLD` | `60` | 启动阶梯式风扇控制的温度阈值 (°C) |
| `CPU_TEMPERATURE_THRESHOLD_MAX` | `80` | 触发紧急 Dell 默认模式的温度 (°C) |
| `FAN_STEP` | `20` | 每级风扇转速递增的温度步长 (°C) |
| `CHECK_INTERVAL` | `30` | 温度检查间隔（秒） |
| `DISABLE_THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE` | `false` | 禁用第三方 PCIe 卡的 Dell 散热响应 |
| `KEEP_THIRD_PARTY_PCIE_CARD_COOLING_RESPONSE_STATE_ON_EXIT` | `false` | 容器停止时保持 PCIe 散热状态 |
| `IDRAC_RETRY_COUNT` | `3` | iDRAC 命令失败时的重试次数 |
| `IDRAC_RETRY_DELAY` | `5` | iDRAC 重试间隔（秒） |

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- STEPPED FAN CONTROL -->
## 阶梯式风扇控制说明

### 工作原理

阶梯式控制不再逐次递增风扇转速（可能导致超调），而是根据**当前温度**计算目标转速：

```
温度 → 确定阶梯 → 计算转速 → 应用
```

### 转速计算

```
转速 = FAN_SPEED + (阶梯号 × 每步增量)

其中：
  阶梯号 = floor((当前温度 - 阈值) / FAN_STEP)
  每步增量 = (100 - FAN_SPEED) / 最大阶梯数
  最大阶梯数 = ceil((最高阈值 - 阈值) / FAN_STEP)
```

### 示例

**配置：**
- `FAN_SPEED = 10`
- `FAN_STEP = 20`
- `CPU_TEMPERATURE_THRESHOLD = 60`
- `CPU_TEMPERATURE_THRESHOLD_MAX = 80`

**结果：**

| CPU 温度 | 风扇转速 | 状态 |
|----------|----------|------|
| < 60°C | 10% | 安静，基础转速 |
| 60-80°C | 10-100% | 阶梯递增 |
| >= 80°C | Dell 默认 | 紧急模式 |

使用 `FAN_STEP=5` 获得更精细的控制：

| CPU 温度 | 风扇转速 |
|----------|----------|
| < 60°C | 10% |
| 60-65°C | ~30% |
| 65-70°C | ~50% |
| 70-75°C | ~70% |
| 75-80°C | ~90% |
| >= 80°C | Dell 默认 |

### 配置指南

| 使用场景 | FAN_STEP | FAN_SPEED | 说明 |
|----------|----------|-----------|------|
| 静音家用服务器 | 5-10 | 5-10 | 更平滑的过渡，更安静 |
| 默认 | 20 | 10 | 平衡模式 |
| 性能优先 | 3-5 | 15-20 | 更快的响应 |

### 为什么选择阶梯式控制？

**逐次递增控制的问题：**
- 温度 65°C → 风扇 30%
- 温度降到 62°C → 风扇仍然是 30%（必须低于阈值才能重置）
- 结果：不必要的高转速持续更长时间

**阶梯式控制的优势：**
- 温度 70°C → 风扇 50%
- 温度降到 67°C → 风扇自动降到 30%
- 无需等待降到阈值以下，自动调整

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- TROUBLESHOOTING -->
## 故障排除

### 服务器频繁切换回 Dell 默认风扇模式：
1. 在 Intel Ark 网站上查看您 CPU 的 `Tcase`（外壳温度），然后将 `CPU_TEMPERATURE_THRESHOLD` 设置稍低一些。例如我的 CPU（[Intel Xeon E5-2630L v2](https://www.intel.com/content/www/us/en/products/sku/75791/intel-xeon-processor-e52630l-v2-15m-cache-2-40-ghz/specifications.html)）：Tcase = 63°C，我设置 `CPU_TEMPERATURE_THRESHOLD` 为 60(°C)。
2. 如果已经设置正确，调整 `FAN_SPEED` 值以增加气流，从而进一步降低 CPU 温度。
3. 如果增加风扇转速和调整阈值都不能解决问题，可能是时候更换导热硅脂了。

### 在 UnRAID OS 上出现 `/!\ Your server isn't a Dell product. Exiting.` 错误

- 使用常规 `docker run` 命令运行镜像，而不是 UnRAID Community Apps 或 Docker UI。[更多信息。](https://github.com/tigerblue77/Dell_iDRAC_fan_controller_Docker/issues/89#issuecomment-4166458799)

### 容器持续重试并记录警告

这是预期行为，表示 iDRAC 暂时无法连接（网络问题）。连接恢复后，容器将自动恢复正常运行。如有需要，可调整 `IDRAC_RETRY_COUNT` 和 `IDRAC_RETRY_DELAY`。

### 风扇转速似乎太高/太低

- 更安静的运行：减小 `FAN_SPEED`，增大 `FAN_STEP`
- 更快的散热响应：增大 `FAN_SPEED`，减小 `FAN_STEP`

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- CONTRIBUTING -->
## 贡献代码

贡献使开源社区成为学习和创造的绝佳场所。非常感谢您的任何贡献！

如果您有更好的建议，请 Fork 项目并创建 Pull Request。您也可以提交带有 "enhancement" 标签的 Issue。
别忘了给项目加星！谢谢！

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

本地测试：
```bash
docker build -t tigerblue77/dell_idrac_fan_controller:dev .
docker run -d ...
```
或
```bash
export IDRAC_HOST=<iDRAC IP 地址>
export IDRAC_USERNAME=<iDRAC 用户名>
export IDRAC_PASSWORD=<iDRAC 密码>
export FAN_SPEED=<十进制或十六进制风扇转速>
export CPU_TEMPERATURE_THRESHOLD=<温度阈值>
export CPU_TEMPERATURE_THRESHOLD_MAX=<最大温度阈值>
export FAN_STEP=<温度步长>
export CHECK_INTERVAL=<检查间隔秒数>
export IDRAC_RETRY_COUNT=<重试次数>
export IDRAC_RETRY_DELAY=<重试延迟秒数>
export DISABLE_THIRD_PARTY_PCIE_CARD_DELL_DEFAULT_COOLING_RESPONSE=<true 或 false>
export KEEP_THIRD_PARTY_PCIE_CARD_COOLING_RESPONSE_STATE_ON_EXIT=<true 或 false>

chmod +x Dell_iDRAC_fan_controller.sh
./Dell_iDRAC_fan_controller.sh
```

### 运行测试
```bash
bats tests/
```

<p align="right">(<a href="#top">返回顶部</a>)</p>

<!-- LICENSE -->
## 许可证

Shield: [![CC BY-NC-SA 4.0][cc-by-nc-sa-shield]][cc-by-nc-sa]

本作品采用 [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License][cc-by-nc-sa] 许可。完整许可证说明请阅读[此处][link-to-license-file]。

[![CC BY-NC-SA 4.0][cc-by-nc-sa-image]][cc-by-nc-sa]

[cc-by-nc-sa]: http://creativecommons.org/licenses/by-nc-sa/4.0/
[cc-by-nc-sa-image]: https://licensebuttons.net/l/by-nc-sa/4.0/88x31.png
[cc-by-nc-sa-shield]: https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg
[link-to-license-file]: ./LICENSE

<p align="right">(<a href="#top">返回顶部</a>)</p>
