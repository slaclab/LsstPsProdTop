-------------------------------------------------------------------------------
-- Title         : LSST PS Package
-- File          : UserPkg.vhd
-- Author        : Leonid Sapozhnikov, leosap@slac.stanford.edu
-- Created       : 03/16/2015
-------------------------------------------------------------------------------
-- Description:
-- Package file for LSST power supply board
-------------------------------------------------------------------------------
-- Copyright (c) 2015 by Leonid Sapozhnikov. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 03/15/2015: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.AxiStreamPkg.all;
use surf.SsiPkg.all;
use surf.I2cPkg.all;


package UserPkg is

   type powerValuesArrayType is array (natural range <>) of Slv16Array(0 to 7);
   type powerValuesArrayType12 is array (natural range <>) of Slv12Array(0 to 7);

   -- -- PSsequenceType Record
   -- type PSsequenceType is record
      -- -- Power sequence status
      -- Raft0REB0_on_off  : slv(7 downto 0);
      -- Raft0REB1_on_off  : slv(7 downto 0);
      -- Raft0REB2_on_off  : slv(7 downto 0);
      -- Raft1REB0_on_off  : slv(7 downto 0);
      -- Raft1REB1_on_off  : slv(7 downto 0);
      -- Raft1REB2_on_off  : slv(7 downto 0);
      -- TimeSlot0_on_off  : slv(6 downto 0);
      -- TimeSlot1_on_off  : slv(6 downto 0);
      -- TimeSlot2_on_off  : slv(6 downto 0);
      -- TimeSlot3_on_off  : slv(6 downto 0);
      -- TimeSlot4_on_off  : slv(6 downto 0);
      -- TimeSlot5_on_off  : slv(6 downto 0);
      -- TimeSlot6_on_off  : slv(6 downto 0);
      -- Delay10_on_off    : slv(15 downto 0);
      -- Delay21_on_off    : slv(15 downto 0);
      -- Delay32_on_off    : slv(15 downto 0);
      -- Delay43_on_off    : slv(15 downto 0);
      -- Delay54_on_off    : slv(15 downto 0);
      -- Delay65_on_off    : slv(15 downto 0);
      -- Spare             : slv(31 downto 0);
   -- end record;

   -- -- Initialization constants
   -- constant PS_SEQUENCE_INIT_C : PSsequenceType := (
       -- Raft0REB0_on_off  => (others => '0'),
       -- Raft0REB1_on_off  => (others => '0'),
       -- Raft0REB2_on_off  => (others => '0'),
       -- Raft1REB0_on_off  => (others => '0'),
       -- Raft1REB1_on_off  => (others => '0'),
       -- Raft1REB2_on_off  => (others => '0'),
       -- TimeSlot0_on_off  => (others => '0'),
       -- TimeSlot1_on_off  => (others => '0'),
       -- TimeSlot2_on_off  => (others => '0'),
       -- TimeSlot3_on_off  => (others => '0'),
       -- TimeSlot4_on_off  => (others => '0'),
       -- TimeSlot5_on_off  => (others => '0'),
       -- TimeSlot6_on_off  => (others => '0'),
       -- Delay10_on_off    => (others => '1'),
       -- Delay21_on_off    => (others => '1'),
       -- Delay32_on_off    => (others => '1'),
       -- Delay43_on_off    => (others => '1'),
       -- Delay54_on_off    => (others => '1'),
       -- Delay65_on_off    => (others => '1'),
       -- Spare             => (others => '0')
      -- );


      -- type SeqCntlInType is record
         -- pollActive      : sl;
      -- end record SeqCntlInType;

   -- constant SEC_CNTL_IN_C : SeqCntlInType := (
       -- pollActive             => '0'
      -- );

       -- type SeqCntlOutType is record
         -- aquaring        : sl;
         -- errDetect       : sl;
         -- pollActive      : sl;
      -- end record SeqCntlOutType;

   -- constant SEC_CNTL_OUT_C : SeqCntlOutType := (
       -- aquaring               => '0',
       -- errDetect              => '0',
       -- pollActive             => '0'
      -- );

       type I2cReadAddresses is record
         read_reg_total  : slv(3 downto 0);
         getPSAddr       : Slv32Array(5 downto 0);
      end record I2cReadAddresses;

     constant POWER_MONITOR_SSI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(2, TKEEP_COMP_C);


   constant LOCAL_AXI_CONFIG_C : AxiStreamConfigType := ssiAxiStreamConfig(4);

     -- AXI-Lite Constants
  constant NUM_AXI_MASTERS_C : natural := 10;

  constant REGFILE_INDEX_C       : natural := 0;
  constant PS0_AXI_INDEX_C       : natural := 1;
  constant PS1_AXI_INDEX_C       : natural := 2;
  constant PS2_AXI_INDEX_C       : natural := 3;
  constant PS3_AXI_INDEX_C       : natural := 4;
  constant PS4_AXI_INDEX_C       : natural := 5;
  constant PS5_AXI_INDEX_C       : natural := 6;
  constant VERSION_INDEX_C       : natural := 7;
  constant XADC_INDEX_C          : natural := 8;
  constant BOOT_PROM_INDEX_C     : natural := 9;

   constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := genAxiLiteConfig(NUM_AXI_MASTERS_C, x"0000_0000", 22, 18);


     -- Array

     constant PS_REB_TOTAL_C     : natural := PS5_AXI_INDEX_C - PS0_AXI_INDEX_C + 1;

     type AxiLiteIndexArray is array (natural range<>) of natural;
     constant PS_AXI_INDEX_ARRAY_C : AxiLiteIndexArray((PS5_AXI_INDEX_C-PS0_AXI_INDEX_C) downto 0) := (
             5 => PS5_AXI_INDEX_C,
             4 => PS4_AXI_INDEX_C,
             3 => PS3_AXI_INDEX_C,
             2 => PS2_AXI_INDEX_C,
             1 => PS1_AXI_INDEX_C,
             0 => PS0_AXI_INDEX_C);




     -- constant VERSION_AXI_BASE_ADDR_C  : slv(31 downto 0) := X"00000000";
     -- constant PS0_AXI_BASE_ADDR_C      : slv(31 downto 0) := X"00040000";
     -- constant PS1_AXI_BASE_ADDR_C      : slv(31 downto 0) := X"00080000";
     -- constant PS2_AXI_BASE_ADDR_C      : slv(31 downto 0) := X"000C0000";
     -- constant PS3_AXI_BASE_ADDR_C      : slv(31 downto 0) := X"00100000";
     -- constant PS4_AXI_BASE_ADDR_C      : slv(31 downto 0) := X"00140000";
     -- constant PS5_AXI_BASE_ADDR_C      : slv(31 downto 0) := X"00180000";
     -- constant XADC_AXI_BASE_ADDR_C     : slv(31 downto 0) := X"001c0000";
