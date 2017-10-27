-------------------------------------------------------------------------------
-- Title      :
-------------------------------------------------------------------------------
-- File       : PowerMonitorSeqPS.vhd
-- Author     : Leonid Sapozhnikov  <leosap@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-17
-- Last update: 2015-03-17
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Wrapper around AxiLiteMaster to generate custom write/read/check sequence
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
use work.AxiLiteMasterPkg.all;
use work.SsiPkg.all;

use work.UserPkg.all;
use work.ThresholdPkg.all;

entity PowerMonitorSeqPS is
   generic (
      TPD_G                : time                   := 1 ns;
      SIMULATION_G         : boolean                := false;
	  PS_REG_READ_LENGTH_C : positive := 1;
	  FAIL_CNT_C           : integer := 3
	  );

   port (
      axiClk : in sl;
      axiRst : in sl;

	  ps_addresses       : in Slv32Array(PS_REG_READ_LENGTH_C-1 downto 0) := (Others => (Others => '0'));
	  ps_data            : in Slv32Array(PS_REG_READ_LENGTH_C-1 downto 0) := (Others => (Others => '0'));
	  numbEntry          : in Slv(7 downto 0);
	  
      SeqCntlIn       : in  SeqCntlInType;
      SeqCntlOut      : out  SeqCntlOutType;
         
      mAxilReadMaster : out AxiLiteReadMasterType;
      mAxilReadSlave  : in  AxiLiteReadSlaveType;
	  mAxilWriteMaster : out AxiLiteWriteMasterType;
      mAxilWriteSlave  : in  AxiLiteWriteSlaveType);

end entity PowerMonitorSeqPS;

architecture rtl of PowerMonitorSeqPS is

   type StateType is (
      IDLE_S,
      W_START_S,
      W_WAIT_S,
      R_START_S,
      R_WAIT_S,
      CHECK_OPER_S	  ); 

   type RegType is record
      cnt   : natural range 0 to PS_REG_READ_LENGTH_C;
	  f_cnt : natural range 0 to FAIL_CNT_C;
	  stV   :slv(3 downto 0);
	  fail  : sl;
	  initDone : sl;
	  ps_on  : sl;
	  status : slv(1 downto 0);
      valid : slv(PS_REG_READ_LENGTH_C-1 downto 0);
      inSlv : Slv32Array(PS_REG_READ_LENGTH_C-1 downto 0);
      req   : AxiLiteMasterReqType;
      state : StateType;
   end record;

   constant REG_INIT_C : RegType := (
      cnt   => 0,
	  f_cnt => 0,
	  stV => (others => '0'),
	  fail  => '0',
	  initDone  => '0',
	  ps_on  => '0',
	  status => (others => '0'),
      valid => (others => '0'),
      inSlv => (others => (others => '0')),
      req   => AXI_LITE_MASTER_REQ_INIT_C,
      state => IDLE_S);

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal inSlv : Slv32Array(PS_REG_READ_LENGTH_C-1 downto 0);
   signal ack   : AxiLiteMasterAckType;
   constant  ONEVECT : slv(MAX_ENTRY_C-1 downto 0) := (Others => '1');
   

begin

	
    U_AxiLiteMaster : entity work.AxiLiteMaster
      generic map (
         TPD_G => TPD_G)
      port map (
         req             => r.req,
         ack             => ack,
         axilClk         => axiClk,
         axilRst         => axiRst,
         axilWriteMaster => mAxilWriteMaster,
         axilWriteSlave  => mAxilWriteSlave,
         axilReadMaster  => mAxilReadMaster,
         axilReadSlave   => mAxilReadSlave);  

   comb : process (ack, axiRst, SeqCntlIn, numbEntry, ps_data, ps_addresses, r) is
      variable v : RegType;
      variable i : natural;
   begin
      -- Latch the current value
      v := r;
	  v.Ps_On := SeqCntlIn.Ps_On;
	  
	        -- Loop through the SLV array
      for i in (PS_REG_READ_LENGTH_C-1) downto 0 loop
         -- Check for changes in the bus
         if ps_data(i)(7 downto 0) = r.inSlv(i)(7 downto 0) then
            -- Set the flag
            v.valid(i) := '1';
         end if;
      end loop;


      -- Update the registered value
      --v.inSlv := inSlv;

      -- State Machine
      case (r.state) is
         ----------------------------------------------------------------------
		 
         when IDLE_S =>
            -- Wait for DONE to set
			v.stV   := "0001";
			if (SeqCntlIn.Ps_On = '0') then
			   v.cnt   := 0;
			   v.f_cnt := 0;
			   v.fail  := '0';
