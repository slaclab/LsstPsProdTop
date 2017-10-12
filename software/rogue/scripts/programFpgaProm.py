#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : Data Dev test
#-----------------------------------------------------------------------------
# File       : dataDev.py
# Created    : 2017-03-22
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import sys
import argparse
import pyrogue as pr

from LsstPsProdTop import *
    
# Set the argument parser
parser = argparse.ArgumentParser()

# Add arguments
parser.add_argument(
    "--ip", 
    type     = str,
    required = True,
    help     = "IP address of the FPGA",
)  

parser.add_argument(
    "--mcs", 
    type     = str,
    required = True,
    help     = "path to primary MCS file",
)  
  
# Get the arguments
args = parser.parse_args()

# Set base
devTop = pr.Root(name='devTop',description='')

# Add device
devTop.add(LsstPsProdTop(
    name  = 'HW',
    ip    = args.ip,
))

# Start the system
devTop.start(pollEn=False)

# Load the primary MCS file to SPI PROM
devTop.HW.AxiMicronN25Q.LoadMcsFile(args.mcs)  

# Load the new firmware from the PROM to the FPGA with an IPROG command
devTop.HW.AxiVersion.FpgaReload.set(0x1)
# devTop.HW.AxiVersion.FpgaReload.post(0x1) # Waiting for Ben to merge his updates to support post()

# Close out
devTop.stop()
exit()
