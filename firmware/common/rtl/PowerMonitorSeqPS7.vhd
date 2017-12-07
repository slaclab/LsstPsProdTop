-------------------------------------------------------------------------------
-- Title      :
-------------------------------------------------------------------------------
-- File       : PowerMonitorSeqPS7.vhd
-- Author     : Leonid Sapozhnikov  <leosap@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-17
-- Last update: 2015-03-17
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Combine multiple RS per same REB configuration sequences
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

use work.UserPkg.all;
use work.ThresholdPkg.all;

entity PowerMonitorSeqPS7 is

   generic (
      TPD_G           : time                   := 1 ns;
      SIMULATION_G    : boolean                := false;
	  Aq_period       : integer                := 250000000;  -- 2 second to see if stability in PS help with communication
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      REB_number      : slv(3 downto 0)        := "0000";
	  FILT_ADDR0      : slv(31 downto 0)        := x"00000000";
	  FILT_ADDR1      : slv(31 downto 0)        := x"00000000";
	  FAIL_CNT_C           : integer := 3);

   port (
      axiClk : in sl;
      axiRst : in sl;

      REB_on : in sl;
	  selectCR : in sl;

      sAxiReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      sAxiReadSlave   : out AxiLiteReadSlaveType;
      sAxiWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      sAxiWriteSlave  : out AxiLiteWriteSlaveType;

      mAxiReadMasters : out AxiLiteReadMasterArray(6 downto 0);
      mAxiReadSlaves  : in  AxiLiteReadSlaveArray(6 downto 0);
	  mAxilWriteMasters : out AxiLiteWriteMasterArray(6 downto 0);
      mAxilWriteSlaves  : in  AxiLiteWriteSlaveArray(6 downto 0);

      numbPs   : out slv(7 downto 0);
      InitDone : out sl;
	  InitFail : out sl;
      i2c_lock_seq  : out sl);

end entity PowerMonitorSeqPS7;

