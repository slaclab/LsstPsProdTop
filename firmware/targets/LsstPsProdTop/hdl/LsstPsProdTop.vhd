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
-- Last update: 2018-02-13
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
      TPD_G        : time := 1 ns;
      BUILD_INFO_G : BuildInfoType);
   port (
      led         : out   slv(2 downto 0);
      enable_in   : in    sl;
      spare_in    : in    sl;
      dout0       : in    slv(41 downto 0);
      dout1       : in    slv(41 downto 0);
      din         : out   slv(41 downto 0);
      serID       : inout sl;
      test_IO     : inout slv(7 downto 0);
      sync_DCDC   : out   slv(5 downto 0);
      reb_on      : out   slv(5 downto 0);
      dummy       : out   sl;
      GA          : in    slv(3 downto 0);
      -- Line to FO transceiver
      fp_i2c_data : inout sl;           -- Not implemented
      fp_i2c_clk  : inout sl;           -- Not implemented
      fp_los      : in    sl;
      --Temperature monitoring
      temp_SDA    : inout sl;
      temp_SCL    : inout sl;
      temp_Alarm  : in    sl;
      -- I2C lines to individual PS
      SDA_ADC     : inout slv(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
      SCL_ADC     : inout slv(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
      -- Boot Memory Ports
--      bootCsL     : out   sl;
--      bootMosi    : out   sl;
--      bootMiso    : in    sl;
      -- 1GbE Ports
      ethClkP     : in    sl;
      ethClkN     : in    sl;
      ethRxP      : in    slv(0 downto 0);
      ethRxN      : in    slv(0 downto 0);
      ethTxP      : out   slv(0 downto 0);
      ethTxN      : out   slv(0 downto 0);
      -- Misc.
      extRstL     : in    sl;
      -- XADC Ports
      vPIn        : in    sl;
      vNIn        : in    sl);
end LsstPsProdTop;

architecture top_level of LsstPsProdTop is

   signal axilClk          : sl;
   signal axilRst          : sl;
   signal axilWriteMasters : AxiLiteWriteMasterArray(6 downto 0);
   signal axilWriteSlaves  : AxiLiteWriteSlaveArray(6 downto 0);
   signal axilReadMasters  : AxiLiteReadMasterArray(6 downto 0);
   signal axilReadSlaves   : AxiLiteReadSlaveArray(6 downto 0);

   signal psI2cIn  : i2c_in_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
   signal psI2cOut : i2c_out_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);

   signal tempI2cIn  : i2c_in_type;
   signal tempI2cOut : i2c_out_type;
   signal fp_I2cIn   : i2c_in_type;
   signal fp_I2cOut  : i2c_out_type;

   signal RegFileIn  : RegFileInType;
   signal RegFileOut : RegFileOutType;

   signal heartBeat : sl;
   signal ethLinkUp : slv(0 downto 0);

   signal rebOnOff     : slv(5 downto 0);
   signal rebOnOff_add : slv(5 downto 0);
   signal reb_on_l     : slv(5 downto 0);
   signal configDone   : slv(5 downto 0);
   signal allRunning   : slv(5 downto 0);
   signal initDone_add : slv(5 downto 0);
   signal initFail_add : slv(5 downto 0);
   signal initDone     : slv(5 downto 0);
   signal initFail     : slv(5 downto 0);
   signal powerFailure : slv(5 downto 0);
   signal selectCR     : sl;
   signal din_l        : slv(47 downto 0);
   signal din_out      : slv(41 downto 0);
   signal dout_l       : slv(95 downto 0);
   signal dout         : slv(83 downto 0);
   signal StatusSeq    : slv32Array(5 downto 0);

   signal dout0Map     : slv(41 downto 0);
   signal dout1Map     : slv(41 downto 0);
   signal dinMap       : slv(41 downto 0);
   signal sync_DCDCMap : slv(5 downto 0);
   signal reb_onMap    : slv(5 downto 0);

   signal efuse    : slv(31 downto 0);
   signal dnaValue : slv(127 downto 0);
   
--   signal alertCleared : slv(5 downto 0);
--   signal alertCleared_add : slv(5 downto 0);
   signal clearAlert   : slv(5 downto 0);
   signal sequenceDone : slv(5 downto 0);
--   signal alertCldAck  : slv(5 downto 0);
   signal clearAlert_add   : slv(5 downto 0);
   signal sequenceDone_add : slv(5 downto 0);
--   signal alertCldAck_add  : slv(5 downto 0);
   signal clearAlert_l   : slv(5 downto 0);
   signal sequenceDone_l : slv(5 downto 0);
--   signal alertCldAck_l  : slv(5 downto 0);
   
   signal psI2cInMap  : i2c_in_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
   signal psI2cOutMap : i2c_out_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);

   attribute dont_touch               : string;
   attribute dont_touch of RegFileOut : signal is "true";

