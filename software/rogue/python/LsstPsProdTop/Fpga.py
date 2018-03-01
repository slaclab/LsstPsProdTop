#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : 
#-----------------------------------------------------------------------------
# File       : TopLevel.py
# Created    : 2017-04-03
#-----------------------------------------------------------------------------
# Description:
# 
#-----------------------------------------------------------------------------
# This file is part of the rogue_example software. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue_example software, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import LsstPwrCtrlCore as base
from LsstPsProdTop.RegFile import *
from LsstPsProdTop.PSi2cIoCore import *
  
class Fpga(pr.Device):
    def __init__(self, 
                 name        = "Fpga",
                 description = "Device Memory Mapping",
                 **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        mapStride = 0x40000 # genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 22, 18);
        
        # Add Core device
        self.add(base.Core())            
        
        # Add RegFile Module
        self.add(RegFile(                            
            offset  = (0*mapStride), 
            expand  = False,
        )) 

        # Add PSi2cIoCore devices
        for i in range(6):
            self.add(PSi2cIoCore(
                name    = ('PSi2cIoCore[%d]' % i), 
                offset  = ((i+1)*mapStride), 
                expand  = False,
            ))
