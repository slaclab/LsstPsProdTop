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
use work.ComparatorUserPkg.all;
--use work.PowerMonitorPkg.all;

entity REBSequencer is

   generic (
      TPD_G           : time                   := 1 ns;
      SIMULATION_G    : boolean                := false;
      REB_number      : slv(3 downto 0)        := "0000");

   port (
      axiClk : in sl;
      axiRst : in sl;

      Reg2SeqData     : in  Reg2SeqData_type := REG2SEQDATA_C;
      Seq2RegData     : out  Seq2RegData_type;
      powerValuesPSArr : in powerValuesArrayType12(6 downto 0); -- 7 supplyes, 8 vlaues per entry 
      AquisitionDone  : in sl;
      AqErrDone       : in sl);

end entity REBSequencer;

architecture rtl of REBSequencer is

   -------------------------------------------------------------------------------------------------
   -- Reg Master I2C Bridge Constants and signals
   -------------------------------------------------------------------------------------------------

           

--   type MasterStateType is (
--      WAIT_START_S,
--      WAIT_CONFIG_S,
--      WAIT_MEAS_S,
--      TURN_ON_PS0,
--      WAIT_MEAS_PS0_S,
--      TURN_ON_PS1,
--      WAIT_MEAS_PS1_S,
--      TURN_ON_PS34,
--      WAIT_MEAS_PS34_S,
--      TURN_ON_PS5,
--      WAIT_MEAS_PS5_S,
--      TURN_ON_PS2,
--      WAIT_MEAS_PS2_S,
--      TURN_ON_PS6,
--      WAIT_MEAS_PS6_S,
--      CHECK_ALL_PS,
--      TURN_OFF_PS6,
--      FAIL_PS1_TURN_OFFPS6,
--      FAIL_PS2345_TURN_OFFPS6,
--      WAIT_OFF,
--      WAIT_OFF_CMD);
      

         constant WAIT_START_S       : slv(4 downto 0) := "00000";
         constant WAIT_CONFIG_S      : slv(4 downto 0) := "00001";
         constant WAIT_MEAS_S        : slv(4 downto 0) := "00010";
         constant TURN_ON_PS0        : slv(4 downto 0) := "00011";
         constant WAIT_MEAS_PS0_S    : slv(4 downto 0) := "00100";
         constant TURN_ON_PS1        : slv(4 downto 0) := "00101";
         constant WAIT_MEAS_PS1_S    : slv(4 downto 0) := "00110";
         constant TURN_ON_PS34       : slv(4 downto 0) := "00111";
         constant WAIT_MEAS_PS34_S   : slv(4 downto 0) := "01000";
         constant TURN_ON_PS5        : slv(4 downto 0) := "01001";
         constant WAIT_MEAS_PS5_S    : slv(4 downto 0) := "01010";
         constant TURN_ON_PS2        : slv(4 downto 0) := "01011";
         constant WAIT_MEAS_PS2_S    : slv(4 downto 0) := "01100";
         constant TURN_ON_PS6        : slv(4 downto 0) := "01101";
         constant WAIT_MEAS_PS6_S    : slv(4 downto 0) := "01110";
         constant CHECK_ALL_PS       : slv(4 downto 0) := "01111";
         constant TURN_OFF_PS6       : slv(4 downto 0) := "10000";
         constant FAIL_PS1_TURN_OFFPS6  : slv(4 downto 0) := "10001";
         constant FAIL_PS2345_TURN_OFFPS6 : slv(4 downto 0) := "10010";
         constant WAIT_OFF           : slv(4 downto 0) := "10011";
         constant WAIT_OFF_CMD        : slv(4 downto 0) := "10100";

            
            
   type RegType is record
      din            : slv(6 downto 0);
      REB_on          : sl;

      -- Polling registers
      delayCnt        : slv(29 downto 0);
      masterState        : slv(4 downto 0); --MasterStateType;
      FailedState     : slv(4 downto 0); --MasterStateType;
      FailedStatus    : slv(6 downto 0);
      FailedTO        : sl;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      din       => (Others => '0'),
      REB_on      => '0',
      delayCnt    => (Others => '0'),
      masterState     => WAIT_START_S,
      FailedState     => WAIT_START_S,
      FailedStatus     => (others => '0'),
      FailedTO      => '0');

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;


