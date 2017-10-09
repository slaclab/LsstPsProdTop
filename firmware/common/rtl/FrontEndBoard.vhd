-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      FrontEndBoard.vhd -
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Leonid Sapozhnikov
--      Created on: 4/20/2017 2:04:46 PM
--      Last change: LS 10/09/2017 12:23:02 PM
--
-------------------------------------------------------------------------------
-- File       : FrontEndBoardvhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-02-04
-- Last update: 2017-08-02
-------------------------------------------------------------------------------
-- Description: Firmware Target's Top Level
-- 
-- Note: Common-to-Application interface defined in HPS ESD: LCLSII-2.7-ES-0536
-- 
-------------------------------------------------------------------------------
-- This file is part of 'firmware-template'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'firmware-template', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

entity FrontEndBoard is
  generic (
    TPD_G            : time            := 1 ns;
    AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C;
    CLK_PERIOD_G     : real            := 6.4E-9  -- 156Mhz
    );
  port (

-- Slave AXI-Lite Interface
    axilClk        : in  sl;
    axilRst        : in  sl;
    axiReadMaster  : in  AxiLiteReadMasterType;
    axiReadSlave   : out AxiLiteReadSlaveType;
    axiWriteMaster : in  AxiLiteWriteMasterType;
    axiWriteSlave  : out AxiLiteWriteSlaveType;

-- Controller IO
-- Ion Pump Control Board ADC SPI Interfaces
    iMonDin : in  sl;                   -- Serial in from Current Mon ADC
    vMonDin : in  sl;                   -- Serial in from Voltage Mon ADC
    pMonDin : in  sl;                   -- Serial in from Power Mon ADC
    adcSClk : out sl;                   -- Clock for Monitor ADCs

-- Ion Pump Control Board ADC SPI Interfaces
    dacDout  : out sl;                  -- Serial out for Setpoint DACs
    dacSclk  : out sl;                  -- Clock for the Setpoint DACs
    iProgCsL : out sl;                  -- Chip Enable for Current DAC
    vProgCsL : out sl;                  -- Chip Enable for Voltage DAC
    pProgCsL : out sl;                  -- Chip Enable for Power DAC

-- Ion Pump Control Board Mode bits
    iMode : in sl;                      -- HVPS in Current Limit Mode
    vMode : in sl;                      -- HVPS in Voltage Limit Mode
    pMode : in sl;                      -- HVPS in Power Limit Mode

-- Ion Pump Enable
    enable : out sl                     -- Enable HVPS
    );
end entity FrontEndBoard;

architecture Behavioral of FrontEndBoard is

  signal readMaster  : AxiLiteReadMasterType;
  signal readSlave   : AxiLiteReadSlaveType;
  signal writeMaster : AxiLiteWriteMasterType;
  signal writeSlave  : AxiLiteWriteSlaveType;
  signal axiRstL     : sl;
  signal idacSclk    : slv(2 downto 0);
  signal idacDout    : slv(2 downto 0);
  signal iCsb        : slv(2 downto 0);
  signal adcIn       : slv(2 downto 0);

  -------------------------------------------------------------------------------------------------
  -- AXI Lite Config and Signals
  -------------------------------------------------------------------------------------------------

  constant NUM_AXI_MASTERS_C : natural := 7;
  constant REG_INDEX_C       : natural := 0;

  constant DAC_INDEX_C : natural := 1;
  constant ADC_INDEX_C : natural := DAC_INDEX_C + 3;

  constant AXI_CROSSBAR_MASTERS_CONFIG_C : AxiLiteCrossbarMasterConfigArray(NUM_AXI_MASTERS_C-1 downto 0) := (
    REG_INDEX_C    => (
      baseAddr     => X"0000_0000",
      addrBits     => 4,
      connectivity => X"0001"),
    DAC_INDEX_C+0  => (
      baseAddr     => x"0000_0001",
      addrBits     => 4,
      connectivity => X"0001"),
    DAC_INDEX_C+1  => (
      baseAddr     => x"0000_0002",
      addrBits     => 4,
      connectivity => X"0001"),
    DAC_INDEX_C+2  => (
      baseAddr     => x"0000_0003",
      addrBits     => 4,
      connectivity => X"0001"),
    ADC_INDEX_C+0  => (
      baseAddr     => x"0000_0004",
      addrBits     => 4,
      connectivity => X"0001"),
    ADC_INDEX_C+1  => (
      baseAddr     => x"0000_0005",
      addrBits     => 4,
      connectivity => X"0001"),
    ADC_INDEX_C+2  => (
      baseAddr     => x"0000_0006",
      addrBits     => 4,
      connectivity => X"0001")
    );

  signal locAxilWriteMasters : AxiLiteWriteMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilWriteSlaves  : AxiLiteWriteSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilReadMasters  : AxiLiteReadMasterArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal locAxilReadSlaves   : AxiLiteReadSlaveArray(NUM_AXI_MASTERS_C-1 downto 0);
  signal iadcSclk            : slv(2 downto 0);

