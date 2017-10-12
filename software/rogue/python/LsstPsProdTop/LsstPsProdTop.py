#!/usr/bin/env python
##############################################################################
## This file is part of 'LsstPsProdTop'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'LsstPsProdTop', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

import pyrogue as pr
import pyrogue.simulation
import pyrogue.protocols

from surf.axi import *
from surf.devices.micron import *
from surf.xilinx import *

from LsstPsProdTop.RegFile import *
from LsstPsProdTop.PSi2cIoCore import *

class LsstPsProdTop(pr.Device):
    def __init__(   self,       
            name        = "LsstPsProdTop",
            description = "Container for application registers",
            ip          = "10.0.0.100",
            port        = 8192,
            hwEmu       = False,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        mapStride = 0x40000 # genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 22, 18);
        
        if (hwEmu):
            # Create emulate SRP interface
            srp=pyrogue.simulation.MemEmulate()
        else:        
            # Create the SRPv3 interface
            srp = rogue.protocols.srp.SrpV3()
            # Create the UDP client Interface
            udp = rogue.protocols.udp.Client(ip,port,1500)
            # Map the UDP stream to the SRP stream
            pr.streamConnectBiDir(srp,udp)
            
        # RegFile Module
        self.add(RegFile(            
            memBase = srp,                                   
            offset  = (0*mapStride), 
            expand  = False,
        )) 

        # PSi2cIoCore Module
        for i in range(6):
            self.add(PSi2cIoCore(            
                memBase = srp,                                   
                name    = ('PSi2cIoCore[%d]' % i), 
                offset  = ((i+1)*mapStride), 
                expand  = False,
            ))         
        
        # Standard AxiVersion Module
        self.add(AxiVersion(            
            memBase = srp,                                   
            offset = (7*mapStride), 
            expand = False,
        ))
        
        # XADC Module
        self.add(Xadc(
            memBase = srp,                                   
            offset = (8*mapStride),
            expand = False,                                                                    
        ))           
        
        # Boot PROM
        self.add(AxiMicronN25Q(
            memBase = srp,                                   
            offset  = (9*mapStride),
            expand  = False,                                    
            hidden  = True,                                    
        ))
        