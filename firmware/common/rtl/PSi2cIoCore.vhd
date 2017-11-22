-------------------------------------------------------------------------------
-- Title      :
-------------------------------------------------------------------------------
-- File       : PSi2cIoCore.vhd
-- Author     : Leonid Sapozhnikov  <leosap@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-17
-- Last update: 2015-03-17
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Base on Ben HybridIoCore
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
use work.I2cPkg.all;
use work.SsiPkg.all;
use work.UserPkg.all;
use work.ThresholdPkg.all;

entity PSi2cIoCore is

   generic (
      TPD_G           : time             := 1 ns;
      SIMULATION_G    : boolean          := false;
      REB_number      : slv(3 downto 0)  := "0000";
      AXI_BASE_ADDR_G : slv(31 downto 0) := X"00002000");

   port (
      axiClk : in sl;
      axiRst : in sl;

      REB_on : in sl;
	  selectCR : in sl := '0';
	  unlockFilt : in sl := '1';
--      Aq_period : slv(31 downto 0) := X"09502F90";
      -- Slave interface
      axiReadMaster  : in  AxiLiteReadMasterType;
      axiReadSlave   : out AxiLiteReadSlaveType;
      axiWriteMaster : in  AxiLiteWriteMasterType;
      axiWriteSlave  : out AxiLiteWriteSlaveType;

      -- External Hybrid I2C Interface
      psI2cIn  : in  i2c_in_array(6 downto 0);
      psI2cOut : out i2c_out_array(6 downto 0);
	  InitDone : out sl;
      InitFail : out sl
	  );
end entity PSi2cIoCore;

architecture rtl of PSi2cIoCore is
   attribute keep_hierarchy        : string;
   attribute keep_hierarchy of rtl : architecture is "yes";

   -------------------------------------------------------------------------------------------------
   -- Axi Crossbar Constants and signals
   -- Serves 1 REB with 7 PS. each bus has own i2c bus
   -------------------------------------------------------------------------------------------------
   constant AXI_PS0_I2C_INDEX_C  : natural := 0;
   constant AXI_PS1_I2C_INDEX_C  : natural := 1;
   constant AXI_PS2_I2C_INDEX_C  : natural := 2;
   constant AXI_PS3_I2C_INDEX_C  : natural := 3;
   constant AXI_PS4_I2C_INDEX_C  : natural := 4;
   constant AXI_PS5_I2C_INDEX_C  : natural := 5;
   constant AXI_PS6_I2C_INDEX_C  : natural := 6;
   constant AXI_PS_READOUT_INDEX_C : natural := 7;

   constant AXI_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray := (
      AXI_PS0_I2C_INDEX_C => (                           -- Adc Readout Config
         baseAddr             => AXI_BASE_ADDR_G + X"0000",  -- to X"00FF"
         addrBits             => 13,
         connectivity         => X"0001"),
      AXI_PS1_I2C_INDEX_C  => (                           -- Adc Config
         baseAddr             => AXI_BASE_ADDR_G + X"4000",  -- to X"07FF"
         addrBits             => 13,
         connectivity         => X"0001"),
      AXI_PS2_I2C_INDEX_C  => (                           -- Adc Config
         baseAddr             => AXI_BASE_ADDR_G + X"8000",  -- to X"07FF"
         addrBits             => 13,
         connectivity         => X"0001"),
      AXI_PS3_I2C_INDEX_C  => (                           -- Adc Config
         baseAddr             => AXI_BASE_ADDR_G + X"C000",  -- to X"07FF"
         addrBits             => 13,
         connectivity         => X"0001"),
      AXI_PS4_I2C_INDEX_C  => (                           -- Adc Config
         baseAddr             => AXI_BASE_ADDR_G + X"10000",  -- to X"07FF"
         addrBits             => 13,
         connectivity         => X"0001"),
      AXI_PS5_I2C_INDEX_C  => (                           -- Adc Config
         baseAddr             => AXI_BASE_ADDR_G + X"14000",  -- to X"07FF"
         addrBits             => 14,
         connectivity         => X"0001"),
      AXI_PS6_I2C_INDEX_C  => (                           -- Adc Config
         baseAddr             => AXI_BASE_ADDR_G + X"18000",  -- to X"07FF"
         addrBits             => 13,
         connectivity         => X"0001"),
      AXI_PS_READOUT_INDEX_C  => (                           -- Adc Config
         baseAddr             => AXI_BASE_ADDR_G + X"1C000",  -- to X"07FF"
         addrBits             => 14,
         connectivity         => X"0001"));

	constant PS_FULL_ADDR_FILT_ARRAY_C : PsWrFiltAddrArray(NUM_MAX_PS_C-1 downto 0) := (
                           6 => (0 => (AXI_MASTERS_CONFIG_C(6).baseAddr + PS_ADDR_FILT_ARRAY_C(6)(0))),
                           5 => (0 => (AXI_MASTERS_CONFIG_C(5).baseAddr + PS_ADDR_FILT_ARRAY_C(5)(0))),
	                       4 => (0 => (AXI_MASTERS_CONFIG_C(4).baseAddr + PS_ADDR_FILT_ARRAY_C(4)(0))), -- unused address
						   3 => (0 => (AXI_MASTERS_CONFIG_C(3).baseAddr + PS_ADDR_FILT_ARRAY_C(3)(0))), -- unused address
						   2 => (0 => (AXI_MASTERS_CONFIG_C(2).baseAddr + PS_ADDR_FILT_ARRAY_C(2)(0))), -- unused address
						   1 => (0 => (AXI_MASTERS_CONFIG_C(1).baseAddr + PS_ADDR_FILT_ARRAY_C(1)(0))), -- unused address
						   0 => (0 => (AXI_MASTERS_CONFIG_C(0).baseAddr + PS_ADDR_FILT_ARRAY_C(0)(0))));
						   
   signal mAxiWriteMasters : AxiLiteWriteMasterArray(7 downto 0);
   signal mAxiWriteSlaves  : AxiLiteWriteSlaveArray(7 downto 0);
   signal mAxiReadMasters  : AxiLiteReadMasterArray(7 downto 0);
   signal mAxiReadSlaves   : AxiLiteReadSlaveArray(7 downto 0);
   signal mAxiWSeqMasters : AxiLiteWriteMasterArray(6 downto 0);
   signal mAxiWSeqSlaves  : AxiLiteWriteSlaveArray(6 downto 0);
   signal mAxiRSeqMasters  : AxiLiteReadMasterArray(6 downto 0);
   signal mAxiRSeqSlaves   : AxiLiteReadSlaveArray(6 downto 0);
   signal fAxiWriteMasters : AxiLiteWriteMasterArray(7 downto 0);
   signal fAxiWriteSlaves  : AxiLiteWriteSlaveArray(7 downto 0);
   signal fAxiReadMasters  : AxiLiteReadMasterArray(7 downto 0);
   signal fAxiReadSlaves   : AxiLiteReadSlaveArray(7 downto 0);
   
