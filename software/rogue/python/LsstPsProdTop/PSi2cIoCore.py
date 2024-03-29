#!/usr/bin/env python
##############################################################################
## This file is part of 'camera-link-gen1'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'camera-link-gen1', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

import pyrogue as pr

from LsstPsProdTop.PSi2cIo import *

class PSi2cIoCore(pr.Device):
    def __init__(   self,       
            name        = "PSi2cIoCore",
            description = "",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        mapStride = 0x4000 # genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 18, 14);
        
        # PSi2cIo Module
        for i in range(6):
            self.add(PSi2cIo(            
                name   = ('PSi2cIo[%d]' % i), 
                offset = (i*mapStride), 
                expand = False,
            ))
        