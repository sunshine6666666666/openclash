# OpenClash 下 SSH 直连排障手册（腾讯云新加坡）

更新时间：2026-03-08

## 1. 目标

在 **不关闭 OpenClash** 的前提下，让开发服务器 SSH 连接强制直连，避免被代理链路影响。

本次目标主机：

- 服务器：`129.226.82.18`
- SSH 端口：`2222`
- 本地别名：`tencent-light-2222`

## 2. 本次已验证结论

- 仅在“规则附加”增加 `ipcidr + DIRECT`，不一定能命中 SSH 流量。
- 关键生效入口是：`插件设置 -> 黑白名单 -> 不走代理的 WAN IP`。
- 新增 `129.226.82.18/32` 后，SSH 来源 IP 从代理出口切换为中国出口，且稳定性正常。
- 即使 SSH 已直连，网页流量仍可能走代理出口，这是正常分流行为。

## 3. 一次性配置步骤（最小可用）

1. 确认 SSH 目标配置无误（本地终端）：

```bash
ssh -G tencent-light-2222 | rg "^(hostname|port|user|proxycommand|proxyjump)\b"
```

预期包含：

- `hostname 129.226.82.18`
- `port 2222`
- 无 `proxycommand/proxyjump`

2. 路由器 WebUI 进入：

- `OpenClash -> 插件设置 -> 黑白名单`

3. 在 `不走代理的 WAN IP` 输入：

```txt
129.226.82.18/32
```

4. 点击右侧 `+`，然后点击：

- `保存配置`
- `应用配置`

5. 如果你改过“来源流量访问控制”，删除空白或无效规则，避免后续干扰。

## 4. 验证命令（本地终端）

1. 验证服务器看到的客户端来源 IP：

```bash
ssh "tencent-light-2222" "echo SSH_CLIENT=\$SSH_CLIENT; echo SSH_CONNECTION=\$SSH_CONNECTION"
```

判定：

- 若第一段来源 IP 为中国出口（如 `101.x.x.x`），说明 SSH 直连生效。
- 若仍是代理出口（如 `206.83.106.231`），说明未命中直连规则。

2. 验证稳定性（5 次短连接）：

```bash
for i in 1 2 3 4 5; do
  ts=$(date '+%H:%M:%S')
  out=$(ssh -o BatchMode=yes -o ConnectTimeout=5 -o ConnectionAttempts=1 "tencent-light-2222" "echo ok" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "$ts [#$i] OK"
  else
    echo "$ts [#$i] FAIL rc=$rc $out"
  fi
  sleep 1
done
```

判定：

- `5/5 OK` 说明当前可用。

3. 说明命令（非 SSH 专用）：

```bash
curl -sS --max-time 6 "https://api.ipify.org"; echo
```

该命令显示的是“当前默认网页出口 IP”，不等于 SSH 一定走同一路径。

## 5. 常见误区

- 误区 1：看见 `curl ipify` 是海外 IP，就认为 SSH 仍走代理。
- 误区 2：只改规则附加，不改 WAN IP 直连名单。
- 误区 3：一次改太多项，无法判断哪一步真正生效。

## 6. 变更维护

- 腾讯云公网 IP 变化后，必须同步更新 `不走代理的 WAN IP`。
- 保留 `/32` 精确匹配，避免放大绕过范围。
- 每次改动后都执行“来源 IP + 5 次稳定性”双验证再收工。