--   signal mAxilWriteMasters  : AxiLiteWriteMasterArray(6 downto 0);
--   signal mAxilWriteSlaves   : AxiLiteWriteSlaveArray(6 downto 0);  


   -------------------------------------------------------------------------------------------------
   -- Reg Master I2C Bridge Constants and signals
   -------------------------------------------------------------------------------------------------
   constant AXI_I2C_BRIDGE_PS013_CONFIG_C : I2cAxiLiteDevArray := (
      0           =>                    -- LTC2945
      (i2cAddress => "0001101010",
       i2cTenbit  => '0',
       dataSize   => 8,
       addrSize   => 8,
       endianness => '0',
       repeatStart => '1'),
      1           =>                    -- MAX11644
      (i2cAddress => "0000110110",
       i2cTenbit  => '0',
       dataSize   => 32,
       addrSize   => 0,
       endianness => '1',
       repeatStart => '0'));

   constant AXI_I2C_BRIDGE_PS24_CONFIG_C : I2cAxiLiteDevArray := (
      0           =>                    -- LTC2945
      (i2cAddress => "0001101010",
       i2cTenbit  => '0',
       dataSize   => 8,
       addrSize   => 8,
       endianness => '0',
       repeatStart => '1'),
      1           =>                    -- LTC2945
      (i2cAddress => "0001101011",
       i2cTenbit  => '0',
       dataSize   => 8,
       addrSize   => 8,
       endianness => '0',
      repeatStart => '1'));

   constant AXI_I2C_BRIDGE_PS5_CONFIG_C : I2cAxiLiteDevArray := (
      0           =>                    -- LTC2945
      (i2cAddress => "0001101010",
       i2cTenbit  => '0',
       dataSize   => 8,
       addrSize   => 8,
       endianness => '0',
       repeatStart => '1'),
      1           =>                    -- MAX11644
      (i2cAddress => "0000110110",
       i2cTenbit  => '0',
       dataSize   => 32,
       addrSize   => 0,
       endianness => '1',
       repeatStart => '0'),
      2           =>                    -- MAX5805
      (i2cAddress => "0000011000",
       i2cTenbit  => '0',
       dataSize   => 16,
       addrSize   => 8,
       endianness => '1',
       repeatStart => '1'));

   constant AXI_I2C_BRIDGE_PS6_CONFIG_C : I2cAxiLiteDevArray := (
      0           =>                    -- LTC2945
      (i2cAddress => "0001101011",
       i2cTenbit  => '0',
       dataSize   => 8,  -- only for test, really need to be 8
       addrSize   => 8,
       endianness => '0',
       repeatStart => '1'),
      1           =>                    -- MAX5805
      (i2cAddress => "0000011000",
       i2cTenbit  => '0',
       dataSize   => 16,
       addrSize   => 8,
       endianness => '1',
       repeatStart => '1'));

   signal i2cRegMastersIn  : I2cRegMasterInArray(6 downto 0);
   signal i2cRegMastersOut : I2cRegMasterOutArray(6 downto 0);
   signal i2cSeqMastersIn  : I2cRegMasterInArray(6 downto 0);
   signal i2cSeqMastersOut : I2cRegMasterOutArray(6 downto 0);
   signal i2c_lock_seq     : sl;
   signal numbPs           : slv(7 downto 0);


    attribute dont_touch                 : string;
    attribute dont_touch of  axiWriteMaster   : signal is "true";
    attribute dont_touch of  axiWriteSlave   : signal is "true";
    attribute dont_touch of  axiReadMaster   : signal is "true";
    attribute dont_touch of  axiReadSlave   : signal is "true";

