include $(TOPDIR)/rules.mk

-include ./env

PKG_NAME?=$(CPE_PKG_NAME)
PKG_VERSION?=$(CPE_PKG_VERSION)

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)
CPE_STAGING_DIR:=$(PKG_BUILD_DIR)/staging

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
	SECTION:=luci
	CATEGORY:=LuCI
	SUBMENU:=3. Applications
	TITLE:=$(CPE_PKG_TITLE)
	PKGARCH:=all
	DEPENDS:=+curl +jq +wireguard-tools +kmod-wireguard +dnsmasq +ip +iptables
endef

define Package/$(PKG_NAME)/description
	$(CPE_PKG_DESCRIPTION)
endef

define Package/$(PKG_NAME)/conffiles
/etc/config/$(CPE_UCI)
endef

define Build/Prepare
	$(RM) -rf $(CPE_STAGING_DIR)
	$(INSTALL_DIR) $(CPE_STAGING_DIR)
	$(CP) ./files/* $(CPE_STAGING_DIR)/
	rm -f $(CPE_STAGING_DIR)/usr/share/gogogo/defaults.sh.in
	$(CP) ./files/usr/share/gogogo/defaults.sh.in $(CPE_STAGING_DIR)/usr/share/gogogo/defaults.sh
	$(SED) 's|@CPE_SERVICE@|$(CPE_SERVICE)|g; \
		s|@CPE_DAEMON@|$(CPE_DAEMON)|g; \
		s|@CPE_UCI@|$(CPE_UCI)|g; \
		s|@CPE_VPNAME@|$(CPE_VPNAME)|g; \
		s|@CPE_LAN_BRIDGE@|$(CPE_LAN_BRIDGE)|g; \
		s|@CPE_DNS_HIJACK_TO@|$(CPE_DNS_HIJACK_TO)|g; \
		s|@CPE_DEFAULT_URL@|$(CPE_DEFAULT_URL)|g; \
		s|@CPE_API_USER_PATH@|$(CPE_API_USER_PATH)|g; \
		s|@CPE_DNS_LOCAL_1@|$(CPE_DNS_LOCAL_1)|g; \
		s|@CPE_DNS_REMOTE_1@|$(CPE_DNS_REMOTE_1)|g; \
		s|@CPE_DNS_PROBE_DOMAIN@|$(CPE_DNS_PROBE_DOMAIN)|g; \
		s|@CPE_DNS_LOCAL_FALLBACK@|$(CPE_DNS_LOCAL_FALLBACK)|g; \
		s|@CPE_DOH_ALI_HOST@|$(CPE_DOH_ALI_HOST)|g; \
		s|@CPE_DOH_ALI_IP2@|$(CPE_DOH_ALI_IP2)|g; \
		s|@CPE_DOH_ALI_IP@|$(CPE_DOH_ALI_IP)|g; \
		s|@CPE_DOH_TENCENT_HOST@|$(CPE_DOH_TENCENT_HOST)|g; \
		s|@CPE_DOH_TENCENT_IP2@|$(CPE_DOH_TENCENT_IP2)|g; \
		s|@CPE_DOH_TENCENT_IP@|$(CPE_DOH_TENCENT_IP)|g; \
		s|@CPE_DOH_FORCE_HOSTS@|$(CPE_DOH_FORCE_HOSTS)|g; \
		s|@CPE_CHNROUTE_FILE@|$(CPE_CHNROUTE_FILE)|g; \
		s|@CPE_CHNROUTES_API_PATH@|$(CPE_CHNROUTES_API_PATH)|g; \
		s|@CPE_ROUTE_CHN_METRIC@|$(CPE_ROUTE_CHN_METRIC)|g; \
		s|@CPE_ROUTE_TABLE_ID@|$(CPE_ROUTE_TABLE_ID)|g; \
		s|@CPE_ROUTE_TABLE_NAME@|$(CPE_ROUTE_TABLE_NAME)|g; \
		s|@CPE_ROUTE_RULE_PREF@|$(CPE_ROUTE_RULE_PREF)|g; \
		s|@CPE_ROUTE_RESERVED_PREF@|$(CPE_ROUTE_RESERVED_PREF)|g; \
		s|@CPE_ROUTE_RESERVED_CIDRS@|$(CPE_ROUTE_RESERVED_CIDRS)|g; \
		s|@CPE_FIREWALL_ZONE@|$(CPE_FIREWALL_ZONE)|g; \
		s|@CPE_WG_HANDSHAKE_MAX_AGE@|$(CPE_WG_HANDSHAKE_MAX_AGE)|g; \
		s|@CPE_MAIN_LOOP_SEC@|$(CPE_MAIN_LOOP_SEC)|g; \
		s|@CPE_WATCHDOG_LOOP_SEC@|$(CPE_WATCHDOG_LOOP_SEC)|g; \
		s|@CPE_CURL_TIMEOUT@|$(CPE_CURL_TIMEOUT)|g; \
		s|@CPE_WAN_ROUTE_METRIC@|$(CPE_WAN_ROUTE_METRIC)|g; \
		s|@CPE_WG_KEEPALIVE@|$(CPE_WG_KEEPALIVE)|g; \
		s|@CPE_PKG_NAME@|$(CPE_PKG_NAME)|g; \
		s|@CPE_AUTO_UPDATE@|$(CPE_AUTO_UPDATE)|g; \
		s|@CPE_GITHUB_REPO@|$(CPE_GITHUB_REPO)|g; \
		s|@CPE_GITHUB_MIRROR@|$(CPE_GITHUB_MIRROR)|g; \
		s|@CPE_GITHUB_MIRROR_PREFIXES@|$(CPE_GITHUB_MIRROR_PREFIXES)|g; \
		s|@CPE_GITHUB_MANIFEST_PATH@|$(CPE_GITHUB_MANIFEST_PATH)|g; \
		s|@CPE_GITHUB_RELEASE_MANIFEST@|$(CPE_GITHUB_RELEASE_MANIFEST)|g; \
		s|@CPE_UPDATE_MANIFEST@|$(CPE_UPDATE_MANIFEST)|g; \
		s|@CPE_UPDATE_CHECK_SEC@|$(CPE_UPDATE_CHECK_SEC)|g; \
		s|@CPE_CHNROUTES_REFRESH_SEC@|$(CPE_CHNROUTES_REFRESH_SEC)|g; \
		s|@CPE_CHNROUTES_RETRY_SEC@|$(CPE_CHNROUTES_RETRY_SEC)|g; \
		s|@CPE_WG_ENDPOINT_PORT@|$(CPE_WG_ENDPOINT_PORT)|g; \
		s|@CPE_DEFAULT_ENABLE@|$(CPE_DEFAULT_ENABLE)|g; \
		s|@CPE_UBOOT_URL_VAR@|$(CPE_UBOOT_URL_VAR)|g; \
		s|@CPE_UBOOT_USER_VAR@|$(CPE_UBOOT_USER_VAR)|g; \
		s|@CPE_UBOOT_PASS_VAR@|$(CPE_UBOOT_PASS_VAR)|g; \
		s|@CPE_TIMESYNC_RETRY_SEC@|$(CPE_TIMESYNC_RETRY_SEC)|g; \
		s|@CPE_RESOLV_RETRY_SEC@|$(CPE_RESOLV_RETRY_SEC)|g; \
		s|@CPE_CRED_SYNC_SEC@|$(CPE_CRED_SYNC_SEC)|g' \
		$(CPE_STAGING_DIR)/usr/share/gogogo/defaults.sh
	( \
		echo "config default"; \
		echo "	option enable '$(CPE_DEFAULT_ENABLE)'"; \
		echo "	option vpname '$(CPE_VPNAME)'"; \
		echo "	option base_url '$(CPE_DEFAULT_URL)'"; \
		echo "	option tunnelall '0'"; \
		echo "	option dnsleak '0'"; \
		echo "	option description ''"; \
		echo "	option login_status '0'"; \
		[ -n "$(CPE_DEFAULT_USERNAME)" ] && echo "	option username '$(CPE_DEFAULT_USERNAME)'"; \
		[ -n "$(CPE_DEFAULT_PASSWORD)" ] && echo "	option password '$(CPE_DEFAULT_PASSWORD)'"; \
		true \
	) > $(CPE_STAGING_DIR)/etc/config/$(CPE_UCI)
	chmod 0644 $(CPE_STAGING_DIR)/usr/share/gogogo/defaults.sh
	chmod 0755 $(CPE_STAGING_DIR)/usr/sbin/gogogo $(CPE_STAGING_DIR)/usr/sbin/gogogod \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-cred $(CPE_STAGING_DIR)/usr/sbin/gogogo-url \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-kill $(CPE_STAGING_DIR)/usr/sbin/gogogo-timesync \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-resolv-guard $(CPE_STAGING_DIR)/usr/sbin/gogogo-dns-probe \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-chnroutes-update \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-luci-after-save \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-luci-diag \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-luci-status \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-update \
		$(CPE_STAGING_DIR)/usr/sbin/gogogo-route-guard \
		$(CPE_STAGING_DIR)/etc/init.d/gogogo \
		$(CPE_STAGING_DIR)/etc/hotplug.d/iface/99-gogogo
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	$(CP) $(CPE_STAGING_DIR)/etc $(1)/
	$(CP) $(CPE_STAGING_DIR)/usr $(1)/
endef

define Package/$(PKG_NAME)/postinst
	#!/bin/sh
	[ -n "$${IPKG_INSTROOT}" ] || {
		[ -x /usr/sbin/gogogo-cred ] && /usr/sbin/gogogo-cred repair >/dev/null 2>&1 || true
		if [ -z "$$(uci -q get gogogo.@default[0].dnsleak)" ]; then
			_ipmode=$$(uci -q get gogogo.@default[0].ipmode)
			if [ "$$_ipmode" = "1" ]; then
				uci -q set gogogo.@default[0].dnsleak=1
			else
				uci -q set gogogo.@default[0].dnsleak=0
			fi
		fi
		uci -q delete gogogo.@default[0].ipmode
		uci commit gogogo >/dev/null 2>&1 || true
		[ -x /usr/sbin/gogogo-cred ] && /usr/sbin/gogogo-cred sync >/dev/null 2>&1 || true
		/etc/init.d/quagga stop >/dev/null 2>&1 || true
		/etc/init.d/quagga disable >/dev/null 2>&1 || true
		/etc/init.d/gogogo enable >/dev/null 2>&1 || true
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
