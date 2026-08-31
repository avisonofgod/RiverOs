include $(TOPDIR)/rules.mk

PKG_NAME:=riveros-portnames
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/riveros-portnames
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=RiverOs rename DSA ports to ethX (S08)
  DEPENDS:=+libc
  URL:=https://github.com/avisonofgod/RiverOs
endef

define Package/riveros-portnames/description
  Renombra los puertos DSA MT7530 en el boot (START=08, antes de network):
  wan->eth0, lan2..lan5->eth1..eth4, cpu port->sw0. Nombres neutros para
  que Risp configure eth0..eth4.
endef

define Package/riveros-portnames/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/rename-ports $(1)/etc/init.d/rename-ports
endef

$(eval $(call BuildPackage,riveros-portnames))