-- --     constant COMMON_AXI_BASE_ADDR_C   : slv(31 downto 0) := X"00030000";
  -- --   constant TEN_GIGE_AXI_BASE_ADDR_C : slv(31 downto 0) := X"00040000";


     -- constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
        -- VERSION_AXI_INDEX_C  => (
           -- baseAddr          => VERSION_AXI_BASE_ADDR_C,
           -- addrBits          => 12,
           -- connectivity      => X"0001"),
        -- PS0_AXI_INDEX_C  => (
           -- baseAddr          => PS0_AXI_BASE_ADDR_C,
           -- addrBits          => 17,
           -- connectivity      => X"0001"),
        -- PS1_AXI_INDEX_C  => (
           -- baseAddr          => PS1_AXI_BASE_ADDR_C,
           -- addrBits          => 17,
           -- connectivity      => X"0001"),
        -- PS2_AXI_INDEX_C  => (
           -- baseAddr          => PS2_AXI_BASE_ADDR_C,
           -- addrBits          => 17,
           -- connectivity      => X"0001"),
        -- PS3_AXI_INDEX_C  => (
           -- baseAddr          => PS3_AXI_BASE_ADDR_C,
           -- addrBits          => 17,
           -- connectivity      => X"0001"),
        -- PS4_AXI_INDEX_C  => (
           -- baseAddr          => PS4_AXI_BASE_ADDR_C,
           -- addrBits          => 17,
           -- connectivity      => X"0001"),
        -- PS5_AXI_INDEX_C  => (
           -- baseAddr          => PS5_AXI_BASE_ADDR_C,
           -- addrBits          => 17,
           -- connectivity      => X"0001"),
        -- XADC_AXI_INDEX_C     => (
           -- baseAddr          => XADC_AXI_BASE_ADDR_C,
           -- addrBits          => 12,
           -- connectivity      => X"0001")
-- --        COMMON_AXI_INDEX_C   => (
-- --           baseAddr          => COMMON_AXI_BASE_ADDR_C,
-- --           addrBits          => 12,
-- --           connectivity      => X"0001")
-- --  --         ,
  -- --      TEN_GIGE_AXI_INDEX_C => (
  -- --         baseAddr          => TEN_GIGE_AXI_BASE_ADDR_C,
  -- --         addrBits          => 12,
  -- --         connectivity      => X"0001")
           -- );

     type CommonStatusType is record
        trig : sl;
        busy : sl;
     end record;
     constant COMMON_STATUS_INIT_C : CommonStatusType := (
        trig => '0',
        busy => '0');

     type CommonConfigType is record
        packetLength : slv(31 downto 0);
     end record;
     constant COMMON_CONFIG_INIT_C : CommonConfigType := (
        packetLength => toSlv((4-1), 32));

