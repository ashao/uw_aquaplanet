# Local relative paths to with source whose version is usually determined by sub-modules in MOM6-examples
SITE ?= ncrc
SRC_DIR = ./src
FMS_SRC = $(SRC_DIR)/FMS
MOM6_SRC = $(SRC_DIR)/MOM6
SIS2_SRC = $(SRC_DIR)/SIS2
COUPLER_SRC = $(SRC_DIR)/coupler
ICEBERGS_SRC = $(SRC_DIR)/icebergs
MKMF_SRC = $(SRC_DIR)/mkmf
LIST_PATHS = $(MKMF_SRC)/bin/list_paths -l
MKMF = $(MKMF_SRC)/bin/mkmf
BUILD = build
ICE_PARAM_SRC=$(SRC_DIR)/ice_param
ATMOS_PARAM_SRC=$(SRC_DIR)/atmos_param_am3
LM2_SRC=$(LM2)
AM2_SRC=$(AM2)/atmos_drivers/coupled $(AM2)/atmos_fv_dynamics/driver/coupled $(AM2)/atmos_fv_dynamics/model $(AM2)/atmos_fv_dynamics/tools $(AM2)/atmos_shared_am3 $(ATMOS_PARAM_SRC)
LM2=$(SRC_DIR)/LM2
LM2_REPOS=$(LM2)/land_param
AM2=$(SRC_DIR)/AM2
AM2_REPOS=$(AM2)/atmos_drivers $(AM2)/atmos_fv_dynamics $(AM2)/atmos_shared_am3

SHELL = bash
COMPONENT_SRC ?= fms coupler icebergs ice_param lm2 am2
COMPILERS ?= gnu intel
MODES = repro debug
LOG = > log

MKMF=$(MKMF_SRC)/bin/mkmf
LIST_PATHS=$(MKMF_SRC)/bin/list_paths
MKMF_TEMPLATES=$(MKMF_SRC)/templates

build/gnu/env:
	mkdir -p build/gnu/
	touch $@ 

build/gnu/lib/fms/libfms.a: gnu_env
	BUILD_DIR = build/gnu/fms
	MKMF_OPTS = -p $(basename $@) -c '-Duse_netCDF -Duse_libMPI'
	mkdir -p $(BUILD_DIR); pushd $(BUILD_DIR)
	$(LIST_PATHS) -l $(FMS_SRC)
	$(MKMF) -t $(MKMF_TEMPLATES)/$(SITE)-gnu.mk $(MKMF_OPTS) path_names
	source $<
	make -




  

	
