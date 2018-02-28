#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# Title      : PyRogue febBoard Module
#-----------------------------------------------------------------------------
# File       : SingleNodeTest.py
# Created    : 2016-11-09
# Last update: 2016-11-09
#-----------------------------------------------------------------------------
# Description:
# Rogue interface to FEB board
#-----------------------------------------------------------------------------
# This file is part of the LCLS2-PRL. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the LCLS2-PRL, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import sys
import pyrogue as pr
import pyrogue.gui
import PyQt4.QtGui
import argparse
import LsstPsProdTop as board

# Set the argument parser
parser = argparse.ArgumentParser()

# Add arguments
parser.add_argument(
    "--ip", 
    type     = str,
    required = True,
    help     = "IP address",
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
base = pr.Root(name='base',description='')    

# Add Base Device
base.add(board.Top(
    ip    = args.ip,
    hwEmu = args.hwEmu,
))

# Start the system
base.start(pollEn=args.pollEn)
base.Top.Fpga.Core.AxiVersion.printStatus()

# Create GUI
appTop = PyQt4.QtGui.QApplication(sys.argv)
appTop.setStyle('Fusion')
guiTop = pyrogue.gui.GuiTop(group='rootMesh')
guiTop.resize(800, 1000)
guiTop.addTree(base)

print("Starting GUI...\n");

# Run GUI
appTop.exec_()    
    
base.stop()
exit()   
