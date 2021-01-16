##########################################################################################
# Applications must define the 32-bitFirmware Version Number
##########################################################################################
export PRJ_VERSION = 0x00000005

##########################################################################################
# Application have the option to remove unused source code from Vivado project
#     If REMOVE_UNUSED_CODE = 0, all source code is kept after importing to Vivado project
#     If REMOVE_UNUSED_CODE = 1, all unused source code is removed from Vivado project
##########################################################################################
export REMOVE_UNUSED_CODE = 0

##########################################################################################
############################  DO NOT EDIT THE CODE BELOW  ################################
##########################################################################################

# Define target output
target: prom

# Define target part
# Edit this for each target
export PRJ_PART = xc7a100tfgg484-3

# Use top level makefile
include ../../submodules/ruckus/system_vivado.mk
