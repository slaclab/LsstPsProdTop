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

class RegFile(pr.Device):
    def __init__(   self,       
            name        = "RegFile",
            description = "",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
        
        self.add(pr.RemoteVariable( 
            name         = "FpgaVersion",
            description  = "FPGA Firmware Version Number",
            offset       = (0x00*4),
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RO",
            # pollInterval = 1
        ))           
        
        self.add(pr.RemoteVariable( 
            name         = "ScratchPad",
            description  = "Register to test reads and writes",
            offset       = (0x01*4),
            bitSize      = 32,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",   
        ))   
        
        self.add(pr.RemoteVariable(   
            name         = "DnaValue",
            description  = "Device Identification",
            offset       = (0x02*4),
            bitSize      = 64,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RO",
            # pollInterval = 1
        ))        

        self.add(pr.RemoteVariable( 
            name         = "sync_DCDC",
            description  = "",
            offset       = (0x04*4),
            bitSize      = 6,
            bitOffset    = 16,
            base         = pr.UInt,
            mode         = "RW",   
        ))        
        
        self.add(pr.RemoteVariable(   
            name         = "Spare_in",
            description  = "",
            offset       = (0x04*4),
            bitSize      = 1,
            bitOffset    = 9,
            base         = pr.UInt,
            mode         = "RO",
            # pollInterval = 1
        ))
        
        self.add(pr.RemoteVariable(   
            name         = "Enable_in",
            description  = "",
            offset       = (0x04*4),
            bitSize      = 1,
            bitOffset    = 8,
            base         = pr.UInt,
            mode         = "RO",
            # pollInterval = 1
        ))   

        self.add(pr.RemoteVariable(   
            name         = "GA",
            description  = "",
            offset       = (0x04*4),
            bitSize      = 5,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RO",
            # pollInterval = 1
        ))           
        
        # self.add(pr.RemoteVariable( 
            # name         = "Spare",
            # description  = "",
            # offset       = (0x05*4),
            # bitSize      = 32,
            # bitOffset    = 0,
            # base         = pr.UInt,
            # mode         = "RW",   
        # ))   

        self.add(pr.RemoteVariable( 
            name         = "FpgaReload",
            description  = "",
            offset       = (0x05*4),
            bitSize      = 1,
            bitOffset    = 1,
            base         = pr.UInt,
            mode         = "RW",   
        ))         

        self.add(pr.RemoteVariable( 
            name         = "MasterReset",
            description  = "",
            offset       = (0x05*4),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",   
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "StatusData_D",
            description  = "",
            offset       = (0x06*4),
            bitSize      = 128,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RO",
            # pollInterval = 1
        ))      

        self.add(pr.RemoteVariable(   
            name         = "StatusDataL",
            description  = "",
            offset       = (0x0A*4),
            bitSize      = 128,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RO",
            # pollInterval = 1
        ))              
        
        self.addRemoteVariables(   
            name         = "StatusRst",
            description  = "",
            offset       = (0x0A*4),
            bitSize      = 1,
            bitOffset    = 31,
            base         = pr.UInt,
            mode         = "WO",
            number       = 4,
            stride       = 4,
            # hidden       = True,
        )        

        ########################################################
        # Please add the reset of the registers from RegFile.vhd
        ######################################################## 
        