################################################################################
#
# helium-miner
#
################################################################################

HELIUM_GATEWAY_RS_VERSION = v1.0.0-alpha.30
HELIUM_GATEWAY_RS_SITE = $(call github,helium,miner,$(HELIUM_GATEWAY_RS_VERSION))
HELIUM_GATEWAY_RS_LICENSE = Apache-2.0
HELIUM_GATEWAY_RS_LICENSE_FILES = LICENSE
HELIUM_GATEWAY_RS_DEPENDENCIES = host-rust-bin
            
#HELIUM_GATEWAY_RS_POST_EXTRACT_HOOKS += HELIUM_GATEWAY_RS_FETCH_PATCH_DEPS
#HELIUM_GATEWAY_RS_POST_EXTRACT_HOOKS += HELIUM_GATEWAY_RS_UPDATE_VERSION

#define HELIUM_GATEWAY_RS_FETCH_PATCH_DEPS
#    (cd $(@D); $(TARGET_MAKE_ENV) ./rebar3 get-deps)
#
#    patch -d $(@D)/_build/default/lib/erasure -p1 < package/helium-miner/erlang-erasure._patch
#    patch -d $(@D)/_build/default/lib/procket -p1 < package/helium-miner/procket._patch
#    patch -d $(@D)/_build/default/lib/clique -p1 < package/helium-miner/clique._patch
#endef

#define HELIUM_GATEWAY_RS_UPDATE_VERSION
#    sed -i 's/git}/"$(HELIUM_GATEWAY_RS_VERSION)"}/g' $(@D)/rebar.config
#endef
            
define HELIUM_GATEWAY_RS_BUILD_CMDS
    (cd $(@D); \
            CARGO_HOME=$(HOST_DIR)/share/cargo \
            CARGO_BUILD_TARGET=aarch64-unknown-linux-gnu \
            CC="$(TARGET_CC)" \
            CXX="$(TARGET_CXX)" \
            CFLAGS="$(TARGET_CFLAGS) -U__sun__" \
            CXXFLAGS="$(TARGET_CXXFLAGS)" \
            RUSTFLAGS="-C target-feature=-crt-static" \
            $(TARGET_MAKE_ENV) \
            cargo build --release \
    )
endef

define HELIUM_GATEWAY_RS_INSTALL_TARGET_CMDS
    echo "AAA"
endef

define HELIUM_GATEWAY_RS_INSTALL_STAGING_CMDS
endef

define HELIUM_GATEWAY_RS_INSTALL_CMDS
endef

$(eval $(generic-package))
