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
use work.ThresholdPkg.all;

--use work.TextUtilPkg.all;

entity RegFile is
   generic (
      TPD_G           : time    := 1 ns;
      AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_SLVERR_C;
      CLK_PERIOD_G    : real    := 8.0E-9;  -- units of seconds
      EN_DEVICE_DNA_G : boolean := false;
      EN_DS2411_G     : boolean := false;
	  FAIL_CNT_C           : integer := 3);
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
	  configDone   : in slv(5 downto 0);
	  allRunning   : in slv(5 downto 0);
	  initDone     : in slv(5 downto 0);
	  initFail     : in slv(5 downto 0);
	  selectCR     : in sl;
	  StatusSeq    : in slv32Array(5 downto 0);
	  powerFailure : in slv(5 downto 0);
	  din_out      : in slv(41 downto 0);
	  reb_on_out   : in slv(5 downto 0);
		 
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

   type StateType is (
      IDLE_S,
      W_START_S,
      W_WAIT_S,
      R_START_S,
      R_WAIT_S,
      CHECK_OPER_S,
	  WAIT_CMD_S, 
	  REG_WAIT_S); 
	  
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
	  unlockSeting  : slv(2 downto 0);
	  unlockPsOn    : slv(31 downto 0);
	  unlockFilt    : slv(31 downto 0);
	  unlockManual  : slv(31 downto 0);
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
	  cnt   : natural range 0 to TEMP_ENTRY_C;
	  f_cnt : natural range 0 to FAIL_CNT_C;
	  stV   :slv(3 downto 0);
	  fail  : sl;
	  initDone : sl;
      valid : slv(TEMP_ENTRY_C-1 downto 0);
      inSlv : Slv32Array(TEMP_ENTRY_C-1 downto 0);
	  temp_i2cRegMasterIn : I2cRegMasterInType;
--      temp_i2cRegMasterOut : I2cRegMasterOutType;
      state : StateType;
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
	  unlockSeting  => (others => '0'),
	  unlockPsOn    => (others => '0'),
	  unlockFilt    => (others => '0'),
	  unlockManual  => (others => '0'),
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
      AquireStartP   => (others => '0'),
	  cnt   => 0,
	  f_cnt => 0,
	  stV => (others => '0'),
	  fail  => '0',
	  initDone  => '0',
      valid => (others => '0'),
      inSlv => (others => (others => '0')),
      temp_i2cRegMasterIn => I2C_REG_MASTER_IN_INIT_C,
--      temp_i2cRegMasterOut => I2C_REG_MASTER_OUT_INIT_C,
      state => IDLE_S);


   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal dnaValid : sl               := '0';
   signal masterReset : sl               := '0';
   signal dnaValue : slv(127 downto 0) := (others => '0');
   signal fdValid  : sl               := '0';
   signal fdSerial : slv(63 downto 0) := (others => '0');
   signal temp_i2cRegMasterIn : I2cRegMasterInType;
   signal temp_i2cRegMasterOut : I2cRegMasterOutType;
   constant  ONEVECT : slv(NUM_MAX_PS_C-1 downto 0) := (Others => '1');


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
                   configDone, allRunning, initDone, initFail, StatusSeq, powerFailure, RegFileIn, masterReset,
                   selectCR, din_out, reb_on_out, r,
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
	  
	  RegFileOut.Tempfail  <= r.fail;
	  RegFileOut.TempInitDone <= r.initDone;

      if (r.unlockFilt = UNLOCK_FILTERING) then   -- unlock selected
          v.unlockSeting(0) := '0';
      else
          v.unlockSeting(0) := '1';
      end if;

      if (r.unlockPsOn = UNLOCK_PS_STAY_ON) then   -- unlock selected
          v.unlockSeting(1) := '1';
      else
          v.unlockSeting(1) := '0';
      end if;

      if (r.unlockManual = UNLOCK_MANUAL_PS_ON) then   -- unlock selected
          v.unlockSeting(2) := '1';
      else
          v.unlockSeting(2) := '0';
      end if;
	  
				 
 --     for i in 3 to 5  loop
 --        RegFileOut.REB_on(i) <= Seq2RegData(i).REB_on;  -- toredirect to output