begin

   ---------------------
   -- Common Core Module
   ---------------------
   U_Core : entity work.LsstPwrCtrlCore
      generic map (
         TPD_G        => TPD_G,
         BUILD_INFO_G => BUILD_INFO_G)
      port map (
         -- Register Interface
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMasters  => axilReadMasters,
         axilReadSlaves   => axilReadSlaves,
         axilWriteMasters => axilWriteMasters,
         axilWriteSlaves  => axilWriteSlaves,
         -- Misc.
         extRstL          => extRstL,
         ethLinkUp        => ethLinkUp,
         heartBeat        => heartBeat,
         efuse            => efuse,
         dnaValue         => dnaValue,
         -- XADC Ports
         vPIn             => vPIn,
         vNIn             => vNIn,
         -- Boot Memory Ports
--         bootCsL          => bootCsL,
--         bootMosi         => bootMosi,
--         bootMiso         => bootMiso,
         -- 1GbE Interface
         ethClkP          => ethClkP,
         ethClkN          => ethClkN,
         ethRxP           => ethRxP,
         ethRxN           => ethRxN,
         ethTxP           => ethTxP,
         ethTxN           => ethTxN);

   ------------
   -- Remapping
   ------------
   U_Map : entity work.Mapping
      port map (
         dout0        => dout0,
         dout1        => dout1,
         din          => din,
         dout0Map     => dout0Map,
         dout1Map     => dout1Map,
         dinMap       => dinMap,
         sync_DCDC    => sync_DCDC,
         reb_on       => reb_on,
         sync_DCDCMap => sync_DCDCMap,
         reb_onMap    => reb_onMap,
         psI2cIn      => psI2cIn,
         psI2cOut     => psI2cOut,
         psI2cInMap   => psI2cInMap,
         psI2cOutMap  => psI2cOutMap,
		 selectVerB   => efuse(1),
         selectCR     => selectCR);

   ----------
   -- RegFile
   ----------
   U_RegFile : entity work.RegFile
      generic map (
         TPD_G => TPD_G)
      port map (
         axiReadMaster  => axilReadMasters(REGFILE_INDEX_C),
         axiReadSlave   => axilReadSlaves(REGFILE_INDEX_C),
         axiWriteMaster => axilWriteMasters(REGFILE_INDEX_C),
         axiWriteSlave  => axilWriteSlaves(REGFILE_INDEX_C),
         RegFileIn      => RegFileIn,
         RegFileOut     => RegFileOut,
         configDone     => configDone,
         allRunning     => allRunning,
         initDone       => initDone,
         initFail       => initFail,
         selectCR       => selectCR,
         StatusSeq      => StatusSeq,
         powerFailure   => powerFailure,
         din_out        => din_out,
         reb_on_out     => reb_on_l,
         dnaValue       => dnaValue,
         fdSerSdio      => serID,
         axiClk         => axilClk,
         axiRst         => axilRst);

   PS_REB_intf : for i in PS_REB_TOTAL_C-1 downto 0 generate
      PSi2cIoCore_Inst : entity work.PSi2cIoCore
         generic map (
            TPD_G           => TPD_G,
            SIMULATION_G    => false,
            REB_number      => AXI_CROSSBAR_MASTERS_CONFIG_C(PS_AXI_INDEX_ARRAY_C(i)-1).baseAddr(21 downto 18),  --"0000",
            AXI_BASE_ADDR_G => AXI_CROSSBAR_MASTERS_CONFIG_C(PS_AXI_INDEX_ARRAY_C(i)).baseAddr)  --X"00010000")   -- 0x10000
         port map (
            axiClk         => axilClk,
            axiRst         => axilRst,
            REB_on         => reb_on_l(i),  --RegFileOut.reb_on(i),  --
--		    alertCleared   => alertCleared(i),
	        clearAlert     => clearAlert_l(i),
			sequenceDone   => sequenceDone_l(i),
--			alertCldAck     => alertCldAck_l(i),
            selectCR       => selectCR,
            unlockFilt     => RegFileOut.unlockSeting(0),
            axiReadMaster  => axilReadMasters(PS_AXI_INDEX_ARRAY_C(i)),
            axiReadSlave   => axilReadSlaves(PS_AXI_INDEX_ARRAY_C(i)),
            axiWriteMaster => axilWriteMasters(PS_AXI_INDEX_ARRAY_C(i)),
            axiWriteSlave  => axilWriteSlaves(PS_AXI_INDEX_ARRAY_C(i)),
            psI2cIn        => psI2cIn(((PS_AXI_INDEX_ARRAY_C(i)-1) * 7) + 6 downto (PS_AXI_INDEX_ARRAY_C(i)-1) * 7),
            psI2cOut       => psI2cOut(((PS_AXI_INDEX_ARRAY_C(i)-1) * 7) + 6 downto (PS_AXI_INDEX_ARRAY_C(i)-1) * 7),
            InitDone       => initDone(i),
            InitFail       => initFail(i)
            );

      REBSequencer_Inst : entity work.REBSequencer
         generic map (
            TPD_G        => TPD_G,
            SIMULATION_G => false,
            REB_number   => AXI_CROSSBAR_MASTERS_CONFIG_C(PS_AXI_INDEX_ARRAY_C(i)-1).baseAddr(21 downto 18))
         port map (
            axiClk        => axilClk,
            axiRst        => axilRst,
            rebOn         => RegFileOut.reb_on(i),  --
            hvOn          => RegFileOut.din(i*7 + 6),
			dPhiOn        => RegFileOut.din(i*7 + 5),
			retryOnFail   => RegFileOut.retryOnFail, 
--	        alertCleared  => alertCleared(i),
--			alertCleared_add  => alertCleared_add(i),
	        clearAlert    => clearAlert(i),
			clearAlert_add => clearAlert_add(i),
			sequenceDone  => sequenceDone(i),
			sequenceDone_add => sequenceDone_add(i),
--			alertCldAck     => alertCldAck(i),
--			alertCldAck_add => alertCldAck_add(i),
            rebOnOff      => rebOnOff(i),
            rebOnOff_add  => rebOnOff_add(i),
            RegFileIn     => RegFileIn,
            configDone    => configDone(i),
            allRunning    => allRunning(i),
            initDone_add  => initDone_add(i),
            initFail_add  => initFail_add(i),
            initDone      => initDone(i),
            initFail      => initFail(i),
            initDone_temp => RegFileOut.TempInitDone,
            initFail_temp => RegFileOut.Tempfail,
            selectCR      => selectCR,
            unlockPsOn    => RegFileOut.unlockSeting(1),
			unlockSeq     => RegFileOut.unlockSeting(2),
            din           => din_l(i*8 +7 downto i*8),
            dout          => dout_l(i*16 +15 downto i*16),
            temp_Alarm    => temp_Alarm,
            Status        => StatusSeq(i),
            powerFailure  => powerFailure(i)
            );

   end generate PS_REB_intf;
   initDone_add          <= "00" & initDone(5) & "00" & initDone(2);
   initFail_add          <= "00" & initFail(5) & "00" & initFail(2);
