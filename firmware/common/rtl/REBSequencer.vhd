-------------------------------------------------------------------------------
-- Title         : LSST PS individual REB sequencer
-- File          : REBSequencer.vhd
-- Author        : Leonid Sapozhnikov, leosap@slac.stanford.edu
-- Created       : 10/16/2017
-------------------------------------------------------------------------------
-- Description:
-- Sequencer logic to configure LTC2945 for fault monitoring by asserting Alert low
-- Handle individual REB, or in case of CR, can do upto 2 REBs
-------------------------------------------------------------------------------
-- Copyright (c) 2017 by Leonid Sapozhnikov. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/16/2017: created.
--5/24/18 adding indepndent control for dPhi on
-------------------------------------------------------------------------------
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


entity REBSequencer is

   generic (
      TPD_G           : time                   := 1 ns;
      SIMULATION_G    : boolean                := false;
	  Delay_period    : integer                := 125000;
	  Delay_period_last    : integer           := 25000000;  --200mSec
      REB_number      : slv(3 downto 0)        := "0000");

   port (
      axiClk : in sl;
      axiRst : in sl;

	  rebOn        : in  sl;
	  hvOn         : in  sl;
	  dPhiOn       : in  sl;
	  retryOnFail  : in  slv(2 downto 0);
--	  alertCleared : in  sl;
--	  alertCleared_add : in  sl;
	  clearAlert   : out sl;
	  clearAlert_add : out sl;
	  sequenceDone : out sl;
	  sequenceDone_add : out sl;
--	  alertCldAck   : out sl;
--	  alertCldAck_add : out sl;
	  rebOnOff     : out sl;
	  rebOnOff_add : out sl;
	  RegFileIn    : in  RegFileInType := REGFILEIN_C;
	  configDone   : out sl;
	  allRunning   : out sl;
	  initDone_add : in  sl;
      initFail_add : in  sl;
	  initDone     : in  sl;
      initFail     : in  sl;
	  initDone_temp : in  sl;
      initFail_temp : in  sl;
	  selectCR     : in sl;
	  unlockPsOn   : in sl;
      din          : out slv(7 downto 0);  -- Tere are no -1 due to special case for heaters under CR
      dout         : in  slv(15 downto 0);  -- same due to CR heater
	  temp_Alarm   : in sl;
	  Status       : out slv(31 downto 0);  -- 
      powerFailure : out sl);

end entity REBSequencer;

architecture rtl of REBSequencer is

   -------------------------------------------------------------------------------------------------
   -- Reg Master I2C Bridge Constants and signals
   -------------------------------------------------------------------------------------------------

           

  type MasterStateType is (
     WAIT_START_S,
     WAIT_CONFIG_S,      
     TURN_ON_PS0_S,     -- Digi
	 CLEAR_ALERT_PS0_S,
     TURN_ON_PS1_S,     -- Ana
	 CLEAR_ALERT_PS1_S,
     TURN_ON_PS2_S,     -- Clk Low
	 CLEAR_ALERT_PS2_S,
     TURN_ON_PS3_S,     -- Clk High
	 CLEAR_ALERT_PS3_S,
--     TURN_ON_PS4_S,     -- dPhi
--	 CLEAR_ALERT_PS4_S,
     TURN_ON_PS5_S,     -- OD 
	 CLEAR_ALERT_PS5_S,
	 TURN_ON_PS6_S,     -- Heater 
	 CLEAR_ALERT_PS6_S,
     WAIT_FOR_CCS_ON,   -- CCS command wait for HV and CR dPhi
--	 CLEAR_WAIT_FOR_CCS_ON,
     TURN_ON_PS4_S,     -- dPhi
--	 CLEAR_ALERT_PS4_S,
	 TURN_ON_PS7_S,     -- Bias
--	 CLEAR_ALERT_PS7_S,
	 MONITORING_S,
     TURN_OFF_PS7_S,     -- Bias
     TURN_OFF_PS6_S,     -- Heater
     TURN_OFF_PS5_S,     -- OD
     TURN_OFF_PS4_S,     -- dPhi
     TURN_OFF_PS3_S,     -- Clk Hi
     TURN_OFF_PS2_S,     -- Clk low
	 TURN_OFF_PS1_S,     -- Analog 
	 TURN_OFF_PS0_S,     -- digi
	 TURN_OFF_S);
      
            
   type RegType is record
      rebOn          : sl;
	  rebOn_d        : sl;
	  rebOnOff       : sl;
	  rebOnOff_add   : sl;
	  initDone       : sl;
	  initFail       : sl;
	  clearAlert     : sl;
