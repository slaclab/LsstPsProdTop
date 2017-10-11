-------------------------------------------------------------------------------
-- File       : LsstIonPumpCtrlEth.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-05-01
-- Last update: 2017-05-01
-------------------------------------------------------------------------------
-- Description: Ethernet Wrapper
-------------------------------------------------------------------------------
-- This file is part of 'LSST Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'LSST Firmware', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;
use work.EthMacPkg.all;

entity LsstIonPumpCtrlEth is
   generic (
      TPD_G     : time             := 1 ns;
      DHCP_G    : boolean          := true;  -- true = DHCP, false = static address
      RSSI_G    : boolean          := false;  -- true = RUDP, false = UDP only
      IP_ADDR_G : slv(31 downto 0) := x"0A01A8C0");  -- 192.168.1.10 (before DHCP)     
   port (
      -- Register Interface
      axilClk         : out sl;
      axilRst         : out sl;
      axilReadMaster  : out AxiLiteReadMasterType;
      axilReadSlave   : in  AxiLiteReadSlaveType;
      axilWriteMaster : out AxiLiteWriteMasterType;
      axilWriteSlave  : in  AxiLiteWriteSlaveType;
      -- Misc.
      extRstL         : in  sl;
      ethMac          : in  slv(47 downto 0);
      ethLinkUp       : out sl;
      rssiLinkUp      : out sl;
      -- 1GbE Ports
      ethClkP         : in  sl;
      ethClkN         : in  sl;
      ethRxP          : in  sl;
      ethRxN          : in  sl;
      ethTxP          : out sl;
      ethTxN          : out sl);
end LsstIonPumpCtrlEth;

architecture top_level of LsstIonPumpCtrlEth is

   constant ETH_CLK_FREQ_C : real                             := 125.0E+6;
   constant SERVER_PORTS_C : PositiveArray(0 downto 0)        := (0 => 8192);  -- UDP Server @ Port = 8192
   constant AXIS_CONFIG_C  : AxiStreamConfigArray(0 downto 0) := (0 => EMAC_AXIS_CONFIG_C);

   signal obMacMaster : AxiStreamMasterType;
   signal obMacSlave  : AxiStreamSlaveType;
   signal ibMacMaster : AxiStreamMasterType;
   signal ibMacSlave  : AxiStreamSlaveType;

   signal obServerMaster : AxiStreamMasterType;
   signal obServerSlave  : AxiStreamSlaveType;
   signal ibServerMaster : AxiStreamMasterType;
   signal ibServerSlave  : AxiStreamSlaveType;

   signal appIbMaster : AxiStreamMasterType;
   signal appIbSlave  : AxiStreamSlaveType;
   signal appObMaster : AxiStreamMasterType;
   signal appObSlave  : AxiStreamSlaveType;

   signal ethClk     : sl;
   signal ethRst     : sl;
   signal extRst     : sl;
   signal rssiStatus : slv(6 downto 0);

