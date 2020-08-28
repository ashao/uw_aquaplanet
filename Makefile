# Executable targets: build/compiler/mode/mom6_memory/mom6_configuration/MOM6
#
#   compiler = gnu, intel, pgi, cray, ...
#   mode = repro, debug, coverage, ...
#   If mom6_memory = dynamic or dynamic_symmetric
#     mom6_configuration = ocean_only, ice_ocean_SIS, ice_ocean_SIS2, land_ice_ocean_LM3_SIS2, coupled_AM2_LM3_SIS, coupled_AM2_LM3_SIS2
#   If mom6_memory = static
#     mom6_configuration = ocean_only/DOME ocean_only/benchmark ocean_only/double_gyre ...
#
# Intermediate targets:
#   build/compiler/mode/%/lib%.a  for % = fms, icebergs, ice_param, am2, lm3
#   build/compiler/mode/mom6_memory/%/lib%.a  for % = mom6, sis2

# Include local configs if present
-include config.mk

# Local relative paths to with source whose version is usually determined by sub-modules in MOM6-examples
SRC_DIR = src
FMS_SRC = $(SRC_DIR)/FMS
MOM6_SRC = $(SRC_DIR)/MOM6
SIS2_SRC = $(SRC_DIR)/SIS2
COUPLER_SRC = $(SRC_DIR)/coupler/full $(SRC_DIR)/coupler/shared
ICEBERGS_SRC = $(SRC_DIR)/icebergs
MKMF_SRC = $(SRC_DIR)/mkmf
LIST_PATHS = $(MKMF_SRC)/bin/list_paths -l
MKMF = $(MKMF_SRC)/bin/mkmf
BUILD = build
SITE ?= ncrc
ICE_PARAM_SRC=$(SRC_DIR)/ice_param
ATMOS_PARAM_SRC=$(SRC_DIR)/AM2/atmos_param_am3
AM2=$(SRC_DIR)/AM2
AM2_SRC=$(AM2)/atmos_drivers/coupled $(AM2)/atmos_fv_dynamics/driver/coupled $(AM2)/atmos_fv_dynamics/model $(AM2)/atmos_fv_dynamics/tools $(AM2)/atmos_shared_am3 $(ATMOS_PARAM_SRC)
LM2_SRC=$(SRC_DIR)/LM2

SHELL = bash
COMPONENT_SRC ?= fms coupler icebergs ice_param lm2 am2
COMPILERS ?= gnu intel
MODES = repro
LOG = > log

# Converts a path a/b/c to a list "a b c"
slash_to_list = $(subst /, ,$(1))
# Replaces a path a/b/c with ../../../
noop =
rel_path = $(subst $(noop) $(noop),,$(patsubst %,../,$(call slash_to_list,$(1))))
# Returns REPRO=1, DEBUG=1, OPENMP=1, or COVERAGE=1 for repro, debug or coverage, respectively
make_args = $(subst openmp,OPENMP,$(subst repro,REPRO,$(subst debug,DEBUG,$(subst coverage,COVERAGE,$(1)=1))))

all: .SECONDARY

# Environments (env files are source before compilation)
# make-env-dep: $(1) = compiler, $(2) = mode
define make-env-dep
$(BUILD)/$(1)/$(2)/fms/libfms.a: $(BUILD)/$(1)/env
endef
$(foreach c, $(COMPILERS),$(foreach m,$(MODES),$(eval $(call make-env-dep,$c,$m))))
ifeq ($(SITE),ncrc)
$(BUILD)/gnu/env:
	mkdir -p $(@D)
	echo 'source /opt/modules/default/etc/modules.sh' > $@
	echo 'module unload PrgEnv-cray PrgEnv-pgi PrgEnv-intel PrgEnv-gnu; module load PrgEnv-gnu; module unload netcdf gcc; module load cray-hdf5 cray-netcdf' >> $@
$(BUILD)/intel/env:
	mkdir -p $(@D)
	echo 'source /opt/modules/default/etc/modules.sh' > $@
	echo 'module unload PrgEnv-cray PrgEnv-pgi PrgEnv-intel PrgEnv-gnu; module load PrgEnv-intel; module unload netcdf ; module load cray-hdf5 cray-netcdf' >> $@
else
$(BUILD)/gnu/env:
	mkdir -p $(@D)
	echo > $@
$(BUILD)/intel/env:
	mkdir -p $(@D)
	echo > $@
endif