--	  alertCleared   : sl;
	  sequenceDone   : sl;
--	  alertCldAck    : sl;
	  stV            : slv(4 downto 0);
	  din            : slv(7 downto 0);
	  powerFailure   : sl;
	  powerFailureD   : sl;
	  configDone     : sl;
	  allRunning     : sl;
	  powerFault     : slv(17 downto 0);
	  powerFaultStart : slv(17 downto 0);
	  cntRetFail      : slv(2 downto 0);
	  cnt             : natural range 0 to Delay_period_last;
	  masterState     : MasterStateType;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      rebOn            => '0',
	  rebOn_d          => '0',
	  rebOnOff         => '0',
	  rebOnOff_add     => '0',
	  initDone         => '0',
	  initFail         => '0',
	  clearAlert       => '0',
--	  alertCleared     => '0',
	  sequenceDone     => '0',
--	  alertCldAck      => '0',
      stV              => (Others => '0'),
	  din              => (Others => '0'),
      powerFailure     => '0',
	  powerFailureD    => '0',
	  configDone       => '0',
	  allRunning       => '0',
	  powerFault       => (others => '0'),
	  powerFaultStart  => (others => '0'),
	  cntRetFail       => (others => '0'),
	  cnt              => 0,
      masterState      => WAIT_START_S);

   signal alarmSynced : slv(15 downto 0);
   signal alarmIn     : slv(15 downto 0);
   signal initFailS   : sl;
   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

    attribute dont_touch                 : string;
    attribute dont_touch of r    : signal is "true";

begin

   -------------------------------------------------------------------------------------------------
   -- Main process
   -------------------------------------------------------------------------------------------------
   alarmIn <= NOT(temp_Alarm) & dout(15 downto 14) & dout(12 downto 0);
   initFailS <= initFail_add OR initFail;
   SynchronizerVector_0 : entity work.SynchronizerVector
      generic map (
         TPD_G                => TPD_G,
		 WIDTH_G           => 16)
      port map (
         clk          => axiClk,
         rst          => axiRst,
		 dataIn        => alarmIn, --dout,
         dataOut  => alarmSynced);
   
 
   comb : process (axiRst, rebOn, hvOn, dPhiOn, initDone, initDone_temp, initFail_temp, initFail, initFail_add,
  --                 alertCleared, alertCleared_add, 
				   retryOnFail, 
                   RegFileIn, initDone_add, initFailS, alarmSynced, selectCR, unlockPsOn, dout,  r ) is
      variable v           : RegType;
      
   begin
      v := r;
	  v.powerFailureD := r.powerFailure;
	  v.sequenceDone  := '0'; 
--	  v.alertCldAck   := '0';
       
	  
	  if (selectCR = '1') and (REB_number = x"0" OR REB_number =x"3") then 
			     v.rebOnOff_add                      := r.rebOnOff;
				 v.initDone                          := initDone and initDone_add and initDone_temp;
				 v.initFail                          := initFail OR initFail_add OR initFail_temp;
				 v.powerFault                        := initFail_temp & initFailS & alarmSynced(15 downto 5) & '0' & alarmSynced(3 downto 0);  -- Zeros to exclude unused checks
	             v.powerFaultStart                   := FAILMASK_START(17 downto 0) AND (initFail_temp & initFailS & alarmSynced(15 downto 5) & '0' & alarmSynced(3 downto 0));  -- Zeros to exclude unused checks
--				 v.alertCleared                      := alertCleared and alertCleared_add;
	  else
	             v.rebOnOff_add                      := '0';
				 v.initDone                          := initDone and initDone_temp;
				 v.initFail                          := initFail OR initFail_temp;
				 v.powerFault                        := initFail_temp & initFail & alarmSynced(15) & "00" & alarmSynced(12 downto 5) & '0' & alarmSynced(3 downto 0);
				 v.powerFaultStart                   := FAILMASK_START(17 downto 0) AND (initFail_temp & initFail & alarmSynced(15) & "00" & alarmSynced(12 downto 5) & '0' & alarmSynced(3 downto 0));
