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
	  Aq_period       : integer                := 1562500000;  -- 10second to see if stability in PS help with communication
      AXI_ERROR_RESP_G : slv(1 downto 0)       := AXI_RESP_SLVERR_C;
      REB_number      : slv(3 downto 0)        := "0000";
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
--	  psConfigAddress : Slv32VectorArray(NUM_MAX_PS_C-1 downto 0, MAX_ENTRY_C-1 downto 0);
--	  psConfigData    : Slv32VectorArray(NUM_MAX_PS_C-1 downto 0, MAX_ENTRY_C-1 downto 0);
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
--      psConfigAddress => (Others => (Others => (Others => '0'))),
--	  psConfigData    => (Others => (Others => (Others => '0'))),
      state           => IDLE_S,
	  sAxiReadSlave   => AXI_LITE_READ_SLAVE_INIT_C,
      sAxiWriteSlave  => AXI_LITE_WRITE_SLAVE_INIT_C);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   constant  ONEVECT : slv(NUM_MAX_PS_C-1 downto 0) := (Others => '1');   
   signal SeqCntlIn  : SeqCntlInType := SEC_CNTL_IN_C;
   signal SeqCntlOuts : SeqCntlOutTypeArray(6 downto 0);
--   signal OneVect      : slv(NUM_MAX_PS_C-1 downto 0);
--   signal psConfigAddress : Slv32VectorArray(NUM_MAX_PS_C-1 downto 0, MAX_ENTRY_C-1 downto 0);
--   signal psConfigData    : Slv32VectorArray(NUM_MAX_PS_C-1 downto 0, MAX_ENTRY_C-1 downto 0);
   signal numbPs_l      : slv(7 downto 0);
   
    
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

	for i in (NUM_MAX_PS_C-1) downto 0 loop
           v.InitDoneS(i) := SeqCntlOuts(i).initDone;
		   v.failS(i) := SeqCntlOuts(i).fail;
     end loop;
      ----------------------------------------------------------------------------------------------
      -- AXI Slave
      ----------------------------------------------------------------------------------------------

	  axiSlaveWaitTxn(regCon, sAxiWriteMaster, sAxiReadMaster, v.sAxiWriteSlave, v.sAxiReadSlave);

	  
	  axiSlaveRegister(regCon, x"000", 0, v.spare);
	  axiSlaveRegisterR(regCon, x"004", 0, r.Status);
