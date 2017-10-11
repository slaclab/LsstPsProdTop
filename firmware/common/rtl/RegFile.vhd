-------------------------------------------------------------------------------
-- Title      :
-------------------------------------------------------------------------------
-- File       :
-- Author     : Leonid Sapozhnikov ,leosap@SLAC.Stanford.edu
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-13
-- Last update: 2015-03-13
-- Platform   :  Used AxiVersion.vhd as prototype
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Creates AXI accessible registers containing configuration
-- information.
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
--use work.Version.all;
use work.UserPkg.all;
use work.I2cPkg.all;

--use work.TextUtilPkg.all;

entity RegFile is
   generic (
      TPD_G           : time    := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C;
      CLK_PERIOD_G    : real    := 8.0E-9;  -- units of seconds
      EN_DEVICE_DNA_G : boolean := false;
      EN_DS2411_G     : boolean := false);
   port (
      axiClk : in sl;
      axiRst : in sl;

      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      RegFileIn   : in  RegFileInType := REGFILEIN_C;
      RegFileOut  : out RegFileOutType;
--      Reg2SeqData : out Reg2SeqDataAll_type;
--      Seq2RegData : in  Seq2RegDataAll_type := ((SEQ2REGDATA_C), (SEQ2REGDATA_C),(SEQ2REGDATA_C),
--                                               (SEQ2REGDATA_C),(SEQ2REGDATA_C),(SEQ2REGDATA_C));

      -- Optional DS2411 interface
      fdSerSdio : inout sl := 'Z';
      -- new user stuff for register file
      Gaddr : in slv(4 downto 0) := "00000"
      );
end RegFile;

architecture rtl of RegFile is

--   type RomType is array (0 to 63) of slv(31 downto 0);