--				 v.alertCleared                      := alertCleared;

	  end if;
	  
	  if (selectCR = '1') and (REB_number = x"2" OR REB_number =x"5") then 
	             v.rebOn                             := '0';  -- controlled by REB0/3 for heaters
	  else
	             v.rebOn                             := rebOn;
	  end if;
	  v.rebOn_d := r.rebOn;
      
      case r.masterState is
         when WAIT_START_S =>
		    v.stV := "00000";
		    v.rebOnOff                      := r.rebOn_d and (unlockPsOn);  --temp to be able to turn of PS
            if (r.rebOn = '1' and r.rebOn_d = '0' and RegFileIn.enable_in = '1') then
               v.powerFailure       := '0';
			   v.configDone           := '0';
			   v.allRunning           := '0';
			   v.din                := (Others => '0');
			   v.cnt                := 0;
			   v.clearAlert         := '0';
			   v.cntRetFail         := (Others => '0');
               v.rebOnOff                      := '1';
               v.masterState                   := WAIT_CONFIG_S;
            end if;
 
         when WAIT_CONFIG_S =>
		    v.stV := "00001";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.sequenceDone                    := '1';
               v.masterState                   := WAIT_START_S;  
            elsif (r.initFail = '1') then
			   v.powerFailure                  := '1';
			   v.sequenceDone                    := '1';
               v.masterState                   := WAIT_START_S;  			   
            elsif (r.initDone = '1') then
			   v.din                           := "00000001";
               v.masterState                   := TURN_ON_PS0_S; 
            end if;
               
         when TURN_ON_PS0_S =>
		    v.stV := "00010";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                          := "11111110" AND r.din; --
               v.masterState                   := TURN_OFF_PS0_S;
            elsif ((r.powerFaultStart /=  "000000000000000000")  and (retryOnFail >  r.cntRetFail) )  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := r.cntRetFail + '1';
			   v.clearAlert                    := '1';
               v.masterState                   := CLEAR_ALERT_PS0_S;    
            elsif (r.powerFaultStart /=  "000000000000000000")  then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
			   v.sequenceDone                    := '1';
			   v.din                          := "11111110" AND r.din; --
               v.masterState                   := TURN_OFF_PS0_S; 			   
            elsif (r.cnt = (Delay_period)) then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "00000010" OR r.din;
               v.masterState                   := TURN_ON_PS1_S; 
			else
			   v.cnt := r.cnt + 1;
            end if;
			
         when CLEAR_ALERT_PS0_S =>
		    v.stV := "10100";
			v.clearAlert                    := '0';
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                          := "11111110" AND r.din; --
               v.masterState                   := TURN_OFF_PS0_S;
            elsif (r.powerFaultStart =  "000000000000000000")  then
			   v.cnt                           := 0;
