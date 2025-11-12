# See /LICENSE for more information.
# This is free software, licensed under the GNU General Public License v2.

include $(TOPDIR)/rules.mk

LUCI_TITLE:=Wireless Range Test Application
LUCI_DEPENDS:=+luci-base +rpcd +rpcd-mod-iwinfo
LUCI_PKGARCH:=all

PKG_LICENSE:=GPL-2.0
PKG_MAINTAINER:=Luke Jenkins

include ../../luci.mk

# call BuildPackage - OpenWrt buildroot signature
