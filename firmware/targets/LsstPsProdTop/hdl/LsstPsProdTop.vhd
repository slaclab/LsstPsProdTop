-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      LsstPsProdTop.vhd -
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Leonid Sapozhnikov
--      Created on: 7/19/2017 1:33:09 PM
--      Last change: LS 10/09/2017 9:40:28 AM
--
-------------------------------------------------------------------------------
-- File       : LsstPsProdTop.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-20
-- Last update: 2017-08-02
-------------------------------------------------------------------------------
-- Description: Firmware Target's Top Level
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

library unisim;
use unisim.vcomponents.all;

entity LsstPsProdTop is
  generic (
    TPD_G            : time             := 1 ns;
    BUILD_INFO_G     : BuildInfoType;
    DHCP_G           : boolean          := true;  -- true = DHCP, false = static address
    RSSI_G           : boolean          := false;  -- true = RUDP, false = UDP only
    IP_ADDR_G        : slv(31 downto 0) := x"0A01A8C0";  -- 192.168.1.10 (before DHCP)
    AXI_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_DECERR_C);
  port (
    -- Ion Pump Control Board ADC SPI Interfaces
    iMonDin  : in    slv(5 downto 0);   -- Serial in from Current Mon ADC
    vMonDin  : in    slv(5 downto 0);   -- Serial in from Voltage Mon ADC
    pMonDin  : in    slv(5 downto 0);   -- Serial in from Power Mon ADC
    adcSClk  : out   slv(5 downto 0);   -- Clock for Monitor ADCs
    -- Ion Pump Control Board ADC SPI Interfaces
    dacDout  : out   slv(5 downto 0);   -- Serial out for Setpoint DACs
    dacSclk  : out   slv(5 downto 0);   -- Clock for the Setpoint DACs
    iProgCsL : out   slv(5 downto 0);   -- Chip Enable for Current DAC
    vProgCsL : out   slv(5 downto 0);   -- Chip Enable for Voltage DAC
    pProgCsL : out   slv(5 downto 0);   -- Chip Enable for Power DAC
    -- Ion Pump Control Board Mode bits
    iMode    : in    slv(5 downto 0);   -- HVPS in Current Limit Mode
    vMode    : in    slv(5 downto 0);   -- HVPS in Voltage Limit Mode
    pMode    : in    slv(5 downto 0);   -- HVPS in Power Limit Mode
    -- Ion Pump Enable
    enable   : out   slv(5 downto 0);   -- Enable HVPS
    -- Boot Memory Ports
    bootCsL  : out   sl;
    bootMosi : out   sl;
    bootMiso : in    sl;
    -- Scratch Pad Prom
    promScl  : inout sl;
    promSda  : inout sl;
    -- 1GbE Ports
    ethClkP  : in    sl;
    ethClkN  : in    sl;
    ethRxP   : in    sl;
    ethRxN   : in    sl;
    ethTxP   : out   sl;
    ethTxN   : out   sl;
    -- Misc.
    extRstL  : in    sl;
    -- XADC Ports
    vPIn     : in    sl;
    vNIn     : in    sl);
end LsstPsProdTop;

architecture top_level of LsstPsProdTop is

  constant SYS_CLK_FREQ_C : real := 156.0E+6;

  constant NUM_AXI_MASTERS_C : natural := 5;

  constant VERSION_INDEX_C     : natural := 0;
  constant XADC_INDEX_C        : natural := 1;
  constant BOOT_PROM_INDEX_C   : natural := 2;
  constant PROM_I2C_INDEX_C    : natural := 3;
  constant ION_CONTROL_INDEX_C : natural := 4;

  constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    VERSION_INDEX_C     => (
      baseAddr          => x"0000_0000",
      addrBits          => 16,
      connectivity      => x"FFFF"),
    XADC_INDEX_C        => (
      baseAddr          => x"0001_0000",
      addrBits          => 16,
      connectivity      => x"FFFF"),
    BOOT_PROM_INDEX_C   => (
      baseAddr          => x"0002_0000",
      addrBits          => 16,
      connectivity      => x"FFFF"),
    PROM_I2C_INDEX_C    => (
      baseAddr          => x"0003_0000",
      addrBits          => 16,
      connectivity      => x"FFFF"),
    ION_CONTROL_INDEX_C => (
      baseAddr          => x"0004_0000",
      addrBits          => 16,
      connectivity      => x"FFFF"));

  signal axilWriteMaster : AxiLiteWriteMasterType;
  signal axilWriteSlave  : AxiLiteWriteSlaveType;
  signal axilReadMaster  : AxiLiteReadMasterType;
  signal axilReadSlave   : AxiLiteReadSlaveType;

  signal axilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal axilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal axilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal axilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);

  signal axilClk : sl;
  signal axilRst : sl;
  signal bootSck : sl;
  signal efuse   : slv(31 downto 0);
  signal ethMac  : slv(47 downto 0);