architecture rtl of PowerMonitorSeqPS7 is

   -------------------------------------------------------------------------------------------------

   type MasterStateType is (
      IDLE_S,
      WAIT_1S_S,
      CONFIG_S,
      DONE_S);


   type RegType is record
      numbEntry       : Slv8Array(MAX_ENTRY_C-1 downto 0);
	  stV             : slv(3 downto 0);
      Status          : slv(31 downto 0);
      cnt             : natural range 0 to Aq_period;
	  spare           : slv(31 downto 0);
      REB_on          : sl;
      InitDone        : sl;
	  InitDoneS       : slv(NUM_MAX_PS_C-1 downto 0);
      cntlI2C         : sl;
      fail            : sl;
	  failS           : slv(NUM_MAX_PS_C-1 downto 0);
      SeqCntlIn       : SeqCntlInType;
      state           : MasterStateType;
      sAxiReadSlave   : AxiLiteReadSlaveType;
      sAxiWriteSlave  : AxiLiteWriteSlaveType;
   end record RegType;

   constant REG_INIT_C : RegType := (
	  numbEntry       => (others => (Others => '0')),
	  stV             => (others => '0'),
	  Status          => (others => '0'),
	  cnt             => 0,
	  spare           => (others => '0'),
      REB_on          => '0',
      InitDone        => '0',
	  InitDoneS       => (others => '0'),
      cntlI2C         => '0',
	  fail            => '0',
	  failS           => (others => '0'),
	  SeqCntlIn       => SEC_CNTL_IN_C,
      state           => IDLE_S,
	  sAxiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      sAxiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   constant  ONEVECT : slv(NUM_MAX_PS_C-1 downto 0) := (Others => '1');
   signal SeqCntlIn  : SeqCntlInType := SEC_CNTL_IN_C;
   signal SeqCntlOuts : SeqCntlOutTypeArray(6 downto 0);

   attribute dont_touch                 : string;
   attribute dont_touch of r    : signal is "true";
   attribute dont_touch of SeqCntlIn    : signal is "true";

begin


   -------------------------------------------------------------------------------------------------
   -- Main process
   -------------------------------------------------------------------------------------------------
   comb : process (axiRst, REB_on, SeqCntlOuts, selectCR,
         sAxiWriteMaster, sAxiReadMaster, r ) is
      variable v           : RegType;
	  variable regCon : AxiLiteEndPointType;
   begin
      v := r;


	  v.REB_on := REB_on;
	  v.Status := toSlv(r.cnt,19) & REB_on & REB_number & r.cntlI2C  & r.SeqCntlIn.Ps_On & r.InitDone & r.fail & r.stV;

--	for i in (NUM_MAX_PS_C-1) downto 0 loop
		if (selectCR = '1') and (REB_number = x"2" OR REB_number =x"5") then
		   v.InitDoneS(NUM_MAX_PS_C-1 downto NUM_CR_ADD_PS_C-1) := (Others => '1');
		   v.failS(NUM_MAX_PS_C-1 downto NUM_CR_ADD_PS_C-1) := (Others => '0');
		   for i in (NUM_CR_ADD_PS_C-2) downto 0 loop
				v.InitDoneS(i) := SeqCntlOuts(i).initDone;
				v.failS(i) := SeqCntlOuts(i).fail;
		   end loop;
		else
		   for i in (NUM_MAX_PS_C-1) downto 0 loop
				v.InitDoneS(i) := SeqCntlOuts(i).initDone;
				v.failS(i) := SeqCntlOuts(i).fail;
			end loop;
		end if;
--     end loop;
      ----------------------------------------------------------------------------------------------
      -- AXI Slave
      ----------------------------------------------------------------------------------------------

	  axiSlaveWaitTxn(regCon, sAxiWriteMaster, sAxiReadMaster, v.sAxiWriteSlave, v.sAxiReadSlave);


	  axiSlaveRegister(regCon, x"000", 0, v.spare);
	  axiSlaveRegisterR(regCon, x"004", 0, r.Status);
		    axiSlaveRegisterR(regCon, x"008", 0, SeqCntlOuts(0).stV(31 downto 0)); -- & SeqCntlOuts(i).initDone);
		    axiSlaveRegisterR(regCon, x"00C", 0, SeqCntlOuts(0).stV(63 downto 32));
			axiSlaveRegisterR(regCon, x"010", 0, SeqCntlOuts(1).stV(31 downto 0)); -- & SeqCntlOuts(i).initDone);
		    axiSlaveRegisterR(regCon, x"014", 0, SeqCntlOuts(1).stV(63 downto 32));
		    axiSlaveRegisterR(regCon, x"018", 0, SeqCntlOuts(2).stV(31 downto 0)); -- & SeqCntlOuts(i).initDone);
		    axiSlaveRegisterR(regCon, x"01C", 0, SeqCntlOuts(2).stV(63 downto 32));
			axiSlaveRegisterR(regCon, x"020", 0, SeqCntlOuts(3).stV(31 downto 0)); -- & SeqCntlOuts(i).initDone);
		    axiSlaveRegisterR(regCon, x"024", 0, SeqCntlOuts(3).stV(63 downto 32));
		    axiSlaveRegisterR(regCon, x"028", 0, SeqCntlOuts(4).stV(31 downto 0)); -- & SeqCntlOuts(i).initDone);
		    axiSlaveRegisterR(regCon, x"02C", 0, SeqCntlOuts(4).stV(63 downto 32));
			axiSlaveRegisterR(regCon, x"030", 0, SeqCntlOuts(5).stV(31 downto 0)); -- & SeqCntlOuts(i).initDone);
		    axiSlaveRegisterR(regCon, x"034", 0, SeqCntlOuts(5).stV(63 downto 32));
		    axiSlaveRegisterR(regCon, x"038", 0, SeqCntlOuts(6).stV(31 downto 0)); -- & SeqCntlOuts(i).initDone);
		    axiSlaveRegisterR(regCon, x"03C", 0, SeqCntlOuts(6).stV(63 downto 32));
			axiSlaveRegisterR(regCon, x"040", 0, FILT_ADDR0);
			axiSlaveRegisterR(regCon, x"044", 0, FILT_ADDR1);

      -- Closeout the transaction
      axiSlaveDefault(regCon,v.sAxiWriteSlave, v.sAxiReadSlave, AXI_ERROR_RESP_G);




      case r.state is
         when IDLE_S =>
            v.stV := "0001";
			v.SeqCntlIn.Ps_On  := '0';
			v.InitDone     := '0';
			v.cntlI2C      := '0';
			v.cnt := 0;
			v.fail := '0';
            if (REB_on = '1' and r.REB_on = '0') then
               v.state       := WAIT_1S_S;
            end if;

         when WAIT_1S_S =>
		    v.stV := "0010";
		     -- Increment the counter
			v.cntlI2C      := '1';
			if (REB_on = '0') then
               v.cnt := 0;
			   v.state        := IDLE_S;
            elsif r.cnt = (Aq_period) then
               v.cnt := 0;
			   v.SeqCntlIn.Ps_On  := '1';
			   v.state        := CONFIG_S;
            else
               v.cnt := r.cnt + 1;
            end if;

         when CONFIG_S =>
		    v.stV := "0011";
		     -- Increment the counter
			 v.cntlI2C      := '1';
			if (REB_on = '0') then
               v.cnt := 0;
			   v.SeqCntlIn.Ps_On  := '0';
			   v.state        := IDLE_S;
			elsif r.cnt = (Aq_period) then
               v.cnt := 0;
			   v.fail := '1';
			   v.state        := DONE_S;
			elsif (selectCR = '1') and (REB_number = x"2" OR REB_number =x"5")
			       and (r.initDoneS(NUM_CR_ADD_PS_C -1 downto 0) = ONEVECT(NUM_CR_ADD_PS_C-1 downto 0)) then
			   v.InitDone     := '1';
			   v.state        := DONE_S;
            elsif (r.initDoneS(NUM_MAX_PS_C -1 downto 0) = ONEVECT(NUM_MAX_PS_C-1 downto 0)) then
			   v.InitDone     := '1';
			   v.state        := DONE_S;
            elsif (selectCR = '1') and (REB_number = x"2" OR REB_number =x"5")
			        and (r.failS(NUM_CR_ADD_PS_C -1 downto 0) > 0) then
               v.fail := '1';
			   v.state        := DONE_S;
			elsif r.failS(NUM_MAX_PS_C -1 downto 0) > 0 then
               v.fail := '1';
			   v.state        := DONE_S;
			else
               v.cnt := r.cnt + 1;
            end if;

         when DONE_S =>
		    v.stV := "0100";
		     -- Configured and wait for PS off condition, otherwise do noting
			 v.cntlI2C      := '0';
			if (REB_on = '0') then
               v.cnt := 0;
			   v.SeqCntlIn.Ps_On  := '0';
			   v.state        := IDLE_S;
            end if;
      end case;


      ----------------------------------------------------------------------------------------------
      -- Reset
      ----------------------------------------------------------------------------------------------
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      rin <= v;

      ----------------------------------------------------------------------------------------------
      -- Outputs
      ----------------------------------------------------------------------------------------------
      sAxiReadSlave   <= r.sAxiReadSlave;
      sAxiWriteSlave  <= r.sAxiWriteSlave;
      SeqCntlIn <=   r.SeqCntlIn;
      InitDone <=   r.InitDone;
      InitFail <=   r.fail;