--   alertCleared_add          <= "00" & alertCleared(5) & "00" & alertCleared(2);
   selectCR              <= efuse(0);   --GA(0);
   -- Rearangement due to CR special case
   din_out(3 downto 0)   <= din_l(3 downto 0);
   din_out(4)            <= not(din_l(4));
   din_out(5)            <= din_l(5);
   din_out(6)            <= not(din_l(6));
   din_out(10 downto 7)  <= din_l(11 downto 8);
   din_out(11)           <= not(din_l(12));
   din_out(12)           <= din_l(13);
   din_out(13)           <= not(din_l(14));
   din_out(14)           <= din_l(16) or din_l(7);
   din_out(17 downto 15) <= din_l(19 downto 17);
   din_out(18)           <= not(din_l(20));
   din_out(19)           <= din_l(21);
   din_out(20)           <= not(din_l(22));
   din_out(24 downto 21) <= din_l(27 downto 24);
   din_out(25)           <= not(din_l(28));
   din_out(26)           <= din_l(29);
   din_out(27)           <= not(din_l(30));
   din_out(31 downto 28) <= din_l(35 downto 32);
   din_out(32)           <= not(din_l(36));
   din_out(33)           <= din_l(37);
   din_out(34)           <= not(din_l(38));
   din_out(35)           <= din_l(40) or din_l(31);
   din_out(38 downto 36) <= din_l(43 downto 41);
   din_out(39)           <= not(din_l(44));
   din_out(40)           <= din_l(45);
   din_out(41)           <= not(din_l(46));

   dinMap <= din_out;

   DOUT_REARRANGE : for i in 41 downto 0 generate
      dout(2 * i + 1 downto 2*i) <= dout1Map(i) & dout0Map(i);
   end generate DOUT_REARRANGE;

   dout_l(15 downto 0)  <= not(dout(29 downto 28)) & not(dout(13 downto 0));
   dout_l(31 downto 16) <= "00" & not(dout(27 downto 14));
   dout_l(47 downto 32) <= "00" & not(dout(41 downto 28));
   dout_l(63 downto 48) <= not(dout(71 downto 70)) & not(dout(55 downto 42));
   dout_l(79 downto 64) <= "00" & not(dout(69 downto 56));
   dout_l(95 downto 80) <= "00" & not(dout(83 downto 70));

   reb_on_l(0) <= rebOnOff(0);
   reb_on_l(1) <= rebOnOff(1);
   reb_on_l(2) <= rebOnOff(2) or rebOnOff_add(0);
   reb_on_l(3) <= rebOnOff(3);
   reb_on_l(4) <= rebOnOff(4);
   reb_on_l(5) <= rebOnOff(5) or rebOnOff_add(3);
   reb_onMap   <= reb_on_l;
   
   clearAlert_l(0) <= clearAlert(0);
   clearAlert_l(1) <= clearAlert(1);
   clearAlert_l(2) <= clearAlert(2) or clearAlert_add(0);
   clearAlert_l(3) <= clearAlert(3);
   clearAlert_l(4) <= clearAlert(4);
   clearAlert_l(5) <= clearAlert(5) or clearAlert_add(3);
 
   sequenceDone_l(0) <= sequenceDone(0);
   sequenceDone_l(1) <= sequenceDone(1);
   sequenceDone_l(2) <= sequenceDone(2) or sequenceDone_add(0);
   sequenceDone_l(3) <= sequenceDone(3);
   sequenceDone_l(4) <= sequenceDone(4);
   sequenceDone_l(5) <= sequenceDone(5) or sequenceDone_add(3); 

   -- alertCldAck_l(0) <= alertCldAck(0);
   -- alertCldAck_l(1) <= alertCldAck(1);
   -- alertCldAck_l(2) <= alertCldAck(2) or alertCldAck_add(0);
   -- alertCldAck_l(3) <= alertCldAck(3);
   -- alertCldAck_l(4) <= alertCldAck(4);
   -- alertCldAck_l(5) <= alertCldAck(5) or alertCldAck_add(3); 
   
   led(2) <= (heartBeat and not(axilRst)) or
             (initDone(5) and initDone(4) and initDone(3) and initDone(2)
              and initDone(1) and initDone(0));
   led(1) <= ethLinkUp(0) and not(axilRst);  --
   led(0) <= (axilRst) or ((powerFailure(0) or powerFailure(1) or powerFailure(2) or
                            powerFailure(3) or powerFailure(4) or powerFailure(5)) and heartBeat);


   PS_i2c_intf : for i in (7 * (PS_REB_TOTAL_C - 1) + 6) downto 0 generate
      -- not using enable (used for multimaster i2c, have just 1)
      USDA_ADC : IOBUF port map (I => psI2cOutMap(i).sda, O => psI2cInMap(i).sda, T => psI2cOutMap(i).sdaoen, IO => SDA_ADC(i));
      USCL_ADC : IOBUF port map (I => psI2cOutMap(i).scl, O => psI2cInMap(i).scl, T => psI2cOutMap(i).scloen, IO => SCL_ADC(i));
   end generate PS_i2c_intf;

   RegFileIn.GA              <= '0' & GA;
   RegFileIn.dout0           <= dout0Map;
   RegFileIn.dout1           <= dout1Map;
   RegFileIn.REB_config_done <= (others => '1');  -- Unused for now , need for case if measuring IC need addtional configuration befere normal sequencing
   RegFileIn.enable_in       <= not enable_in;    -- low true logic
   RegFileIn.spare_in        <= spare_in;
   RegFileIn.temp_Alarm      <= temp_Alarm;
   RegFileIn.fp_los          <= fp_los;
   RegFileIn.alertCleared    <= clearAlert_l;
   

   --din <= RegFileOut.din;
   sync_DCDCMap <= RegFileOut.sync_DCDC;
   --reb_on <= RegFileOut.reb_on;

   UtestIO : for i in 7 downto 0 generate
      UTEST : IOBUF port map (I => RegFileOut.TestOut(i), O => RegFileIn.TestIn(i), T => RegFileOut.TestOutOE(i), IO => test_IO(i));
   end generate UtestIO;

   --   UserID: IOBUF port map ( I => RegFileOut.serIDout, O  => RegFileIn.serIDin,  T => RegFileOut.serIDoutOE, IO => serID);

   USDA_temp : IOBUF port map (I => RegFileOut.tempI2cOut.sda, O => RegFileIn.tempI2cIn.sda, T => RegFileOut.tempI2cOut.sdaoen, IO => temp_SDA);
   USCL_temp : IOBUF port map (I => RegFileOut.tempI2cOut.scl, O => RegFileIn.tempI2cIn.scl, T => RegFileOut.tempI2cOut.scloen, IO => temp_SCL);
   USDA_fp   : IOBUF port map (I => RegFileOut.fp_I2cOut.sda, O => RegFileIn.fp_i2cIn.sda, T => RegFileOut.fp_I2cOut.sdaoen, IO => fp_i2c_data);
   USCL_fp   : IOBUF port map (I => RegFileOut.fp_I2cOut.scl, O => RegFileIn.fp_i2cIn.scl, T => RegFileOut.fp_I2cOut.scloen, IO => fp_i2c_clk);

end top_level;