--   function makeStringRom return RomType is
--      variable ret : RomType := (others => (others => '0'));
--      variable c   : character;
--   begin
--      for i in BUILD_STAMP_C'range loop
--         c                                                      := BUILD_STAMP_C(i);
--         ret((i-1)/4)(8*((i-1) mod 4)+7 downto 8*((i-1) mod 4)) :=
--            toSlv(character'pos(c), 8);
--      end loop;
--      return ret;
--   end function makeStringRom;

--   signal stringRom : RomType := makeStringRom;


   type RegType is record
      scratchPad    : slv(31 downto 0);
      spare         : slv(31 downto 0);
      masterReset   : sl;
      fpgaReload    : sl;
      StatusRst     : sl;
      StatusRst_D   : sl;
      writeEnable_D : sl;
      I2C_RESET_CNTL : sl;
      REB_on_off        : slv(5 downto 0);
      din            : slv(41 downto 0);
      REB_enable    : slv(5 downto 0);
      sync_DCDC     : slv(5 downto 0);
      LED_on        : slv(2 downto 0);
      Test_out      : slv(7 downto 0);
      Test_outOE      : slv(7 downto 0);
      DS75LV_cntl   : slv(31 downto 0);
      DS75LV_reqReg : sl;
      DS75LV_result : slv(31 downto 0);
      axiReadSlave  : AxiLiteReadSlaveType;
      axiWriteSlave : AxiLiteWriteSlaveType;
      StatusData :  slv(127 downto 0);
      StatusData_D :  slv(127 downto 0);
      StatusDataL :  slv(127 downto 0);
      EnableAlarm       : slv(5 downto 0);
      REB_config_done   : slv(5 downto 0);
      AquireStartP     : slv(5 downto 0);
 end record;

   constant REG_INIT_C : RegType := (
      scratchPad    => (others => '0'),
      spare         => (others => '0'),
      masterReset   => '0',
      fpgaReload    => '0',
      StatusRst     => '0',
      StatusRst_D   => '0',
      writeEnable_D => '0',
      I2C_RESET_CNTL => '0',
      REB_on_off        => (others => '0'),
      din            => (others => '0'),
      REB_enable    => (others => '0'),
      sync_DCDC     => (others => '0'),
      LED_on        => (others => '0'),
      Test_out      => (others => '0'),
      Test_outOE    => (others => '0'),
      DS75LV_cntl   => (others => '0'),
      DS75LV_reqReg => '0',
      DS75LV_result => (others => '0'),
      axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
      axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
      StatusData   => (others => '0'),
      StatusData_D   => (others => '0'),
      StatusDataL   => (others => '0'),
      EnableAlarm   => (others => '0'),
      REB_config_done   => (others => '0'),
      AquireStartP   => (others => '0'));


   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaValid : sl               := '0';
   signal masterReset : sl               := '0';
   signal dnaValue : slv(127 downto 0) := (others => '0');
   signal fdValid  : sl               := '0';
   signal fdSerial : slv(63 downto 0) := (others => '0');
   signal temp_i2cRegMasterIn : I2cRegMasterInType;
   signal temp_i2cRegMasterOut : I2cRegMasterOutType;

    attribute dont_touch                 : string;
    attribute dont_touch of r    : signal is "true";
--    attribute dont_touch of Lnk_TxDone     : signal is "true";

begin

   GEN_DEVICE_DNA : if (EN_DEVICE_DNA_G) generate
      DeviceDna_1 : entity work.DeviceDna
         generic map (
            TPD_G => TPD_G)
         port map (
            clk      => axiClk,
            rst      => axiRst,
            dnaValue => dnaValue,
            dnaValid => dnaValid);
   end generate GEN_DEVICE_DNA;

   GEN_DS2411 : if (EN_DS2411_G) generate
      DS2411Core_1 : entity work.DS2411Core
         generic map (
            TPD_G        => TPD_G,
            CLK_PERIOD_G => CLK_PERIOD_G)
         port map (
            clk       => axiClk,
            rst       => axiRst,
            fdSerSdio => fdSerSdio,
            fdValue   => fdSerial,
            fdValid   => fdValid);
   end generate GEN_DS2411;



   comb : process (axiRst, axiReadMaster, axiWriteMaster, dnaValid, dnaValue, fdSerial, fdValid,  --Seq2RegData,
                   RegFileIn, masterReset,
                   r,
                   -- stringRom,
                   temp_i2cRegMasterOut) is
      variable v            : RegType;
      variable axiStatus    : AxiLiteStatusType;
      variable axiWriteResp : slv(1 downto 0);
      variable axiReadResp  : slv(1 downto 0);
   begin
      -- Latch the current value
      v := r;

--      for i in 0 to 5  loop
      RegFileOut.REB_on(0) <= r.spare(8);  -- toredirect to output
      RegFileOut.din(3 downto 0) <= r.spare(12 downto 9);
      RegFileOut.din(4) <= NOT r.spare(13);
      RegFileOut.din(5) <= r.spare(14);
      RegFileOut.din(6) <= NOT r.spare(15);
      v.din((6) downto 0) := r.spare(15 downto 9);
      RegFileOut.REB_on(1) <= r.spare(16);  -- toredirect to output
      RegFileOut.din((10) downto 7) <= r.spare(20 downto 17);
      RegFileOut.din(11) <= NOT r.spare(21);
      RegFileOut.din(12) <= r.spare(22);
      RegFileOut.din(13) <= NOT r.spare(23);
      v.din((13) downto 7) := r.spare(23 downto 17);
      RegFileOut.REB_on(2) <= r.spare(24);  -- toredirect to output
      RegFileOut.din((17) downto 14) <= r.spare(28 downto 25);
      RegFileOut.din(18) <= NOT r.spare(29);
      RegFileOut.din(19) <= r.spare(30);
      RegFileOut.din(20) <= NOT r.spare(31);
      v.din((20) downto 14) := r.spare(31 downto 25);

      -- Modification for ^ REBs

      RegFileOut.REB_on(3) <= r.scratchPad(8);  -- toredirect to output
      RegFileOut.din(24 downto 21) <= r.scratchPad(12 downto 9);
      RegFileOut.din(25) <= NOT r.scratchPad(13);
      RegFileOut.din(26) <= r.scratchPad(14);
      RegFileOut.din(27) <= NOT r.scratchPad(15);
      v.din((27) downto 21) := r.scratchPad(15 downto 9);
      RegFileOut.REB_on(4) <= r.scratchPad(16);  -- toredirect to output
      RegFileOut.din((31) downto 28) <= r.scratchPad(20 downto 17);
      RegFileOut.din(32) <= NOT r.scratchPad(21);
      RegFileOut.din(33) <= r.scratchPad(22);
      RegFileOut.din(34) <= NOT r.scratchPad(23);
      v.din((34) downto 28) := r.scratchPad(23 downto 17);
      RegFileOut.REB_on(5) <= r.scratchPad(24);  -- toredirect to output
      RegFileOut.din((38) downto 35) <= r.scratchPad(28 downto 25);
      RegFileOut.din(39) <= NOT r.scratchPad(29);
      RegFileOut.din(40) <= r.scratchPad(30);
      RegFileOut.din(41) <= NOT r.scratchPad(31);
      v.din((41) downto 35) := r.scratchPad(31 downto 25);

 --     for i in 3 to 5  loop
 --        RegFileOut.REB_on(i) <= Seq2RegData(i).REB_on;  -- toredirect to output
--         RegFileOut.din((6 + 7 *i) downto 7*i) <= Seq2RegData(i).din;
--         v.din((6 + 7 *i) downto 7*i) := Seq2RegData(i).din;
--      end loop;

      for i in RegFileOut.din'range loop
         v.StatusData((3 * i + 2) downto (3*i))  := r.din(i) & RegFileIn.dout1(i)  & RegFileIn.dout0(i);
      end loop;




      -- To correct unused on PS6 for each reb
      for i in 0 to 5 loop
               v.StatusData(21 * i + 19)  := '1';
      end loop;
      v.StatusData(127)  := RegFileIn.temp_Alarm;
      v.StatusData(126)  := RegFileIn.fp_los;

      v.StatusData_D := r.StatusData;
      v.StatusRst_D := r.StatusRst;


      if (r.StatusRst_D = '0' and r.StatusRst = '1') then   -- edge detect
          v.StatusDataL := r.StatusData_D;
      else
          v.StatusDataL := r.StatusData_D OR r.StatusDataL;
      end if;

      -- Determine the transaction type
      axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

      v.writeEnable_D := axiStatus.writeEnable;
      if (axiWriteMaster.awaddr(9 downto 2) = X"E0" and axiStatus.writeEnable = '1' and r.writeEnable_D = '0') then  -- to make pulse
          v.DS75LV_reqReg := '1';
      else
          v.DS75LV_reqReg := '0';
      end if;

      if (r.DS75LV_reqReg = '1') then
         v.DS75LV_result := (Others => '0');
      elsif(temp_i2cRegMasterOut.regAck = '1' OR temp_i2cRegMasterOut.regFail = '1') then
         v.DS75LV_result(31) := temp_i2cRegMasterOut.regAck;
         v.DS75LV_result(30) := temp_i2cRegMasterOut.regFail;
         v.DS75LV_result(23 downto 16) := temp_i2cRegMasterOut.regFailCode;
         v.DS75LV_result(15 downto 8) := temp_i2cRegMasterOut.regRdData(7 downto 0); -- due to interface and endianness
         v.DS75LV_result(7 downto 0) := temp_i2cRegMasterOut.regRdData(15 downto 8); -- due to interface and endianness
      end if;

      if (axiStatus.writeEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiWriteResp := ite(axiWriteMaster.awaddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and perform write
         case (axiWriteMaster.awaddr(9 downto 2)) is
            when X"01" =>
               v.scratchPad := axiWriteMaster.wdata;
            when X"04" =>
               v.sync_DCDC := axiWriteMaster.wdata(21 downto 16);
            when X"05" =>
               v.spare := axiWriteMaster.wdata;
               v.masterReset := axiWriteMaster.wdata(0);
               v.fpgaReload := axiWriteMaster.wdata(1);
            when X"0a" =>
               v.StatusRst  := axiWriteMaster.wdata(31);
            when X"0b" =>
               v.StatusRst  := axiWriteMaster.wdata(31);
            when X"0c" =>
               v.StatusRst  := axiWriteMaster.wdata(31);
            when X"0d" =>
               v.StatusRst  := axiWriteMaster.wdata(31);
            when X"0E" =>
               v.I2C_RESET_CNTL := axiWriteMaster.wdata(31);
               v.EnableAlarm := axiWriteMaster.wdata(17) & axiWriteMaster.wdata(14) & axiWriteMaster.wdata(11) &
                                       axiWriteMaster.wdata(8) & axiWriteMaster.wdata(5) & axiWriteMaster.wdata(2);
               v.REB_on_off := axiWriteMaster.wdata(15) & axiWriteMaster.wdata(12) & axiWriteMaster.wdata(9) &
                           axiWriteMaster.wdata(6) & axiWriteMaster.wdata(3) & axiWriteMaster.wdata(0);
               v.REB_enable :=  axiWriteMaster.wdata(16) & axiWriteMaster.wdata(13) & axiWriteMaster.wdata(10) &
                             axiWriteMaster.wdata(7) & axiWriteMaster.wdata(4) & axiWriteMaster.wdata(1);
            when X"0F" =>
               v.Test_outOE :=  axiWriteMaster.wdata(23 downto 16);
               v.LED_on := axiWriteMaster.wdata(10 downto 8);
               v.Test_out :=  axiWriteMaster.wdata(31 downto 24);
            when X"e0" =>
                  v.DS75LV_cntl := axiWriteMaster.wdata(31 downto 0);

            when others =>
               axiWriteResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI response
         axiSlaveWriteResponse(v.axiWriteSlave, axiWriteResp);
      end if;

      if (axiStatus.readEnable = '1') then
         -- Check for an out of 32 bit aligned address
         axiReadResp          := ite(axiReadMaster.araddr(1 downto 0) = "00", AXI_RESP_OK_C, AXI_ERROR_RESP_G);
         -- Decode address and assign read data
         v.axiReadSlave.rdata := (others => '0');
         case (axiReadMaster.araddr(11 downto 10)) is
            when "00" =>
               case (axiReadMaster.araddr(9 downto 2)) is
                  when X"00" =>
                     v.axiReadSlave.rdata := x"0000020a"; --FPGA_VERSION_C;
                  when X"01" =>
                     v.axiReadSlave.rdata := r.scratchPad;
                  when X"02" =>
                     v.axiReadSlave.rdata := ite(dnaValid = '1', dnaValue(63 downto 32), X"00000000");
                  when X"03" =>
                     v.axiReadSlave.rdata := ite(dnaValid = '1', dnaValue(31 downto 0), X"00000000");
                  when X"04" =>
                     v.axiReadSlave.rdata(21 downto 16) := r.sync_DCDC;
                     v.axiReadSlave.rdata(9) := RegFileIn.spare_in;
                     v.axiReadSlave.rdata(8) := RegFileIn.enable_in;
                     v.axiReadSlave.rdata(4 downto 0) := RegFileIn.GA;
                  when X"05" =>
                     v.axiReadSlave.rdata := r.spare;
                  when X"06" =>
                     v.axiReadSlave.rdata := r.StatusData_D(31 downto 0);
                  when X"07" =>
                     v.axiReadSlave.rdata := r.StatusData_D(63 downto 32);
                  when X"08" =>
                     v.axiReadSlave.rdata := r.StatusData_D(95 downto 64);
                  when X"09" =>
                     v.axiReadSlave.rdata := r.StatusData_D(127 downto 96);
                  when X"0a" =>
                     v.axiReadSlave.rdata := r.StatusDataL(31 downto 0);
                  when X"0b" =>
                     v.axiReadSlave.rdata := r.StatusDataL(63 downto 32);
                  when X"0c" =>
                     v.axiReadSlave.rdata := r.StatusDataL(95 downto 64);
                   when X"0d" =>
                     v.axiReadSlave.rdata := r.StatusDataL(127 downto 96);
                   when X"0e" =>
                       v.axiReadSlave.rdata(31) := r.I2C_RESET_CNTL;
                      -- v.axiReadSlave.rdata(29 downto 18) := RegFileIn.REB_config_done & Seq2RegData(5).REB_on
                      --                                      & Seq2RegData(4).REB_on & Seq2RegData(3).REB_on
                      --                                      & Seq2RegData(2).REB_on & Seq2RegData(1).REB_on
                      --                                      & Seq2RegData(0).REB_on;
                       v.axiReadSlave.rdata(17 downto 0) := r.EnableAlarm(5) &  r.REB_enable(5) &  r.REB_on_off(5) & r.EnableAlarm(4) & r.REB_enable(4) &  r.REB_on_off(4)
                                                            & r.EnableAlarm(3) & r.REB_enable(3) &  r.REB_on_off(3) & r.EnableAlarm(2) & r.REB_enable(2) &  r.REB_on_off(2)
                                                            & r.EnableAlarm(1) & r.REB_enable(1) &  r.REB_on_off(1) & r.EnableAlarm(0) & r.REB_enable(0) &  r.REB_on_off(0);
                   when X"0f" =>
                        v.axiReadSlave.rdata(31 downto 24) := r.Test_out;
                        v.axiReadSlave.rdata(23 downto 16) := r.Test_outOE;
                        v.axiReadSlave.rdata(15 downto 11) := (Others => '0');
                        v.axiReadSlave.rdata(10 downto 8) := r.LED_on;
                        v.axiReadSlave.rdata(7 downto 0) := RegFileIn.TestIn;
                  when X"10" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.CONFIG_WAIT;
                  when X"11" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.ON_WAIT;
                  when X"12" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.PS0;
                  when X"13" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.PS1;
                  when X"14" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.PS34;
                  when X"15" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.PS5;
                  when X"16" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.PS2;
                  when X"17" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.PS6;
                  when X"18" =>
                        v.axiReadSlave.rdata := WAIT_TIMEOUT.PS_OK;
                  when X"19" =>
                       v.axiReadSlave.rdata := WAIT_TIMEOUT.C5SEC_WAIT_C;
                  -- when X"1a" =>
                       -- v.axiReadSlave.rdata := X"00" & Seq2RegData(2).SeqState & Seq2RegData(1).SeqState & Seq2RegData(0).SeqState;
                  -- when X"1b" =>
                       -- v.axiReadSlave.rdata := X"00" & Seq2RegData(5).SeqState & Seq2RegData(4).SeqState & Seq2RegData(3).SeqState;
                  -- when X"1c" =>
                       -- v.axiReadSlave.rdata := X"00" & Seq2RegData(2).FailedState & Seq2RegData(1).FailedState & Seq2RegData(0).FailedState;
                  -- when X"1d" =>
                       -- v.axiReadSlave.rdata := X"00" & Seq2RegData(5).FailedState & Seq2RegData(4).FailedState & Seq2RegData(3).FailedState;
                  -- when X"1e" =>
                        -- v.axiReadSlave.rdata :=  X"00" & Seq2RegData(2).FailedTO  & Seq2RegData(2).FailedStatus
                                                       -- & Seq2RegData(1).FailedTO  & Seq2RegData(1).FailedStatus
                                                       -- & Seq2RegData(0).FailedTO  & Seq2RegData(0).FailedStatus;
                  -- when X"1f" =>
                        -- v.axiReadSlave.rdata :=  X"00" & Seq2RegData(5).FailedTO  & Seq2RegData(5).FailedStatus
                                                       -- & Seq2RegData(4).FailedTO  & Seq2RegData(4).FailedStatus
                                                       -- & Seq2RegData(3).FailedTO  & Seq2RegData(3).FailedStatus;
                  -- when X"20" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(0).powerValuesArOut(1)
                                                                               -- & Seq2RegData(0).reportFaultArr(0).powerValuesArOut(0);
                        -- when X"21" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(0).powerValuesArOut(3)
                                                                               -- & Seq2RegData(0).reportFaultArr(0).powerValuesArOut(2);
                        -- when X"22" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(0).powerValuesArOut(5)
                                                                               -- & Seq2RegData(0).reportFaultArr(0).powerValuesArOut(4);
                        -- when X"23" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(0).powerValuesArOut(7)
                                                                               -- & Seq2RegData(0).reportFaultArr(0).powerValuesArOut(6);
                        -- when X"24" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(1).powerValuesArOut(1)
                                                                               -- & Seq2RegData(0).reportFaultArr(1).powerValuesArOut(0);
                        -- when X"25" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(1).powerValuesArOut(3)
                                                                               -- & Seq2RegData(0).reportFaultArr(1).powerValuesArOut(2);
                        -- when X"26" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(1).powerValuesArOut(5)
                                                                               -- & Seq2RegData(0).reportFaultArr(1).powerValuesArOut(4);
                        -- when X"27" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(1).powerValuesArOut(7)
                                                                               -- & Seq2RegData(0).reportFaultArr(1).powerValuesArOut(6);
                        -- when X"28" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(2).powerValuesArOut(1)
                                                                               -- & Seq2RegData(0).reportFaultArr(2).powerValuesArOut(0);
                        -- when X"29" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(2).powerValuesArOut(3)
                                                                               -- & Seq2RegData(0).reportFaultArr(2).powerValuesArOut(2);
                        -- when X"2a" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(2).powerValuesArOut(5)
                                                                               -- & Seq2RegData(0).reportFaultArr(2).powerValuesArOut(4);
                        -- when X"2b" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(2).powerValuesArOut(7)
                                                                               -- & Seq2RegData(0).reportFaultArr(2).powerValuesArOut(6);
                        -- when X"2c" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(3).powerValuesArOut(1)
                                                                               -- & Seq2RegData(0).reportFaultArr(3).powerValuesArOut(0);
                        -- when X"2d" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(3).powerValuesArOut(3)
                                                                               -- & Seq2RegData(0).reportFaultArr(3).powerValuesArOut(2);
                        -- when X"2e" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(3).powerValuesArOut(5)
                                                                               -- & Seq2RegData(0).reportFaultArr(3).powerValuesArOut(4);
                        -- when X"2f" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(3).powerValuesArOut(7)
                                                                               -- & Seq2RegData(0).reportFaultArr(3).powerValuesArOut(6);
                  -- when X"30" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(4).powerValuesArOut(1)
                                                                         -- & Seq2RegData(0).reportFaultArr(4).powerValuesArOut(0);
                  -- when X"31" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(4).powerValuesArOut(3)
                                                                         -- & Seq2RegData(0).reportFaultArr(4).powerValuesArOut(2);
                  -- when X"32" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(4).powerValuesArOut(5)
                                                                         -- & Seq2RegData(0).reportFaultArr(4).powerValuesArOut(4);
                  -- when X"33" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(4).powerValuesArOut(7)
                                                                         -- & Seq2RegData(0).reportFaultArr(4).powerValuesArOut(6);
                  -- when X"34" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(5).powerValuesArOut(1)
                                                                         -- & Seq2RegData(0).reportFaultArr(5).powerValuesArOut(0);
                  -- when X"35" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(5).powerValuesArOut(3)
                                                                         -- & Seq2RegData(0).reportFaultArr(5).powerValuesArOut(2);
                  -- when X"36" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(5).powerValuesArOut(5)
                                                                         -- & Seq2RegData(0).reportFaultArr(5).powerValuesArOut(4);
                  -- when X"37" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(5).powerValuesArOut(7)
                                                                         -- & Seq2RegData(0).reportFaultArr(5).powerValuesArOut(6);
                  -- when X"38" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(6).powerValuesArOut(1)
                                                                         -- & Seq2RegData(0).reportFaultArr(6).powerValuesArOut(0);
                  -- when X"39" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(6).powerValuesArOut(3)
                                                                         -- & Seq2RegData(0).reportFaultArr(6).powerValuesArOut(2);
                  -- when X"3a" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(6).powerValuesArOut(5)
                                                                         -- & Seq2RegData(0).reportFaultArr(6).powerValuesArOut(4);
                  -- when X"3b" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(0).reportFaultArr(6).powerValuesArOut(7)
                                                                         -- & Seq2RegData(0).reportFaultArr(6).powerValuesArOut(6);
                  -- when X"3c" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"3d" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"3e" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"3f" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";

                  -- when X"40" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(0).powerValuesArOut(1)
                                                                               -- & Seq2RegData(1).reportFaultArr(0).powerValuesArOut(0);
                        -- when X"41" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(0).powerValuesArOut(3)
                                                                               -- & Seq2RegData(1).reportFaultArr(0).powerValuesArOut(2);
                        -- when X"42" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(0).powerValuesArOut(5)
                                                                               -- & Seq2RegData(1).reportFaultArr(0).powerValuesArOut(4);
                        -- when X"43" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(0).powerValuesArOut(7)
                                                                               -- & Seq2RegData(1).reportFaultArr(0).powerValuesArOut(6);
                        -- when X"44" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(1).powerValuesArOut(1)
                                                                               -- & Seq2RegData(1).reportFaultArr(1).powerValuesArOut(0);
                        -- when X"45" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(1).powerValuesArOut(3)
                                                                               -- & Seq2RegData(1).reportFaultArr(1).powerValuesArOut(2);
                        -- when X"46" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(1).powerValuesArOut(5)
                                                                               -- & Seq2RegData(1).reportFaultArr(1).powerValuesArOut(4);
                        -- when X"47" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(1).powerValuesArOut(7)
                                                                               -- & Seq2RegData(1).reportFaultArr(1).powerValuesArOut(6);
                        -- when X"48" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(2).powerValuesArOut(1)
                                                                               -- & Seq2RegData(1).reportFaultArr(2).powerValuesArOut(0);
                        -- when X"49" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(2).powerValuesArOut(3)
                                                                               -- & Seq2RegData(1).reportFaultArr(2).powerValuesArOut(2);
                        -- when X"4a" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(2).powerValuesArOut(5)
                                                                               -- & Seq2RegData(1).reportFaultArr(2).powerValuesArOut(4);
                        -- when X"4b" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(2).powerValuesArOut(7)
                                                                               -- & Seq2RegData(1).reportFaultArr(2).powerValuesArOut(6);
                        -- when X"4c" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(3).powerValuesArOut(1)
                                                                               -- & Seq2RegData(1).reportFaultArr(3).powerValuesArOut(0);
                        -- when X"4d" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(3).powerValuesArOut(3)
                                                                               -- & Seq2RegData(1).reportFaultArr(3).powerValuesArOut(2);
                        -- when X"4e" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(3).powerValuesArOut(5)
                                                                               -- & Seq2RegData(1).reportFaultArr(3).powerValuesArOut(4);
                        -- when X"4f" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(3).powerValuesArOut(7)
                                                                               -- & Seq2RegData(1).reportFaultArr(3).powerValuesArOut(6);
                  -- when X"50" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(4).powerValuesArOut(1)
                                                                         -- & Seq2RegData(1).reportFaultArr(4).powerValuesArOut(0);
                  -- when X"51" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(4).powerValuesArOut(3)
                                                                         -- & Seq2RegData(1).reportFaultArr(4).powerValuesArOut(2);
                  -- when X"52" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(4).powerValuesArOut(5)
                                                                         -- & Seq2RegData(1).reportFaultArr(4).powerValuesArOut(4);
                  -- when X"53" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(4).powerValuesArOut(7)
                                                                         -- & Seq2RegData(1).reportFaultArr(4).powerValuesArOut(6);
                  -- when X"54" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(5).powerValuesArOut(1)
                                                                         -- & Seq2RegData(1).reportFaultArr(5).powerValuesArOut(0);
                  -- when X"55" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(5).powerValuesArOut(3)
                                                                         -- & Seq2RegData(1).reportFaultArr(5).powerValuesArOut(2);
                  -- when X"56" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(5).powerValuesArOut(5)
                                                                         -- & Seq2RegData(1).reportFaultArr(5).powerValuesArOut(4);
                  -- when X"57" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(5).powerValuesArOut(7)
                                                                         -- & Seq2RegData(1).reportFaultArr(5).powerValuesArOut(6);
                  -- when X"58" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(6).powerValuesArOut(1)
                                                                         -- & Seq2RegData(1).reportFaultArr(6).powerValuesArOut(0);
                  -- when X"59" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(6).powerValuesArOut(3)
                                                                         -- & Seq2RegData(1).reportFaultArr(6).powerValuesArOut(2);
                  -- when X"5a" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(6).powerValuesArOut(5)
                                                                         -- & Seq2RegData(1).reportFaultArr(6).powerValuesArOut(4);
                  -- when X"5b" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(1).reportFaultArr(6).powerValuesArOut(7)
                                                                         -- & Seq2RegData(1).reportFaultArr(6).powerValuesArOut(6);
                  -- when X"5c" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"5d" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"5e" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"5f" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";

                  -- when X"60" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(0).powerValuesArOut(1)
                                                                               -- & Seq2RegData(2).reportFaultArr(0).powerValuesArOut(0);
                        -- when X"61" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(0).powerValuesArOut(3)
                                                                               -- & Seq2RegData(2).reportFaultArr(0).powerValuesArOut(2);
                        -- when X"62" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(0).powerValuesArOut(5)
                                                                               -- & Seq2RegData(2).reportFaultArr(0).powerValuesArOut(4);
                        -- when X"63" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(0).powerValuesArOut(7)
                                                                               -- & Seq2RegData(2).reportFaultArr(0).powerValuesArOut(6);
                        -- when X"64" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(1).powerValuesArOut(1)
                                                                               -- & Seq2RegData(2).reportFaultArr(1).powerValuesArOut(0);
                        -- when X"65" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(1).powerValuesArOut(3)
                                                                               -- & Seq2RegData(2).reportFaultArr(1).powerValuesArOut(2);
                        -- when X"66" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(1).powerValuesArOut(5)
                                                                               -- & Seq2RegData(2).reportFaultArr(1).powerValuesArOut(4);
                        -- when X"67" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(1).powerValuesArOut(7)
                                                                               -- & Seq2RegData(2).reportFaultArr(1).powerValuesArOut(6);
                        -- when X"68" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(2).powerValuesArOut(1)
                                                                               -- & Seq2RegData(2).reportFaultArr(2).powerValuesArOut(0);
                        -- when X"69" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(2).powerValuesArOut(3)
                                                                               -- & Seq2RegData(2).reportFaultArr(2).powerValuesArOut(2);
                        -- when X"6a" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(2).powerValuesArOut(5)
                                                                               -- & Seq2RegData(2).reportFaultArr(2).powerValuesArOut(4);
                        -- when X"6b" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(2).powerValuesArOut(7)
                                                                               -- & Seq2RegData(2).reportFaultArr(2).powerValuesArOut(6);
                        -- when X"6c" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(3).powerValuesArOut(1)
                                                                               -- & Seq2RegData(2).reportFaultArr(3).powerValuesArOut(0);
                        -- when X"6d" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(3).powerValuesArOut(3)
                                                                               -- & Seq2RegData(2).reportFaultArr(3).powerValuesArOut(2);
                        -- when X"6e" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(3).powerValuesArOut(5)
                                                                               -- & Seq2RegData(2).reportFaultArr(3).powerValuesArOut(4);
                        -- when X"6f" =>
                                    -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(3).powerValuesArOut(7)
                                                                               -- & Seq2RegData(2).reportFaultArr(3).powerValuesArOut(6);
                  -- when X"70" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(4).powerValuesArOut(1)
                                                                         -- & Seq2RegData(2).reportFaultArr(4).powerValuesArOut(0);
                  -- when X"71" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(4).powerValuesArOut(3)
                                                                         -- & Seq2RegData(2).reportFaultArr(4).powerValuesArOut(2);
                  -- when X"72" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(4).powerValuesArOut(5)
                                                                         -- & Seq2RegData(2).reportFaultArr(4).powerValuesArOut(4);
                  -- when X"73" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(4).powerValuesArOut(7)
                                                                         -- & Seq2RegData(2).reportFaultArr(4).powerValuesArOut(6);
                  -- when X"74" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(5).powerValuesArOut(1)
                                                                         -- & Seq2RegData(2).reportFaultArr(5).powerValuesArOut(0);
                  -- when X"75" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(5).powerValuesArOut(3)
                                                                         -- & Seq2RegData(2).reportFaultArr(5).powerValuesArOut(2);
                  -- when X"76" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(5).powerValuesArOut(5)
                                                                         -- & Seq2RegData(2).reportFaultArr(5).powerValuesArOut(4);
                  -- when X"77" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(5).powerValuesArOut(7)
                                                                         -- & Seq2RegData(2).reportFaultArr(5).powerValuesArOut(6);
                  -- when X"78" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(6).powerValuesArOut(1)
                                                                         -- & Seq2RegData(2).reportFaultArr(6).powerValuesArOut(0);
                  -- when X"79" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(6).powerValuesArOut(3)
                                                                         -- & Seq2RegData(2).reportFaultArr(6).powerValuesArOut(2);
                  -- when X"7a" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(6).powerValuesArOut(5)
                                                                         -- & Seq2RegData(2).reportFaultArr(6).powerValuesArOut(4);
                  -- when X"7b" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00" & Seq2RegData(2).reportFaultArr(6).powerValuesArOut(7)
                                                                         -- & Seq2RegData(2).reportFaultArr(6).powerValuesArOut(6);
                  -- when X"7c" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"7d" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"7e" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  -- when X"7f" =>
                              -- v.axiReadSlave.rdata(31 downto 0) := X"00000000";
                  when X"e0" =>
                        v.axiReadSlave.rdata := r.DS75LV_cntl;
                  when X"e1" =>
                         v.axiReadSlave.rdata := r.DS75LV_result;

                  when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
               end case;

            when "01" =>
                case (axiReadMaster.araddr(9 downto 8)) is
                when "00" =>
           --           v.axiReadSlave.rdata := PS_REPORT_THRSH_B0_C(conv_integer(axiReadMaster.araddr(7 downto 2)));
                when "01" =>
           --           v.axiReadSlave.rdata := PS_REPORT_THRSH_B1_C(conv_integer(axiReadMaster.araddr(7 downto 2)));
                when others =>
                      axiReadResp := AXI_ERROR_RESP_G;
                end case;
            --when "10" =>
            --   v.axiReadSlave.rdata := stringRom(conv_integer(axiReadMaster.araddr(7 downto 2)));
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axiRst = '1') then
         v             := REG_INIT_C;
         v.masterReset := r.masterReset;
      end if;

      rin <= v;

      axiReadSlave  <= r.axiReadSlave;
      axiWriteSlave <= r.axiWriteSlave;
      RegFileOut.fpgaReload    <= r.fpgaReload;
      RegFileOut.masterReset    <= masterReset;
      RegFileOut.I2C_RESET_CNTL <= r.I2C_RESET_CNTL;
      RegFileOut.TestOut <= r.Test_Out;
      RegFileOut.TestOutOE <= r.Test_OutOE;
      RegFileOut.LED_on <= r.LED_on;
      RegFileOut.REB_enable <= r.REB_enable;
      RegFileOut.sync_DCDC <= r.sync_DCDC;

      -- for i in r.EnableAlarm'range loop
            -- Reg2SeqData(i).EnableAlarm <= r.EnableAlarm(i);
            -- Reg2SeqData(i).dout        <= r.StatusData((20 + 21*i) downto (21*i));
            -- Reg2SeqData(i).REB_on_off  <= r.REB_on_off(i);
            -- Reg2SeqData(i).REB_config_done  <= RegFileIn.REB_config_done(i);
            -- Reg2SeqData(i).AquireStartP  <= r.AquireStartP(i);
            -- Reg2SeqData(i).Enable_in  <= RegFileIn.enable_in;
      -- end loop;

      temp_i2cRegMasterIn.i2cAddr <= "00" & X"48";
      temp_i2cRegMasterIn.tenbit <= '0';
      temp_i2cRegMasterIn.regAddr <= X"0000000" & "00" & r.DS75LV_cntl(17 downto 16);  -- specify
      temp_i2cRegMasterIn.regWrData <= X"0000" & "00" & r.DS75LV_cntl(7 downto 0) & r.DS75LV_cntl(15 downto 8);  -- Endieness
      temp_i2cRegMasterIn.regOp <= r.DS75LV_cntl(18);  -- to borrow
      temp_i2cRegMasterIn.regAddrSkip <= '0';
      temp_i2cRegMasterIn.regAddrSize <= "00";
      temp_i2cRegMasterIn.regDataSize <= '0' & r.DS75LV_cntl(19);
      temp_i2cRegMasterIn.regReq <= r.DS75LV_reqReg;  -- build request
      temp_i2cRegMasterIn.endianness <= '0';

   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

   -- masterReset output needs asynchronous reset and this is the easiest way to do it
   Synchronizer_1 : entity work.Synchronizer
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '1',
         OUT_POLARITY_G => '1',
         RST_ASYNC_G    => true,
         STAGES_G       => 2,
         INIT_G         => "00")
      port map (
         clk     => axiClk,
         rst     => axiRst,
         dataIn  => r.masterReset,
         dataOut => masterReset);

   i2cRegMaster_TempSensor : entity work.i2cRegMaster
      generic map (
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => 0,
         FILTER_G             => 8, -- ite(SIMULATION_G, 2, FILTER_G),
         PRESCALE_G           => 249) --ite(SIMULATION_G, 4, PRESCALE_G))  -- 100 kHz (Simulation faster)
      port map (
         clk    => axiClk,
         srst   => axiRst,
         regIn  => temp_i2cRegMasterIn,
         regOut => temp_i2cRegMasterOut,
         i2ci   => RegFileIn.tempI2cIn,
         i2co   => RegFileOut.tempI2cOut);




-- Temp assignment
--     RegFileIn.din <= RegFileOut.dout0 OR  RegFileOut.dout1;


--         tempI2cIn       : i2c_in;
--         fp_I2cIn        : i2c_in;
--         serIDin         : sl;
--         enable_in       : sl;
--         spare_in        : sl;
--         temp_Alarm      : sl;
--         fp_los          : sl;

end architecture rtl;
