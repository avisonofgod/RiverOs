include $(TOPDIR)/rules.mk

PKG_NAME:=riveros-dropbear
PKG_RELEASE:=1
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/riveros-dropbear
  SECTION:=base
  CATEGORY:=Base system
  TITLE:=RiverOs dropbear manual (sin UCI, key ed25519)
  DEPENDS:=+libc +dropbear
  URL:=https://github.com/avisonofgod/RiverOs
endef

define Package/riveros-dropbear/description
  Arranca dropbear (S95) con host key ed25519 generada en /etc/dropbear,
  sin depender de la config UCI de dropbear.
endef

define Package/riveros-dropbear/install
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/dropbear-manual $(1)/etc/init.d/dropbear-manual
endef

$(eval $(call BuildPackage,riveros-dropbear))
