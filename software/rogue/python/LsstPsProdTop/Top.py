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

import rogue
import pyrogue
import pyrogue.interfaces.simulation
import pyrogue.protocols
import LsstPsProdTop as board
  
class Top(pyrogue.Device):
    def __init__(   self,       
            name        = "Top",
            description = "Container for FPGA",
            hwEmu       = False,
            rssiEn      = False,
            ip          = '192.168.1.10',
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        # Check if emulating the GUI interface
        if (hwEmu):
            # Create emulated hardware interface
            print ("Running in Hardware Emulation Mode:")
            srp = pyrogue.interfaces.simulation.MemEmulate()
            
        else:        
            # Create srp interface
            srp = rogue.protocols.srp.SrpV3()
            
            # Check for RSSI
            if (rssiEn):
                # UDP + RSSI
                udp = pyrogue.protocols.UdpRssiPack( host=ip, port=8192, size=1500 )
                # Connect the SRPv3 to tDest = 0x0
                pyrogue.streamConnectBiDir( srp, udp.application(dest=0x0) )
            else:        
                # UDP only
                udp = rogue.protocols.udp.Client(  ip, 8192, 1500 )
                # Connect the SRPv3 to UDP
                pyrogue.streamConnectBiDir( srp, udp )
                
        self.add(board.Fpga(
            memBase = srp,
            offset  = 0x00000000, 
        ))        
       
