# AGENTS.md

This is a documentation repository containing technical guides for Cudy AX3000 router deployment with OpenWrt/ImmortalWrt and OpenClash proxy configuration.

## Repository Structure

```
openclash/
└── guide.md          # Main technical documentation (Chinese)
```

## Target Hardware

- **Model**: Cudy TR3000 (AX3000 Series)
- **Type**: Portable Wi-Fi 6 Router
- **Flash**: 256MB
- **Ethernet Port**: 2.5G
- **Wi-Fi**: Wi-Fi 6 (AX3000)

## Build/Test/Lint Commands

This repository contains documentation only - no build system, tests, or linting configured.

- No package.json, Makefile, or build configuration
- No automated tests (documentation repository)
- No linting or formatting tools configured

## Documentation Style Guidelines

### Content Structure
- Use clear hierarchical headers (##, ###, ####)
- Number major sections (1., 2., 3.) for technical procedures
- Use sub-numbering (1.1, 1.2) for subsections

### Code Examples
- Use fenced code blocks with language identifiers (```bash, ```yaml)
- Include comments in Chinese explaining commands
- Provide complete command sequences, not partial snippets
- Example:
  ```bash
  # 更新软件包列表
  opkg update
  opkg install dnsmasq-full
  ```

### Technical Writing
- Maintain Chinese language throughout
- Use technical terminology precisely (e.g., "Fake-IP (TUN-Mixed) Mode")
- Define acronyms on first use
- Include hardware specifications in table format

### Formatting
- Separate sections with blank lines
- Use **bold** for important warnings or key terms
- Use tables for comparing options or specifications
- Keep lines under 100 characters when possible

## Editing Checklist

- [ ] Verify all shell commands are accurate and tested
- [ ] Check that version numbers reflect current releases
- [ ] Ensure IP addresses and ports are correctly formatted
- [ ] Verify Chinese technical terms are used consistently
- [ ] Confirm links to external resources are valid

## No AI/Editor Rules Found

- No .cursorrules file
- No .cursor/rules/ directory
- No .github/copilot-instructions.md

## Common Tasks

**Editing guide.md:**
```bash
# Open the file directly
vim guide.md
```

**Previewing changes:**
```bash
# No build step required - view directly in Markdown viewer
```

## Notes for Agents

1. This is a technical guide, not source code
2. Accuracy of technical information is critical
3. Changes to configuration examples should be tested on actual hardware when possible
4. Preserve Chinese language - do not translate to English
5. Maintain the academic/formal writing style

## 实战问题记录 (Cudy TR3000 当前进度)

### 1) 已完成阶段（按时间线，更新到当前）

1. 初始救援与回退阶段（已完成）
   - TFTP 恢复链路验证通过（路由器恢复请求 IP：`192.168.1.112`）。
   - 成功回退 Cudy 官方 2.4.7，恢复可管理状态。

2. 过渡到 OpenWrt 中间态（已完成）
   - 成功刷入 `cudy_tr3000-256mb-v1-sysupgrade.bin`。
   - 进入 `OpenWrt 23.05-SNAPSHOT`，管理地址 `192.168.1.1`。

3. 中间态联网与包源阶段（已完成）
   - 通过无线客户端连接上游 Wi-Fi（SSID：`911`）。
   - `opkg` 源修复后可更新。

4. 中间态代理试装阶段（已完成，结论为“路线不优”）
   - 未检出 `luci-app-openclash/passwall/homeproxy`。
   - `v2raya + sing-box` 安装受 `kmod` 内核版本冲突阻断。
   - 临时安装 `shadowsocks-libev` 相关包并可访问直链页面。

5. 路线切换阶段（已完成）
   - 用户明确需求：要“一键订阅、可切换节点”的主流体验。
   - 决策切换到 OpenClash 终态路线，先做固件基线升级。

6. 固件重刷到新基线（已完成）
   - 已下载并校验两份 24.10.4 镜像：
     - `...cudy_tr3000-256mb-v1-initramfs-kernel.bin`
     - `...cudy_tr3000-256mb-v1-squashfs-sysupgrade.bin`
   - SHA256 校验匹配官方索引。
   - 使用 `sysupgrade -n` 刷写 `...256mb-v1-squashfs-sysupgrade.bin` 成功重启。

7. 新系统上线（已完成）
   - SSH 指纹变更已处理（`ssh-keygen -R 192.168.1.1`）。
   - 已进入 `ImmortalWrt 24.10.4, r33602-e717d133ed6d`。
   - root 密码已设置（弱密码提示但生效）。

8. 当前网络与包管理状态（最新）
   - 首次 `opkg update` 失败：`SSL verify error: certificate is not yet valid`。
   - 定位根因：系统时间停在 `2025`，证书时间窗未生效。
   - 手动设定时间到 `2026-02-11` 后，`opkg update` 全部成功，签名校验通过。

9. OpenClash 安装与运行阶段（已完成核心闭环）
   - 执行 `opkg update && opkg list | grep -E "luci-app-openclash|openclash"`，确认源内存在 `luci-app-openclash`。
   - 安装命令执行后，`luci-app-openclash - 0.47.055` 已安装。
   - `luci-i18n-openclash-zh-cn` 不在当前源，报 `Unknown package`，但不影响主功能。
   - OpenClash 页面可打开，插件设置中 Meta 内核可见并可运行。
   - 运行状态页确认：`Meta 运行中`。
   - 订阅已添加并生效（配置文件 `times1770784317_subtangniu.yaml` 已加载）。

10. 分流与连通验证（已完成）
   - 运行模式为 `Fake-IP`。
   - 代理模式为 `规则`。
   - `DNS 代理` 已启用，`域名嗅探` 已启用。
   - 访问检查中：百度正常、GitHub/YouTube 正常。
   - IP 检测显示国内与海外出口并存，符合规则分流预期。

11. 安全与运维收尾（进行中）
   - 管理密码已设置。
   - SSH 已限制在 `LAN` 接口访问，`WAN` 未开放（不做公网暴露）。
   - 当前在做部署形态收尾：是否长期以“Cudy 常驻中间层”方式接入上级无线网络。
   - 用户当前策略偏好：可接受速度损失，优先“机场可快速更换 + 持续可用”。

### 2) 当前系统信息（最新）

- 设备：`Cudy TR3000 256MB`
- 设备识别目标：`cudy,tr3000-256mb-v1`
- 系统：`ImmortalWrt 24.10.4, r33602-e717d133ed6d`
- 管理地址：`http://192.168.1.1`
- SSH：可登录（LAN 内开放）
- 软件源：`opkg update` 成功
- OpenClash：已安装、已运行（Meta）
- 订阅：已导入 1 条并加载成功
- 当前配置文件：`times1770784317_subtangniu.yaml`

### 3) 已确认的错误案例与错误思路（必须避免）

1. 错误案例：用 `cudy_tr3000-v1` 非 256mb 镜像尝试升级
   - 结果：`Image check failed / not supported by this device`
   - 错误思路：认为“同型号就能刷”
   - 正确策略：以设备识别与元数据匹配为准，优先 `256mb-v1`

2. 错误案例：在 23.05 中间态强推 `v2raya/sing-box`
   - 结果：`kmod-*` 依赖冲突（内核不对齐）
   - 错误思路：插件可见即代表可落地
   - 正确策略：先核对“系统内核 vs 仓库 kmod”

3. 错误案例：`opkg update` SSL 报错时直接怀疑镜像源
   - 结果：反复失败
   - 错误思路：忽略系统时间
   - 正确策略：先校时，再更新源

4. 错误案例：刷机后 SSH 失败被误判为网络问题
   - 结果：连接阻断
   - 错误思路：忽略 host key 变化
   - 正确策略：先清理旧指纹再连接

5. 错误案例：`opkg list | rg ...` 在路由器端执行失败
   - 结果：`-ash: rg: not found`
   - 错误思路：把本机开发环境命令习惯直接套到路由器
   - 正确策略：在路由器端使用 `grep -E`

6. 错误案例：误以为 OpenClash “没保存节点选择”
   - 结果：重复配置、操作焦虑
   - 错误思路：仅凭主观判断，不看代理组当前节点状态
   - 正确策略：看代理组当前节点展示并刷新二次确认

7. 错误案例：在“挂上级路由 WAN”后直接扫 `192.168.1.1` 管理地址
   - 结果：只能看到上级路由地址（如 `192.168.3.1`），误判设备离线
   - 错误思路：忽略上下级 NAT 后管理面隔离
   - 正确策略：明确管理路径（直连 Cudy 网络或同网段有线管理）

### 4) 当前进度（精确到节点）

当前已到：**OpenClash 已安装并运行，主订阅已生效，进入“安全收尾 + 常驻部署 + 备用订阅容灾”阶段**。

已完成的前置条件：
- 固件已切到 `ImmortalWrt 24.10.4`。
- 路由器可联网，系统时间问题已修复，`opkg update` 成功。
- OpenClash 已运行（`Meta 运行中`）。
- 主订阅已导入并加载，规则分流验证通过。

### 5) 下一步接续顺序（下一会话直接执行）

1. 固化“常驻拓扑”方案（用户接受慢速，优先稳定可切换）
2. 新增 1 条备用订阅，完成主备切换演练
3. 导出 OpenClash 备份（本地保存）
4. 完成无线隐私与安全项复核（WPA/WPS/管理入口最小暴露）
5. 输出“一分钟应急恢复口令”（机场失效时）

### 6) 快速接续口令

- 用户下次只需发送：`继续从 OpenClash 已运行状态，做主备订阅容灾和安全收尾`
