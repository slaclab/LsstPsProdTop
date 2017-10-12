#!/usr/bin/env python3
##############################################################################
## This file is part of 'camera-link-gen1'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'camera-link-gen1', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

import sys
import argparse

import pyrogue as pr
import pyrogue.gui
import PyQt4.QtGui

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
    "--hwEmu", 
    type     = bool,
    required = False,
    default  = False,
    help     = "hardware emulation (false=normal operation, true=emulation)",
) 

parser.add_argument(
    "--pollEn", 
    type     = bool,
    required = False,
    default  = False,
    help     = "enable auto-polling",
)  

# Get the arguments
args = parser.parse_args()

# Set base
devTop = pr.Root(name='devTop',description='')

# Add device
devTop.add(LsstPsProdTop(
    name  = 'HW',
    ip    = args.ip,
    hwEmu = args.hwEmu,
))

# Start up the base
devTop.start(pollEn=args.pollEn)

# Create GUI
appTop = PyQt4.QtGui.QApplication(sys.argv)
appTop.setStyle('Fusion')
guiTop = pyrogue.gui.GuiTop(group='rootMesh')
guiTop.resize(800, 1000)
guiTop.addTree(devTop)
print("Starting GUI...\n");

# Run GUI
appTop.exec_()

# Shutdown procedures
devTop.stop()
exit()