type RegFileInType is record
         dout0           : slv(41 downto 0);
         dout1           : slv(41 downto 0);
         REB_config_done : slv(5 downto 0);
         GA              : slv(4 downto 0);
         TestIn          : slv(7 downto 0);
		 alertCleared    : slv(5 downto 0);
         tempI2cIn       : i2c_in_type;
         fp_I2cIn        : i2c_in_type;
         serIDin         : sl;
         enable_in       : sl;
         spare_in        : sl;
         temp_Alarm      : sl;
         fp_los          : sl;
      end record RegFileInType;

     constant REGFILEIN_C : RegFileInType := (
      dout0     => (Others => '0'),
      dout1     => (Others => '0'),
      REB_config_done => (Others => '0'),
      GA        => (Others => '0'),
      TestIn    => (Others => '0'),
	  alertCleared    => (Others => '0'),
      tempI2cIn => ('0','0'),
      fp_I2cIn  => ('0','0'),
      serIDin   => '0',
      enable_in => '0',
      spare_in  => '0',
      temp_Alarm => '0',
      fp_los    => '0');


type RegFileOutType is record
         sync_DCDC       : slv(5 downto 0);
         reb_on          : slv(5 downto 0);
         REB_enable      : slv(5 downto 0);
         din             : slv(41 downto 0);
         TestOut         : slv(7 downto 0);
         TestOutOE       : slv(7 downto 0);
         LED_on          : slv(2 downto 0);
		 unlockSeting    : slv(2 downto 0);
		 Tempfail        : sl;
	     TempInitDone    : sl;
         tempI2cOut      : i2c_out_type;
         fp_I2cOut       : i2c_out_type;
--         serIDout        : sl;
--         serIDoutOE      : sl;
         fpgaReload      : sl;
         masterReset     : sl;
         I2C_RESET_CNTL  : sl;
         retryOnFail     : slv(2 downto 0);
      end record RegFileOutType;

     constant REGFILEOUT_C : RegFileOutType := (
     sync_DCDC  => (Others => '0'),
     reb_on     => (Others => '0'),
     REB_enable => (Others => '0'),
     din        => (Others => '0'),
     TestOut    => (Others => '0'),
     TestOutOE  => (Others => '0'),
     LED_on     => (Others => '0'),
	 unlockSeting  => (Others => '0'),
	 Tempfail       => '0',
	 TempInitDone   => '0',
     tempI2cOut => ('0','0','0','0','0'),
     fp_I2cOut  => ('0','0','0','0','0'),
     fpgaReload => '0',
     masterReset => '0',
     I2C_RESET_CNTL => '0',
     retryOnFail => "001");

--type Reg2SeqType is record
--         MeasStatus       : slv(127 downto 0);
--         reb_on_off       : slv(5 downto 0);
--         reb_seq_on       : slv(5 downto 0);
--         TreshLimits      : TreshLimits_type;
--         SeqTiming        : SeqTiming_type;
--      end record Reg2SeqType;


--type Seq2RegType is record
--         REB_on           : sl;
--         din              : slv(6 downto 0);
--         SeqState         : slv(31 downto 0);
--         FailedState      : slv(31 downto 0);
--         FailedStatus     : slv(6 downto 0);
--         FailedTO         : sl;
--      end record Seq2RegType;

--     constant SEQ2REGTYPE_C : Seq2RegType := (
--        REB_on => '0', --
--        din => (Others => '0'), --
--        SeqState =>  (Others => '0'),
--        FailedState =>  (Others => '0'),
--        FailedStatus =>  (Others => '0'),
--        FailedTO => '0'
--        );

     type TimeoutWaits is record
        CONFIG_WAIT : slv(31 downto 0);
        ON_WAIT : slv(31 downto 0);
        PS0 : slv(31 downto 0);
        PS1 : slv(31 downto 0);
        PS34 : slv(31 downto 0);
        PS5 : slv(31 downto 0);
        PS2 : slv(31 downto 0);
        PS6 : slv(31 downto 0);
        PS_OK : slv(31 downto 0);
        C5SEC_WAIT_C : slv(31 downto 0);
        WAIT_OFF : slv(31 downto 0);
     end record;

     constant WAIT_TIMEOUT : TimeoutWaits := (
     CONFIG_WAIT => X"2540BE40", -- 5seconds
     ON_WAIT =>  X"2540BE40", -- 5seconds
     PS0 =>  X"2540BE40", -- 5seconds
     PS1 =>  X"2540BE40", -- 5seconds
     PS34 =>  X"2540BE40", -- 5seconds
     PS5 =>  X"2540BE40", -- 5seconds
     PS2 =>  X"2540BE40", -- 5seconds
     PS6 =>   X"2540BE40", -- 5seconds
     PS_OK =>  X"2540BE40", -- 5seconds
     C5SEC_WAIT_C =>  X"2540BE40", -- 5seconds
     WAIT_OFF =>  X"2540BE40"
        );


