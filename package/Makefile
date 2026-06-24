include $(TOPDIR)/rules.mk

PKG_NAME:=glinet-sms-tool-webapp
PKG_VERSION:=1.0.0
PKG_RELEASE:=1
PKGARCH:=all

include $(INCLUDE_DIR)/package.mk

define Package/glinet-sms-tool-webapp
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=GL.iNet SMS Tool Web App
  DEPENDS:=+uhttpd
endef

define Package/glinet-sms-tool-webapp/description
A lightweight web UI and CGI endpoint for reading and sending SMS through the
GL.iNet/smstools SMS spool directories.
endef

define Build/Compile
endef

define Package/glinet-sms-tool-webapp/install
	$(INSTALL_DIR) $(1)/www/sms
	$(INSTALL_DATA) ./files/www/sms/index.html $(1)/www/sms/index.html
	$(INSTALL_DATA) ./files/www/sms/app.css $(1)/www/sms/app.css
	$(INSTALL_DATA) ./files/www/sms/app.js $(1)/www/sms/app.js
	$(INSTALL_DIR) $(1)/www/cgi-bin
	$(INSTALL_BIN) ./files/www/cgi-bin/glinet-sms-webapp $(1)/www/cgi-bin/glinet-sms-webapp
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_CONF) ./files/etc/config/glinet_sms_webapp $(1)/etc/config/glinet_sms_webapp
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/glinet_sms_webapp.lua $(1)/usr/lib/lua/luci/controller/glinet_sms_webapp.lua
endef

$(eval $(call BuildPackage,glinet-sms-tool-webapp))