begin

   -------------------------------------------------------------------------------------------------
   -- Crossbar connecting all internal components
   -------------------------------------------------------------------------------------------------
   PsAxiCrossbar : entity work.AxiLiteCrossbar
      generic map (
         TPD_G              => TPD_G,
         NUM_SLAVE_SLOTS_G  => 1,
         NUM_MASTER_SLOTS_G => 8,
         MASTERS_CONFIG_G   => AXI_MASTERS_CONFIG_C)
      port map (
         axiClk              => axiClk,
         axiClkRst           => axiRst,
         sAxiWriteMasters(0) => axiWriteMaster,
         sAxiWriteSlaves(0)  => axiWriteSlave,
         sAxiReadMasters(0)  => axiReadMaster,
         sAxiReadSlaves(0)   => axiReadSlave,
         mAxiWriteMasters    => fAxiWriteMasters,
         mAxiWriteSlaves     => fAxiWriteSlaves,
         mAxiReadMasters     => mAxiReadMasters,
         mAxiReadSlaves      => mAxiReadSlaves);

  PS_filt_intf: for i in  6 downto 0 generate
   PsAxiBusFilt : entity work.AxiLiteWriteFilter
      generic map (
         TPD_G              => TPD_G,
         FILTER_SIZE_G      => 1,
         FILTER_ADDR_G      => PS_FULL_ADDR_FILT_ARRAY_C(i),
         AXI_ERROR_RESP_G   => AXI_RESP_DECERR_C)
      port map (
         axilClk             => axiClk,
         axilRst             => axiRst,
		 enFilter            => unlockFilt,
		 blockAll            => BLOCK_FILT_C(i),
         sAxilWriteMaster    => fAxiWriteMasters(i),
         sAxilWriteSlave     => fAxiWriteSlaves(i),
         mAxilWriteMaster    => mAxiWriteMasters(i),
         mAxilWriteSlave     => mAxiWriteSlaves(i));
    end generate PS_filt_intf;

   ----------------------------------------------------------------------------------------------
   -- I2C Interface to hybrid is shared between 2 AXI Slaves
   -- First is for APV config and (on old hybrids) temp ADC
   -- Second is for new hybrids with ADS1115 ADC for temp and far end voltage monitoring
   ----------------------------------------------------------------------------------------------
   -- PS interfaces
   I2cRegMasterAxiBridge_0 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS013_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiReadMasters(AXI_PS0_I2C_INDEX_C),
         axiReadSlave    => mAxiReadSlaves(AXI_PS0_I2C_INDEX_C),
         axiWriteMaster  => mAxiWriteMasters(AXI_PS0_I2C_INDEX_C),
         axiWriteSlave   => mAxiWriteSlaves(AXI_PS0_I2C_INDEX_C),
         i2cRegMasterIn  => i2cRegMastersIn(0),
         i2cRegMasterOut => i2cRegMastersOut(0));

   I2cRegMasterAxiBridge_1 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS013_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiReadMasters(AXI_PS1_I2C_INDEX_C),
         axiReadSlave    => mAxiReadSlaves(AXI_PS1_I2C_INDEX_C),
         axiWriteMaster  => mAxiWriteMasters(AXI_PS1_I2C_INDEX_C),
         axiWriteSlave   => mAxiWriteSlaves(AXI_PS1_I2C_INDEX_C),
         i2cRegMasterIn  => i2cRegMastersIn(1),
         i2cRegMasterOut => i2cRegMastersOut(1));

   I2cRegMasterAxiBridge_2 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS24_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiReadMasters(AXI_PS2_I2C_INDEX_C),
         axiReadSlave    => mAxiReadSlaves(AXI_PS2_I2C_INDEX_C),
         axiWriteMaster  => mAxiWriteMasters(AXI_PS2_I2C_INDEX_C),
         axiWriteSlave   => mAxiWriteSlaves(AXI_PS2_I2C_INDEX_C),
         i2cRegMasterIn  => i2cRegMastersIn(2),
         i2cRegMasterOut => i2cRegMastersOut(2));

   I2cRegMasterAxiBridge_3 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS013_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiReadMasters(AXI_PS3_I2C_INDEX_C),
         axiReadSlave    => mAxiReadSlaves(AXI_PS3_I2C_INDEX_C),
         axiWriteMaster  => mAxiWriteMasters(AXI_PS3_I2C_INDEX_C),
         axiWriteSlave   => mAxiWriteSlaves(AXI_PS3_I2C_INDEX_C),
         i2cRegMasterIn  => i2cRegMastersIn(3),
         i2cRegMasterOut => i2cRegMastersOut(3));

   I2cRegMasterAxiBridge_4 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS24_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiReadMasters(AXI_PS4_I2C_INDEX_C),
         axiReadSlave    => mAxiReadSlaves(AXI_PS4_I2C_INDEX_C),
         axiWriteMaster  => mAxiWriteMasters(AXI_PS4_I2C_INDEX_C),
         axiWriteSlave   => mAxiWriteSlaves(AXI_PS4_I2C_INDEX_C),
         i2cRegMasterIn  => i2cRegMastersIn(4),
         i2cRegMasterOut => i2cRegMastersOut(4));

   I2cRegMasterAxiBridge_5 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS5_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiReadMasters(AXI_PS5_I2C_INDEX_C),
         axiReadSlave    => mAxiReadSlaves(AXI_PS5_I2C_INDEX_C),
         axiWriteMaster  => mAxiWriteMasters(AXI_PS5_I2C_INDEX_C),
         axiWriteSlave   => mAxiWriteSlaves(AXI_PS5_I2C_INDEX_C),
         i2cRegMasterIn  => i2cRegMastersIn(5),
         i2cRegMasterOut => i2cRegMastersOut(5));

   I2cRegMasterAxiBridge_6 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS6_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiReadMasters(AXI_PS6_I2C_INDEX_C),
         axiReadSlave    => mAxiReadSlaves(AXI_PS6_I2C_INDEX_C),
         axiWriteMaster  => mAxiWriteMasters(AXI_PS6_I2C_INDEX_C),
         axiWriteSlave   => mAxiWriteSlaves(AXI_PS6_I2C_INDEX_C),
         i2cRegMasterIn  => i2cRegMastersIn(6),
         i2cRegMasterOut => i2cRegMastersOut(6));