--			   v.alertCldAck                     := '1';
               v.masterState                   := TURN_ON_PS0_S;                                          
            elsif (r.cnt = (Delay_period_last)) then -- to keep SM going
			   v.cnt                           := 0;
               v.masterState                   := TURN_ON_PS0_S; 
			else
			   v.cnt := r.cnt + 1;
            end if;
			

		when TURN_ON_PS1_S =>
		    v.stV := "00011";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                          := "11111101" AND r.din; --
               v.masterState                   := TURN_OFF_PS1_S;
            elsif ((r.powerFaultStart /=  "000000000000000000")  and (retryOnFail >  r.cntRetFail) )  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := r.cntRetFail + '1';
			   v.clearAlert                    := '1';
               v.masterState                   := CLEAR_ALERT_PS1_S;  
            elsif (r.powerFaultStart /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
			   v.sequenceDone                    := '1';
			   v.din                          := "11111101" AND r.din; --
               v.masterState                   := TURN_OFF_PS1_S;                                          
            elsif (r.cnt = (Delay_period)) then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "00010000" OR r.din;
               v.masterState                   := TURN_ON_PS2_S;
			else
			   v.cnt := r.cnt + 1;
            end if;
			
         when CLEAR_ALERT_PS1_S =>
		    v.stV := "10101";
			v.clearAlert                    := '0';
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                           := 0;
			   v.sequenceDone                    := '1';
			   v.din                           := "11111101" AND r.din; --
               v.masterState                   := TURN_OFF_PS1_S;
            elsif (r.powerFaultStart =  "000000000000000000")  then
			   v.cnt                           := 0;
--			   v.alertCldAck                     := '1';
               v.masterState                   := TURN_ON_PS1_S;                                          
            elsif (r.cnt = (Delay_period_last)) then -- to keep SM going
			   v.cnt                           := 0;
               v.masterState                   := TURN_ON_PS1_S; 
			else
			   v.cnt := r.cnt + 1;
            end if;
			
			
		when TURN_ON_PS2_S =>
		    v.stV := "00100";
            if (rebOn = '0'  OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                          := "11101111" AND r.din; --
               v.masterState                   := TURN_OFF_PS2_S;
            elsif ((r.powerFaultStart /=  "000000000000000000")  and (retryOnFail >  r.cntRetFail) )  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := r.cntRetFail + '1';
			   v.clearAlert                    := '1';
               v.masterState                   := CLEAR_ALERT_PS2_S; 
            elsif (r.powerFaultStart /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
			   v.sequenceDone                    := '1';
			   v.din                          := "11101111" AND r.din; --
               v.masterState                   := TURN_OFF_PS2_S;                                          
            elsif (r.cnt = (Delay_period)) then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "00001000" OR r.din;
               v.masterState                   := TURN_ON_PS3_S ;   --
			else
			   v.cnt := r.cnt + 1;
            end if;

		when CLEAR_ALERT_PS2_S =>
		    v.stV := "10110";
			v.clearAlert                    := '0';
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                          := "11101111" AND r.din; --
               v.masterState                   := TURN_OFF_PS2_S;
            elsif (r.powerFaultStart =  "000000000000000000")  then
			   v.cnt                           := 0;
--			   v.alertCldAck                     := '1';
               v.masterState                   := TURN_ON_PS2_S;                                          
            elsif (r.cnt = (Delay_period_last)) then -- to keep SM going
			   v.cnt                           := 0;
               v.masterState                   := TURN_ON_PS2_S; 
			else
			   v.cnt := r.cnt + 1;
            end if;
			
		when TURN_ON_PS3_S =>
		    v.stV := "00101";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                          := "11110111" AND r.din; --
               v.masterState                   := TURN_OFF_PS3_S;
            elsif ((r.powerFaultStart /=  "000000000000000000")  and (retryOnFail >  r.cntRetFail) )  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := r.cntRetFail + '1';
			   v.clearAlert                    := '1';
               v.masterState                   := CLEAR_ALERT_PS3_S; 
            elsif (r.powerFaultStart /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
			   v.sequenceDone                    := '1';
			   v.din                          := "11110111" AND r.din; --
               v.masterState                   := TURN_OFF_PS3_S;                                          
            elsif (r.cnt = (Delay_period))  and selectCR = '0' then
			   v.cnt                           := 0;
			   v.din                           := "00000100" OR r.din;
               v.masterState                   := TURN_ON_PS5_S;   -- skip dPhi powering
            elsif (r.cnt = (Delay_period))   then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "00000100" OR r.din;  --And now dPhi manual
               v.masterState                   := TURN_ON_PS5_S;  
			 else
			   v.cnt := r.cnt + 1;
            end if;

		when CLEAR_ALERT_PS3_S =>
		    v.stV := "10111";
			v.clearAlert                    := '0';
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                          := "11110111" AND r.din; --
               v.masterState                   := TURN_OFF_PS3_S;
            elsif (r.powerFaultStart =  "000000000000000000")  then
			   v.cnt                           := 0;
--			   v.alertCldAck                     := '1';
               v.masterState                   := TURN_ON_PS3_S;                                          
            elsif (r.cnt = (Delay_period_last)) then -- to keep SM going
			   v.cnt                           := 0;
               v.masterState                   := TURN_ON_PS3_S; 
			else
			   v.cnt := r.cnt + 1;
            end if;
			
		-- when TURN_ON_PS4_S =>
		    -- v.stV := "00110";
            -- if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   -- v.cnt                             := 0;
			   -- v.sequenceDone                    := '1';
			   -- v.din                          := "11011111" AND r.din; --
               -- v.masterState                   := TURN_OFF_PS4_S;
            -- elsif ((r.powerFaultStart /=  "000000000000000000")  and (retryOnFail >  r.cntRetFail) )  then
			   -- v.cnt                           := 0;
			   -- v.cntRetFail                    := r.cntRetFail + '1';
			   -- v.clearAlert                    := '1';
               -- v.masterState                   := CLEAR_ALERT_PS4_S; 
            -- elsif (r.powerFaultStart /=  "000000000000000000") then
			   -- v.cnt                           := 0;
			   -- v.powerFailure                    := '1';
			   -- v.sequenceDone                    := '1';
			   -- v.din                          := "11011111" AND r.din; --
               -- v.masterState                   := TURN_OFF_PS4_S;                                          
            -- elsif (r.cnt = (Delay_period))  then
			   -- v.cnt                           := 0;
			   -- v.cntRetFail                    := (Others => '0');
			   -- v.din                           := "00000100" OR r.din;
               -- v.masterState                   := TURN_ON_PS5_S;    
			-- else
			   -- v.cnt := r.cnt + 1;
            -- end if;

		-- when CLEAR_ALERT_PS4_S =>
		    -- v.stV := "11000";
			-- v.clearAlert                    := '0';
            -- if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   -- v.cnt                             := 0;
			   -- v.sequenceDone                    := '1';
			   -- v.din                          := "11011111" AND r.din; --
               -- v.masterState                   := TURN_OFF_PS4_S;
           -- elsif (r.powerFaultStart =  "000000000000000000")  then
			   -- v.cnt                           := 0;
-- --			   v.alertCldAck                     := '1';
               -- v.masterState                   := TURN_ON_PS4_S;                                          
            -- elsif (r.cnt = (Delay_period_last)) then -- to keep SM going
			   -- v.cnt                           := 0;
               -- v.masterState                   := TURN_ON_PS4_S; 
			-- else
			   -- v.cnt := r.cnt + 1;
            -- end if;
			
		when TURN_ON_PS5_S =>
		    v.stV := "00111";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                            := "11111011" AND r.din; --
			   v.masterState                   := TURN_OFF_PS5_S;
            elsif ((r.powerFaultStart /=  "000000000000000000")  and (retryOnFail >  r.cntRetFail) )  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := r.cntRetFail + '1';
			   v.clearAlert                    := '1';
               v.masterState                   := CLEAR_ALERT_PS5_S; 
            elsif (r.powerFaultStart /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
			   v.sequenceDone                    := '1';
			   v.din                            := "11111011" AND r.din; --
               v.masterState                   := TURN_OFF_PS5_S;                                          
            elsif (r.cnt = (Delay_period))  and selectCR = '0' then
			   v.cnt                           := 0;
			   v.din                           := "00100000" OR r.din;   -- heaters at differenet locations
               v.masterState                   := TURN_ON_PS6_S;    
            elsif (r.cnt = (Delay_period))  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "10000000" OR r.din;    -- heaters at differenet locations
               v.masterState                   := TURN_ON_PS6_S; 
			else
			   v.cnt := r.cnt + 1;
            end if;

		when CLEAR_ALERT_PS5_S =>
		    v.stV := "11001";
			v.clearAlert                    := '0';
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   v.din                            := "11111011" AND r.din; --
			   v.masterState                   := TURN_OFF_PS5_S;
            elsif (r.powerFaultStart =  "000000000000000000")  then
			   v.cnt                           := 0;
--			   v.alertCldAck                     := '1';
               v.masterState                   := TURN_ON_PS5_S;                                          
            elsif (r.cnt = (Delay_period_last)) then -- to keep SM going
			   v.cnt                           := 0;
               v.masterState                   := TURN_ON_PS5_S; 
			else
			   v.cnt := r.cnt + 1;
            end if;
			
		when TURN_ON_PS6_S =>
		    v.stV := "01000";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   if selectCR = '0' then
			      v.din                          := "11011111" AND r.din; --
			   else
			      v.din                          := "01111111" AND r.din; --
			   end if;
               v.masterState                   := TURN_OFF_PS6_S;
            elsif ((r.powerFaultStart /=  "000000000000000000")  and (retryOnFail >  r.cntRetFail) )  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := r.cntRetFail + '1';
			   v.clearAlert                    := '1';
               v.masterState                   := CLEAR_ALERT_PS6_S; 
            elsif (r.powerFaultStart /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
			   v.sequenceDone                    := '1';
			   if selectCR = '0' then
			      v.din                          := "11011111" AND r.din; --
			   else
			      v.din                          := "01111111" AND r.din; --
			   end if;
               v.masterState                   := TURN_OFF_PS6_S;                                          
            elsif (r.cnt = (Delay_period_last))  then   -- long wait to make sure all measurement done
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "00000000" OR r.din; -- hv configured manually
			   v.configDone                      := '1';
			   v.sequenceDone                    := '1';
               v.masterState                   := WAIT_FOR_CCS_ON;    
			else
			   v.cnt := r.cnt + 1;
            end if;
			
		when CLEAR_ALERT_PS6_S =>
		    v.stV := "11010";
			v.clearAlert                    := '0';
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.sequenceDone                    := '1';
			   if selectCR = '0' then
			      v.din                          := "11011111" AND r.din; --
			   else
			      v.din                          := "01111111" AND r.din; --
			   end if;
               v.masterState                   := TURN_OFF_PS6_S;
            elsif (r.powerFaultStart =  "000000000000000000")  then
			   v.cnt                           := 0;
--			   v.alertCldAck                     := '1';
               v.masterState                   := TURN_ON_PS6_S;                                          
            elsif (r.cnt = (Delay_period_last)) then -- to keep SM going
			   v.cnt                           := 0;
               v.masterState                   := TURN_ON_PS6_S; 
			else
			   v.cnt := r.cnt + 1;
            end if;
			
		when WAIT_FOR_CCS_ON =>
		    v.stV := "10100";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
--			   v.sequenceDone                    := '1';
			   v.din                           := "10111111" AND r.din; --
               v.masterState                   := TURN_OFF_PS7_S;
            elsif (r.powerFaultStart /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
--			   v.sequenceDone                    := '1';
			   v.din                           := "10111111" AND r.din; --
               v.masterState                   := TURN_OFF_PS7_S; 
            elsif (r.din =  "01111111" and selectCR = '0') then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.allRunning                      := '1';
               v.masterState                   := MONITORING_S;
            elsif (r.din =  "11111111" and selectCR = '1') then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.allRunning                      := '1';
               v.masterState                   := MONITORING_S;
            elsif (dPhiOn = '1' and selectCR = '1' and  r.din(5) = '0')  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "00100000" OR r.din; -- hv configured manually
               v.masterState                   := TURN_ON_PS4_S; 			   
            elsif (hvOn = '0' and r.din(6) = '0')  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "01000000" OR r.din; -- hv configured manually
               v.masterState                   := TURN_ON_PS7_S;   			   
            end if;

			
		when TURN_ON_PS4_S =>
		    v.stV := "00110";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
--			   v.sequenceDone                    := '1';
			   v.din                           := "10111111" AND r.din; --
               v.masterState                   := TURN_OFF_PS7_S;              --due to uncertanty of manual on start with HV        
            elsif (r.powerFaultStart /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
--			   v.sequenceDone                    := '1';
			   v.din                           := "10111111" AND r.din; --
               v.masterState                   := TURN_OFF_PS7_S;              --due to uncertanty of manual on start with HV                             
            elsif (r.cnt = (Delay_period))  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "00000100" OR r.din;
               v.masterState                   := WAIT_FOR_CCS_ON;    
			else
			   v.cnt := r.cnt + 1;
            end if;

		when TURN_ON_PS7_S =>
		    v.stV := "01001";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
--			   v.sequenceDone                    := '1';
			   v.din                           := "10111111" AND r.din; --
               v.masterState                   := TURN_OFF_PS7_S; 
            elsif (r.powerFaultStart /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
--			   v.sequenceDone                    := '1';
			   v.din                           := "10111111" AND r.din; --
               v.masterState                   := TURN_OFF_PS7_S;    
            elsif (r.cnt = (Delay_period))  then
			   v.cnt                           := 0;
			   v.cntRetFail                    := (Others => '0');
			   v.din                           := "01000000" OR r.din; -- hv configured manually
               v.masterState                   := WAIT_FOR_CCS_ON;    
			else
			   v.cnt := r.cnt + 1; 
            end if;
						
		when MONITORING_S =>
		    v.stV := "01010";
            if (rebOn = '0' OR RegFileIn.enable_in = '0') then
			   v.cnt                             := 0;
			   v.din                           := "10111111" AND r.din; -- 
			   v.configDone                      := '0';
			   v.allRunning                      := '0';
               v.masterState                   := TURN_OFF_PS7_S;
            elsif (r.powerFault /=  "000000000000000000") then
			   v.cnt                           := 0;
			   v.powerFailure                    := '1';
			   v.din                           := "10111111" AND r.din; --
			   v.configDone                      := '0';
			   v.allRunning                      := '0';
               v.masterState                   := TURN_OFF_PS7_S;                                          
            end if;


		when TURN_OFF_PS7_S =>
		    v.stV := "01011";
			 v.configDone                      := '0';
			 v.allRunning                      := '0';
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   if selectCR = '0' then
			      v.din                          := "11011111" AND r.din; --
			   else
			      v.din                          := "01111111" AND r.din; --
			   end if;
			   
               v.masterState                   := TURN_OFF_PS6_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;

		when TURN_OFF_PS6_S =>
		    v.stV := "01100";
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   v.din                           := "11111011" AND r.din; --
               v.masterState                   := TURN_OFF_PS5_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;
			
		when TURN_OFF_PS5_S =>
		    v.stV := "01101";
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   v.din                           := "11011111" AND r.din; --
               v.masterState                   := TURN_OFF_PS4_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;
	
		when TURN_OFF_PS4_S =>
		    v.stV := "01110";
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   v.din                           := "11110111" AND r.din; --
               v.masterState                   := TURN_OFF_PS3_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;

		when TURN_OFF_PS3_S =>
		    v.stV := "01111";
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   v.din                           := "11101111" AND r.din; --
               v.masterState                   := TURN_OFF_PS2_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;

		when TURN_OFF_PS2_S =>
		    v.stV := "10000";
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   v.din                           := "11111101" AND r.din; --
               v.masterState                   := TURN_OFF_PS1_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;

		when TURN_OFF_PS1_S =>
		    v.stV := "10001";
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   v.din                           := "11111110" AND r.din; --
               v.masterState                   := TURN_OFF_PS0_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;
			
		when TURN_OFF_PS0_S =>
		    v.stV := "10010";
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   v.rebOnOff                      := (unlockPsOn); --'0'; --
               v.masterState                   := TURN_OFF_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;			
			
		when TURN_OFF_S =>
		    v.stV := "10011";
            if (r.cnt = (Delay_period/2))  then
			   v.cnt                           := 0;
			   v.rebOnOff                      := (unlockPsOn); --
               v.masterState                   := WAIT_START_S;    
			else
			   v.cnt := r.cnt + 1;
            end if;	

         when others => null;

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
      rebOnOff      <= r.rebOnOff;
	  rebOnOff_add  <= r.rebOnOff_add;
      configDone    <= r.configDone;
	  allRunning    <= r.allRunning;
      if (selectCR = '1') then 
          din           <= r.din AND ('1' & NOT(hvOn)  & dPhiOn & "11111") ;
	  else
          din           <= r.din AND ('1' & NOT(hvOn)  & "111111") ;
	  end if;	  
	  powerFailure  <= r.powerFailure;	 
      clearAlert   	<= r.clearAlert;  
	  sequenceDone 	<= r.sequenceDone;
--	  alertCldAck   <= r.alertCldAck;
	  clearAlert_add <= r.clearAlert AND selectCR;
	  sequenceDone_add <= r.sequenceDone AND selectCR;
--	  alertCldAck_add <= r.alertCldAck AND selectCR;

	  if (selectCR = '1') and (REB_number = x"0" OR REB_number =x"3") then 
          Status(31 downto 28) <= initDone_add & initDone & r.rebOnOff_add & r.rebOnOff;
	  else
          Status(31 downto 28) <= '0' & initDone & '0' & r.rebOnOff;
	  end if;	  
	  
	  Status(27 downto 23) <= r.stV;
	  

   end process comb;
                   
   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
		 if (r.powerFailure = '1' and r.powerFailureD = '0') then   -- try to catch condition
            Status(17 downto 0)  <= r.powerFault;
		    Status(22 downto 18)  <= r.stV;
		 elsif(r.rebOn = '1' and r.rebOn_d = '0') then  -- clear at restart
		    Status(22 downto 0)  <= (Others => '0');
         end if;
      end if;
   end process seq;


end architecture rtl;

