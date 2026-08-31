include $(TOPDIR)/rules.mk

PKG_NAME:=riveros-red
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/riveros-red
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=RiverOs manual network (ip puro, sin netifd)
  DEPENDS:=+libc
  URL:=https://github.com/avisonofgod/RiverOs
endef

define Package/riveros-red/description
  Configura la red manual de RiverOs (S98): renombra cpu port -> sw0,
  ether1 -> eth0 y levanta 192.168.5.1/24 sin netifd.
endef

define Package/riveros-red/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/riveros-red $(1)/etc/init.d/riveros-red
endef

$(eval $(call BuildPackage,riveros-red))