# path_names:
# - must have LIST_PATHS_ARGS set for final target
#$(BUILD)/%/path_names: $(wildcard $(LIST_PATHS_ARGS)*) $(wildcard $(LIST_PATHS_ARGS)*/*) $(wildcard $(LIST_PATHS_ARGS)*/*/*) $$(wildcard $(LIST_PATHS_ARGS)*/*/*/*)
$(BUILD)/%/path_names:
	mkdir -p $(@D)
	cd $(@D); rm -f path_names; $(call rel_path,$(@D))$(LIST_PATHS) $(foreach p,$(LIST_PATHS_ARGS),$(call rel_path,$(@D))$(p)) . $(LOG)

# Makefile:
# - must have MKMF_OPTS set for final target
# fms_compiler = gnu, intel, pgi, cray, ...
fms_compiler = $(word 2,$(call slash_to_list, $(1)))
$(BUILD)/%/Makefile: $(BUILD)/%/path_names
	cd $(@D); $(call rel_path,$(@D))$(MKMF) -t $(call rel_path,$(@D))$(MKMF_SRC)/templates/$(SITE)-$(call fms_compiler,$@).mk $(MKMF_OPTS) path_names $(LOG) 2>&1

# Keep path_names, makefiles and libraries
define secondaries
.SECONDARY: $(foreach c,$(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/$(1)/path_names))
.SECONDARY: $(foreach c,$(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/$(1)/Makefile))
.SECONDARY: $(foreach c,$(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/$(1)/lib$(1).a))
endef
$(foreach d,$(COMPONENT_SRC),$(eval $(call secondaries,$(d))))

# fms_mode = repro, debug, coverage, ...
fms_mode = $(word 3,$(call slash_to_list, $(1)))

#compile target, path_to_env, library dependencies
define compile
$(BUILD)/%/$(1)$(2): $(BUILD)/%/$(1)Makefile $(foreach l,$(4),$(BUILD)/%/$(l))
	rm -f $$@
	@echo Building $$@
	cd $$(@D); (source $(3) && make NETCDF=3 $$(call make_args, $$(call fms_mode, $$@)) $(EXTRA_MAKE_ARGS) $$(@F) $(LOG)) 2>&1 | sed 's,^,$$@: ,'
	@test -f $$@ || exit 11
endef