--        Reg2SeqData : in Reg2SeqDataPS_type;  -- enable alarm compare, dout
--        Seq2ComData : in Seq2ComDataPS_type;  -- reb on , din (Ps on)


     type Reg2SeqDataPS_type is record
        EnableAlarm : sl;
        dout : slv(1 downto 0);
     end record;

     type Seq2ComDataPS_type is record
        REB_on : sl;
        din : sl;
     end record;

     constant REG2DATAPS_INIT : Reg2SeqDataPS_type := (
     EnableAlarm => '0',
     dout => "00"
        );

     constant SEQ2COMP_INIT : Seq2ComDataPS_type := (
        REB_on => '0',
        din => '0'
           );


--     type Reg2SeqData_type is record
--        EnableAlarm       : slv(5 downto 0);
--        dout              : slv(127 downto 0);
--        REB_on_off            : slv(5 downto 0);
--        REB_config_done   : slv(5 downto 0);
--        AqquireStartP     : slv(5 downto 0);
--     end record;

--     constant REG2SEQDATA_C : Reg2SeqData_type := (
--        EnableAlarm     => (Others => '0'),
--        dout            => (Others => '0'),
--        REb_on_off      => (Others => '0'),
--        REB_config_done => (Others => '0'),
--        AqquireStartP   => (Others => '0')
--           );

     -- type Reg2SeqData_type is record
        -- EnableAlarm       : sl;
        -- dout              : slv(20 downto 0);
        -- REB_on_off        : sl;
        -- REB_config_done   : sl;
        -- AquireStartP      : sl;
        -- Enable_in         : sl;
     -- end record;

     -- constant REG2SEQDATA_C : Reg2SeqData_type := (
        -- EnableAlarm     => '0',
        -- dout            => (Others => '0'),
        -- REb_on_off      => '0',
        -- REB_config_done => '0',
        -- AquireStartP   => '0',
        -- Enable_in   => '0'
           -- );


   -- type Reg2SeqDataAll_type is array (natural range <>) of Reg2SeqData_type;


      -- type  reportFaultPS_type is record
              -- ErrDet            : sl;
              -- powerValuesArOut  : Slv12Array(0 to 7);
              -- dout              : slv(1 downto 0);
           -- end record;

           -- constant REPORTFAULTPS_C : reportFaultPS_type := (
              -- ErrDet              => '0',
              -- powerValuesArOut   => ((Others => '0'),(Others => '0'),(Others => '0'),(Others => '0'),(Others => '0'),(Others => '0'),(Others => '0'),(Others => '0')),
              -- dout               => (Others => '0')
                 -- );
     -- type reportFaultArr_type is array (6 downto 0) of reportFaultPS_type;
     -- constant REPORTFAULTARR_C : reportFaultArr_type := (REPORTFAULTPS_C,REPORTFAULTPS_C,REPORTFAULTPS_C,REPORTFAULTPS_C,
                                                        -- REPORTFAULTPS_C,REPORTFAULTPS_C,REPORTFAULTPS_C);

      -- type Seq2RegData_type is record
              -- REB_on            : sl;
              -- din               : slv(6 downto 0);
              -- period            : slv(31 downto 0);
              -- SeqState          : slv(7 downto 0);
              -- FailedState       : slv(7 downto 0);
              -- FailedStatus      : slv(6 downto 0);
              -- FailedTO          : sl;
              -- reportFaultArr    : reportFaultArr_type;
         -- end record;


           -- constant SEQ2REGDATA_C : Seq2RegData_type := (
              -- REb_on          => '0',
              -- din             => (Others => '0'),
              -- period          =>  X"09502F90", -- 5sec /4
              -- SeqState        => (Others => '0'),
              -- FailedState     => (Others => '0'),
              -- FailedStatus    => (Others => '0'),
              -- FailedTO        => '0',
              -- reportFaultArr  => REPORTFAULTARR_C
                 -- );

        -- type Seq2RegDataAll_type is array (natural range <>) of Seq2RegData_type;




end UserPkg;

package body UserPkg is

end package body UserPkg;

