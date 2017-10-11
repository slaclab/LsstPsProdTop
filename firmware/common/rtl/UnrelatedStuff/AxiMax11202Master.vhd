-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      AxiMax11202Master.vhd - 
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Leonid Sapozhnikov
--      Created on: 7/18/2017 9:35:50 AM
--      Last change: JO 8/3/2017 1:54:33 PM
--
-------------------------------------------------------------------------------
-- Title      : Axi lite interface for a Max11202 ADC
-------------------------------------------------------------------------------
-- File       : AxiMax11202Master.vhd
-- From           : AxiSpiMaster by
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
--            : Uros Legat Modified <ulegat@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-01-12
-- Last update: 2017-08-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- There are 5 modes of operation.
-- 0 -- Read and leave Dout at LSB, 24 Clock ticks.
--      A new conversion starts after the 24th Clock tick.
--      This mode does not seem very usefull
-- 1 -- Read and leave Dout High, 25 Clock ticks.
--      A new conversion start after 25th Clock tick.
-- 2 -- Read, leave Dout High, 26 Clock ticks
--      A calibration and new convert start after 26th clock.
-- 3 -- Read, leave Dout High and go to sleep, 23-1/2 Clock ticks.
--      Conversion starts when Clock goes low.
-- 4 -- Read, leave Dout High, Sleep, 25-1/2 Clock ticks.
--      Calibration and conversion start when the Clock goes low.
--
-- 7/18/17 jjo
-- I am going to start with only mode 2, free runing with calibration.
-- Rate is 208ms + update time ~5Hz
-- but leaving the hooks in to do the other modes
--
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

use work.StdRtlPkg.all;
use work.AxiLitePkg.all;

entity AxiMax11202Master is
  generic (
    TPD_G                : time            := 1 ns;
    AXI_ERROR_RESP_G     : slv(1 downto 0) := AXI_RESP_DECERR_C;
    CLK_PERIOD_G         : real            := 6.4E-9;
    SERIAL_SCLK_PERIOD_G : real            := 1.0E-6
    );
  port (
    axiClk : in sl;
    axiRst : in sl;

    axiReadMaster  : in  AxiLiteReadMasterType;
    axiReadSlave   : out AxiLiteReadSlaveType;
    axiWriteMaster : in  AxiLiteWriteMasterType;
    axiWriteSlave  : out AxiLiteWriteSlaveType;

    coreSclk : out sl;
    coreSDin : in  slv(2 downto 0)
    );
end entity AxiMax11202Master;

architecture rtl of AxiMax11202Master is

  signal rdEn   : sl;

  type data32 is array (2 downto 0) of slv(31 downto 0);

signal rdData : data32;

  type StateType is (WAIT_AXI_TXN_S, WAIT_CYCLE_S, WAIT_SERIAL_TXN_DONE_S);

  -- Registers
  type RegType is record
    state         : StateType;
    axiReadSlave  : AxiLiteReadSlaveType;
    axiWriteSlave : AxiLiteWriteSlaveType;
    -- Adc Core Inputs
    wrEn          : sl;
  end record RegType;

  constant REG_INIT_C : RegType := (
    state         => WAIT_AXI_TXN_S,
    axiReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axiWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C,
    wrEn          => '0');

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

  comb : process (axiReadMaster, axiRst, axiWriteMaster, r, rdData, rdEn) is
    variable v         : RegType;
    variable axiStatus : AxiLiteStatusType;
  begin
    v := r;

    axiSlaveWaitTxn(axiWriteMaster, axiReadMaster, v.axiWriteSlave, v.axiReadSlave, axiStatus);

    case (r.state) is
      when WAIT_AXI_TXN_S =>

        if (axiStatus.readEnable = '1') then
          -- In some modes, setting wren will cause the serial clock to drop,
          -- initiating a calibration and convert depending on the mode.
          -- then Rden will drop until the conversion is complete
          v.wrEn  := '1';
          v.state := WAIT_CYCLE_S;

        end if;

      when WAIT_CYCLE_S =>
        -- Wait 1 cycle for rdEn to drop
        v.wrEn  := '0';
        v.state := WAIT_SERIAL_TXN_DONE_S;

      when WAIT_SERIAL_TXN_DONE_S =>

        if (rdEn = '1') then
          v.state              := WAIT_AXI_TXN_S;
          v.axiReadSlave.rdata := rddata(conv_integer(axiReadMaster.araddr));
          axiSlaveReadResponse(v.axiReadSlave);

        end if;

      when others => null;
    end case;

    if (axiRst = '1') then
      v := REG_INIT_C;
    end if;

    rin <= v;

    axiWriteSlave <= r.axiWriteSlave;
    axiReadSlave  <= r.axiReadSlave;

  end process comb;

  seq : process (axiClk) is
  begin
    if (rising_edge(axiClk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

  Master_3 : entity work.Max11202Master
    generic map (
      TPD_G                => TPD_G,
      CLK_PERIOD_G         => CLK_PERIOD_G,          -- 8.0E-9,
      SERIAL_SCLK_PERIOD_G => SERIAL_SCLK_PERIOD_G)  --ite(SIMULATION_G, 100.0E-9, 100.0E-6))
    port map (
      clk    => axiClk,
      Rst    => axiRst,
      wrEn   => r.wrEn,
      rdEn   => rdEn,
    rdDataA => rdData(0),
    rdDataB => rdData(1),
    rdDataC => rdData(2),
      Sclk   => coreSclk,
      Sdin   => coreSDin
      );
end architecture rtl;
