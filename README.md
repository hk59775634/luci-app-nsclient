# luci-app-nsclient

Netsignory 路由器客户端：登录编排站，预选区域出口，按需连接 WireGuard。

菜单：**VPN**（与 CPE 一样单独顶级入口）

## 用户可见

界面只要求输入账号和密码。登录后列出出口节点，选中再点连接。

## 隐藏写入（代理 / 环境）

API 地址和代理识别域名不出现在表单里，通过 LuCI URL 写入 **U-Boot 环境**（`fw_setenv`）并同步到 UCI。刷机或恢复出厂后仍可从 `fw_printenv` 读回：

```
/cgi-bin/luci/admin/nsclient/config?orch=https://orch.one.netsignory.net&domain=client.one.netsignory.net
```

| 参数 | U-Boot 变量 |
|---|---|
| `orch` / `url` | `nsc_orch` |
| `domain` | `nsc_domain` |

写入成功后跳回干净页面。URL 与账号输入都会去掉首尾空白、不可见字符和包裹引号。仅在值变化时调用 `fw_setenv`。

命令行：

```
nsclient set orch https://orch.example.com
nsclient set domain client.example.com
fw_printenv nsc_orch nsc_domain
nsclient sync
```

## 编译

放在 OpenWrt 的 `package/custom_packages/luci-app-nsclient`，然后：

```
make package/luci-app-nsclient/compile V=s
```

依赖：`curl`、`jq`、`wireguard-tools`、`kmod-wireguard`。

登录时会先尝试 HTTPS；若本机旧版 wolfSSL/OpenSSL 1.1 无法与编排站完成握手，自动改走 HTTP。系统时间早于 2025 时会先用 NTP 校时。

## Release

GitHub Release 同时发布 NS Client 软件包和对应设备固件：

https://github.com/hk59775634/luci-app-nsclient/releases

每个 Release 包含：

| 文件 | 说明 |
|---|---|
| `manifest.json` | 版本清单，路由器更新页读取 |
| `luci-app-nsclient_*-1_all.ipk` | NS Client 软件包 |
| `*-squashfs-sysupgrade.bin` | MT7981 可升级固件 |

路由器 **更新** 页会检测 latest release，可单独更新 NS Client 或整包固件。

## 分流

默认 **分流**：中国大陆 IP（[chnroutes](https://github.com/hk59775634/chnroutes) IPv4）走 WAN，其余走隧道。可改为 **全局**（全部公网走隧道）。

路由表优先从 GitHub / jsDelivr / ghproxy 更新；失败时使用软件包内置回退列表。

DNS 使用本机已打补丁的 dnsmasq `chnroutes` 模式：国内走 WAN 原始 DNS 或 `180.76.76.76`，海外走 API 下发的 DNS。

## 命令

```
nsclient login
nsclient connect hk
nsclient disconnect
nsclient status
```
