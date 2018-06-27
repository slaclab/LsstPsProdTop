-------------------------------------------------------------------------------
-- Title         : LSST PS Threshold Package
-- File          : ThresholdPkg.vhd
-- Author        : Leonid Sapozhnikov, leosap@slac.stanford.edu
-- Created       : 10/16/2017
-------------------------------------------------------------------------------
-- Description:
-- Package file for LSST power supply board setting thresholds
-- Refer to LTC2945 datasheet and excel calulating value
-- http://cds.linear.com/docs/en/datasheet/2945fb.pdf
-------------------------------------------------------------------------------
-- Copyright (c) 2017 by Leonid Sapozhnikov. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 10/16/2017: created.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

package ThresholdPkg is


   constant UNLOCK_FILTERING  : slv(31 downto 0) := x"DE_AD_BE_EF";
   constant UNLOCK_PS_STAY_ON : slv(31 downto 0) := x"DE_AD_BE_EF";
   constant UNLOCK_MANUAL_PS_ON : slv(31 downto 0) := x"DE_AD_BE_EF";
   constant FAILMASK_START      : slv(19 downto 0) := x"F_DA_AA";
   
   constant TEMP_ENTRY_C      : natural := 3;
   constant TEMP_SET_C : Slv20Array(0 to TEMP_ENTRY_C-1) := (
                           (x"5_60_00"),
                           (x"E_37_00"),
	                       (x"F_3C_00"));

   constant TEMP_GET_C : Slv20Array(0 to TEMP_ENTRY_C-1) := (
                           (x"1_00_00"),
                           (x"A_00_00"),
	                       (x"B_00_00"));						   

   -- LTC 2945 entry record
   type Ltc2945Entry is record
      Address           : slv(31 downto 0);
      Data              : slv(31 downto 0);
   end record;
   
   type Ltc2945Config is array (natural range<>) of Ltc2945Entry;
   type Ltc2945Reb is array (natural range<>) of Ltc2945Config;
   
   constant NUM_SR_PS_C : natural := 7;
   constant NUM_CR_PS_C : natural := 7;
   constant NUM_CR_ADD_PS_C : natural := 2;
   constant NUM_MAX_PS_C : natural := 7;

   constant DIGITAL_ENTRY_C      : natural := 7;
   constant ANALOG_ENTRY_C       : natural := 7;
   constant OD_ENTRY_C           : natural := 7;
   constant CLK_HIGH_ENTRY_C     : natural := 7;
   constant CLK_LOW_ENTRY_C      : natural := 11;
   constant HEATER_ENTRY_C       : natural := 7;
   constant BIAS_ENTRY_C         : natural := 5;
   constant DPHI_ENTRY_C         : natural := 7;
   constant MAX_ENTRY_C          : natural := CLK_LOW_ENTRY_C;
   
--   constant PS_CONFIG_ADDRESS_C      : Slv32VectorArray((NUM_MAX_PS_C downto 0)(MAX_ENTRY_C downto 0))  := (Others => (Others => (Others => '0')));
--   constant PS_CONFIG_DATA_C      : Slv32VectorArray((NUM_MAX_PS_C do wnto 0)(MAX_ENTRY_C downto 0)) := (Others => (Others => (Others => '0')));
   
   type PsEntryArray is array (natural range<>) of natural;
   constant SR_PS_ENTRY_ARRAY_C : PsEntryArray(0 to NUM_MAX_PS_C-1) := (
             DIGITAL_ENTRY_C+1,
             ANALOG_ENTRY_C+1,
             OD_ENTRY_C,
             CLK_HIGH_ENTRY_C+1,
             CLK_LOW_ENTRY_C,
			 HEATER_ENTRY_C+1,
             BIAS_ENTRY_C+2);

   constant CR_PS_ENTRY_ARRAY_C : PsEntryArray(0 to NUM_MAX_PS_C-1) := (
             DIGITAL_ENTRY_C+1,
             ANALOG_ENTRY_C+1,
             OD_ENTRY_C,
             CLK_HIGH_ENTRY_C+1,
             CLK_LOW_ENTRY_C,
			 DPHI_ENTRY_C+3,
             BIAS_ENTRY_C+2);
			 
   constant CR_ADD_PS_ENTRY_ARRAY_C : PsEntryArray(0 to NUM_MAX_PS_C-1) := (
             HEATER_ENTRY_C+1,
             HEATER_ENTRY_C+1,
			 1,
			 1,
			 1,
			 1,
			 1);
			 