--	  for i in (NUM_MAX_PS_C-1) downto 0 loop
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
--			axiSlaveRegisterR(regCon, x"040", 0, SeqCntlOuts(7).fail); -- & SeqCntlOuts(i).initDone);
--		    axiSlaveRegisterR(regCon, x"044", 0, SeqCntlOuts(7).initDone);
 --     end loop;
 
 
            axiSlaveRegisterR(regCon, x"100", 0, SR_PS_THRESHOLD_C(3)(0).address);
			axiSlaveRegisterR(regCon, x"104", 0, SR_PS_THRESHOLD_C(3)(0).data);
			axiSlaveRegisterR(regCon, x"108", 0, SR_PS_THRESHOLD_C(3)(1).address);
			axiSlaveRegisterR(regCon, x"10C", 0, SR_PS_THRESHOLD_C(3)(1).data);
            axiSlaveRegisterR(regCon, x"110", 0, SR_PS_THRESHOLD_C(3)(2).address);
			axiSlaveRegisterR(regCon, x"114", 0, SR_PS_THRESHOLD_C(3)(2).data);
			axiSlaveRegisterR(regCon, x"118", 0, SR_PS_THRESHOLD_C(3)(3).address);
			axiSlaveRegisterR(regCon, x"11C", 0, SR_PS_THRESHOLD_C(3)(3).data);
            axiSlaveRegisterR(regCon, x"120", 0, SR_PS_THRESHOLD_C(3)(4).address);
			axiSlaveRegisterR(regCon, x"124", 0, SR_PS_THRESHOLD_C(3)(4).data);
			axiSlaveRegisterR(regCon, x"128", 0, SR_PS_THRESHOLD_C(3)(5).address);
			axiSlaveRegisterR(regCon, x"12C", 0, SR_PS_THRESHOLD_C(3)(5).data);
            axiSlaveRegisterR(regCon, x"130", 0, SR_PS_THRESHOLD_C(3)(6).address);
			axiSlaveRegisterR(regCon, x"134", 0, SR_PS_THRESHOLD_C(3)(6).data);
			axiSlaveRegisterR(regCon, x"138", 0, SR_PS_THRESHOLD_C(3)(7).address);
			axiSlaveRegisterR(regCon, x"13C", 0, SR_PS_THRESHOLD_C(3)(7).data);			
            axiSlaveRegisterR(regCon, x"140", 0, SR_PS_THRESHOLD_C(3)(8).address);
			axiSlaveRegisterR(regCon, x"144", 0, SR_PS_THRESHOLD_C(3)(8).data);
			axiSlaveRegisterR(regCon, x"148", 0, SR_PS_THRESHOLD_C(3)(9).address);
			axiSlaveRegisterR(regCon, x"14C", 0, SR_PS_THRESHOLD_C(3)(9).data);
            axiSlaveRegisterR(regCon, x"150", 0, SR_PS_THRESHOLD_C(3)(10).address);
			axiSlaveRegisterR(regCon, x"154", 0, SR_PS_THRESHOLD_C(3)(10).data);

            axiSlaveRegisterR(regCon, x"200", 0, SR_PS_THRESHOLD_C(6)(0).address);
			axiSlaveRegisterR(regCon, x"204", 0, SR_PS_THRESHOLD_C(6)(0).data);
			axiSlaveRegisterR(regCon, x"208", 0, SR_PS_THRESHOLD_C(6)(1).address);
			axiSlaveRegisterR(regCon, x"20C", 0, SR_PS_THRESHOLD_C(6)(1).data);
            axiSlaveRegisterR(regCon, x"210", 0, SR_PS_THRESHOLD_C(6)(2).address);
			axiSlaveRegisterR(regCon, x"214", 0, SR_PS_THRESHOLD_C(6)(2).data);
			axiSlaveRegisterR(regCon, x"218", 0, SR_PS_THRESHOLD_C(6)(3).address);
			axiSlaveRegisterR(regCon, x"21C", 0, SR_PS_THRESHOLD_C(6)(3).data);
            axiSlaveRegisterR(regCon, x"220", 0, SR_PS_THRESHOLD_C(6)(4).address);
			axiSlaveRegisterR(regCon, x"224", 0, SR_PS_THRESHOLD_C(6)(4).data);
			axiSlaveRegisterR(regCon, x"228", 0, SR_PS_THRESHOLD_C(6)(5).address);
			axiSlaveRegisterR(regCon, x"22C", 0, SR_PS_THRESHOLD_C(6)(5).data);
            axiSlaveRegisterR(regCon, x"230", 0, SR_PS_THRESHOLD_C(6)(6).address);
			axiSlaveRegisterR(regCon, x"234", 0, SR_PS_THRESHOLD_C(6)(6).data);
			axiSlaveRegisterR(regCon, x"238", 0, SR_PS_THRESHOLD_C(6)(7).address);
			axiSlaveRegisterR(regCon, x"23C", 0, SR_PS_THRESHOLD_C(6)(7).data);			
            axiSlaveRegisterR(regCon, x"240", 0, SR_PS_THRESHOLD_C(6)(8).address);
			axiSlaveRegisterR(regCon, x"244", 0, SR_PS_THRESHOLD_C(6)(8).data);
			axiSlaveRegisterR(regCon, x"248", 0, SR_PS_THRESHOLD_C(6)(9).address);
			axiSlaveRegisterR(regCon, x"24C", 0, SR_PS_THRESHOLD_C(6)(9).data);
            axiSlaveRegisterR(regCon, x"250", 0, SR_PS_THRESHOLD_C(6)(10).address);
			axiSlaveRegisterR(regCon, x"254", 0, SR_PS_THRESHOLD_C(6)(10).data);
			
			-- axiSlaveRegisterR(regCon, x"200", 0, r.psConfigAddress(1,0));
			-- axiSlaveRegisterR(regCon, x"204", 0, r.psConfigData(1,0));
			-- axiSlaveRegisterR(regCon, x"208", 0, r.psConfigAddress(1,1));
			-- axiSlaveRegisterR(regCon, x"20C", 0, r.psConfigData(1,1));
            -- axiSlaveRegisterR(regCon, x"210", 0, r.psConfigAddress(1,2));
			-- axiSlaveRegisterR(regCon, x"214", 0, r.psConfigData(1,2));
			-- axiSlaveRegisterR(regCon, x"218", 0, r.psConfigAddress(1,3));
			-- axiSlaveRegisterR(regCon, x"21C", 0, r.psConfigData(1,3));
            -- axiSlaveRegisterR(regCon, x"220", 0, r.psConfigAddress(1,4));
			-- axiSlaveRegisterR(regCon, x"224", 0, r.psConfigData(1,4));
			-- axiSlaveRegisterR(regCon, x"228", 0, r.psConfigAddress(1,5));
			-- axiSlaveRegisterR(regCon, x"22C", 0, r.psConfigData(1,5));
            -- axiSlaveRegisterR(regCon, x"230", 0, r.psConfigAddress(1,6));
			-- axiSlaveRegisterR(regCon, x"234", 0, r.psConfigData(1,6));
			-- axiSlaveRegisterR(regCon, x"238", 0, r.psConfigAddress(1,7));
			-- axiSlaveRegisterR(regCon, x"23C", 0, r.psConfigData(1,7));			
            -- axiSlaveRegisterR(regCon, x"240", 0, r.psConfigAddress(1,8));
			-- axiSlaveRegisterR(regCon, x"244", 0, r.psConfigData(1,8));
			-- axiSlaveRegisterR(regCon, x"248", 0, r.psConfigAddress(1,9));
			-- axiSlaveRegisterR(regCon, x"24C", 0, r.psConfigData(1,9));
            -- axiSlaveRegisterR(regCon, x"250", 0, r.psConfigAddress(1,10));
			-- axiSlaveRegisterR(regCon, x"254", 0, r.psConfigData(1,10));


            -- axiSlaveRegisterR(regCon, x"300", 0, r.psConfigAddress(2,0));
			-- axiSlaveRegisterR(regCon, x"304", 0, r.psConfigData(2,0));
			-- axiSlaveRegisterR(regCon, x"308", 0, r.psConfigAddress(2,1));
			-- axiSlaveRegisterR(regCon, x"30C", 0, r.psConfigData(2,1));
            -- axiSlaveRegisterR(regCon, x"310", 0, r.psConfigAddress(2,2));
			-- axiSlaveRegisterR(regCon, x"314", 0, r.psConfigData(2,2));
			-- axiSlaveRegisterR(regCon, x"318", 0, r.psConfigAddress(2,3));
			-- axiSlaveRegisterR(regCon, x"31C", 0, r.psConfigData(2,3));
            -- axiSlaveRegisterR(regCon, x"320", 0, r.psConfigAddress(2,4));
			-- axiSlaveRegisterR(regCon, x"324", 0, r.psConfigData(2,4));
			-- axiSlaveRegisterR(regCon, x"328", 0, r.psConfigAddress(2,5));
			-- axiSlaveRegisterR(regCon, x"32C", 0, r.psConfigData(2,5));
            -- axiSlaveRegisterR(regCon, x"330", 0, r.psConfigAddress(2,6));
			-- axiSlaveRegisterR(regCon, x"334", 0, r.psConfigData(2,6));
			-- axiSlaveRegisterR(regCon, x"338", 0, r.psConfigAddress(2,7));
			-- axiSlaveRegisterR(regCon, x"33C", 0, r.psConfigData(2,7));			
            -- axiSlaveRegisterR(regCon, x"340", 0, r.psConfigAddress(2,8));
			-- axiSlaveRegisterR(regCon, x"344", 0, r.psConfigData(2,8));
			-- axiSlaveRegisterR(regCon, x"348", 0, r.psConfigAddress(2,9));
			-- axiSlaveRegisterR(regCon, x"34C", 0, r.psConfigData(2,9));
            -- axiSlaveRegisterR(regCon, x"350", 0, r.psConfigAddress(2,10));
			-- axiSlaveRegisterR(regCon, x"354", 0, r.psConfigData(2,10));


            -- axiSlaveRegisterR(regCon, x"400", 0, r.psConfigAddress(3,0));
			-- axiSlaveRegisterR(regCon, x"404", 0, r.psConfigData(3,0));
			-- axiSlaveRegisterR(regCon, x"408", 0, r.psConfigAddress(3,1));
			-- axiSlaveRegisterR(regCon, x"40C", 0, r.psConfigData(3,1));
            -- axiSlaveRegisterR(regCon, x"410", 0, r.psConfigAddress(3,2));
			-- axiSlaveRegisterR(regCon, x"414", 0, r.psConfigData(3,2));
			-- axiSlaveRegisterR(regCon, x"418", 0, r.psConfigAddress(3,3));
			-- axiSlaveRegisterR(regCon, x"41C", 0, r.psConfigData(3,3));
            -- axiSlaveRegisterR(regCon, x"420", 0, r.psConfigAddress(3,4));
			-- axiSlaveRegisterR(regCon, x"424", 0, r.psConfigData(3,4));
			-- axiSlaveRegisterR(regCon, x"428", 0, r.psConfigAddress(3,5));
			-- axiSlaveRegisterR(regCon, x"42C", 0, r.psConfigData(3,5));
            -- axiSlaveRegisterR(regCon, x"430", 0, r.psConfigAddress(3,6));
			-- axiSlaveRegisterR(regCon, x"434", 0, r.psConfigData(3,6));
			-- axiSlaveRegisterR(regCon, x"438", 0, r.psConfigAddress(3,7));
			-- axiSlaveRegisterR(regCon, x"43C", 0, r.psConfigData(3,7));			
            -- axiSlaveRegisterR(regCon, x"440", 0, r.psConfigAddress(3,8));
			-- axiSlaveRegisterR(regCon, x"444", 0, r.psConfigData(3,8));
			-- axiSlaveRegisterR(regCon, x"448", 0, r.psConfigAddress(3,9));
			-- axiSlaveRegisterR(regCon, x"44C", 0, r.psConfigData(3,9));
            -- axiSlaveRegisterR(regCon, x"450", 0, r.psConfigAddress(3,10));
			-- axiSlaveRegisterR(regCon, x"454", 0, r.psConfigData(3,10));

            -- axiSlaveRegisterR(regCon, x"500", 0, r.psConfigAddress(4,0));
			-- axiSlaveRegisterR(regCon, x"504", 0, r.psConfigData(4,0));
			-- axiSlaveRegisterR(regCon, x"508", 0, r.psConfigAddress(4,1));
			-- axiSlaveRegisterR(regCon, x"50C", 0, r.psConfigData(4,1));
            -- axiSlaveRegisterR(regCon, x"510", 0, r.psConfigAddress(4,2));
			-- axiSlaveRegisterR(regCon, x"514", 0, r.psConfigData(4,2));
			-- axiSlaveRegisterR(regCon, x"518", 0, r.psConfigAddress(4,3));
			-- axiSlaveRegisterR(regCon, x"51C", 0, r.psConfigData(4,3));
            -- axiSlaveRegisterR(regCon, x"520", 0, r.psConfigAddress(4,4));
			-- axiSlaveRegisterR(regCon, x"524", 0, r.psConfigData(4,4));
			-- axiSlaveRegisterR(regCon, x"528", 0, r.psConfigAddress(4,5));
			-- axiSlaveRegisterR(regCon, x"52C", 0, r.psConfigData(4,5));
            -- axiSlaveRegisterR(regCon, x"530", 0, r.psConfigAddress(4,6));
			-- axiSlaveRegisterR(regCon, x"534", 0, r.psConfigData(4,6));
			-- axiSlaveRegisterR(regCon, x"538", 0, r.psConfigAddress(4,7));
			-- axiSlaveRegisterR(regCon, x"53C", 0, r.psConfigData(4,7));			
            -- axiSlaveRegisterR(regCon, x"540", 0, r.psConfigAddress(4,8));
			-- axiSlaveRegisterR(regCon, x"544", 0, r.psConfigData(4,8));
			-- axiSlaveRegisterR(regCon, x"548", 0, r.psConfigAddress(4,9));
			-- axiSlaveRegisterR(regCon, x"54C", 0, r.psConfigData(4,9));
            -- axiSlaveRegisterR(regCon, x"550", 0, r.psConfigAddress(4,10));
			-- axiSlaveRegisterR(regCon, x"554", 0, r.psConfigData(4,10));


            -- axiSlaveRegisterR(regCon, x"600", 0, r.psConfigAddress(5,0));
			-- axiSlaveRegisterR(regCon, x"604", 0, r.psConfigData(5,0));
			-- axiSlaveRegisterR(regCon, x"608", 0, r.psConfigAddress(5,1));
			-- axiSlaveRegisterR(regCon, x"60C", 0, r.psConfigData(5,1));
            -- axiSlaveRegisterR(regCon, x"610", 0, r.psConfigAddress(5,2));
			-- axiSlaveRegisterR(regCon, x"614", 0, r.psConfigData(5,2));
			-- axiSlaveRegisterR(regCon, x"618", 0, r.psConfigAddress(5,3));
			-- axiSlaveRegisterR(regCon, x"61C", 0, r.psConfigData(5,3));
            -- axiSlaveRegisterR(regCon, x"620", 0, r.psConfigAddress(5,4));
			-- axiSlaveRegisterR(regCon, x"624", 0, r.psConfigData(5,4));
			-- axiSlaveRegisterR(regCon, x"628", 0, r.psConfigAddress(5,5));
			-- axiSlaveRegisterR(regCon, x"62C", 0, r.psConfigData(5,5));
            -- axiSlaveRegisterR(regCon, x"630", 0, r.psConfigAddress(5,6));
			-- axiSlaveRegisterR(regCon, x"634", 0, r.psConfigData(5,6));
			-- axiSlaveRegisterR(regCon, x"638", 0, r.psConfigAddress(5,7));
			-- axiSlaveRegisterR(regCon, x"63C", 0, r.psConfigData(5,7));			
            -- axiSlaveRegisterR(regCon, x"640", 0, r.psConfigAddress(5,8));
			-- axiSlaveRegisterR(regCon, x"644", 0, r.psConfigData(5,8));
			-- axiSlaveRegisterR(regCon, x"648", 0, r.psConfigAddress(5,9));
			-- axiSlaveRegisterR(regCon, x"64C", 0, r.psConfigData(5,9));
            -- axiSlaveRegisterR(regCon, x"650", 0, r.psConfigAddress(5,10));
			-- axiSlaveRegisterR(regCon, x"654", 0, r.psConfigData(5,10));

            -- axiSlaveRegisterR(regCon, x"700", 0, r.psConfigAddress(6,0));
			-- axiSlaveRegisterR(regCon, x"704", 0, r.psConfigData(6,0));
			-- axiSlaveRegisterR(regCon, x"708", 0, r.psConfigAddress(6,1));
			-- axiSlaveRegisterR(regCon, x"70C", 0, r.psConfigData(6,1));
            -- axiSlaveRegisterR(regCon, x"710", 0, r.psConfigAddress(6,2));
			-- axiSlaveRegisterR(regCon, x"714", 0, r.psConfigData(6,2));
			-- axiSlaveRegisterR(regCon, x"718", 0, r.psConfigAddress(6,3));
			-- axiSlaveRegisterR(regCon, x"71C", 0, r.psConfigData(6,3));
            -- axiSlaveRegisterR(regCon, x"720", 0, r.psConfigAddress(6,4));
			-- axiSlaveRegisterR(regCon, x"724", 0, r.psConfigData(6,4));
			-- axiSlaveRegisterR(regCon, x"728", 0, r.psConfigAddress(6,5));
			-- axiSlaveRegisterR(regCon, x"72C", 0, r.psConfigData(6,5));
            -- axiSlaveRegisterR(regCon, x"730", 0, r.psConfigAddress(6,6));
			-- axiSlaveRegisterR(regCon, x"734", 0, r.psConfigData(6,6));
			-- axiSlaveRegisterR(regCon, x"738", 0, r.psConfigAddress(6,7));
			-- axiSlaveRegisterR(regCon, x"73C", 0, r.psConfigData(6,7));			
            -- axiSlaveRegisterR(regCon, x"740", 0, r.psConfigAddress(6,8));
			-- axiSlaveRegisterR(regCon, x"744", 0, r.psConfigData(6,8));
			-- axiSlaveRegisterR(regCon, x"748", 0, r.psConfigAddress(6,9));
			-- axiSlaveRegisterR(regCon, x"74C", 0, r.psConfigData(6,9));
            -- axiSlaveRegisterR(regCon, x"750", 0, r.psConfigAddress(6,10));
			-- axiSlaveRegisterR(regCon, x"754", 0, r.psConfigData(6,10));


			
	  -- for i in (NUM_MAX_PS_C-1) downto 0 loop
	      -- for j in (MAX_ENTRY_C -1) downto 0 loop
		    -- axiSlaveRegisterR(regCon, x"100" * i + 8 * j, 0, r.psConfigAddress(i)(j));
			-- axiSlaveRegisterR(regCon, x"100" * i + 8 * j + 4, 0, r.psConfigData(i)(j));
         -- end loop;
      -- end loop; 

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
	  numbPs_l       <= toSlv(NUM_SR_PS_C, 8);
	  
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
		 PS_REG_READ_LENGTH_C => MAX_ENTRY_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
		 ps_addresses(0)    => SR_PS_THRESHOLD_C(i)(0).Address, --psConfigAddress(i, 0),
		 ps_addresses(1)    => SR_PS_THRESHOLD_C(i)(1).Address, --psConfigAddress(i, 1),
		 ps_addresses(2)    => SR_PS_THRESHOLD_C(i)(2).Address, --psConfigAddress(i, 2),
		 ps_addresses(3)    => SR_PS_THRESHOLD_C(i)(3).Address, --psConfigAddress(i, 3),
		 ps_addresses(4)    => SR_PS_THRESHOLD_C(i)(4).Address, --psConfigAddress(i, 4),
		 ps_addresses(5)    => SR_PS_THRESHOLD_C(i)(5).Address, --psConfigAddress(i, 5),
		 ps_addresses(6)    => SR_PS_THRESHOLD_C(i)(6).Address, --psConfigAddress(i, 6),
		 ps_addresses(7)    => SR_PS_THRESHOLD_C(i)(7).Address, --psConfigAddress(i, 7),
		 ps_addresses(8)    => SR_PS_THRESHOLD_C(i)(8).Address, --psConfigAddress(i, 8),
		 ps_addresses(9)    => SR_PS_THRESHOLD_C(i)(9).Address, --psConfigAddress(i, 9),
		 ps_addresses(10)    => SR_PS_THRESHOLD_C(i)(10).Address, --psConfigAddress(i, 10),
		 ps_data(0)    => SR_PS_THRESHOLD_C(i)(0).data,
		 ps_data(1)    => SR_PS_THRESHOLD_C(i)(1).data,
		 ps_data(2)    => SR_PS_THRESHOLD_C(i)(2).data,
		 ps_data(3)    => SR_PS_THRESHOLD_C(i)(3).data,
		 ps_data(4)    => SR_PS_THRESHOLD_C(i)(4).data,
		 ps_data(5)    => SR_PS_THRESHOLD_C(i)(5).data,
		 ps_data(6)    => SR_PS_THRESHOLD_C(i)(6).data,
		 ps_data(7)    => SR_PS_THRESHOLD_C(i)(7).data,
		 ps_data(8)    => SR_PS_THRESHOLD_C(i)(8).data,
		 ps_data(9)    => SR_PS_THRESHOLD_C(i)(9).data,
		 ps_data(10)    => SR_PS_THRESHOLD_C(i)(10).data,
 --		 ps_data         => psConfigData(i,MAX_ENTRY_C - 1 downto 0),
         numbEntry       => numbPs_l,
         SeqCntlIn       => SeqCntlIn,
         SeqCntlOut      => SeqCntlOuts(i),
         mAxilReadMaster  => mAxiReadMasters(i),
         mAxilReadSlave   => mAxiReadSlaves(i),
         mAxilWriteMaster => mAxilWriteMasters(i),
         mAxilWriteSlave  => mAxilWriteSlaves(i));
    end generate PS_Reb_Config;

end architecture rtl;