--         RegFileOut.din((6 + 7 *i) downto 7*i) <= Seq2RegData(i).din;
--         v.din((6 + 7 *i) downto 7*i) := Seq2RegData(i).din;
--      end loop;

      for i in RegFileOut.din'range loop
         v.StatusData((3 * i + 2) downto (3*i))  := r.din(i) & RegFileIn.dout1(i)  & RegFileIn.dout0(i);
      end loop;
      RegFileOut.unlockSeting <= r.unlockSeting;



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

      -- if (r.DS75LV_reqReg = '1') then
         -- v.DS75LV_result := (Others => '0');
      -- elsif(temp_i2cRegMasterOut.regAck = '1' OR temp_i2cRegMasterOut.regFail = '1') then
         -- v.DS75LV_result(31) := temp_i2cRegMasterOut.regAck;
         -- v.DS75LV_result(30) := temp_i2cRegMasterOut.regFail;
         -- v.DS75LV_result(23 downto 16) := temp_i2cRegMasterOut.regFailCode;
         -- v.DS75LV_result(15 downto 8) := temp_i2cRegMasterOut.regRdData(7 downto 0); -- due to interface and endianness
         -- v.DS75LV_result(7 downto 0) := temp_i2cRegMasterOut.regRdData(15 downto 8); -- due to interface and endianness
      -- end if;

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

			 when X"20" =>
				 v.unlockFilt  := axiWriteMaster.wdata;
			 when X"21" =>
			     v.unlockPsOn  := axiWriteMaster.wdata;
			 when X"22" =>
			     v.unlockManual  := axiWriteMaster.wdata;
				 
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
                    -- v.axiReadSlave.rdata := r.scratchPad;
					 v.axiReadSlave.rdata :=  
					      NOT(din_out(20+21)) & din_out(19+21) & NOT(din_out(18+21)) & din_out(17+21 downto 14+21) & reb_on_out(5)
					    & NOT(din_out(13+21)) & din_out(12+21) & NOT(din_out(11+21)) & din_out(10+21 downto 7+21) & reb_on_out(4) 
						& NOT(din_out(6+21)) & din_out(5+21) & NOT(din_out(4+21)) & din_out(3+21 downto 0+21) & reb_on_out(3)
						& r.scratchPad(7 downto 0);
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
                     --v.axiReadSlave.rdata := r.spare;
					 v.axiReadSlave.rdata :=  
					      NOT(din_out(20)) & din_out(19) & NOT(din_out(18)) & din_out(17 downto 14) & reb_on_out(2)
					    & NOT(din_out(13)) & din_out(12) & NOT(din_out(11)) & din_out(10 downto 7) & reb_on_out(1) 
						& NOT(din_out(6)) & din_out(5) & NOT(din_out(4)) & din_out(3 downto 0) & reb_on_out(0)
						& r.spare(7 downto 0);
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

															
				  when X"10" =>
                     v.axiReadSlave.rdata := selectCR & '0' & allRunning & "00" & configDone &
					                         "00" & initDone & "00" & initFail;
				  when X"11" =>
                     v.axiReadSlave.rdata := x"000000" & "00" & powerFailure;

				 when X"12" =>
				     v.axiReadSlave.rdata := StatusSeq(0);
				 when X"13" =>
				     v.axiReadSlave.rdata := StatusSeq(1);
				 when X"14" =>
				     v.axiReadSlave.rdata := StatusSeq(2);
				 when X"15" =>
				     v.axiReadSlave.rdata := StatusSeq(3);
				 when X"16" =>
				     v.axiReadSlave.rdata := StatusSeq(4);
				 when X"17" =>
				     v.axiReadSlave.rdata := StatusSeq(5);
					 
				 when X"20" =>
				     v.axiReadSlave.rdata := r.unlockFilt;
				 when X"21" =>
				     v.axiReadSlave.rdata := r.unlockPsOn;
				 when X"22" =>
				     v.axiReadSlave.rdata := r.unlockManual;					 

				 when X"23" =>
				     v.axiReadSlave.rdata := x"0000000" & '0' & r.unlockSeting;
				     	  
				 when X"e0" =>
                        v.axiReadSlave.rdata := r.DS75LV_cntl;
                 when X"e1" =>
                         v.axiReadSlave.rdata := r.DS75LV_result(31 downto 30) & r.initDone & r.fail & r.stV & r.DS75LV_result(23 downto 0);

                  when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
               end case;

            when "01" =>
                case (axiReadMaster.araddr(9 downto 2)) is
				
				-- SR Digital
                when x"00" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(0).address;
			    when x"01" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(0).data;
                when x"02" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(1).address;
			    when x"03" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(1).data;
                when x"04" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(2).address;
			    when x"05" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(2).data;
                when x"06" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(3).address;
			    when x"07" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(3).data;					  
                when x"08" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(4).address;
			    when x"09" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(4).data;
                when x"0a" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(5).address;
			    when x"0b" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(5).data;
                when x"0c" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(6).address;
			    when x"0d" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(6).data;
                when x"0e" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(7).address;
			    when x"0f" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(7).data;
                when x"10" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(8).address;
			    when x"11" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(8).data;
                when x"12" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(9).address;
			    when x"13" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(9).data;
                when x"14" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(10).address;
			    when x"15" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(0)(10).data;
					  
				-- SR Analog
                when x"20" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(0).address;
			    when x"21" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(0).data;
                when x"22" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(1).address;
			    when x"23" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(1).data;
                when x"24" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(2).address;
			    when x"25" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(2).data;
                when x"26" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(3).address;
			    when x"27" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(3).data;					  
                when x"28" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(4).address;
			    when x"29" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(4).data;
                when x"2a" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(5).address;
			    when x"2b" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(5).data;
                when x"2c" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(6).address;
			    when x"2d" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(6).data;
                when x"2e" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(7).address;
			    when x"2f" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(7).data;
                when x"30" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(8).address;
			    when x"31" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(8).data;
                when x"32" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(9).address;
			    when x"33" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(9).data;
                when x"34" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(10).address;
			    when x"35" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(1)(10).data;

				-- SR OD
                when x"40" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(0).address;
			    when x"41" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(0).data;
                when x"42" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(1).address;
			    when x"43" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(1).data;
                when x"44" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(2).address;
			    when x"45" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(2).data;
                when x"46" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(3).address;
			    when x"47" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(3).data;					  
                when x"48" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(4).address;
			    when x"49" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(4).data;
                when x"4a" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(5).address;
			    when x"4b" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(5).data;
                when x"4c" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(6).address;
			    when x"4d" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(6).data;
                when x"4e" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(7).address;
			    when x"4f" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(7).data;
                when x"50" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(8).address;
			    when x"51" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(8).data;
                when x"52" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(9).address;
			    when x"53" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(9).data;
                when x"54" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(10).address;
			    when x"55" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(2)(10).data;
					  
				-- SR Clk High
                when x"60" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(0).address;
			    when x"61" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(0).data;
                when x"62" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(1).address;
			    when x"63" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(1).data;
                when x"64" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(2).address;
			    when x"65" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(2).data;
                when x"66" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(3).address;
			    when x"67" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(3).data;					  
                when x"68" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(4).address;
			    when x"69" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(4).data;
                when x"6a" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(5).address;
			    when x"6b" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(5).data;
                when x"6c" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(6).address;
			    when x"6d" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(6).data;
                when x"6e" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(7).address;
			    when x"6f" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(7).data;
                when x"70" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(8).address;
			    when x"71" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(8).data;
                when x"72" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(9).address;
			    when x"73" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(9).data;
                when x"74" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(10).address;
			    when x"75" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(3)(10).data;

				-- SR Clk Low
                when x"80" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(0).address;
			    when x"81" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(0).data;
                when x"82" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(1).address;
			    when x"83" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(1).data;
                when x"84" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(2).address;
			    when x"85" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(2).data;
                when x"86" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(3).address;
			    when x"87" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(3).data;					  
                when x"88" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(4).address;
			    when x"89" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(4).data;
                when x"8a" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(5).address;
			    when x"8b" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(5).data;
                when x"8c" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(6).address;
			    when x"8d" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(6).data;
                when x"8e" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(7).address;
			    when x"8f" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(7).data;
                when x"90" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(8).address;
			    when x"91" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(8).data;
                when x"92" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(9).address;
			    when x"93" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(9).data;
                when x"94" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(10).address;
			    when x"95" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(4)(10).data;

				-- SR Heater
                when x"a0" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(0).address;
			    when x"a1" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(0).data;
                when x"a2" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(1).address;
			    when x"a3" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(1).data;
                when x"a4" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(2).address;
			    when x"a5" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(2).data;
                when x"a6" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(3).address;
			    when x"a7" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(3).data;					  
                when x"a8" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(4).address;
			    when x"a9" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(4).data;
                when x"aa" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(5).address;
			    when x"ab" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(5).data;
                when x"ac" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(6).address;
			    when x"ad" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(6).data;
                when x"ae" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(7).address;
			    when x"af" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(7).data;
                when x"b0" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(8).address;
			    when x"b1" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(8).data;
                when x"b2" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(9).address;
			    when x"b3" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(9).data;
                when x"b4" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(10).address;
			    when x"b5" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(5)(10).data;
					  
				-- SR Bias
                when x"c0" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(0).address;
			    when x"c1" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(0).data;
                when x"c2" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(1).address;
			    when x"c3" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(1).data;
                when x"c4" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(2).address;
			    when x"c5" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(2).data;
                when x"c6" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(3).address;
			    when x"c7" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(3).data;					  
                when x"c8" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(4).address;
			    when x"c9" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(4).data;
                when x"ca" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(5).address;
			    when x"cb" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(5).data;
                when x"cc" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(6).address;
			    when x"cd" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(6).data;
                when x"ce" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(7).address;
			    when x"cf" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(7).data;
                when x"d0" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(8).address;
			    when x"d1" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(8).data;
                when x"d2" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(9).address;
			    when x"d3" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(9).data;
                when x"d4" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(10).address;
			    when x"d5" =>
                      v.axiReadSlave.rdata :=SR_PS_THRESHOLD_C(6)(10).data;					  

                when others =>
                     axiReadResp := AXI_ERROR_RESP_G;
            end case;					

