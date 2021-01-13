-------------------------------------------------------------------------------
-- Title      :
-------------------------------------------------------------------------------
-- File       : I2cRegMasterAndMux.vhd
-- Author     : Leonid Sapozhnikov  <leosap@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-03-17
-- Last update: 2015-03-17
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Combine Mux and RegMaster
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.I2cPkg.all;

use work.UserPkg.all;

entity I2cRegMasterAndMux is

   generic (
      TPD_G        : time                 := 1 ns;
      SIMULATION_G    : boolean          := false;
      OUTPUT_EN_POLARITY_G : integer range 0 to 1      := 0;
      FILTER_G             : integer range 2 to 512    := 8;
      PRESCALE_G           : integer range 0 to 655535 := 249;
      NUM_INPUTS_C : natural range 2 to 8 := 2);
   port (
      clk       : in  sl;
      srst      : in  sl                           := '0';
      arst      : in  sl                           := '0';
      lockReq   : in  slv(NUM_INPUTS_C-1 downto 0) := (others => '0');
      regIn     : in  I2cRegMasterInArray(0 to NUM_INPUTS_C-1);
      regOut    : out I2cRegMasterOutArray(0 to NUM_INPUTS_C-1);
      i2ci   : in  i2c_in_type;
      i2co   : out i2c_out_type);
end entity I2cRegMasterAndMux;

architecture rtl of I2cRegMasterAndMux is
   attribute keep_hierarchy        : string;
   attribute keep_hierarchy of rtl : architecture is "yes";


   signal i2cRegMasterIn   : I2cRegMasterInType;
   signal i2cRegMasterOut  : I2cRegMasterOutType;

begin

   -- Multiplexes 2 I2cRegMasterAxiBridges onto on I2cRegMaster
   I2cRegMasterMux_1 : entity surf.I2cRegMasterMux
      generic map (
         TPD_G        => TPD_G,
         NUM_INPUTS_C => NUM_INPUTS_C)
      port map (
         clk       => clk,
         srst      => srst,
         lockReq   => lockReq,
         regIn     => regIn,
         regOut    => regOut,
         masterIn  => i2cRegMasterIn,
         masterOut => i2cRegMasterOut);

   -- Finally, the I2cRegMaster
   i2cRegMaster_HybridConfig : entity surf.i2cRegMaster
      generic map (
         TPD_G                => TPD_G,
         OUTPUT_EN_POLARITY_G => OUTPUT_EN_POLARITY_G,
         FILTER_G             => ite(SIMULATION_G, 2, FILTER_G),
         PRESCALE_G           => ite(SIMULATION_G, 4, PRESCALE_G))  -- 100 kHz (Simulation faster)
      port map (
         clk    => clk,
         srst   => srst,
         regIn  => i2cRegMasterIn,
         regOut => i2cRegMasterOut,
         i2ci   => i2ci,
         i2co   => i2co);

end architecture rtl;