# build/compiler/mode/fms/libfms.a
#$(BUILD)/%/fms/path_names: LIST_PATHS_ARGS = $(FMS_SRC)/{platform,include,memutils,mpp,fms,constants,time_manager,diag_manager,coupler,field_manager,time_interp,axis_utils,horiz_interp,data_override,astronomy,exchange,mosaic,tracer_manager,sat_vapor_pres,random_numbers}
$(BUILD)/%/fms/path_names: LIST_PATHS_ARGS = $(FMS_SRC)/
$(foreach c, $(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/fms/path_names)): $(FMS_SRC)/*/*
$(BUILD)/%/fms/Makefile: MKMF_OPTS = -p libfms.a -c '-Duse_netCDF -Duse_libMPI'
$(eval $(call compile,fms/,libfms.a,../../env))

# build/compiler/mode/coupler/libcoupler.a
$(BUILD)/%/coupler/path_names: LIST_PATHS_ARGS = $(COUPLER_SRC)/
$(foreach c, $(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/coupler/path_names)): $(COUPLER_SRC)/*
$(BUILD)/%/coupler/Makefile: MKMF_OPTS = -p libcoupler.a -o '-I../fms -I../ice_param -I../am2 -I../lm2 -I../dynamic/mom6 -I../dynamic/sis2 -I../icebergs' -c '$(CPP_DEFS)'
$(BUILD)/%/coupler/Makefile: CPP_DEFS = -Duse_AM3_physics
$(BUILD)/%/coupler/Makefile: CPP_DEFS += -D_USE_LEGACY_LAND_
$(eval $(call compile,coupler/,libcoupler.a,../../env,fms/libfms.a ice_param/libice_param.a am2/libam2.a lm2/liblm2.a dynamic/sis2/libsis2.a icebergs/libicebergs.a dynamic/mom6/libmom6.a))

# build/compiler/mode/icebergs/libicebergs.a
$(BUILD)/%/icebergs/path_names: LIST_PATHS_ARGS = $(ICEBERGS_SRC)/
$(foreach c, $(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/icebergs/path_names)): $(ICEBERGS_SRC)/*
$(BUILD)/%/icebergs/Makefile: MKMF_OPTS = -p libicebergs.a -o '-I../fms'
$(eval $(call compile,icebergs/,libicebergs.a,../../env,fms/libfms.a))

# build/compiler/mode/lm2/liblm2.a
$(BUILD)/%/lm2/path_names: LIST_PATHS_ARGS = $(LM2_SRC)/ $(FMS_SRC)/include/fms_platform.h
$(foreach c, $(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/lm2/path_names)): $(LM2_SRC)/*
$(BUILD)/%/lm2/Makefile: CPP_DEFS += -DLAND_BND_TRACERS
$(BUILD)/%/lm2/Makefile: MKMF_OPTS = -p liblm2.a -o '-I../fms' -c $(CPP_DEFS)
$(eval $(call compile,lm2/,liblm2.a,../../env,fms/libfms.a))

# build/compiler/mode/ice_param/libice_param.a
$(BUILD)/%/ice_param/path_names: LIST_PATHS_ARGS = $(ICE_PARAM_SRC)/
$(foreach c, $(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/ice_param/path_names)): $(ICE_PARAM_SRC)/*
$(BUILD)/%/ice_param/Makefile: MKMF_OPTS = -p libice_param.a -o '-I../fms'
$(eval $(call compile,ice_param/,libice_param.a,../../env,fms/libfms.a))

# build/compiler/mode/am2/libam2.a
$(BUILD)/%/am2/path_names: LIST_PATHS_ARGS = $(AM2_SRC)/ $(AM2_SRC)/*/ $(AM2_SRC)/*/*/ $(FMS_SRC)/include/fms_platform.h
$(foreach c, $(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(c)/$(m)/am2/path_names)): $(AM2_SRC)/*/* $(AM2_SRC)/*/*/*
$(BUILD)/%/am2/Makefile: CPP_DEFS += -DSPMD -Duse_AM3_physics
$(BUILD)/%/am2/Makefile: MKMF_OPTS = -p libam2.a -o '-I../fms' -c '$(CPP_DEFS)'
$(eval $(call compile,am2/,libam2.a,../../env,fms/libfms.a))

# build/compiler/mode/sis2/libsis2.a
$(BUILD)/%/sis2/Makefile: MKMF_OPTS = -p libsis2.a -o '-I../../fms -I../mom6 -I../../icebergs -I../../ice_param' -c '$(CPP_DEFS)'
$(eval $(call compile,sis2/,libsis2.a,../../../env,mom6/libmom6.a))

# build/compiler/mode/mom6_memory/mom6/libmom6.a
$(BUILD)/%/mom6/libmom6.a: MKMF_OPTS = -p libmom6.a -o '-I../../fms' -c '$(CPP_DEFS)'
$(eval $(call compile,mom6/,libmom6.a,../../../env,))

# Generate lists of variables and dependencies for SIS2 libraries
# $(1) = compiler, $(2) = mode, $(3) = memory style, $(4) = mom6 configuration
define sis2-variables
$(BUILD)/$(1)/$(2)/$(3)/$(4)/path_names: $(SIS2_SRC)/src/* $(SIS2_SRC)/config_src/$(3)/* $(MOM6_SRC)/src/framework/MOM_memory_macros.h
$(BUILD)/$(1)/$(2)/$(3)/$(4)/path_names: LIST_PATHS_ARGS = $(SIS2_SRC)/src/ $(SIS2_SRC)/config_src/$(3)/ $(MOM6_SRC)/src/framework/MOM_memory_macros.h
$(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile: CPP_DEFS = -D_FILE_VERSION="`../../../../../$(MKMF_SRC)/bin/git-version-string $$$$<`" -DSTATSLABEL=\"$(STATS_PLATFORM)$(1)$(STATS_COMPILER_VER)\"
$(BUILD)/$(1)/$(2)/$(3)/$(4)/libsis2.a: $(BUILD)/$(1)/$(2)/icebergs/libicebergs.a $(BUILD)/$(1)/$(2)/ice_param/libice_param.a
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/$(4)/path_names
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/$(4)/libsis2.a
endef
$(foreach c,$(COMPILERS),$(foreach m,$(MODES),$(foreach d,dynamic dynamic_symmetric,$(foreach o,sis2,$(eval $(call sis2-variables,$(c),$(m),$(d),$(o)))))))

# Generate lists of variables and dependencies for MOM6 libraries
# $(1) = compiler, $(2) = mode, $(3) = memory style
define libmom6-variables
$(BUILD)/$(1)/$(2)/$(3)/mom6/path_names: LIST_PATHS_ARGS = $(MOM6_SRC)/src/*/ $(MOM6_SRC)/src/*/*/ $(MOM6_SRC)/config_src/$(3)/ $(MOM6_SRC)/config_src/coupled_driver/ $(wildcard $(MOM6_SRC)/config_src/ext*/*/)
$(BUILD)/$(1)/$(2)/$(3)/mom6/path_names: $(MOM6_SRC)/src/*/* $(MOM6_SRC)/src/*/*/* $(MOM6_SRC)/config_src/$(3)/* $(MOM6_SRC)/config_src/coupled_driver/* $(wildcard $(MOM6_SRC)/config_src/ext*/*/*)
$(BUILD)/$(1)/$(2)/$(3)/mom6/Makefile: CPP_DEFS += -D_FILE_VERSION="`../../../../../$(MKMF_SRC)/bin/git-version-string $$$$<`" -DSTATSLABEL=\"$(STATS_PLATFORM)$(1)$(STATS_COMPILER_VER)\"
$(BUILD)/$(1)/$(2)/$(3)/mom6/libmom6.a: $(BUILD)/$(1)/$(2)/fms/libfms.a
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/mom6/path_names
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/mom6/Makefile
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/mom6/libmom6.a
endef
$(foreach c,$(COMPILERS),$(foreach m,$(MODES),$(foreach d,dynamic dynamic_symmetric,$(eval $(call libmom6-variables,$(c),$(m),$(d))))))

# Generate lists of variables and dependencies for MOM6 executables
# $(1) = compiler, $(2) = mode, $(3) = memory style, $(4) = mom6 configuration
define mom6-am2-lm2_sis2-variables
$(BUILD)/$(1)/$(2)/$(3)/$(4)/path_names: LIST_PATHS_ARGS = $(COUPLER_SRC)/
$(foreach c, $(COMPILERS),$(foreach m,$(MODES),$(BUILD)/$(1)/$(2)/$(3)/$(4)/coupler/path_names)): $(COUPLER_SRC)/full/*
$(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile: LIBS += $(foreach l,am2 lm2 ice_param icebergs fms,-L../../$(l))
$(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile: LIBS += $(foreach l,sis2 mom6,-L../$(l))
$(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile: LIBS += $(foreach l,am2 lm2 sis2 ice_param icebergs mom6 fms,-l$(l))
$(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile: CPP_DEFS += -Duse_AM3_physics
$(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile: CPP_DEFS += -D_USE_LEGACY_LAND_
$(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile: MKMF_OPTS = -p MOM6 -o '-I../../fms -I../../am2 -I../../lm2 -I../mom6 -I../sis2 -I../../icebergs -I../../ice_param' -l '$$(LIBS)' -c '$$(CPP_DEFS)'
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: $(BUILD)/$(1)/$(2)/fms/libfms.a
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: $(BUILD)/$(1)/$(2)/icebergs/libicebergs.a
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: $(BUILD)/$(1)/$(2)/$(3)/sis2/libsis2.a
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: $(BUILD)/$(1)/$(2)/$(3)/mom6/libmom6.a
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: $(BUILD)/$(1)/$(2)/coupler/libcoupler.a
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: $(BUILD)/$(1)/$(2)/ice_param/libice_param.a
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: $(BUILD)/$(1)/$(2)/lm2/liblm2.a
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: $(BUILD)/$(1)/$(2)/am2/libam2.a
$(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6: ENV_SCRIPT = ../../../env
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/$(4)/path_names
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/$(4)/Makefile
.SECONDARY: $(BUILD)/$(1)/$(2)/$(3)/$(4)/MOM6
endef
$(foreach c,$(COMPILERS),$(foreach m,$(MODES),$(foreach d,dynamic dynamic_symmetric,$(eval $(call mom6-am2-lm2_sis2-variables,$(c),$(m),$(d),coupled_AM2_LM2_SIS2)))))

# Convenience targets
what:
	find $(BUILD) -name "MOM6" -o -name "lib*.a"
versions:
	find $(SRC_DIR) -name .git -printf "%h\n" | xargs -L 1 bash -c 'cd "$$0" && git remote -v | grep fetch && git status | grep -v "directory clean" && echo '

# For testing this Makefile
# gaea12
# build_gnu -j 3m55s
# build_intel -j 11m40s
# build_pgi -j 22m50s
MOM_CONFIG ?= coupled_AM2_LM2_SIS2
build_gnu:   $(foreach m,dynamic dynamic_symmetric,$(BUILD)/gnu/repro/$(m)/$(MOM_CONFIG)/MOM6)
build_intel: $(foreach m,dynamic dynamic_symmetric,$(BUILD)/intel/repro/$(m)/$(MOM_CONFIG)/MOM6)
debug_gnu:   $(foreach m,dynamic dynamic_symmetric,$(BUILD)/gnu/debug/$(m)/$(MOM_CONFIG)/MOM6)
debug_intel: $(foreach m,dynamic dynamic_symmetric,$(BUILD)/intel/debug/$(m)/$(MOM_CONFIG)/MOM6)

clean_libs:
	find $(BUILD)/ -name "lib*.a" -o -name "MOM6" -exec rm {} \;
clean_make:
	find $(BUILD)/ -name "path_names*" -o -name "Makefile" -exec rm {} \;
clean:
	rm -rf $(BUILD)

.PHONY: list
list:
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'