-- SR START   

   constant SR_DIGITAL_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_92"),
	                       (x"00_00_00_1B", x"00_00_00_A0"),
                           (x"00_00_00_2E", x"00_00_00_77"),
	                       (x"00_00_00_2F", x"00_00_00_20"),
	                       (x"00_00_00_30", x"00_00_00_58"),
	                       (x"00_00_00_31", x"00_00_00_00"),
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA
	                       (x"00_00_00_2F", x"00_00_00_20"), -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_58"),
	                       (x"00_00_00_31", x"00_00_00_00"));
	  
   constant SR_ANALOG_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_DB"),
	                       (x"00_00_00_1B", x"00_00_00_F0"),
                           (x"00_00_00_2E", x"00_00_00_A6"),
	                       (x"00_00_00_2F", x"00_00_00_50"),
	                       (x"00_00_00_30", x"00_00_00_7A"),
	                       (x"00_00_00_31", x"00_00_00_F0"),
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA   
	                       (x"00_00_00_2F", x"00_00_00_50"),  -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_7A"),
	                       (x"00_00_00_31", x"00_00_00_F0"));

   constant SR_OD_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_ED"),
	                       (x"00_00_00_1B", x"00_00_00_30"),
                           (x"00_00_00_2E", x"00_00_00_86"),
	                       (x"00_00_00_2F", x"00_00_00_B0"),
	                       (x"00_00_00_30", x"00_00_00_63"),
	                       (x"00_00_00_31", x"00_00_00_80"),
                           (x"00_00_00_2E", x"00_00_00_86"),   -- redundant to keep same size of arrays
	                       (x"00_00_00_2F", x"00_00_00_B0"),
	                       (x"00_00_00_30", x"00_00_00_63"),
	                       (x"00_00_00_31", x"00_00_00_80"));

   constant SR_CLKHIGH_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_EA"),   -- diviation due to tripping at max load at some channels
	                       (x"00_00_00_1B", x"00_00_00_00"),
                           (x"00_00_00_2E", x"00_00_00_A8"),
	                       (x"00_00_00_2F", x"00_00_00_60"),
	                       (x"00_00_00_30", x"00_00_00_7C"),
	                       (x"00_00_00_31", x"00_00_00_70"),
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA  
	                       (x"00_00_00_2F", x"00_00_00_60"), -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_7C"),
	                       (x"00_00_00_31", x"00_00_00_70"));

   constant SR_CLKLOW_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_2F"),
                           (x"00_00_00_1A", x"00_00_00_E0"),
	                       (x"00_00_00_1B", x"00_00_00_40"),
                           (x"00_00_00_2E", x"00_00_00_31"),   -- adjusted higher due to real board observations
	                       (x"00_00_00_2F", x"00_00_00_00"),
	                       (x"00_00_00_30", x"00_00_00_03"),
	                       (x"00_00_00_31", x"00_00_00_00"),
						   (x"00_00_00_24", x"00_00_00_2B"),
	                       (x"00_00_00_25", x"00_00_00_20"),
	                       (x"00_00_00_26", x"00_00_00_1C"),
	                       (x"00_00_00_27", x"00_00_00_B0"));
						   
   constant SR_HEATER_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_E0"),
	                       (x"00_00_00_1B", x"00_00_00_40"),
                           (x"00_00_00_2E", x"00_00_00_7F"),
	                       (x"00_00_00_2F", x"00_00_00_40"),
	                       (x"00_00_00_30", x"00_00_00_5E"),
	                       (x"00_00_00_31", x"00_00_00_00"),
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA   
	                       (x"00_00_00_2F", x"00_00_00_40"),  -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_5E"),
	                       (x"00_00_00_31", x"00_00_00_00"));
	  
   constant SR_BIAS_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_28"),
                           (x"00_00_00_1A", x"00_00_00_8F"),
	                       (x"00_00_00_1B", x"00_00_00_30"),
                           (x"00_00_00_24", x"00_00_00_C9"),
	                       (x"00_00_00_25", x"00_00_00_40"),
						   (x"00_00_01_26", x"00_00_00_30"),  -- set reference DAC
                           (x"00_00_01_a0", x"00_00_00_00"),  
	                       (x"00_00_00_2F", x"00_00_00_F0"),  -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_FF"),
	                       (x"00_00_00_31", x"00_00_00_F0"),
	                       (x"00_00_00_27", x"00_00_00_00"));
   
  
   constant SR_PS_THRESHOLD_C : Ltc2945Reb(0 to NUM_SR_PS_C-1):= (
             SR_DIGITAL_THRESHOLD_C,
             SR_ANALOG_THRESHOLD_C,
             SR_OD_THRESHOLD_C,
             SR_CLKHIGH_THRESHOLD_C,
             SR_CLKLOW_THRESHOLD_C,
			 SR_HEATER_THRESHOLD_C,
             SR_BIAS_THRESHOLD_C);