begin

   axilClk    <= ethClk;
   axilRst    <= ethRst;
   extRst     <= not(extRstL);
   rssiLinkUp <= rssiStatus(0);

   ------------------------
   -- GigE Core for ARTIX-7
   ------------------------
   U_PHY_MAC : entity work.GigEthGtp7Wrapper
      generic map (
         TPD_G              => TPD_G,
         NUM_LANE_G         => 1,
         -- Clocking Configurations
         USE_GTREFCLK_G     => false,
         CLKIN_PERIOD_G     => 6.4,     -- 156.25 MHz
         DIVCLK_DIVIDE_G    => 5,       -- 31.25 MHz = (156.25 MHz/5)
         CLKFBOUT_MULT_F_G  => 32.0,    -- 1 GHz = (32 x 31.25 MHz)
         CLKOUT0_DIVIDE_F_G => 8.0,     -- 125 MHz = (1.0 GHz/8)   
         -- AXI Streaming Configurations
         AXIS_CONFIG_G      => (others => EMAC_AXIS_CONFIG_C))
      port map (
         -- Local Configurations
         localMac(0)     => ethMac,
         -- Streaming DMA Interface 
         dmaClk(0)       => ethClk,
         dmaRst(0)       => ethRst,
         dmaIbMasters(0) => obMacMaster,
         dmaIbSlaves(0)  => obMacSlave,
         dmaObMasters(0) => ibMacMaster,
         dmaObSlaves(0)  => ibMacSlave,
         -- Misc. Signals
         extRst          => extRst,
         phyClk          => ethClk,
         phyRst          => ethRst,
         phyReady(0)     => ethLinkUp,
         -- MGT Ports
         gtClkP          => ethClkP,
         gtClkN          => ethClkN,
         gtTxP(0)        => ethTxP,
         gtTxN(0)        => ethTxN,
         gtRxP(0)        => ethRxP,
         gtRxN(0)        => ethRxN);

   ----------------------
   -- IPv4/ARP/UDP Engine
   ----------------------
   U_UDP : entity work.UdpEngineWrapper
      generic map (
         -- Simulation Generics
         TPD_G          => TPD_G,
         -- UDP Server Generics
         SERVER_EN_G    => true,
         SERVER_SIZE_G  => 1,
         SERVER_PORTS_G => SERVER_PORTS_C,
         -- UDP Client Generics
         CLIENT_EN_G    => false,
         -- General IPv4/ARP/DHCP Generics
         DHCP_G         => DHCP_G,
         CLK_FREQ_G     => ETH_CLK_FREQ_C,
         COMM_TIMEOUT_G => 30)
      port map (
         -- Local Configurations
         localMac           => ethMac,
         localIp            => IP_ADDR_G,
         -- Interface to Ethernet Media Access Controller (MAC)
         obMacMaster        => obMacMaster,
         obMacSlave         => obMacSlave,
         ibMacMaster        => ibMacMaster,
         ibMacSlave         => ibMacSlave,
         -- Interface to UDP Server engine(s)
         obServerMasters(0) => obServerMaster,
         obServerSlaves(0)  => obServerSlave,
         ibServerMasters(0) => ibServerMaster,
         ibServerSlaves(0)  => ibServerSlave,
         -- Clock and Reset
         clk                => ethClk,
         rst                => ethRst);

   GEN_RSSI : if (RSSI_G = true) generate
      ---------------------------------------------------------------
      -- Wrapper for RSSI + AXIS packetizer 
      -- Documentation: https://confluence.slac.stanford.edu/x/1IyfD  
      ---------------------------------------------------------------      
      U_RssiServer : entity work.RssiCoreWrapper
         generic map (
            TPD_G               => TPD_G,
            MAX_SEG_SIZE_G      => 1024,
            SEGMENT_ADDR_SIZE_G => 7,
            APP_STREAMS_G       => 1,
            APP_STREAM_ROUTES_G => (0 => "--------"),
            CLK_FREQUENCY_G     => ETH_CLK_FREQ_C,
            TIMEOUT_UNIT_G      => 1.0E-3,  -- In units of seconds
            SERVER_G            => true,
            RETRANSMIT_ENABLE_G => true,
            BYPASS_CHUNKER_G    => false,
            WINDOW_ADDR_SIZE_G  => 3,
            PIPE_STAGES_G       => 1,
            APP_AXIS_CONFIG_G   => AXIS_CONFIG_C,
            TSP_AXIS_CONFIG_G   => EMAC_AXIS_CONFIG_C,
            INIT_SEQ_N_G        => 16#80#)
         port map (
            clk_i                => ethClk,
            rst_i                => ethRst,
            openRq_i             => '1',
            -- Transport Layer Interface
            sTspAxisMaster_i     => obServerMaster,
            sTspAxisSlave_o      => obServerSlave,
            mTspAxisMaster_o     => ibServerMaster,
            mTspAxisSlave_i      => ibServerSlave,
            -- Application Layer Interface
            sAppAxisMasters_i(0) => appIbMaster,
            sAppAxisSlaves_o(0)  => appIbSlave,
            mAppAxisMasters_o(0) => appObMaster,
            mAppAxisSlaves_i(0)  => appObSlave,
            -- Internal statuses
            statusReg_o          => rssiStatus);
   end generate;

   BYP_RSSI : if (RSSI_G = false) generate
      ---------------------------
      -- No UDP reliability Layer
      ---------------------------
      appObMaster    <= obServerMaster;
      obServerSlave  <= appObSlave;
      ibServerMaster <= appIbMaster;
      appIbSlave     <= ibServerSlave;
      rssiStatus     <= (others => '0');
   end generate;

   ---------------------------------------------------------------
   -- SLAC Register Protocol Version 3, AXI-Lite Interface
   -- Documentation: https://confluence.slac.stanford.edu/x/cRmVD   
   ---------------------------------------------------------------
   U_SRPv3 : entity work.SrpV3AxiLite
      generic map (
         TPD_G               => TPD_G,
         SLAVE_READY_EN_G    => true,
         GEN_SYNC_FIFO_G     => true,
         AXI_STREAM_CONFIG_G => EMAC_AXIS_CONFIG_C)
      port map (
         -- Streaming Slave (Rx) Interface (sAxisClk domain) 
         sAxisClk         => ethClk,
         sAxisRst         => ethRst,
         sAxisMaster      => appObMaster,
         sAxisSlave       => appObSlave,
         -- Streaming Master (Tx) Data Interface (mAxisClk domain)
         mAxisClk         => ethClk,
         mAxisRst         => ethRst,
         mAxisMaster      => appIbMaster,
         mAxisSlave       => appIbSlave,
         -- Master AXI-Lite Interface (axilClk domain)
         axilClk          => ethClk,
         axilRst          => ethRst,
         mAxilReadMaster  => axilReadMaster,
         mAxilReadSlave   => axilReadSlave,
         mAxilWriteMaster => axilWriteMaster,
         mAxilWriteSlave  => axilWriteSlave);

end top_level;
