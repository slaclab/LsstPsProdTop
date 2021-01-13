-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      Mapping.vhd -
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Leonid Sapozhnikov
--      Created on: 7/19/2017 1:33:09 PM
--      Last change: LS 10/09/2017 9:40:28 AM
--
-------------------------------------------------------------------------------
-- File       : Mapping.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2017-04-20
-- Last update: 2017-08-02
-------------------------------------------------------------------------------
-- Description: Mapping to fix mapping errors and minimize actual hardware effect
-------------------------------------------------------------------------------
-- This file is part of 'LSST Firmware'.
-- It is subject to the license terms in the LICENSE.txt file found in the
-- top-level directory of this distribution and at:
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
-- No part of 'LSST Firmware', including this file,
-- may be copied, modified, propagated, or distributed except according to
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library surf;
use surf.StdRtlPkg.all;
use surf.AxiLitePkg.all;
use surf.I2cPkg.all;

use work.UserPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Mapping is
  generic (
    TPD_G            : time             := 1 ns);
  port (

    dout0     : in  slv(41 downto 0);
    dout1     : in  slv(41 downto 0);
    din       : out slv(41 downto 0);
	dout0Map  : out slv(41 downto 0);
    dout1Map  : out slv(41 downto 0);
    dinMap    : in  slv(41 downto 0);

    sync_DCDC : out slv(5 downto 0);
    reb_on    : out slv(5 downto 0);
    sync_DCDCMap : in slv(5 downto 0);
    reb_onMap    : in slv(5 downto 0);
	psI2cIn   : out i2c_in_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
    psI2cOut  : in  i2c_out_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
	  
	psI2cInMap : in  i2c_in_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
    psI2cOutMap : out i2c_out_array(7 * (PS_REB_TOTAL_C - 1) + 6 downto 0);
	  
	selectVerB  : in  sl;
	selectCR  : in  sl
	
);
end Mapping;

architecture rtl of Mapping is


begin

   U_Mapping : process (dout0, dout1, dinMap, sync_DCDCMap, reb_onMap, psI2cInMap, psI2cOut,selectCR, selectVerB ) is
   
   begin
 -- REB 0-2
          dout0Map(20 downto 0)       <= dout0(20 downto 0);
		  dout1Map(20 downto 0)       <= dout1(20 downto 0);
		  din(20 downto 0)            <= dinMap(20 downto 0);
		  sync_DCDC(2 downto 0)       <= sync_DCDCMap(2 downto 0);
		  reb_on(2 downto 0)          <= reb_onMap(2 downto 0);
		  psI2cIn(20 downto 0)        <= psI2cInMap(20 downto 0);
		  psI2cOutMap(20 downto 0)    <= psI2cOut(20 downto 0);
 -- REB 3
        if (selectCR = '1' and selectVerB = '0')  then 
		  dout0Map(27 downto 21)       <= dout0(27 downto 21);
		  dout1Map(27 downto 21)       <= dout1(27 downto 21);
		  din(27 downto 21)            <= dinMap(27 downto 21);
		  sync_DCDC(3)                 <= sync_DCDCMap(3);
		  reb_on(3)                    <= reb_onMap(3);
		  psI2cIn(27 downto 21)        <= psI2cInMap(27 downto 21);
		  psI2cOutMap(27 downto 21)    <= psI2cOut(27 downto 21);
		else
		  dout0Map(27 downto 21)       <= dout0(41 downto 35);
		  dout1Map(27 downto 21)       <= dout1(41 downto 35);
		  din(27 downto 21)            <= dinMap(41 downto 35);
		  sync_DCDC(3)                 <= sync_DCDCMap(5);
		  reb_on(3)                    <= reb_onMap(5);
		  psI2cIn(27 downto 21)        <= psI2cInMap(41 downto 35);
		  psI2cOutMap(27 downto 21)    <= psI2cOut(41 downto 35);
		end if;
		  
 -- REB 4		  
		  dout0Map(34 downto 28)       <= dout0(34 downto 28);
		  dout1Map(34 downto 28)       <= dout1(34 downto 28);
		  din(34 downto 28)            <= dinMap(34 downto 28);
		  sync_DCDC(4)                 <= sync_DCDCMap(4);
		  reb_on(4)                    <= reb_onMap(4);
		  psI2cIn(34 downto 28)        <= psI2cInMap(34 downto 28);
		  psI2cOutMap(34 downto 28)    <= psI2cOut(34 downto 28);
		  
 -- REB 5	
        if (selectCR = '1'  and selectVerB = '0')  then  
		  dout0Map(41 downto 35)       <= dout0(41 downto 35);
		  dout1Map(41 downto 35)       <= dout1(41 downto 35);
		  din(41 downto 35)            <= dinMap(41 downto 35);
		  sync_DCDC(5)                 <= sync_DCDCMap(5);
		  reb_on(5)                    <= reb_onMap(5);
		  psI2cIn(41 downto 35)        <= psI2cInMap(41 downto 35);
		  psI2cOutMap(41 downto 35)    <= psI2cOut(41 downto 35);
		else
		  dout0Map(41 downto 35)       <= dout0(27 downto 21);
		  dout1Map(41 downto 35)       <= dout1(27 downto 21);
		  din(41 downto 35)            <= dinMap(27 downto 21);
		  sync_DCDC(5)                 <= sync_DCDCMap(3);
		  reb_on(5)                    <= reb_onMap(3);
		  psI2cIn(41 downto 35)        <= psI2cInMap(27 downto 21);
		  psI2cOutMap(41 downto 35)    <= psI2cOut(27 downto 21);
		end if;
		
    end process U_Mapping;

end rtl;
