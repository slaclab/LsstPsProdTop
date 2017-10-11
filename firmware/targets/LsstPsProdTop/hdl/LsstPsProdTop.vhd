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
use work.UserPkg.all;
use work.I2cPkg.all;

library unisim;
use unisim.vcomponents.all;

entity LsstPsProdTop is
  generic (
    TPD_G            : time             := 1 ns;
    BUILD_INFO_G     : BuildInfoType;
    DHCP_G           : boolean          := false;  -- true = DHCP, false = static address
    RSSI_G           : boolean          := false;  -- true = RUDP, false = UDP only
    IP_ADDR_G        : slv(31 downto 0) := x"1401A8C0";  -- 192.168.1.20 (before DHCP)
	  AXI_BASE_ADDR_G   : slv(31 downto 0)     := (others => '0');  -- Base address
    AXI_ERROR_RESP_G : slv(1 downto 0)  := AXI_RESP_DECERR_C);
  port (


--    extRst  : in  sl;
    led     : out slv(2 downto 0);
    enable_in : in  sl;
    spare_in  : in  sl;
 --     clk_sp_p  : in  sl;
 --     clk_sp_n  : in  sl;
    dout0     : in  slv(41 downto 0);
    dout1     : in  slv(41 downto 0);
    din       : out slv(41 downto 0);
    serID     : inout  sl;
--    fpga_POR  : in sl;
    test_IO   : inout  slv(7 downto 0);
    sync_DCDC : out slv(5 downto 0);
    reb_on    : out slv(5 downto 0);
    dummy     : out sl;

      -- i2c
    -- Line to FO transiver
    fp_i2c_data : inout sl;   -- Not implemented
    fp_i2c_clk  : inout sl;   -- Not implemented
    fp_los      : in sl;

    --Temperature monitoring
    temp_SDA : inout sl;
    temp_SCL : inout sl;
    temp_Alarm : in sl;

	-- I2C lines to indidual PS
    SDA_ADC : inout slv(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
    SCL_ADC : inout slv(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);

    -- Boot Memory Ports
    bootCsL  : out   sl;
    bootMosi : out   sl;
    bootMiso : in    sl;

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




  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, AXI_BASE_ADDR_G, 22, 18);  --


  -- constant AXI_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    -- VERSION_INDEX_C     => (
      -- baseAddr          => x"0000_0000",
      -- addrBits          => 16,
      -- connectivity      => x"FFFF"),
    -- XADC_INDEX_C        => (
      -- baseAddr          => x"0001_0000",
      -- addrBits          => 16,
      -- connectivity      => x"FFFF"),
    -- BOOT_PROM_INDEX_C   => (
      -- baseAddr          => x"0002_0000",
      -- addrBits          => 16,
      -- connectivity      => x"FFFF"),
    -- PROM_I2C_INDEX_C    => (
      -- baseAddr          => x"0003_0000",
      -- addrBits          => 16,
      -- connectivity      => x"FFFF"),
    -- ION_CONTROL_INDEX_C => (
      -- baseAddr          => x"0004_0000",
      -- addrBits          => 16,
      -- connectivity      => x"FFFF"));

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

------

   signal psI2cIn        : i2c_in_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
   signal psI2cOut       : i2c_out_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);

   signal tempI2cIn        : i2c_in_type;
   signal tempI2cOut       : i2c_out_type;
   signal fp_I2cIn         : i2c_in_type;
   signal fp_I2cOut        : i2c_out_type;

   signal RegFileIn        : RegFileInType;
   signal RegFileOut       : RegFileOutType;

   signal heartBeat        : sl;
   signal ethLinkUp        : sl;

   attribute dont_touch                 : string;
   attribute dont_touch of RegFileOut    : signal is "true";

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
      ethLinkUp       => ethLinkUp,
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
      MASTERS_CONFIG_G   => AXI_CROSSBAR_MASTERS_CONFIG_C)
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
      EN_DEVICE_DNA_G    => false,
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

  RegFile_Inst : entity work.RegFile
      generic map (
         TPD_G           => TPD_G,
         EN_DEVICE_DNA_G => true)
      port map (
	     axiReadMaster  => axilReadMasters(REGFILE_INDEX_C),
         axiReadSlave   => axilReadSlaves(REGFILE_INDEX_C),
         axiWriteMaster => axilWriteMasters(REGFILE_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(REGFILE_INDEX_C),
         RegFileIn      => RegFileIn,
         RegFileOut     => RegFileOut,

         fdSerSdio      => serID,
         axiClk         => axilClk,
         axiRst         => axilRst);

   PS_REB_intf: for i in  0 to PS_REB_TOTAL_C-1 generate
      PSi2cIoCore_Inst : entity work.PSi2cIoCore
            generic map (
               TPD_G           => TPD_G,
               SIMULATION_G    => false,
               REB_number      => AXI_CROSSBAR_MASTERS_CONFIG_C(PS_AXI_INDEX_ARRAY_C(i)-1).baseAddr(20 downto 17), --"0000",
               AXI_BASE_ADDR_G =>   AXI_CROSSBAR_MASTERS_CONFIG_C(PS_AXI_INDEX_ARRAY_C(i)).baseAddr) --X"00010000")   -- 0x10000