-- SR END



-- CR Start 

   constant CR_DIGITAL_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_92"),
	                       (x"00_00_00_1B", x"00_00_00_A0"),
                           (x"00_00_00_2E", x"00_00_00_77"),
	                       (x"00_00_00_2F", x"00_00_00_20"),
	                       (x"00_00_00_30", x"00_00_00_58"),
	                       (x"00_00_00_31", x"00_00_00_00"),
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA   
	                       (x"00_00_00_2F", x"00_00_00_20"),  -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_58"),
	                       (x"00_00_00_31", x"00_00_00_00"));  
	  
   constant CR_ANALOG_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_DB"),
	                       (x"00_00_00_1B", x"00_00_00_F0"),
                           (x"00_00_00_2E", x"00_00_00_A6"),
	                       (x"00_00_00_2F", x"00_00_00_50"),
	                       (x"00_00_00_30", x"00_00_00_7A"),
	                       (x"00_00_00_31", x"00_00_00_F0"),
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA   
	                       (x"00_00_00_2F", x"00_00_00_50"),  -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_7A"),
	                       (x"00_00_00_31", x"00_00_00_F0"));

   constant CR_OD_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_ED"),
	                       (x"00_00_00_1B", x"00_00_00_30"),
                           (x"00_00_00_2E", x"00_00_00_76"),
	                       (x"00_00_00_2F", x"00_00_00_40"),
	                       (x"00_00_00_30", x"00_00_00_57"),
	                       (x"00_00_00_31", x"00_00_00_60"),
                           (x"00_00_00_2E", x"00_00_00_76"),   -- redundant to keep same size of arrays
	                       (x"00_00_00_2F", x"00_00_00_40"),
	                       (x"00_00_00_30", x"00_00_00_57"),
	                       (x"00_00_00_31", x"00_00_00_60"));

   constant CR_CLKHIGH_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_5D"),
	                       (x"00_00_00_1B", x"00_00_00_70"),
                           (x"00_00_00_2E", x"00_00_00_85"),
	                       (x"00_00_00_2F", x"00_00_00_50"),
	                       (x"00_00_00_30", x"00_00_00_62"),
	                       (x"00_00_00_31", x"00_00_00_80"),
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA   
	                       (x"00_00_00_2F", x"00_00_00_50"),   -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_62"),
	                       (x"00_00_00_31", x"00_00_00_80"));

   constant CR_CLKLOW_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_2F"),
                           (x"00_00_00_1A", x"00_00_00_8C"),
	                       (x"00_00_00_1B", x"00_00_00_00"),
                           (x"00_00_00_2E", x"00_00_00_31"),
	                       (x"00_00_00_2F", x"00_00_00_00"),
	                       (x"00_00_00_30", x"00_00_00_03"),
	                       (x"00_00_00_31", x"00_00_00_00"),
						   (x"00_00_00_24", x"00_00_00_25"),
	                       (x"00_00_00_25", x"00_00_00_60"),
	                       (x"00_00_00_26", x"00_00_00_1A"),
						   (x"00_00_00_27", x"00_00_00_00"));

   constant CR_DPHI_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_BA"),
	                       (x"00_00_00_1B", x"00_00_00_E0"),
                           (x"00_00_00_2E", x"00_00_00_7F"),
	                       (x"00_00_00_2F", x"00_00_00_40"),
	                       (x"00_00_00_30", x"00_00_00_28"),
	                       (x"00_00_00_31", x"00_00_00_80"),
						   (x"00_00_02_26", x"00_00_00_30"),  -- set reference DAC
						   (x"00_00_02_a0", x"00_00_FF_F0"),  -- and zero it (min voltage -> max  scale)
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA   
	                       (x"00_00_00_31", x"00_00_00_80")); -- redundant to keep same size of arrays
  
   constant CR_BIAS_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_28"),
                           (x"00_00_00_1A", x"00_00_00_8F"),
	                       (x"00_00_00_1B", x"00_00_00_30"),
                           (x"00_00_00_24", x"00_00_00_C9"),
	                       (x"00_00_00_25", x"00_00_00_40"),
						   (x"00_00_01_26", x"00_00_00_30"),  -- set reference DAC
                           (x"00_00_01_a0", x"00_00_00_00"), 
	                       (x"00_00_00_2F", x"00_00_00_F0"),  -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_FF"),
	                       (x"00_00_00_31", x"00_00_00_F0"),
	                       (x"00_00_00_27", x"00_00_00_00"));

			 
   constant CR_PS_THRESHOLD_C : Ltc2945Reb(0 to NUM_CR_PS_C-1):= (
             CR_DIGITAL_THRESHOLD_C,
             CR_ANALOG_THRESHOLD_C,
             CR_OD_THRESHOLD_C,
             CR_CLKHIGH_THRESHOLD_C,
             CR_CLKLOW_THRESHOLD_C,
			 CR_DPHI_THRESHOLD_C,
             CR_BIAS_THRESHOLD_C);
			 
			 
   constant CR_HEATER_THRESHOLD_C : Ltc2945Config(0 to MAX_ENTRY_C-1) := (
                           (x"00_00_00_01", x"00_00_00_23"),
                           (x"00_00_00_1A", x"00_00_00_EE"),
	                       (x"00_00_00_1B", x"00_00_00_D0"),
                           (x"00_00_00_2E", x"00_00_00_FA"),
	                       (x"00_00_00_2F", x"00_00_00_20"),
	                       (x"00_00_00_30", x"00_00_00_B8"),
	                       (x"00_00_00_31", x"00_00_00_E0"),
                           (x"00_00_01_00", x"03_DA_DA_DA"), -- MAx ADC to 0x3DADADA   
	                       (x"00_00_00_2F", x"00_00_00_20"), -- redundant to keep same size of arrays
	                       (x"00_00_00_30", x"00_00_00_b8"),
	                       (x"00_00_00_31", x"00_00_00_E0"));			 

   constant CR_PS_ADD_THRESHOLD_C : Ltc2945Reb(0 to NUM_CR_ADD_PS_C-1):= (
             CR_HEATER_THRESHOLD_C,
             CR_HEATER_THRESHOLD_C);						   