-- -- Sequencer
   U_PowerMonitorSeqPS7 : entity work.PowerMonitorSeqPS7
      generic map (
         TPD_G               => TPD_G,
         SIMULATION_G        => SIMULATION_G,
         REB_number          => REB_number,
		 FILT_ADDR0           => PS_FULL_ADDR_FILT_ARRAY_C(5)(0),
		 FILT_ADDR1           => PS_FULL_ADDR_FILT_ARRAY_C(6)(0))
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
		 
         REB_on          => REB_on,
         selectCR        => selectCR,

         sAxiReadMaster  => mAxiReadMasters(AXI_PS_READOUT_INDEX_C),
         sAxiReadSlave   => mAxiReadSlaves(AXI_PS_READOUT_INDEX_C),
         sAxiWriteMaster => mAxiWriteMasters(AXI_PS_READOUT_INDEX_C),
         sAxiWriteSlave  => mAxiWriteSlaves(AXI_PS_READOUT_INDEX_C),
         mAxiReadMasters => mAxiRSeqMasters,
         mAxiReadSlaves  => mAxiRSeqSlaves,
		 mAxilWriteMasters => mAxiWSeqMasters,
         mAxilWriteSlaves  => mAxiWSeqSlaves,

		 numbPs          => numbPs,
         InitDone        => InitDone,
         InitFail        => InitFail,
         i2c_lock_seq    => i2c_lock_seq
         );

   ------------------------------------------------------------------------------
   -- Unused AXI-Lite buses must be terminated to prevent hanging the bus forever
   ------------------------------------------------------------------------------
   -- U_AxiLiteEmpty : entity work.AxiLiteEmpty
      -- generic map (
         -- TPD_G => TPD_G)
      -- port map (
         -- axiClk         => axiClk,
         -- axiClkRst      => axiRst,
         -- axiReadMaster  => mAxiReadMasters(AXI_PS_READOUT_INDEX_C),
         -- axiReadSlave   => mAxiReadSlaves(AXI_PS_READOUT_INDEX_C),
         -- axiWriteMaster => mAxiWriteMasters(AXI_PS_READOUT_INDEX_C),
         -- axiWriteSlave  => mAxiWriteSlaves(AXI_PS_READOUT_INDEX_C));         

   -- Init_mAxiWSeqMasters: for i in 6 downto 0 generate
      -- mAxiWSeqMasters(i) <= AXI_LITE_WRITE_MASTER_INIT_C;
   -- end generate Init_mAxiWSeqMasters;
   
   I2cSeqMasterAxiBridge : entity work.I2cRegMasterAxiBridge
	  generic map (
		 TPD_G               => TPD_G,
		 DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS013_CONFIG_C)
	  port map (
		 axiClk          => axiClk,
		 axiRst          => axiRst,
		 axiReadMaster   => mAxiRSeqMasters(AXI_PS0_I2C_INDEX_C),
		 axiReadSlave    => mAxiRSeqSlaves(AXI_PS0_I2C_INDEX_C),
		 axiWriteMaster  => mAxiWSeqMasters(AXI_PS0_I2C_INDEX_C),
		 axiWriteSlave   => mAxiWSeqSlaves(AXI_PS0_I2C_INDEX_C),
		 i2cRegMasterIn  => i2cSeqMastersIn(0),
		 i2cRegMasterOut => i2cSeqMastersOut(0));
	
   I2cSeqMasterAxiBridge_1 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS013_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiRSeqMasters(AXI_PS1_I2C_INDEX_C),
         axiReadSlave    => mAxiRSeqSlaves(AXI_PS1_I2C_INDEX_C),
         axiWriteMaster  => mAxiWSeqMasters(AXI_PS1_I2C_INDEX_C),
         axiWriteSlave   => mAxiWSeqSlaves(AXI_PS1_I2C_INDEX_C),
         i2cRegMasterIn  => i2cSeqMastersIn(1),
         i2cRegMasterOut => i2cSeqMastersOut(1));

   I2cSeqMasterAxiBridge_2 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS24_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiRSeqMasters(AXI_PS2_I2C_INDEX_C),
         axiReadSlave    => mAxiRSeqSlaves(AXI_PS2_I2C_INDEX_C),
         axiWriteMaster  => mAxiWSeqMasters(AXI_PS2_I2C_INDEX_C),
         axiWriteSlave   => mAxiWSeqSlaves(AXI_PS2_I2C_INDEX_C),
         i2cRegMasterIn  => i2cSeqMastersIn(2),
         i2cRegMasterOut => i2cSeqMastersOut(2));

   I2cSeqMasterAxiBridge_3 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS013_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiRSeqMasters(AXI_PS3_I2C_INDEX_C),
         axiReadSlave    => mAxiRSeqSlaves(AXI_PS3_I2C_INDEX_C),
         axiWriteMaster  => mAxiWSeqMasters(AXI_PS3_I2C_INDEX_C),
         axiWriteSlave   => mAxiWSeqSlaves(AXI_PS3_I2C_INDEX_C),
         i2cRegMasterIn  => i2cSeqMastersIn(3),
         i2cRegMasterOut => i2cSeqMastersOut(3));

   I2cSeqMasterAxiBridge_4 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS24_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiRSeqMasters(AXI_PS4_I2C_INDEX_C),
         axiReadSlave    => mAxiRSeqSlaves(AXI_PS4_I2C_INDEX_C),
         axiWriteMaster  => mAxiWSeqMasters(AXI_PS4_I2C_INDEX_C),
         axiWriteSlave   => mAxiWSeqSlaves(AXI_PS4_I2C_INDEX_C),
         i2cRegMasterIn  => i2cSeqMastersIn(4),
         i2cRegMasterOut => i2cSeqMastersOut(4));

   I2cSeqMasterAxiBridge_5 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS5_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiRSeqMasters(AXI_PS5_I2C_INDEX_C),
         axiReadSlave    => mAxiRSeqSlaves(AXI_PS5_I2C_INDEX_C),
         axiWriteMaster  => mAxiWSeqMasters(AXI_PS5_I2C_INDEX_C),
         axiWriteSlave   => mAxiWSeqSlaves(AXI_PS5_I2C_INDEX_C),
         i2cRegMasterIn  => i2cSeqMastersIn(5),
         i2cRegMasterOut => i2cSeqMastersOut(5));

   I2cSeqMasterAxiBridge_6 : entity work.I2cRegMasterAxiBridge
      generic map (
         TPD_G               => TPD_G,
         DEVICE_MAP_G        => AXI_I2C_BRIDGE_PS6_CONFIG_C)
      port map (
         axiClk          => axiClk,
         axiRst          => axiRst,
         axiReadMaster   => mAxiRSeqMasters(AXI_PS6_I2C_INDEX_C),
         axiReadSlave    => mAxiRSeqSlaves(AXI_PS6_I2C_INDEX_C),
         axiWriteMaster  => mAxiWSeqMasters(AXI_PS6_I2C_INDEX_C),
         axiWriteSlave   => mAxiWSeqSlaves(AXI_PS6_I2C_INDEX_C),
         i2cRegMasterIn  => i2cSeqMastersIn(6),
         i2cRegMasterOut => i2cSeqMastersOut(6));

   -- Multiplexes 2 I2cRegMasterAxiBridges onto on I2cRegMaster
   -- And generate 7 interfaces 1 per PS
   PS_i2c_intf: for i in 0 to 6 generate

