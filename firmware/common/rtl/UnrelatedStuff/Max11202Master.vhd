-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      Max11202Master.vhd - 
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Leonid Sapozhnikov
--      Created on: 7/18/2017 3:10:01 PM
--      Last change: JO 8/3/2017 1:38:37 PM
--
-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- Max11202Master.vhd
-- From
-- File       : SpiMaster.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-05-24
-- Last update: 2017-08-02
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
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
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
--use ieee.math_real.all;
use work.StdRtlPkg.all;

entity max11202Master is
  generic (
    TPD_G                : time := 1 ns;
    CLK_PERIOD_G         : real := 6.4E-9;
    SERIAL_SCLK_PERIOD_G : real := 1.0E-6);  -- 1 MHz
  port (
    --Global Signals
    clk    : in  sl;
    Rst    : in  sl;
    -- Parallel interface
    wrEn   : in  sl;
    rdEn   : out sl;
    rdDataA : out slv(31 downto 0);
    rdDataB : out slv(31 downto 0);
    rdDataC : out slv(31 downto 0);
    Sclk   : out sl;
    Sdin   : in  slv(2 downto 0)
    );
end max11202Master;

architecture rtl of max11202Master is

  constant SERIAL_CLK_PERIOD_DIV2_CYCLES_C : integer := integer(SERIAL_SCLK_PERIOD_G / (2.0*CLK_PERIOD_G));
  constant SCLK_COUNTER_SIZE_C             : integer := bitSize(SERIAL_CLK_PERIOD_DIV2_CYCLES_C);


  -- Types
  type data32 is array (2 downto 0) of slv(31 downto 0);

  type StateType is (
    IDLE_S,
    SHIFT_S,
    SAMPLE_S,
    DONE_S);

  type RegType is record
    state       : StateType;
    rdEn        : sl;
    rdData      : data32;
    dataCounter : slv(25 downto 0);
    sclkCounter : slv(SCLK_COUNTER_SIZE_C-1 downto 0);
    Sclk        : sl;
  end record RegType;

  constant REG_INIT_C : RegType := (
    state       => IDLE_S,
    rdEn        => '0',
    rdData      => (others => x"00000000"),
    dataCounter => (others => '0'),
    sclkCounter => (others => '0'),
    Sclk        => '0'
    );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

  comb : process (r, Rst, wrEn, sdin) is
    variable v : RegType;
  begin
    v := r;

    case (r.state) is
      when IDLE_S =>

        v.Sclk        := '0';
        v.dataCounter := (others => '0');
        v.sclkCounter := (others => '0');
        v.rdEn        := '1';  -- rdEn always valid between txns, indicates ready for next txn

        if (wrEn = '1') then
          v.rdEn := '0';

          if (Sdin = "000") then        -- All ADCs are ready
            v.state := SAMPLE_S;
          end if;
        end if;

      when SHIFT_S =>
        -- Wait half a clock period then shift out the next data bit
        v.sclkCounter := r.sclkCounter + 1;
        if (r.sclkCounter = SERIAL_CLK_PERIOD_DIV2_CYCLES_C) then
          v.sclkCounter := (others => '0');
          v.Sclk        := not r.Sclk;
        end if;


      when SAMPLE_S =>
        -- Wait half a clock period then sample the next data bit
        v.sclkCounter := r.sclkCounter + 1;
        if (r.sclkCounter = SERIAL_CLK_PERIOD_DIV2_CYCLES_C) then
          v.sclkCounter := (others => '0');
          v.Sclk        := not r.Sclk;
          v.rdData(0)   := r.rdData(0)(30 downto 0) & SDin(0);
          v.rdData(1)   := r.rdData(1)(30 downto 0) & SDin(1);
          v.rdData(2)   := r.rdData(2)(30 downto 0) & SDin(2);
          v.state       := SHIFT_S;

          v.dataCounter := r.dataCounter + 1;
          if (r.dataCounter = 24) then
            v.state := DONE_S;
          end if;
        end if;

      when DONE_S =>
        -- Assert rdEn after half a SPI clk period
        -- Go back to idle after one SPI clk period
        -- Otherwise back to back operations happen too fast.
        v.sclkCounter := r.sclkCounter + 1;
        if (r.sclkCounter = SERIAL_CLK_PERIOD_DIV2_CYCLES_C) then
          v.sclkCounter := (others => '0');
          v.state       := IDLE_S;
        end if;
      when others => null;
    end case;

	 rdDataA <= r.rdData(0);
	 rdDataB <= r.rdData(1);
	 rdDataC <= r.rdData(2);

    if (Rst = '1') then
      v := REG_INIT_C;
    end if;

    rin <= v;

    Sclk <= r.Sclk;

    rdEn   <= r.rdEn;

  end process comb;

  seq : process (clk) is
  begin
    if (rising_edge(clk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

end rtl;