-- CR end	


      type SeqCntlInType is record
         Ps_On      : sl;
      end record SeqCntlInType;

   constant SEC_CNTL_IN_C : SeqCntlInType := (
       Ps_On             => '0'
      );

       type SeqCntlOutType is record
         fail           : sl;
         initDone       : sl;
		 stV            : slv(63 downto 0);
      end record SeqCntlOutType;

   constant SEC_CNTL_OUT_C : SeqCntlOutType := (
       fail                  => '0',
       initDone              => '0',
	   stV                   => (Others => '0')
      );
	type SeqCntlOutTypeArray is array (natural range <>) of SeqCntlOutType;  
	
-- Filtering input data writes
   constant NUMB_WORD2FILT_C : PositiveArray(NUM_MAX_PS_C-1 downto 0) := (
                           6 => 1,
                           5 => 1,
	                       4 => 1,
						   3 => 1,
						   2 => 1,
						   1 => 1,
						   0 => 1);
						   
   constant BLOCK_FILT_C : slv(NUM_MAX_PS_C-1 downto 0) := "0011111";

   type PsWrFiltAddrArray is array (natural range<>) of Slv32Array(0 downto 0);						   
						   
   constant PS_ADDR_FILT_ARRAY_C : PsWrFiltAddrArray(NUM_MAX_PS_C-1 downto 0) := (
                           6 => (Others => x"00000680"),
                           5 => (Others => x"00000A80"),
	                       4 => (Others => x"00000C00"), -- unused address
						   3 => (Others => x"00000C00"), -- unused address
						   2 => (Others => x"00000C00"), -- unused address
						   1 => (Others => x"00000C00"), -- unused address
						   0 => (Others => x"00000C00")); -- unused address
						   			   

end ThresholdPkg;

package body ThresholdPkg is

end package body ThresholdPkg;

