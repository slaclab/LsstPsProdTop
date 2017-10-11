-----------------------------------------------------------------
--                                                             --
-----------------------------------------------------------------
--
--      FrontEndReg.vhd - 
--
--      Copyright(c) SLAC National Accelerator Laboratory 2000
--
--      Author: Leonid Sapozhnikov
--      Created on: 7/25/2017 1:03:24 PM
--      Last change: JO 7/25/2017 2:57:13 PM
--


library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

use work.AxiLitePkg.all;

entity FrontEndReg is
  generic (
    TPD_G            : time            := 1 ns;
    AXI_ERROR_RESP_G : slv(1 downto 0) := AXI_RESP_DECERR_C
    );
  port (

-- Slave AXI-Lite Interface
    axilClk         : in  sl;
    axilRst         : in  sl;
    axilReadMaster  : in  AxiLiteReadMasterType;
    axilReadSlave   : out AxiLiteReadSlaveType;
    axilWriteMaster : in  AxiLiteWriteMasterType;
    axilWriteSlave  : out AxiLiteWriteSlaveType;


-- Ion Pump Control Board Mode bits
    iMode : in sl;                      -- HVPS in Current Limit Mode
    vMode : in sl;                      -- HVPS in Voltage Limit Mode
    pMode : in sl;                      -- HVPS in Power Limit Mode

-- Ion Pump Enable
    enable : out sl                     -- Enable HVPS
    );
end entity FrontEndReg;

architecture Behavioral of FrontEndReg is

  signal modes : slv(2 downto 0);

  type RegType is record
    modeBits       : slv(2 downto 0);
    enableBit      : sl;
    axilReadSlave  : AxiLiteReadSlaveType;
    axilWriteSlave : AxiLiteWriteSlaveType;
  end record;

  constant REG_INIT_C : RegType := (
    modeBits       => "000",
    enableBit      => '0',
    axilReadSlave  => AXI_LITE_READ_SLAVE_INIT_C,
    axilWriteSlave => AXI_LITE_WRITE_SLAVE_INIT_C
    );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;


begin

  modes  <= pMode & vMode & iMode;
  enable <= r.enablebit;

  comb : process (r, axilRst, axilReadMaster, axilWriteMaster, modes) is
    variable v      : RegType;
    variable axilEp : AxiLiteEndpointType;
  begin
    v := r;

    axiSlaveWaitTxn(axilEp, axilWriteMaster, axilReadMaster, v.axilWriteSlave, v.axilReadSlave);

    axiSlaveRegisterR(axilEp, X"00", 1, modes);  -- 3 mode bits in bits 3-1
    axiSlaveRegister(axilEp, X"00", 0, v.enableBit);  -- enable bit in bit 0

    axiSlaveDefault(axilEp, v.axilWriteSlave, v.axilReadSlave);

    if (axilRst = '1') then
      v := REG_INIT_C;
    end if;

    rin <= v;

  end process;

  seq : process (axilClk) is
  begin
    if (rising_edge(axilClk)) then
      r <= rin after TPD_G;
    end if;
  end process seq;

end Behavioral;