--   type powerValuesArrayType is array (natural range <>) of Slv16Array(0 to 7);
   signal   powerValuesArray : powerValuesArrayType(6 downto 0);
   signal   PS_OKs           : slv(6 downto 0);
   signal   CheckPSV         : slv(6 downto 0);
   signal   CheckPS          : sl;
        

         
   type Seq2ComDataArr_type is array (natural range <>) of Seq2ComDataPS_type;
   signal Seq2ComDataArr : Seq2ComDataArr_type(6 downto 0) := ((SEQ2COMP_INIT),(SEQ2COMP_INIT),(SEQ2COMP_INIT),(SEQ2COMP_INIT),(SEQ2COMP_INIT),(SEQ2COMP_INIT),(SEQ2COMP_INIT));

   type Reg2SeqDataArr_type is array (natural range <>) of Reg2SeqDataPS_type;
   signal Reg2SeqDataArr : Reg2SeqDataArr_type(6 downto 0) := ((REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT));
  
--   type PS_LIMIT_ARRAY_type is array (6 downto 0) of LimitPS_Array;
--   signal PS_LIMIT_ARRAY : PS_LIMIT_ARRAY_type(6 downto 0) := ((REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT),(REG2DATAPS_INIT));

   signal PS_LIMIT_ARRAY_ALL: PS_LIMIT_ARRAY_type := (PS_LIMIT_ARRAY_C); 

    attribute dont_touch                 : string;
    attribute dont_touch of r    : signal is "true";

