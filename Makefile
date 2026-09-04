include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-nsclient
PKG_VERSION:=2026090410
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=NS Client — Netsignory WireGuard exit nodes
	PKGARCH:=all
	DEPENDS:=+curl +jq +wireguard-tools +kmod-wireguard
endef

define Package/$(PKG_NAME)/description
	Login to the Netsignory orchestrator, pick a regional WireGuard
	exit, and connect on demand. API URL and agent domain are hidden
	and can be written via the LuCI URL.
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/nsclient
endef

define Build/Prepare
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(CP) ./files/* $(1)/
	chmod 0755 $(1)/usr/sbin/nsclient $(1)/etc/init.d/nsclient \
		$(1)/etc/init.d/nsclient-boot \
		$(1)/etc/hotplug.d/iface/99-nsclient
endef

define Package/$(PKG_NAME)/postinst
	#!/bin/sh
	[ -n "$${IPKG_INSTROOT}" ] || {
		/etc/init.d/nsclient enable >/dev/null 2>&1 || true
		/etc/init.d/nsclient-boot enable >/dev/null 2>&1 || true
		rm -rf /tmp/luci-indexcache /tmp/luci-modulecache >/dev/null 2>&1 || true
	}
	exit 0
endef

define Package/$(PKG_NAME)/postrm
	#!/bin/sh
	[ -n "$${IPKG_INSTROOT}" ] || {
		rm -rf /tmp/luci-indexcache /tmp/luci-modulecache >/dev/null 2>&1 || true
	}
	exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