--   i2cSeqMastersIn(i) <= I2C_REG_MASTER_IN_INIT_C;
--   mAxiWSeqMasters <= AXI_LITE_WRITE_MASTER_INIT_C;

  I2cRegMasterAndMux_1 : entity work.I2cRegMasterAndMux
      generic map (
         TPD_G        => TPD_G,
         SIMULATION_G => SIMULATION_G,
         OUTPUT_EN_POLARITY_G => 0,
         FILTER_G             => 8,
         PRESCALE_G           => 499, --249,
         NUM_INPUTS_C => 2)
      port map (
         clk       => axiClk,
         srst      => axiRst,
         lockReq(0)   => '0',
         lockReq(1)   => i2c_lock_seq,
         regIn(0)     => i2cRegMastersIn(i),
         regIn(1)     => i2cSeqMastersIn(i),
         regOut(0)    => i2cRegMastersOut(i),
         regOut(1)    => i2cSeqMastersOut(i),
         i2ci   => psI2cIn(i),
         i2co   => psI2cOut(i));
   
      -- I2cRegMaster_1 : entity work.I2cRegMaster
      -- generic map (
         -- TPD_G        => TPD_G,
         -- OUTPUT_EN_POLARITY_G => 0,
         -- FILTER_G             => 8,
         -- PRESCALE_G           => 499 --249
		 -- )
      -- port map (
         -- clk       => axiClk,
         -- srst      => axiRst,
         -- regIn     => i2cRegMastersIn(i),
         -- regOut    => i2cRegMastersOut(i),
         -- i2ci   => psI2cIn(i),
         -- i2co   => psI2cOut(i));
  end generate PS_i2c_intf;
   

end architecture rtl;










