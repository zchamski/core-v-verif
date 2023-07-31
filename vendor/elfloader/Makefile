# Copyright 2022 OpenHW Group
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

# Makefile for the CV32E20 "Board Support Package".
# The "BSP" is the bare-metal programming environment
# for the CV32E20 in it's UVM testbench.
SO_NAME = elfloader.so

SRC = elfloader.cc
OBJ = elfloader.o

SPIKE_ROOT ?=

EDA_INCLUDES = -I$(VCS_HOME)/include -I/$(QUESTASIM_HOME)/include -I$(XCEL_HOME)/include

CFLAGS ?= -Os -g -I/$(SPIKE_ROOT)/include/ $(EDA_INCLUDES) -std=c++17
CFLAGS_SO ?= -fPIC -DSHARED

LDFLAGS ?= -lstdc++
LDFLAGS_SO ?= -shared


CCX = g++

all: $(SO_NAME)


%.o : %.cc
	$(CCX) $(CFLAGS) $(CFLAGS_SO) -c $< -o $@

%.so : $(OBJ)
	$(CCX) $(CFLAGS) $(CFLAGS_SO) $(LDFLAGS) $(LDFLAGS_SO) $< -o $@

%.x :
	$(CCX) $(LDFLAGS) $(CFLAGS) $(SRC) -o $@


clean:
	rm -f $(OBJ) $(SO_NAME)