--  lock bus for sequence signal
      i2c_lock_seq  <= r.cntlI2C;

	  --psConfigAddress <= r.psConfigAddress;
	  --psConfigData <= r.psConfigData;
   end process comb;

	  numbPs         <= toSlv(NUM_SR_PS_C, 8);

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;


    PS_Reb_Config: for i in (NUM_MAX_PS_C - 1) downto 0 generate
     PowerMonitorSeqPS_0 : entity work.PowerMonitorSeqPS
      generic map (
         TPD_G                => TPD_G,
		 PS_REG_READ_LENGTH_C => MAX_ENTRY_C,
     PS_NUMB              => i,
		 REB_number           => REB_number)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
		 selectCR        => selectCR,
		 ps_sr_addresses(0)    => SR_PS_THRESHOLD_C(i)(0).Address,
		 ps_sr_addresses(1)    => SR_PS_THRESHOLD_C(i)(1).Address,
		 ps_sr_addresses(2)    => SR_PS_THRESHOLD_C(i)(2).Address,
		 ps_sr_addresses(3)    => SR_PS_THRESHOLD_C(i)(3).Address,
		 ps_sr_addresses(4)    => SR_PS_THRESHOLD_C(i)(4).Address,
		 ps_sr_addresses(5)    => SR_PS_THRESHOLD_C(i)(5).Address,
		 ps_sr_addresses(6)    => SR_PS_THRESHOLD_C(i)(6).Address,
		 ps_sr_addresses(7)    => SR_PS_THRESHOLD_C(i)(7).Address,
		 ps_sr_addresses(8)    => SR_PS_THRESHOLD_C(i)(8).Address,
		 ps_sr_addresses(9)    => SR_PS_THRESHOLD_C(i)(9).Address,
		 ps_sr_addresses(10)    => SR_PS_THRESHOLD_C(i)(10).Address,
		 ps_sr_data(0)    => SR_PS_THRESHOLD_C(i)(0).data,
		 ps_sr_data(1)    => SR_PS_THRESHOLD_C(i)(1).data,
		 ps_sr_data(2)    => SR_PS_THRESHOLD_C(i)(2).data,
		 ps_sr_data(3)    => SR_PS_THRESHOLD_C(i)(3).data,
		 ps_sr_data(4)    => SR_PS_THRESHOLD_C(i)(4).data,
		 ps_sr_data(5)    => SR_PS_THRESHOLD_C(i)(5).data,
		 ps_sr_data(6)    => SR_PS_THRESHOLD_C(i)(6).data,
		 ps_sr_data(7)    => SR_PS_THRESHOLD_C(i)(7).data,
		 ps_sr_data(8)    => SR_PS_THRESHOLD_C(i)(8).data,
		 ps_sr_data(9)    => SR_PS_THRESHOLD_C(i)(9).data,
		 ps_sr_data(10)    => SR_PS_THRESHOLD_C(i)(10).data,
		 ps_cr_addresses(0)    => CR_PS_THRESHOLD_C(i)(0).Address,
		 ps_cr_addresses(1)    => CR_PS_THRESHOLD_C(i)(1).Address,
		 ps_cr_addresses(2)    => CR_PS_THRESHOLD_C(i)(2).Address,
		 ps_cr_addresses(3)    => CR_PS_THRESHOLD_C(i)(3).Address,
		 ps_cr_addresses(4)    => CR_PS_THRESHOLD_C(i)(4).Address,
		 ps_cr_addresses(5)    => CR_PS_THRESHOLD_C(i)(5).Address,
		 ps_cr_addresses(6)    => CR_PS_THRESHOLD_C(i)(6).Address,
		 ps_cr_addresses(7)    => CR_PS_THRESHOLD_C(i)(7).Address,
		 ps_cr_addresses(8)    => CR_PS_THRESHOLD_C(i)(8).Address,
		 ps_cr_addresses(9)    => CR_PS_THRESHOLD_C(i)(9).Address,
		 ps_cr_addresses(10)    => CR_PS_THRESHOLD_C(i)(10).Address,
		 ps_cr_data(0)    => CR_PS_THRESHOLD_C(i)(0).data,
		 ps_cr_data(1)    => CR_PS_THRESHOLD_C(i)(1).data,
		 ps_cr_data(2)    => CR_PS_THRESHOLD_C(i)(2).data,
		 ps_cr_data(3)    => CR_PS_THRESHOLD_C(i)(3).data,
		 ps_cr_data(4)    => CR_PS_THRESHOLD_C(i)(4).data,
		 ps_cr_data(5)    => CR_PS_THRESHOLD_C(i)(5).data,
		 ps_cr_data(6)    => CR_PS_THRESHOLD_C(i)(6).data,
		 ps_cr_data(7)    => CR_PS_THRESHOLD_C(i)(7).data,
		 ps_cr_data(8)    => CR_PS_THRESHOLD_C(i)(8).data,
		 ps_cr_data(9)    => CR_PS_THRESHOLD_C(i)(9).data,
		 ps_cr_data(10)    => CR_PS_THRESHOLD_C(i)(10).data,
		 ps_cr_add_addresses(0)    => CR_PS_ADD_THRESHOLD_C(0)(0).Address,
		 ps_cr_add_addresses(1)    => CR_PS_ADD_THRESHOLD_C(0)(1).Address,
		 ps_cr_add_addresses(2)    => CR_PS_ADD_THRESHOLD_C(0)(2).Address,
		 ps_cr_add_addresses(3)    => CR_PS_ADD_THRESHOLD_C(0)(3).Address,
		 ps_cr_add_addresses(4)    => CR_PS_ADD_THRESHOLD_C(0)(4).Address,
		 ps_cr_add_addresses(5)    => CR_PS_ADD_THRESHOLD_C(0)(5).Address,
		 ps_cr_add_addresses(6)    => CR_PS_ADD_THRESHOLD_C(0)(6).Address,
		 ps_cr_add_addresses(7)    => CR_PS_ADD_THRESHOLD_C(0)(7).Address,
		 ps_cr_add_addresses(8)    => CR_PS_ADD_THRESHOLD_C(0)(8).Address,
		 ps_cr_add_addresses(9)    => CR_PS_ADD_THRESHOLD_C(0)(9).Address,
		 ps_cr_add_addresses(10)    => CR_PS_ADD_THRESHOLD_C(0)(10).Address,
		 ps_cr_add_data(0)    => CR_PS_ADD_THRESHOLD_C(0)(0).data,
		 ps_cr_add_data(1)    => CR_PS_ADD_THRESHOLD_C(0)(1).data,
		 ps_cr_add_data(2)    => CR_PS_ADD_THRESHOLD_C(0)(2).data,
		 ps_cr_add_data(3)    => CR_PS_ADD_THRESHOLD_C(0)(3).data,
		 ps_cr_add_data(4)    => CR_PS_ADD_THRESHOLD_C(0)(4).data,
		 ps_cr_add_data(5)    => CR_PS_ADD_THRESHOLD_C(0)(5).data,
		 ps_cr_add_data(6)    => CR_PS_ADD_THRESHOLD_C(0)(6).data,
		 ps_cr_add_data(7)    => CR_PS_ADD_THRESHOLD_C(0)(7).data,
		 ps_cr_add_data(8)    => CR_PS_ADD_THRESHOLD_C(0)(8).data,
		 ps_cr_add_data(9)    => CR_PS_ADD_THRESHOLD_C(0)(9).data,
		 ps_cr_add_data(10)    => CR_PS_ADD_THRESHOLD_C(0)(10).data,
         SeqCntlIn       => SeqCntlIn,
         SeqCntlOut      => SeqCntlOuts(i),
         mAxilReadMaster  => mAxiReadMasters(i),
         mAxilReadSlave   => mAxiReadSlaves(i),
         mAxilWriteMaster => mAxilWriteMasters(i),
         mAxilWriteSlave  => mAxilWriteSlaves(i));
    end generate PS_Reb_Config;

end architecture rtl;

