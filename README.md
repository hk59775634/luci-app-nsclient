# luci-app-nsclient

Netsignory 路由器客户端：登录编排站，预选区域出口，按需连接 WireGuard。

菜单：**网络 → NS Client**

## 用户可见

界面只要求输入账号和密码。登录后列出出口节点，选中再点连接。

## 隐藏写入（代理 / 环境）

API 地址和代理识别域名不出现在表单里，通过 LuCI URL 写入 **U-Boot 环境**（`fw_setenv`）并同步到 UCI。刷机或恢复出厂后仍可从 `fw_printenv` 读回：

```
/cgi-bin/luci/admin/network/nsclient?orch=https://orch.one.netsignory.net&domain=client.one.netsignory.net
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

## 命令

```
nsclient login
nsclient connect hk
nsclient disconnect
nsclient status
```