begin

  --------------------
  -- Local MAC Address
  --------------------
  U_EFuse : EFUSE_USR
    port map (
      EFUSEUSR => efuse);

  ethMac(23 downto 0)  <= x"56_00_08";  -- 08:00:56:XX:XX:XX (big endian SLV)
  ethMac(47 downto 24) <= efuse(31 downto 8);

  -------------------
  -- Ethernet Wrapper
  -------------------
  U_Eth : entity work.LsstPsProdTopEth
    generic map (
      TPD_G     => TPD_G,
      DHCP_G    => DHCP_G,
      RSSI_G    => RSSI_G,
      IP_ADDR_G => IP_ADDR_G)
    port map (
      -- Register Interface
      axilClk         => axilClk,
      axilRst         => axilRst,
      axilReadMaster  => axilReadMaster,
      axilReadSlave   => axilReadSlave,
      axilWriteMaster => axilWriteMaster,
      axilWriteSlave  => axilWriteSlave,
      -- Misc.
      extRstL         => extRstL,
      ethMac          => ethMac,
      ethLinkUp       => open,
      rssiLinkUp      => open,
      -- 1GbE Interface
      ethClkP         => ethClkP,
      ethClkN         => ethClkN,
      ethRxP          => ethRxP,
      ethRxN          => ethRxN,
      ethTxP          => ethTxP,
      ethTxN          => ethTxN);

  ---------------------------
  -- AXI-Lite Crossbar Module
  ---------------------------
  U_Xbar : entity work.AxiLiteCrossbar
    generic map (
      TPD_G              => TPD_G,
      DEC_ERROR_RESP_G   => AXI_ERROR_RESP_G,
      NUM_SLAVE_SLOTS_G  => 1,
      NUM_MASTER_SLOTS_G => NUM_AXI_MASTERS_C,
      MASTERS_CONFIG_G   => AXI_CONFIG_C)
    port map (
      axiClk              => axilClk,
      axiClkRst           => axilRst,
      sAxiWriteMasters(0) => axilWriteMaster,
      sAxiWriteSlaves(0)  => axilWriteSlave,
      sAxiReadMasters(0)  => axilReadMaster,
      sAxiReadSlaves(0)   => axilReadSlave,
      mAxiWriteMasters    => axilWriteMasters,
      mAxiWriteSlaves     => axilWriteSlaves,
      mAxiReadMasters     => axilReadMasters,
      mAxiReadSlaves      => axilReadSlaves);

  ---------------------------
  -- AXI-Lite: Version Module
  ---------------------------
  U_Version : entity work.AxiVersion
    generic map (
      TPD_G              => TPD_G,
      BUILD_INFO_G       => BUILD_INFO_G,
      AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G,
      CLK_PERIOD_G       => (1.0/SYS_CLK_FREQ_C),
      XIL_DEVICE_G       => "7SERIES",
      EN_DEVICE_DNA_G    => true,
      EN_DS2411_G        => false,
      EN_ICAP_G          => true,
      USE_SLOWCLK_G      => false,
      BUFR_CLK_DIV_G     => 8,
      AUTO_RELOAD_EN_G   => false,
      AUTO_RELOAD_TIME_G => 10.0,
      AUTO_RELOAD_ADDR_G => (others => '0'))
    port map (
      axiReadMaster  => axilReadMasters(VERSION_INDEX_C),
      axiReadSlave   => axilReadSlaves(VERSION_INDEX_C),
      axiWriteMaster => axilWriteMasters(VERSION_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(VERSION_INDEX_C),
      axiClk         => axilClk,
      axiRst         => axilRst);

  ------------------------
  -- AXI-Lite: XADC Module
  ------------------------
  U_Xadc : entity work.AxiXadcWrapper
    generic map (
      TPD_G            => TPD_G,
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
    port map (
      axiReadMaster  => axilReadMasters(XADC_INDEX_C),
      axiReadSlave   => axilReadSlaves(XADC_INDEX_C),
      axiWriteMaster => axilWriteMasters(XADC_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(XADC_INDEX_C),
      axiClk         => axilClk,
      axiRst         => axilRst,
      vPIn           => vPIn,
      vNIn           => vNIn);

  ----------------------
  -- AXI-Lite: Boot Prom
  ----------------------
  U_SpiProm : entity work.AxiMicronN25QCore
    generic map (
      TPD_G            => 1 ns,
      MEM_ADDR_MASK_G  => x"00000000",
      AXI_CLK_FREQ_G   => SYS_CLK_FREQ_C,
      SPI_CLK_FREQ_G   => (SYS_CLK_FREQ_C/5.0),
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
    port map (
      -- FLASH Memory Ports
      csL            => bootCsL,
      sck            => bootSck,
      mosi           => bootMosi,
      miso           => bootMiso,
      -- AXI-Lite Register Interface
      axiReadMaster  => axilReadMasters(BOOT_PROM_INDEX_C),
      axiReadSlave   => axilReadSlaves(BOOT_PROM_INDEX_C),
      axiWriteMaster => axilWriteMasters(BOOT_PROM_INDEX_C),
      axiWriteSlave  => axilWriteSlaves(BOOT_PROM_INDEX_C),
      -- Clocks and Resets
      axiClk         => axilClk,
      axiRst         => axilRst);

  -----------------------------------------------------
  -- Using the STARTUPE2 to access the FPGA's CCLK port
  -----------------------------------------------------
  U_STARTUPE2 : STARTUPE2
    port map (
      CFGCLK    => open,  -- 1-bit output: Configuration main clock output
      CFGMCLK   => open,  -- 1-bit output: Configuration internal oscillator clock output
      EOS       => open,  -- 1-bit output: Active high output signal indicating the End Of Startup.
      PREQ      => open,  -- 1-bit output: PROGRAM request to fabric output
      CLK       => '0',  -- 1-bit input: User start-up clock input
      GSR       => '0',  -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
      GTS       => '0',  -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      KEYCLEARB => '0',  -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      PACK      => '0',  -- 1-bit input: PROGRAM acknowledge input
      USRCCLKO  => bootSck,             -- 1-bit input: User CCLK input
      USRCCLKTS => '0',  -- 1-bit input: User CCLK 3-state enable input
      USRDONEO  => '1',  -- 1-bit input: User DONE pin output control
      USRDONETS => '1');  -- 1-bit input: User DONE 3-state enable output

  ----------------------------------------
  -- AXI-Lite: Configuration Memory Module
  ----------------------------------------
  U_I2cProm : entity work.AxiI2cEeprom
    generic map (
      TPD_G            => TPD_G,
      ADDR_WIDTH_G     => 13,           -- Need to verify this value!!!
      I2C_ADDR_G       => "1010000",    -- Need to verify this value!!!
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
      AXI_CLK_FREQ_G   => SYS_CLK_FREQ_C)
    port map (
      -- I2C Ports
      scl             => promScl,
      sda             => promSda,
      -- AXI-Lite Register Interface
      axilReadMaster  => axilReadMasters(PROM_I2C_INDEX_C),
      axilReadSlave   => axilReadSlaves(PROM_I2C_INDEX_C),
      axilWriteMaster => axilWriteMasters(PROM_I2C_INDEX_C),
      axilWriteSlave  => axilWriteSlaves(PROM_I2C_INDEX_C),
      -- Clocks and Resets
      axilClk         => axilClk,
      axilRst         => axilRst);

  ---------------------------------
  -- AXI-Lite: PS Application
  ---------------------------------
  U_App : entity work.LsstPsProdTopApp
    generic map (
      TPD_G            => TPD_G,
      AXI_CLK_FREQ_C   => SYS_CLK_FREQ_C,
--         AXI_BASE_ADDR_G  => AXI_CONFIG_C(ION_CONTROL_INDEX_C).baseAddr,
      AXI_ERROR_RESP_G => AXI_ERROR_RESP_G)
    port map (
      -- AXI-Lite Interface
      axilClk         => axilClk,
      axilRst         => axilRst,
      axilReadMaster  => axilReadMasters(ION_CONTROL_INDEX_C),
      axilReadSlave   => axilReadSlaves(ION_CONTROL_INDEX_C),
      axilWriteMaster => axilWriteMasters(ION_CONTROL_INDEX_C),
      axilWriteSlave  => axilWriteSlaves(ION_CONTROL_INDEX_C),
      -- Controller IO
      -- Ion Pump Control Board ADC SPI Interfaces
      iMonDin         => iMonDin,       -- Serial in from Current Mon ADC
      vMonDin         => vMonDin,       -- Serial in from Voltage Mon ADC
      pMonDin         => pMonDin,       -- Serial in from Power Mon ADC
      adcSClk         => adcSclk,       -- Clock for Monitor ADCs
      -- Ion Pump Control Board ADC SPI Interfaces
      dacDout         => dacDout,       -- Serial out for Setpoint DACs
      dacSclk         => dacSclk,       -- Clock for the Setpoint DACs
      iProgCsL        => iProgCsL,      -- Chip Enable for Current DAC
      vProgCsL        => vProgCsL,      -- Chip Enable for Voltage DAC
      pProgCsL        => pProgCsL,      -- Chip Enable for Power DAC
      -- Ion Pump Control Board Mode bits
      iMode           => iMode,         -- HVPS in Current Limit Mode
      vMode           => vMode,         -- HVPS in Voltage Limit Mode
      pMode           => pMode,         -- HVPS in Power Limit Mode
      -- Ion Pump Enable
      enable          => enable);       -- Enable HVPS

end top_level;