--               AXI_BASE_ADDR_G =>   AXI_CROSSBAR_MASTERS_CONFIG_C(i+1).baseAddr) --X"00010000")   -- 0x10000
            port map (
               axiClk         => axilClk,
               axiRst         => axilRst,
               axiReadMaster  => axilReadMasters(PS_AXI_INDEX_ARRAY_C(i)),
               axiReadSlave   => axilReadSlaves(PS_AXI_INDEX_ARRAY_C(i)),
               axiWriteMaster => axilWriteMasters(PS_AXI_INDEX_ARRAY_C(i)),
               axiWriteSlave  => axilWriteSlaves(PS_AXI_INDEX_ARRAY_C(i)),
               psI2cIn        => psI2cIn(((PS_AXI_INDEX_ARRAY_C(i)-1) * 7) + 6  downto (PS_AXI_INDEX_ARRAY_C(i)-1) * 7),
               psI2cOut       => psI2cOut(((PS_AXI_INDEX_ARRAY_C(i)-1) * 7) + 6  downto (PS_AXI_INDEX_ARRAY_C(i)-1) * 7)
			   );

    end generate PS_REB_intf;

    led(2)  <= heartBeat and not(axilRst);
    led(1)  <= ethLinkUp and not(axilRst); --
    led(0)  <= (axilRst);

   Heartbeat_Inst : entity work.Heartbeat
      generic map(
         TPD_G       => TPD_G,
         PERIOD_IN_G => 8.0E-9)
      port map (
         clk => axilClk,
         o   => heartBeat);

  PS_i2c_intf: for i in (7 * (PS_REB_TOTAL_C - 1) + 6) downto 0 generate
            -- not using enable (used for multimaster i2c, have just 1)
            USDA_ADC: IOBUF port map ( I => psI2cOut(i).sda, O  => psI2cIn(i).sda,  T => psI2cOut(i).sdaoen, IO => SDA_ADC(i));
            USCL_ADC: IOBUF port map ( I => psI2cOut(i).scl, O  => psI2cIn(i).scl,  T => psI2cOut(i).scloen, IO => SCL_ADC(i));
          end generate PS_i2c_intf;

          RegFileIn.GA <= (Others => '0');
          RegFileIn.dout0 <= dout0;
          RegFileIn.dout1 <= dout1;
          RegFileIn.REB_config_done <= (Others => '1');  -- Unused for now , need for case if measuring IC need addtional configuration befere normal sequencing
          RegFileIn.enable_in <= enable_in;
          RegFileIn.spare_in <= spare_in;
          RegFileIn.temp_Alarm <= temp_Alarm;
          RegFileIn.fp_los <= fp_los;

          din <= RegFileOut.din;
          sync_DCDC <= RegFileOut.sync_DCDC;
          reb_on <= RegFileOut.reb_on;

          UtestIO: for i in 7 downto 0 generate
            UTEST: IOBUF port map ( I => RegFileOut.TestOut(i), O  => RegFileIn.TestIn(i),  T => RegFileOut.TestOutOE(i), IO => test_IO(i));
          end generate UtestIO;

       --   UserID: IOBUF port map ( I => RegFileOut.serIDout, O  => RegFileIn.serIDin,  T => RegFileOut.serIDoutOE, IO => serID);

          USDA_temp: IOBUF port map ( I => RegFileOut.tempI2cOut.sda, O  => RegFileIn.tempI2cIn.sda,  T => RegFileOut.tempI2cOut.sdaoen, IO => temp_SDA);
          USCL_temp: IOBUF port map ( I => RegFileOut.tempI2cOut.scl, O  => RegFileIn.tempI2cIn.scl,  T => RegFileOut.tempI2cOut.scloen, IO => temp_SCL);
          USDA_fp:   IOBUF port map ( I => RegFileOut.fp_I2cOut.sda, O  => RegFileIn.fp_i2cIn.sda,  T => RegFileOut.fp_I2cOut.sdaoen, IO => fp_i2c_data);
          USCL_fp:   IOBUF port map ( I => RegFileOut.fp_I2cOut.scl, O  => RegFileIn.fp_i2cIn.scl,  T => RegFileOut.fp_I2cOut.scloen, IO => fp_i2c_clk);


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


end top_level;