begin

  iProgCsL <= iCsb(0);
  vProgCsL <= iCsb(1);
  pProgCsL <= iCsb(2);

  adcSclk <= iadcSclk(0);

  dacClkSel : process (idacSclk, idacDout, axiWriteMaster.awaddr)
  begin
    case axiWriteMaster.awaddr(2 downto 0) is
      when "001" =>
        dacSclk <= idacSclk(0);
        dacDout <= idacDout(0);
      when "010" =>
        dacSclk <= idacSclk(1);
        dacDout <= idacDout(1);
      when "011" =>
        dacSclk <= idacSclk(2);
        dacDout <= idacDout(2);
      when others =>
        dacSclk <= '0';
        dacDout <= '0';
    end case;
  end process;

  adcIn(0) <= iMonDin;
  adcIn(1) <= vMonDin;
  adcIn(2) <= pMonDin;

  adcClkSel : process (idacSclk, axiReadMaster.araddr)
  begin
    case axiReadMaster.araddr(2 downto 0) is
      when "100" =>
        dacSclk <= idacSclk(0);
      when "101" =>
        dacSclk <= idacSclk(1);
      when "110" =>
        dacSclk <= idacSclk(2);
      when others =>
        dacSclk <= '0';
    end case;
  end process;


  uFrontEndReg : entity work.FrontEndReg
    generic map (
      TPD_G            => 1 ns,
      AXI_ERROR_RESP_G => AXI_RESP_DECERR_C
      )
    port map (
      axilClk => axilClk,
      axilRst => axilRst,


      axilReadMaster  => locAxilReadMasters(REG_INDEX_C),
      axilReadSlave   => locAxilReadSlaves(REG_INDEX_C),
      axilWriteMaster => locAxilWriteMasters(REG_INDEX_C),
      axilWriteSlave  => locAxilWriteSlaves(REG_INDEX_C),

      iMode  => iMode,
      vMode  => vMode,
      pMode  => pMode,
      Enable => enable
      );


  genDacSpi : for I in 0 to 2 generate
    uDacSpi : entity work.AxiSpiMaster
      generic map (
        TPD_G             => 1 ns,
        AXI_ERROR_RESP_G  => AXI_RESP_DECERR_C,
        ADDRESS_SIZE_G    => 15,
        DATA_SIZE_G       => 8,
        MODE_G            => "WO",  -- Or "WO" (write only),  "RO" (read only)
        CPHA_G            => '0',
        CPOL_G            => '0',
        CLK_PERIOD_G      => 6.4E-9,    -- 156Mhz
        SPI_SCLK_PERIOD_G => 1.0E-6
        )
      port map (
        axiClk => axilClk,
        axiRst => axilRst,

        axiReadMaster  => locAxilReadMasters(DAC_INDEX_C+I),
        axiReadSlave   => locAxilReadSlaves(DAC_INDEX_C+I),
        axiWriteMaster => locAxilWriteMasters(DAC_INDEX_C+I),
        axiWriteSlave  => locAxilWriteSlaves(DAC_INDEX_C+I),

        coreSclk  => idacSclk(I),
        coreSDin  => '0',
        coreSDout => idacDout(I),
        coreCsb   => iCsb(I)
        );
  end generate;

  genADC : for I in 0 to 2 generate
    uADC : entity work.AxiMax11202Master
      generic map (
        TPD_G                => 1 ns,
        AXI_ERROR_RESP_G     => AXI_RESP_DECERR_C,
        CLK_PERIOD_G         => 6.4E-9,
        SERIAL_SCLK_PERIOD_G => 1.0E-6
        )
      port map (
        axiClk => axilClk,
        axiRst => axilRst,

        axiReadMaster  => locAxilReadMasters(ADC_INDEX_C+I),
        axiReadSlave   => locAxilReadSlaves(ADC_INDEX_C+I),
        axiWriteMaster => locAxilWriteMasters(ADC_INDEX_C+I),
        axiWriteSlave  => locAxilWriteSlaves(ADC_INDEX_C+I),

        coreSclk => iadcSClk(I),
        coreSDin => adcIn

        );
  end generate;


end Behavioral;