begin

   -------------------------------------------------------------------------------------------------
   -- Main process
   -------------------------------------------------------------------------------------------------
   comb : process (axiRst, PS_OKs, Reg2SeqData, CheckPS, r ) is
      variable v           : RegType;
      variable FailVector : slv(7 downto 0);  -- 6PS and comunication
   begin
      v := r;

      
      case r.masterState is
         when WAIT_START_S =>
            v.din                := (OTHERS => '0');
            v.delayCnt           := (OTHERS => '0');
            if (Reg2SeqData.REB_on_off = '1' and Reg2SeqData.Enable_in = '1') then
               v.REB_on                        := '1';
               v.masterState                   := WAIT_CONFIG_S;
            end if;
 
         when WAIT_CONFIG_S =>
              v.delayCnt := r.delayCnt + '1';
              if (r.delayCnt > WAIT_TIMEOUT.CONFIG_WAIT OR Reg2SeqData.REB_on_off = '0' OR Reg2SeqData.Enable_in = '0') then
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := WAIT_OFF;
                        v.FailedState             := r.masterState;
                        v.FailedStatus            := PS_OKs;
                        v.FailedTO                := '1';                                           
              elsif (Reg2SeqData.REB_config_done = '1') then
                  v.delayCnt                      := (OTHERS => '0');
                  v.masterState                   := WAIT_MEAS_S;
               end if;
               
                          
         when WAIT_MEAS_S =>
            v.delayCnt := r.delayCnt + '1';
            if (r.delayCnt > WAIT_TIMEOUT.ON_WAIT OR Reg2SeqData.REB_on_off = '0' OR Reg2SeqData.Enable_in = '0') then
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := WAIT_OFF;
                        v.FailedState             := r.masterState;
                        v.FailedStatus            := PS_OKs;
                        v.FailedTO                := '1';
            elsif (PS_OKs = "1111111" AND CheckPS = '1') then
                  v.delayCnt                      := (OTHERS => '0');
                  v.masterState                   := TURN_ON_PS0;
            end if;
      
         when TURN_ON_PS0 =>
                  v.din(0) := '1';
                  v.masterState                   := WAIT_MEAS_PS0_S;

         when WAIT_MEAS_PS0_S =>
            v.delayCnt := r.delayCnt + '1';
            if (r.delayCnt > WAIT_TIMEOUT.PS0 OR Reg2SeqData.REB_on_off = '0' OR Reg2SeqData.Enable_in = '0') then
                        v.din := "0000000";
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := WAIT_OFF;
                        v.FailedState             := r.masterState;
                        v.FailedStatus            := PS_OKs;
                        v.FailedTO                := '1';
            elsif (PS_OKs = "1111111"  AND CheckPS = '1') then  -- Maybe too conservative needs only to check PS0
                  v.delayCnt                      := (OTHERS => '0');
                  v.masterState                   := TURN_ON_PS1;
            end if;       
             
         when TURN_ON_PS1 =>
            v.din(1) := '1';
            v.masterState                   := WAIT_MEAS_PS1_S;
   
            when WAIT_MEAS_PS1_S =>
               v.delayCnt := r.delayCnt + '1';
               if (r.delayCnt > WAIT_TIMEOUT.PS1 OR Reg2SeqData.REB_on_off = '0' OR Reg2SeqData.Enable_in = '0') then
                        v.din := "0000000";
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := WAIT_OFF;
                        v.FailedState             := r.masterState;
                        v.FailedStatus            := PS_OKs;
                        v.FailedTO                := '1';
               elsif (PS_OKs = "1111111" AND CheckPS = '1') then  -- Maybe too conservative needs only to check PS0
                     v.delayCnt                      := (OTHERS => '0');
                     v.masterState                   := TURN_ON_PS34;
               end if; 

         when TURN_ON_PS34 =>
            v.din(4 downto 3) := "11";
            v.masterState                   := WAIT_MEAS_PS34_S;
   
         when WAIT_MEAS_PS34_S =>
               v.delayCnt := r.delayCnt + '1';
               if (r.delayCnt > WAIT_TIMEOUT.PS34 OR Reg2SeqData.REB_on_off = '0' OR Reg2SeqData.Enable_in = '0') then
                        v.din := "0000000";
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := WAIT_OFF;
                        v.FailedState             := r.masterState;
                        v.FailedStatus            := PS_OKs;
                        v.FailedTO                := '1';
               elsif (PS_OKs = "1111111"  AND CheckPS = '1') then  -- Maybe too conservative needs only to check PS0
                     v.delayCnt                      := (OTHERS => '0');
                     v.masterState                   := TURN_ON_PS5;
               end if; 
                    
         when TURN_ON_PS5 =>
                  v.din(5) := '1';
                  v.masterState                   := WAIT_MEAS_PS5_S;
         
         when WAIT_MEAS_PS5_S =>
                     v.delayCnt := r.delayCnt + '1';
                     if (r.delayCnt > WAIT_TIMEOUT.PS5 OR Reg2SeqData.REB_on_off = '0' OR Reg2SeqData.Enable_in = '0') then
                        v.din := "0000000";
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := WAIT_OFF;
                        v.FailedState             := r.masterState;
                        v.FailedStatus            := PS_OKs;
                        v.FailedTO                := '1';                                 
                     elsif (PS_OKs = "1111111"  AND CheckPS = '1') then  -- Maybe too conservative needs only to check PS0
                           v.delayCnt                      := (OTHERS => '0');
                           v.masterState                   := TURN_ON_PS2;
                     end if; 
                               
         when TURN_ON_PS2 =>
                    v.din(2) := '1';
                    v.masterState                   := WAIT_MEAS_PS2_S;
                     
         when WAIT_MEAS_PS2_S =>
                    v.delayCnt := r.delayCnt + '1';
                   if (r.delayCnt > WAIT_TIMEOUT.PS2 OR Reg2SeqData.REB_on_off = '0' OR Reg2SeqData.Enable_in = '0') then
                        v.din := "0000000";
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := WAIT_OFF;
                        v.FailedState             := r.masterState;
                        v.FailedStatus            := PS_OKs;
                        v.FailedTO                := '1';                    
                    elsif (PS_OKs = "1111111"  AND CheckPS = '1') then  -- Maybe too conservative needs only to check PS0
                         v.delayCnt                      := (OTHERS => '0');
                         v.masterState                   := TURN_ON_PS6;
                    end if;

         when TURN_ON_PS6 =>
                    v.din(6) := '1';
                    v.masterState                   := WAIT_MEAS_PS6_S;
                     
         when WAIT_MEAS_PS6_S =>
                    v.delayCnt := r.delayCnt + '1';
                   if (r.delayCnt > WAIT_TIMEOUT.PS6 OR Reg2SeqData.REB_on_off = '0' OR Reg2SeqData.Enable_in = '0') then
                        v.din(6) := '0';
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := TURN_OFF_PS6;
                        v.FailedState             := r.masterState;
                        v.FailedStatus            := PS_OKs;
                        v.FailedTO                := '1';
                    elsif (PS_OKs = "1111111"  AND CheckPS = '1') then  -- Maybe too conservative needs only to check PS0
                         v.delayCnt                      := (OTHERS => '0');
                         v.masterState                   := CHECK_ALL_PS;
                    end if;
                     
        when CHECK_ALL_PS =>
                   v.delayCnt := r.delayCnt + '1';
                  if (Reg2SeqData.REB_on_off = '0'  OR Reg2SeqData.Enable_in = '0' ) then
                        v.din(6) := '0';
                        v.delayCnt                := (OTHERS => '0');
                        v.masterState             := TURN_OFF_PS6; 
                  elsif (r.delayCnt > WAIT_TIMEOUT.PS_OK) then                       
                     if (PS_OKs = "1111111"  AND CheckPS = '1' ) then  -- Maybe too conservative needs only to check PS0
                        v.delayCnt                      := (OTHERS => '0');
                     elsif (PS_OKs(0) = '0') then  -- turn all and quit
                           v.din := "0000000";
                           v.delayCnt                      := (OTHERS => '0');
                           v.masterState                   := WAIT_OFF;
                           v.FailedState             := r.masterState;
                           v.FailedStatus            := PS_OKs;
                           v.FailedTO                := '0';
                     elsif (PS_OKs(1)= '0') then  -- 
                            v.din(6) := '0';
                            v.delayCnt                      := (OTHERS => '0');
                            v.masterState                   := FAIL_PS1_TURN_OFFPS6; 
                            v.FailedState             := r.masterState;
                            v.FailedStatus            := PS_OKs;
                            v.FailedTO                := '0';                         
                      else
                          v.din(6) := '0';
                          v.delayCnt                := (OTHERS => '0');
                          v.masterState             := FAIL_PS2345_TURN_OFFPS6;
                          v.FailedState             := r.masterState;
                          v.FailedStatus            := PS_OKs;
                          v.FailedTO                := '0'; 
                      end if;
                   end if; 

        when TURN_OFF_PS6 =>
                   v.delayCnt := r.delayCnt + '1';
                  if (r.delayCnt > WAIT_TIMEOUT.C5SEC_WAIT_C  OR Reg2SeqData.Enable_in = '0') then                       
                           v.din := "0000000";
                           v.delayCnt                      := (OTHERS => '0');
                           v.masterState                   := WAIT_OFF;
                   end if; 

        when FAIL_PS1_TURN_OFFPS6 =>
                   v.delayCnt := r.delayCnt + '1';
                  if (r.delayCnt > WAIT_TIMEOUT.C5SEC_WAIT_C   OR Reg2SeqData.Enable_in = '0') then                       
                           v.din := "0000000";
                           v.delayCnt                      := (OTHERS => '0');
                           v.masterState                   := WAIT_OFF;
                   end if; 

        when FAIL_PS2345_TURN_OFFPS6 =>
                  v.delayCnt := r.delayCnt + '1';
                  if (r.delayCnt > WAIT_TIMEOUT.C5SEC_WAIT_C OR Reg2SeqData.Enable_in = '0') then                       
                           v.din := "0000000";
                           v.delayCnt                      := (OTHERS => '0');
                           v.masterState                   := WAIT_OFF;
                   end if;

        when WAIT_OFF =>
                  v.delayCnt := r.delayCnt + '1';
                  v.REB_on                  := '0';
                  if (r.delayCnt > WAIT_TIMEOUT.WAIT_OFF) then                       
                           v.delayCnt                      := (OTHERS => '0');
                           v.masterState                   := WAIT_OFF_CMD;
                   end if;
                                                           
          when WAIT_OFF_CMD =>
               if (Reg2SeqData.REB_on_off = '0') then
                        v.masterState             := WAIT_START_S;
                        v.FailedState             := WAIT_START_S;
                        v.FailedStatus            := (Others => '0');
                        v.FailedTO                := '0';
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
      Seq2RegData.REB_on  <= r.REb_on;
      Seq2RegData.din  <= r.din;
      Seq2RegData.period  <= "00" & WAIT_TIMEOUT.PS_OK(31 downto 2); -- readout period is PS_OK timeout / 4
      Seq2RegData.SeqState(4 downto 0)  <= r.masterState;
      Seq2RegData.FailedState(4 downto 0)  <= r.FailedState;
      Seq2RegData.FailedStatus  <= r.FailedStatus;
      Seq2RegData.FailedTO  <= r.FailedTO;
      for i in r.din'range loop
         Seq2ComDataArr(i).REB_on <= r.REb_on;
         Seq2ComDataArr(i).din <= r.din(i);
         
         Reg2SeqDataArr(i).EnableAlarm <= Reg2SeqData.EnableAlarm;
         Reg2SeqDataArr(i).dout <= Reg2SeqData.dout(3*i + 1 downto 3*i);
      end loop;
   end process comb;
                   
   seq : process (axiClk) is
   begin
      if (rising_edge(axiClk)) then
         r <= rin after TPD_G;
      end if;
   end process seq;

 PS_COMPARATOR_ARRAY: for i in 6 downto 0 generate     
   PSComparator: entity work.PSComparator
      generic map (
         TPD_G               => TPD_G,
         SIMULATION_G        => false)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         Reg2SeqData     => Reg2SeqDataArr(i),
         Seq2ComData     => Seq2ComDataArr(i),
         PS_OKs          => PS_OKs(i),
         CheckPS         => CheckPSV(i),
         reportFault     => Seq2RegData.reportFaultArr(i),
         PS_LIMIT        => PS_LIMIT_ARRAY_ALL(i),
         powerValues   => powerValuesPSArr(i),
         AquisitionDone  => AquisitionDone,
         AqErrDone       => AqErrDone);

   end generate PS_COMPARATOR_ARRAY;
      
   CheckPS <= CheckPSV(0); -- same for all PS for now

end architecture rtl;