-- CR					
	    when "10" =>
            case (axiReadMaster.araddr(9 downto 2)) is
				
				-- CR Digital
                when x"00" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(0).address;
			    when x"01" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(0).data;
                when x"02" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(1).address;
			    when x"03" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(1).data;
                when x"04" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(2).address;
			    when x"05" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(2).data;
                when x"06" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(3).address;
			    when x"07" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(3).data;					  
                when x"08" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(4).address;
			    when x"09" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(4).data;
                when x"0a" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(5).address;
			    when x"0b" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(5).data;
                when x"0c" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(6).address;
			    when x"0d" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(6).data;
                when x"0e" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(7).address;
			    when x"0f" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(7).data;
                when x"10" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(8).address;
			    when x"11" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(8).data;
                when x"12" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(9).address;
			    when x"13" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(9).data;
                when x"14" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(10).address;
			    when x"15" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(0)(10).data;
					  
				-- CR Analog
                when x"20" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(0).address;
			    when x"21" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(0).data;
                when x"22" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(1).address;
			    when x"23" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(1).data;
                when x"24" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(2).address;
			    when x"25" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(2).data;
                when x"26" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(3).address;
			    when x"27" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(3).data;					  
                when x"28" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(4).address;
			    when x"29" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(4).data;
                when x"2a" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(5).address;
			    when x"2b" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(5).data;
                when x"2c" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(6).address;
			    when x"2d" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(6).data;
                when x"2e" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(7).address;
			    when x"2f" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(7).data;
                when x"30" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(8).address;
			    when x"31" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(8).data;
                when x"32" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(9).address;
			    when x"33" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(9).data;
                when x"34" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(10).address;
			    when x"35" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(1)(10).data;

				-- CR OD
                when x"40" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(0).address;
			    when x"41" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(0).data;
                when x"42" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(1).address;
			    when x"43" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(1).data;
                when x"44" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(2).address;
			    when x"45" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(2).data;
                when x"46" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(3).address;
			    when x"47" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(3).data;					  
                when x"48" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(4).address;
			    when x"49" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(4).data;
                when x"4a" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(5).address;
			    when x"4b" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(5).data;
                when x"4c" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(6).address;
			    when x"4d" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(6).data;
                when x"4e" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(7).address;
			    when x"4f" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(7).data;
                when x"50" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(8).address;
			    when x"51" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(8).data;
                when x"52" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(9).address;
			    when x"53" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(9).data;
                when x"54" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(10).address;
			    when x"55" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(2)(10).data;
					  
				-- CR Clk High
                when x"60" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(0).address;
			    when x"61" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(0).data;
                when x"62" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(1).address;
			    when x"63" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(1).data;
                when x"64" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(2).address;
			    when x"65" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(2).data;
                when x"66" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(3).address;
			    when x"67" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(3).data;					  
                when x"68" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(4).address;
			    when x"69" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(4).data;
                when x"6a" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(5).address;
			    when x"6b" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(5).data;
                when x"6c" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(6).address;
			    when x"6d" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(6).data;
                when x"6e" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(7).address;
			    when x"6f" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(7).data;
                when x"70" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(8).address;
			    when x"71" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(8).data;
                when x"72" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(9).address;
			    when x"73" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(9).data;
                when x"74" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(10).address;
			    when x"75" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(3)(10).data;

				-- CR Clk Low
                when x"80" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(0).address;
			    when x"81" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(0).data;
                when x"82" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(1).address;
			    when x"83" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(1).data;
                when x"84" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(2).address;
			    when x"85" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(2).data;
                when x"86" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(3).address;
			    when x"87" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(3).data;					  
                when x"88" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(4).address;
			    when x"89" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(4).data;
                when x"8a" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(5).address;
			    when x"8b" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(5).data;
                when x"8c" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(6).address;
			    when x"8d" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(6).data;
                when x"8e" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(7).address;
			    when x"8f" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(7).data;
                when x"90" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(8).address;
			    when x"91" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(8).data;
                when x"92" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(9).address;
			    when x"93" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(9).data;
                when x"94" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(10).address;
			    when x"95" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(4)(10).data;

				-- CR dPhi
                when x"a0" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(0).address;
			    when x"a1" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(0).data;
                when x"a2" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(1).address;
			    when x"a3" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(1).data;
                when x"a4" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(2).address;
			    when x"a5" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(2).data;
                when x"a6" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(3).address;
			    when x"a7" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(3).data;					  
                when x"a8" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(4).address;
			    when x"a9" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(4).data;
                when x"aa" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(5).address;
			    when x"ab" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(5).data;
                when x"ac" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(6).address;
			    when x"ad" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(6).data;
                when x"ae" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(7).address;
			    when x"af" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(7).data;
                when x"b0" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(8).address;
			    when x"b1" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(8).data;
                when x"b2" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(9).address;
			    when x"b3" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(9).data;
                when x"b4" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(10).address;
			    when x"b5" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(5)(10).data;
					  
				-- CR Bias
                when x"c0" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(0).address;
			    when x"c1" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(0).data;
                when x"c2" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(1).address;
			    when x"c3" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(1).data;
                when x"c4" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(2).address;
			    when x"c5" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(2).data;
                when x"c6" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(3).address;
			    when x"c7" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(3).data;					  
                when x"c8" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(4).address;
			    when x"c9" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(4).data;
                when x"ca" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(5).address;
			    when x"cb" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(5).data;
                when x"cc" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(6).address;
			    when x"cd" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(6).data;
                when x"ce" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(7).address;
			    when x"cf" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(7).data;
                when x"d0" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(8).address;
			    when x"d1" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(8).data;
                when x"d2" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(9).address;
			    when x"d3" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(9).data;
                when x"d4" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(10).address;
			    when x"d5" =>
                      v.axiReadSlave.rdata :=CR_PS_THRESHOLD_C(6)(10).data;					  					  

				-- CR Heater
                when x"e0" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(0).address;
			    when x"e1" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(0).data;
                when x"e2" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(1).address;
			    when x"e3" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(1).data;
                when x"e4" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(2).address;
			    when x"e5" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(2).data;
                when x"e6" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(3).address;
			    when x"e7" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(3).data;					  
                when x"e8" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(4).address;
			    when x"e9" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(4).data;
                when x"ea" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(5).address;
			    when x"eb" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(5).data;
                when x"ec" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(6).address;
			    when x"ed" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(6).data;
                when x"ee" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(7).address;
			    when x"ef" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(7).data;
                when x"f0" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(8).address;
			    when x"f1" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(8).data;
                when x"f2" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(9).address;
			    when x"f3" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(9).data;
                when x"f4" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(10).address;
			    when x"f5" =>
                      v.axiReadSlave.rdata :=CR_PS_ADD_THRESHOLD_C(0)(10).data;					  
                when others =>
                     axiReadResp := AXI_ERROR_RESP_G;	
			end case; 
            when others =>
               axiReadResp := AXI_ERROR_RESP_G;
         end case;
         -- Send AXI Response
         axiSlaveReadResponse(v.axiReadSlave, axiReadResp);
      end if;

      -- for i in r.EnableAlarm'range loop
            -- Reg2SeqData(i).EnableAlarm <= r.EnableAlarm(i);
            -- Reg2SeqData(i).dout        <= r.StatusData((20 + 21*i) downto (21*i));
            -- Reg2SeqData(i).REB_on_off  <= r.REB_on_off(i);
            -- Reg2SeqData(i).REB_config_done  <= RegFileIn.REB_config_done(i);
            -- Reg2SeqData(i).AquireStartP  <= r.AquireStartP(i);
            -- Reg2SeqData(i).Enable_in  <= RegFileIn.enable_in;
      -- end loop;
      case (r.DS75LV_cntl(22 downto 20)) is
            when "000" =>
                temp_i2cRegMasterIn.i2cAddr <= "00" & X"48";
			when "001" =>
                temp_i2cRegMasterIn.i2cAddr <= "00" & X"49";
            when "010" =>
                temp_i2cRegMasterIn.i2cAddr <= "00" & X"4a";
			when "011" =>
                temp_i2cRegMasterIn.i2cAddr <= "00" & X"4b";				
            when "100" =>
                temp_i2cRegMasterIn.i2cAddr <= "00" & X"4c";
			when "101" =>
                temp_i2cRegMasterIn.i2cAddr <= "00" & X"4d";				
            when "110" =>
                temp_i2cRegMasterIn.i2cAddr <= "00" & X"4e";
			when "111" =>
                temp_i2cRegMasterIn.i2cAddr <= "00" & X"4e";
	  end case;

	  for i in (TEMP_ENTRY_C-1) downto 0 loop
         -- Check for changes in the bus
            if (TEMP_SET_C(i)(15 downto 0) = r.inSlv(i)(15 downto 0)) and  (r.inSlv(i)(30) = '0')then
            -- Set the flag
                v.valid(i) := '1';
            end if;
         end loop;
		 

	  case (r.state) is
         ----------------------------------------------------------------------
		 
         when IDLE_S =>
            -- Wait for DONE to set
			v.stV   := "0001";
			if (r.DS75LV_cntl(31) = '1') then
			   v.cnt   := 0;
			   v.f_cnt := 0;
			   v.fail  := '0';
			   v.initDone := '0';
			   v.state        := IDLE_S;
            elsif (r.DS75LV_reqReg = '1') then
               -- Next state
               v.state       := W_START_S;
            end if;
			
         when W_START_S =>
		    v.stV   := "0010";
            -- Increment the counter
            if (r.DS75LV_cntl(31) = '1') then
			   v.state        := IDLE_S;
			elsif (r.cnt = TEMP_ENTRY_C) then
                v.cnt := 0;
			    v.state        := R_START_S;
            elsif(temp_i2cRegMasterOut.regAck = '0' AND temp_i2cRegMasterOut.regFail = '0') then
               v.cnt := r.cnt + 1;
			   v.temp_i2cRegMasterIn.tenbit := '0';
			   v.temp_i2cRegMasterIn.regAddr := X"0000000" & "00" & TEMP_SET_C(r.cnt)(17 downto 16);  -- specify
			   v.temp_i2cRegMasterIn.regWrData := X"0000" & "00" & TEMP_SET_C(r.cnt)(7 downto 0) & TEMP_SET_C(r.cnt)(15 downto 8);  -- Endieness
			   v.temp_i2cRegMasterIn.regOp := TEMP_SET_C(r.cnt)(18);  -- to borrow
			   v.temp_i2cRegMasterIn.regAddrSkip := '0';
			   v.temp_i2cRegMasterIn.regAddrSize := "00";
			   v.temp_i2cRegMasterIn.regDataSize := '0' & TEMP_SET_C(r.cnt)(19);
			   v.temp_i2cRegMasterIn.regReq := '1';  -- build request
			   v.temp_i2cRegMasterIn.endianness := '0';
			   -- Next state
               v.state        := W_WAIT_S;
            end if;

         ----------------------------------------------------------------------
         when W_WAIT_S =>
		    v.stV   := "0011";
            -- Wait for DONE to set
            if (r.DS75LV_cntl(31) = '1') then
			   v.state        := IDLE_S;
			elsif (temp_i2cRegMasterOut.regAck = '1' OR temp_i2cRegMasterOut.regFail = '1') then
               -- Reset the flag
                v.temp_i2cRegMasterIn.regReq := '0';
               -- Next state
               v.state       := W_START_S;
            end if;
      ----------------------------------------------------------------------
         when R_START_S =>
		    v.stV   := "0100";
            -- Increment the counter
            if (r.DS75LV_cntl(31) = '1') then
			   v.state        := IDLE_S;
			elsif (r.cnt = TEMP_ENTRY_C) then
                v.cnt := 0;
			    v.state        := CHECK_OPER_S;				
            elsif(temp_i2cRegMasterOut.regAck = '0' AND temp_i2cRegMasterOut.regFail = '0') then
			   v.temp_i2cRegMasterIn.tenbit := '0';
			   v.temp_i2cRegMasterIn.regAddr := X"0000000" & "00" & TEMP_GET_C(r.cnt)(17 downto 16);  -- specify
			   v.temp_i2cRegMasterIn.regWrData := X"0000" & "00" & TEMP_GET_C(r.cnt)(7 downto 0) & TEMP_GET_C(r.cnt)(15 downto 8);  -- Endieness
			   v.temp_i2cRegMasterIn.regOp := TEMP_GET_C(r.cnt)(18);  -- to borrow
			   v.temp_i2cRegMasterIn.regAddrSkip := '0';
			   v.temp_i2cRegMasterIn.regAddrSize := "00";
			   v.temp_i2cRegMasterIn.regDataSize := '0' & TEMP_GET_C(r.cnt)(19);
			   v.temp_i2cRegMasterIn.regReq := '1';  -- build request
			   v.temp_i2cRegMasterIn.endianness := '0';			   -- Next state
               v.state        := R_WAIT_S;
            end if;
	  
         ----------------------------------------------------------------------
         when R_WAIT_S =>
		 v.stV   := "0101";
            -- Wait for DONE to set
            if (r.DS75LV_cntl(31) = '1') then
			   v.state        := IDLE_S;
			elsif (temp_i2cRegMasterOut.regAck = '1' OR temp_i2cRegMasterOut.regFail = '1') then
               -- Reset the flag
               v.temp_i2cRegMasterIn.regReq  := '0';
			   
			   v.inSlv(r.cnt - 1)(31) := temp_i2cRegMasterOut.regAck;
               v.inSlv(r.cnt - 1)(30) := temp_i2cRegMasterOut.regFail;
               v.inSlv(r.cnt - 1)(23 downto 16) := temp_i2cRegMasterOut.regFailCode;
               v.inSlv(r.cnt - 1)(15 downto 8) := temp_i2cRegMasterOut.regRdData(7 downto 0); -- due to interface and endianness
               v.inSlv(r.cnt - 1)(7 downto 0) := temp_i2cRegMasterOut.regRdData(15 downto 8); 
               -- Next state
               v.state       := R_START_S;
            end if;

         when CHECK_OPER_S =>
		 v.stV   := "0110";
            -- Increment the counter
            if (r.DS75LV_cntl(31) = '1') then
			   v.state        := IDLE_S;
			elsif r.f_cnt = (FAIL_CNT_C) then
               v.f_cnt := 0;
			   v.fail  := '1';
			   v.state        := WAIT_CMD_S;
			elsif (r.valid(TEMP_ENTRY_C -1 downto 0) = ONEVECT(TEMP_ENTRY_C -1 downto 0)) then
               v.f_cnt := 0;
			   v.fail  := '0';
			   v.initDone := '1';
			   -- Next state
               v.state        := WAIT_CMD_S;
            else
               v.f_cnt := r.f_cnt + 1;
			   -- Next state
               v.state        := W_START_S;	  
            end if;
      ----------------------------------------------------------------------
	  
	     when WAIT_CMD_S =>
		    v.stV   := "0111";
            -- Increment the counter
            if (r.DS75LV_cntl(31) = '1') then
			   v.state        := IDLE_S;
            elsif(temp_i2cRegMasterOut.regAck = '0' AND temp_i2cRegMasterOut.regFail = '0' AND r.DS75LV_reqReg = '1') then
			  v.temp_i2cRegMasterIn.tenbit := '0';
			  v.temp_i2cRegMasterIn.regAddr := X"0000000" & "00" & r.DS75LV_cntl(17 downto 16);  -- specify
			  v.temp_i2cRegMasterIn.regWrData := X"0000" & "00" & r.DS75LV_cntl(7 downto 0) & r.DS75LV_cntl(15 downto 8);  -- Endieness
			  v.temp_i2cRegMasterIn.regOp := r.DS75LV_cntl(18) and r.unlockSeting(0);  -- only write when unlocked
			  v.temp_i2cRegMasterIn.regAddrSkip := '0';
			  v.temp_i2cRegMasterIn.regAddrSize := "00";
			  v.temp_i2cRegMasterIn.regDataSize := '0' & r.DS75LV_cntl(19);
			  v.temp_i2cRegMasterIn.regReq := r.DS75LV_reqReg;  -- build request
			  v.temp_i2cRegMasterIn.endianness := '0';
			   -- Next state
               v.state        := REG_WAIT_S;
            end if;
			
         when REG_WAIT_S =>
		 v.stV   := "1000";
            -- Wait for DONE to set
            if (r.DS75LV_cntl(31) = '1') then
			   v.state        := IDLE_S;
			elsif (temp_i2cRegMasterOut.regAck = '1' OR temp_i2cRegMasterOut.regFail = '1') then
               -- Reset the flag
               v.temp_i2cRegMasterIn.regReq  := '0';
			   v.DS75LV_result(31) := temp_i2cRegMasterOut.regAck;
			   v.DS75LV_result(30) := temp_i2cRegMasterOut.regFail;
			   v.DS75LV_result(23 downto 16) := temp_i2cRegMasterOut.regFailCode;
			   v.DS75LV_result(15 downto 8) := temp_i2cRegMasterOut.regRdData(7 downto 0); -- due to interface and endianness
			   v.DS75LV_result(7 downto 0) := temp_i2cRegMasterOut.regRdData(15 downto 8); -- due to interface and endianness
               -- Next state
               v.state       := WAIT_CMD_S;
            end if;
			
      end case;
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
         regIn  => r.temp_i2cRegMasterIn,
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