--			   v.valid := (Others => '0');
			   v.initDone := '0';
               v.req.request := '0';
			   v.state        := IDLE_S;
            elsif (SeqCntlIn.Ps_On = '1' and r.Ps_On = '0') then
               -- Next state
               v.state       := W_START_S;
            end if;
			
         when W_START_S =>
		    v.stV   := "0010";
            -- Increment the counter
            if (SeqCntlIn.Ps_On = '0') then
			   v.state        := IDLE_S;
			elsif r.cnt = (PS_REG_READ_LENGTH_C) then
               v.cnt := 0;
			   v.state        := R_START_S;
            elsif(ack.done = '0') then
               v.cnt := r.cnt + 1;
			   -- Reset the flag
--               v.valid(r.cnt) := '0';
               -- Setup the AXI-Lite Master request
               v.req.request  := '1';
               v.req.rnw      := '0';   -- Write operation
               v.req.address  := ps_addresses(r.cnt)(29 downto 0) & "00"; -- shift stored value to mutch bus
               v.req.wrData   := ps_data(r.cnt);
			   -- Next state
               v.state        := W_WAIT_S;
            end if;

         ----------------------------------------------------------------------
         when W_WAIT_S =>
		    v.stV   := "0011";
            -- Wait for DONE to set
            if (SeqCntlIn.Ps_On = '0') then
			   v.state        := IDLE_S;
			elsif ack.done = '1' then
               -- Reset the flag
               v.req.request := '0';
               -- Next state
               v.state       := W_START_S;
            end if;
      ----------------------------------------------------------------------
         when R_START_S =>
		    v.stV   := "0100";
            -- Increment the counter
            if (SeqCntlIn.Ps_On = '0') then
			   v.state        := IDLE_S;
			elsif r.cnt = (PS_REG_READ_LENGTH_C) then
               v.cnt := 0;
			   v.state        := CHECK_OPER_S;
            elsif(ack.done = '0') then
               v.cnt := r.cnt + 1;
			   v.req.request  := '1';
               v.req.rnw      := '1';   -- Read operation
               v.req.address  := ps_addresses(r.cnt)(29 downto 0) & "00"; -- shift stored value to mutch bus
			   -- Next state
               v.state        := R_WAIT_S;
            end if;
	  
            -- Check the valid flag and transaction completed
 --           if (r.valid(r.cnt) = '1') and (ack.done = '0') then
               -- Reset the flag
 --              v.valid(r.cnt) := '0';
               -- Setup the AXI-Lite Master request
 --              v.req.request  := '1';
 --              v.req.rnw      := '1';   -- Read operation
 --              v.req.address  := ps_addresses(r.cnt)(29 downto 0) & "00"; -- shift stored value to mutch bus
 --           end if;
         ----------------------------------------------------------------------
         when R_WAIT_S =>
		 v.stV   := "0101";
            -- Wait for DONE to set
            if (SeqCntlIn.Ps_On = '0') then
			   v.state        := IDLE_S;
			elsif ack.done = '1' then
               -- Reset the flag
               v.req.request        := '0';
			   v.inSlv(r.cnt - 1)       := ack.rdData;
               v.status             := ack.resp OR r.status;
               -- Next state
               v.state       := R_START_S;
            end if;
      ----------------------------------------------------------------------
         when CHECK_OPER_S =>
		 v.stV   := "0110";
            -- Increment the counter
            if (SeqCntlIn.Ps_On = '0') then
			   v.state        := IDLE_S;
			elsif r.f_cnt = (FAIL_CNT_C) then
               v.f_cnt := 0;
			   v.fail  := '1';
			   v.state        := IDLE_S;
			elsif (r.valid(PS_REG_READ_LENGTH_C-1 downto 0) = ONEVECT(PS_REG_READ_LENGTH_C-1 downto 0)) and (r.status = "00") then
               v.f_cnt := 0;
			   v.fail  := '0';
			   v.initDone := '1';
			   -- Next state
               v.state        := IDLE_S;
            else
               v.f_cnt := r.f_cnt + 1;
			   -- Next state
               v.state        := W_START_S;	  
            end if;
      ----------------------------------------------------------------------
      end case;

      -- Synchronous Reset
      if (axiRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Register the variable for next clock cycle
      rin <= v;
	  
	      ----------------------------------------------------------------------------------------------
      -- Outputs
      ----------------------------------------------------------------------------------------------
      SeqCntlOut.fail  <= r.fail;
	  SeqCntlOut.initDone  <= r.initDone;
	  SeqCntlOut.stV  <= r.inSlv(4)(7 downto 0) & r.inSlv(3)(7 downto 0) & r.inSlv(2)(7 downto 0) & r.inSlv(1)(7 downto 0) & 
	                     r.inSlv(0)(7 downto 0) & r.fail & r.initDone & r.status & '0' & r.valid & toSlv(r.cnt,4) & r.stV;
      
   end process comb;

   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;



  
end architecture rtl;

