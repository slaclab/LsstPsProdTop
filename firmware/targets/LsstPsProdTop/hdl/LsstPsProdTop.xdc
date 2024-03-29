##############################################################################
## This file is part of 'LSST Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'LSST Firmware', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

#######################
## Application Ports ##
#######################
#Tighten timing constrain from 8ns to 7ns to fix errors observed in IR2 during temperature transition 

create_clock -name ethRefClk -period 7.000 [get_ports {ethClkP}]

## Switched REB0 and REB2 control due to layout change (connector gender change)

# I/O Port Mapping

set_property PACKAGE_PIN A8 [get_ports ethRxN[0]]

set_property PACKAGE_PIN E6 [get_ports ethClkN]

# set_property PACKAGE_PIN M9 [get_ports vNIn]


# BANK14
set_property -dict { PACKAGE_PIN P22 IOSTANDARD LVCMOS33 } [get_ports { bootMosi}]
set_property -dict { PACKAGE_PIN R22 IOSTANDARD LVCMOS33 } [get_ports { bootMiso}]
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS33 } [get_ports { bootWpL}]
set_property -dict { PACKAGE_PIN R21 IOSTANDARD LVCMOS33 } [get_ports { bootHdL}]
set_property -dict { PACKAGE_PIN T19 IOSTANDARD LVCMOS33 } [get_ports { bootCsL}]
set_property PACKAGE_PIN W21 [get_ports {sync_DCDC[2]}]
set_property PACKAGE_PIN W22 [get_ports {sync_DCDC[1]}]
set_property PACKAGE_PIN AA20 [get_ports {sync_DCDC[0]}]
set_property PACKAGE_PIN AA21 [get_ports {sync_DCDC[3]}]
set_property PACKAGE_PIN Y21 [get_ports {sync_DCDC[4]}]
set_property PACKAGE_PIN Y22 [get_ports {sync_DCDC[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports sync_DCDC*]

set_property PACKAGE_PIN U20 [get_ports {test_IO[0]}]
set_property PACKAGE_PIN V20 [get_ports {test_IO[1]}]
set_property PACKAGE_PIN W19 [get_ports {test_IO[2]}]
set_property PACKAGE_PIN W20 [get_ports {test_IO[3]}]
set_property PACKAGE_PIN Y18 [get_ports {test_IO[4]}]
set_property PACKAGE_PIN Y19 [get_ports {test_IO[5]}]
set_property PACKAGE_PIN V18 [get_ports {test_IO[6]}]
set_property PACKAGE_PIN V19 [get_ports {test_IO[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports test_IO*]

set_property PACKAGE_PIN V17 [get_ports temp_SDA]
set_property PACKAGE_PIN W17 [get_ports temp_SCL]
set_property PACKAGE_PIN AA18 [get_ports temp_Alarm]
set_property IOSTANDARD LVCMOS33 [get_ports temp_SDA]
set_property IOSTANDARD LVCMOS33 [get_ports temp_SCL]
set_property IOSTANDARD LVCMOS33 [get_ports temp_Alarm]


#set_property PACKAGE_PIN T18 [get_ports fpga_POR]
#set_property IOSTANDARD LVCMOS33 [get_ports fpga_POR]

set_property PACKAGE_PIN N15 [get_ports extRstL]
set_property IOSTANDARD LVCMOS33 [get_ports extRstL]

#set_property PACKAGE_PIN A24 [get_ports {clkSelA[0]}]
#set_property PACKAGE_PIN C26 [get_ports {clkSelA[1]}]
#set_property IOSTANDARD LVCMOS25 [get_ports clkSelA*]

#set_property PACKAGE_PIN B26 [get_ports {clkSelB[0]}]
#set_property PACKAGE_PIN C24 [get_ports {clkSelB[1]}]
#set_property IOSTANDARD LVCMOS25 [get_ports clkSelB*]

#BANK13
set_property PACKAGE_PIN Y17 [get_ports serID]
set_property IOSTANDARD LVCMOS25 [get_ports serID]

set_property PACKAGE_PIN W11 [get_ports {led[0]}]
set_property PACKAGE_PIN W12 [get_ports {led[1]}]
set_property PACKAGE_PIN V13 [get_ports {led[2]}]

set_property IOSTANDARD LVCMOS25 [get_ports led*]



set_property PACKAGE_PIN U15 [get_ports {GA[0]}]
set_property PACKAGE_PIN T14 [get_ports {GA[1]}]
set_property PACKAGE_PIN T15 [get_ports {GA[2]}]
set_property PACKAGE_PIN W15 [get_ports {GA[3]}]
#set_property PACKAGE_PIN W16 [get_ports {GA[4]}]

set_property IOSTANDARD LVCMOS25 [get_ports GA*]

set_property PACKAGE_PIN W14 [get_ports {reb_on[2]}]
set_property PACKAGE_PIN Y14 [get_ports {reb_on[1]}]
set_property PACKAGE_PIN AB11 [get_ports {reb_on[0]}]
set_property PACKAGE_PIN AB12 [get_ports {reb_on[3]}]
set_property PACKAGE_PIN AA9 [get_ports {reb_on[4]}]
set_property PACKAGE_PIN AB10 [get_ports {reb_on[5]}]
set_property IOSTANDARD LVCMOS25 [get_ports reb_on*]

set_property PACKAGE_PIN AA10 [get_ports fp_i2c_clk]
set_property PACKAGE_PIN AA11 [get_ports fp_i2c_data]
set_property PACKAGE_PIN V10 [get_ports fp_los]
set_property IOSTANDARD LVCMOS25 [get_ports fp_*]

set_property PACKAGE_PIN V14 [get_ports enable_in]
set_property IOSTANDARD LVCMOS25 [get_ports enable_in*]
set_property PACKAGE_PIN V15 [get_ports spare_in]
set_property IOSTANDARD LVCMOS25 [get_ports spare_in*]

set_property PACKAGE_PIN Y11 [get_ports dummy]
set_property IOSTANDARD LVCMOS25 [get_ports dummy]

#set_property PACKAGE_PIN T16 [get_ports clk_sp_p]
set_property PACKAGE_PIN U16 [get_ports clk_sp_n]
set_property IOSTANDARD LVDS_25 [get_ports clk_sp*]

set_property PACKAGE_PIN AA15 [get_ports {dout0[41]}]
set_property PACKAGE_PIN AA16 [get_ports {dout0[40]}]
set_property PACKAGE_PIN M5 [get_ports {dout0[39]}]
set_property PACKAGE_PIN P5 [get_ports {dout0[38]}]
set_property PACKAGE_PIN L4 [get_ports {dout0[37]}]
set_property PACKAGE_PIN M3 [get_ports {dout0[36]}]
set_property PACKAGE_PIN J4 [get_ports {dout0[35]}]
set_property PACKAGE_PIN H3 [get_ports {dout0[34]}]
set_property PACKAGE_PIN G2 [get_ports {dout0[33]}]
set_property PACKAGE_PIN F3 [get_ports {dout0[32]}]
set_property PACKAGE_PIN D1 [get_ports {dout0[31]}]
set_property PACKAGE_PIN B1 [get_ports {dout0[30]}]
set_property PACKAGE_PIN Y7 [get_ports {dout0[29]}]
set_property PACKAGE_PIN V9 [get_ports {dout0[28]}]
set_property PACKAGE_PIN AA6 [get_ports {dout0[27]}]
set_property PACKAGE_PIN U6 [get_ports {dout0[26]}]
set_property PACKAGE_PIN T4 [get_ports {dout0[25]}]
set_property PACKAGE_PIN Y4 [get_ports {dout0[24]}]
set_property PACKAGE_PIN AB2 [get_ports {dout0[23]}]
set_property PACKAGE_PIN U3 [get_ports {dout0[22]}]
set_property PACKAGE_PIN R2 [get_ports {dout0[21]}]
set_property PACKAGE_PIN T1 [get_ports {dout0[6]}]
set_property PACKAGE_PIN D21 [get_ports {dout0[5]}]
set_property PACKAGE_PIN B21 [get_ports {dout0[4]}]
set_property PACKAGE_PIN F20 [get_ports {dout0[3]}]
set_property PACKAGE_PIN B20 [get_ports {dout0[2]}]
set_property PACKAGE_PIN C19 [get_ports {dout0[1]}]
set_property PACKAGE_PIN B17 [get_ports {dout0[0]}]
set_property PACKAGE_PIN B13 [get_ports {dout0[13]}]
set_property PACKAGE_PIN D14 [get_ports {dout0[12]}]
set_property PACKAGE_PIN C15 [get_ports {dout0[11]}]
set_property PACKAGE_PIN F13 [get_ports {dout0[10]}]
set_property PACKAGE_PIN K16 [get_ports {dout0[9]}]
set_property PACKAGE_PIN K17 [get_ports {dout0[8]}]
set_property PACKAGE_PIN M20 [get_ports {dout0[7]}]
set_property PACKAGE_PIN M18 [get_ports {dout0[20]}]
set_property PACKAGE_PIN K19 [get_ports {dout0[19]}]
set_property PACKAGE_PIN J20 [get_ports {dout0[18]}]
set_property PACKAGE_PIN G20 [get_ports {dout0[17]}]
set_property PACKAGE_PIN H17 [get_ports {dout0[16]}]
set_property PACKAGE_PIN H14 [get_ports {dout0[15]}]
set_property PACKAGE_PIN H13 [get_ports {dout0[14]}]
set_property PACKAGE_PIN AB13 [get_ports {dout1[41]}]
set_property PACKAGE_PIN Y16 [get_ports {dout1[40]}]
set_property PACKAGE_PIN M6 [get_ports {dout1[39]}]
set_property PACKAGE_PIN P1 [get_ports {dout1[38]}]
set_property PACKAGE_PIN L5 [get_ports {dout1[37]}]
set_property PACKAGE_PIN L1 [get_ports {dout1[36]}]
set_property PACKAGE_PIN K4 [get_ports {dout1[35]}]
set_property PACKAGE_PIN H5 [get_ports {dout1[34]}]
set_property PACKAGE_PIN H2 [get_ports {dout1[33]}]
set_property PACKAGE_PIN F1 [get_ports {dout1[32]}]
set_property PACKAGE_PIN E1 [get_ports {dout1[31]}]
set_property PACKAGE_PIN F4 [get_ports {dout1[30]}]
set_property PACKAGE_PIN Y8 [get_ports {dout1[29]}]
set_property PACKAGE_PIN AB6 [get_ports {dout1[28]}]
set_property PACKAGE_PIN Y6 [get_ports {dout1[27]}]
set_property PACKAGE_PIN W5 [get_ports {dout1[26]}]
set_property PACKAGE_PIN R4 [get_ports {dout1[25]}]
set_property PACKAGE_PIN AB5 [get_ports {dout1[24]}]
set_property PACKAGE_PIN AB3 [get_ports {dout1[23]}]
set_property PACKAGE_PIN Y1 [get_ports {dout1[22]}]
set_property PACKAGE_PIN R3 [get_ports {dout1[21]}]
set_property PACKAGE_PIN T3 [get_ports {dout1[6]}]
set_property PACKAGE_PIN E21 [get_ports {dout1[5]}]
set_property PACKAGE_PIN B22 [get_ports {dout1[4]}]
set_property PACKAGE_PIN F19 [get_ports {dout1[3]}]
set_property PACKAGE_PIN E18 [get_ports {dout1[2]}]
set_property PACKAGE_PIN C18 [get_ports {dout1[1]}]
set_property PACKAGE_PIN A14 [get_ports {dout1[0]}]
set_property PACKAGE_PIN C13 [get_ports {dout1[13]}]
set_property PACKAGE_PIN D16 [get_ports {dout1[12]}]
set_property PACKAGE_PIN C14 [get_ports {dout1[11]}]
set_property PACKAGE_PIN F15 [get_ports {dout1[10]}]
set_property PACKAGE_PIN L16 [get_ports {dout1[9]}]
set_property PACKAGE_PIN L13 [get_ports {dout1[8]}]
set_property PACKAGE_PIN N20 [get_ports {dout1[7]}]
set_property PACKAGE_PIN M22 [get_ports {dout1[20]}]
set_property PACKAGE_PIN K18 [get_ports {dout1[19]}]
set_property PACKAGE_PIN L21 [get_ports {dout1[18]}]
set_property PACKAGE_PIN H20 [get_ports {dout1[17]}]
set_property PACKAGE_PIN H15 [get_ports {dout1[16]}]
set_property PACKAGE_PIN J14 [get_ports {dout1[15]}]
set_property PACKAGE_PIN J16 [get_ports {dout1[14]}]

set_property IOSTANDARD LVCMOS25 [get_ports dout*]

set_property PACKAGE_PIN AB15 [get_ports {din[41]}]
set_property PACKAGE_PIN AB16 [get_ports {din[40]}]
set_property PACKAGE_PIN P6 [get_ports {din[39]}]
set_property PACKAGE_PIN P4 [get_ports {din[38]}]
set_property PACKAGE_PIN N4 [get_ports {din[37]}]
set_property PACKAGE_PIN M2 [get_ports {din[36]}]
set_property PACKAGE_PIN L3 [get_ports {din[35]}]
set_property PACKAGE_PIN G3 [get_ports {din[34]}]
set_property PACKAGE_PIN K2 [get_ports {din[33]}]
set_property PACKAGE_PIN E3 [get_ports {din[32]}]
set_property PACKAGE_PIN E2 [get_ports {din[31]}]
set_property PACKAGE_PIN A1 [get_ports {din[30]}]
set_property PACKAGE_PIN W9 [get_ports {din[29]}]
set_property PACKAGE_PIN V8 [get_ports {din[28]}]
set_property PACKAGE_PIN V7 [get_ports {din[27]}]
set_property PACKAGE_PIN V5 [get_ports {din[26]}]
set_property PACKAGE_PIN T5 [get_ports {din[25]}]
set_property PACKAGE_PIN AA4 [get_ports {din[24]}]
set_property PACKAGE_PIN Y3 [get_ports {din[23]}]
set_property PACKAGE_PIN V3 [get_ports {din[22]}]
set_property PACKAGE_PIN W2 [get_ports {din[21]}]
set_property PACKAGE_PIN U1 [get_ports {din[6]}]
set_property PACKAGE_PIN G21 [get_ports {din[5]}]
set_property PACKAGE_PIN A21 [get_ports {din[4]}]
set_property PACKAGE_PIN D20 [get_ports {din[3]}]
set_property PACKAGE_PIN A20 [get_ports {din[2]}]
set_property PACKAGE_PIN E19 [get_ports {din[1]}]
set_property PACKAGE_PIN B18 [get_ports {din[0]}]
set_property PACKAGE_PIN A15 [get_ports {din[13]}]
set_property PACKAGE_PIN D15 [get_ports {din[12]}]
set_property PACKAGE_PIN E13 [get_ports {din[11]}]
set_property PACKAGE_PIN F14 [get_ports {din[10]}]
set_property PACKAGE_PIN M15 [get_ports {din[9]}]
set_property PACKAGE_PIN J17 [get_ports {din[8]}]
set_property PACKAGE_PIN K13 [get_ports {din[7]}]
set_property PACKAGE_PIN L18 [get_ports {din[20]}]
set_property PACKAGE_PIN L19 [get_ports {din[19]}]
set_property PACKAGE_PIN J21 [get_ports {din[18]}]
set_property PACKAGE_PIN K21 [get_ports {din[17]}]
set_property PACKAGE_PIN H18 [get_ports {din[16]}]
set_property PACKAGE_PIN G17 [get_ports {din[15]}]
set_property PACKAGE_PIN G13 [get_ports {din[14]}]
set_property IOSTANDARD LVCMOS25 [get_ports din*]





#set_property PACKAGE_PIN K25 [get_ports I2C_SDA_ADC]
#set_property PACKAGE_PIN N18 [get_ports I2C_SCL_ADC]
#set_property PACKAGE_PIN R17 [get_ports I2C_RESET_CNTL]
#set_property IOSTANDARD LVCMOS33 [get_ports I2C_*]

set_property PACKAGE_PIN G16 [get_ports {SDA_ADC[14]}]
set_property PACKAGE_PIN G15 [get_ports {SCL_ADC[14]}]
set_property PACKAGE_PIN J15 [get_ports {SDA_ADC[15]}]
set_property PACKAGE_PIN G18 [get_ports {SCL_ADC[15]}]
set_property PACKAGE_PIN H22 [get_ports {SDA_ADC[16]}]
set_property PACKAGE_PIN J22 [get_ports {SCL_ADC[16]}]
set_property PACKAGE_PIN M21 [get_ports {SDA_ADC[17]}]
set_property PACKAGE_PIN K22 [get_ports {SCL_ADC[17]}]
set_property PACKAGE_PIN H19 [get_ports {SDA_ADC[18]}]
set_property PACKAGE_PIN J19 [get_ports {SCL_ADC[18]}]
set_property PACKAGE_PIN N22 [get_ports {SDA_ADC[19]}]
set_property PACKAGE_PIN L20 [get_ports {SCL_ADC[19]}]
set_property PACKAGE_PIN N19 [get_ports {SDA_ADC[20]}]
set_property PACKAGE_PIN N18 [get_ports {SCL_ADC[20]}]
set_property PACKAGE_PIN M13 [get_ports {SDA_ADC[7]}]
set_property PACKAGE_PIN K14 [get_ports {SCL_ADC[7]}]
set_property PACKAGE_PIN L15 [get_ports {SDA_ADC[8]}]
set_property PACKAGE_PIN L14 [get_ports {SCL_ADC[8]}]
set_property PACKAGE_PIN M17 [get_ports {SDA_ADC[9]}]
set_property PACKAGE_PIN M16 [get_ports {SCL_ADC[9]}]
set_property PACKAGE_PIN E17 [get_ports {SDA_ADC[10]}]
set_property PACKAGE_PIN F16 [get_ports {SCL_ADC[10]}]
set_property PACKAGE_PIN E16 [get_ports {SDA_ADC[11]}]
set_property PACKAGE_PIN E14 [get_ports {SCL_ADC[11]}]
set_property PACKAGE_PIN B16 [get_ports {SDA_ADC[12]}]
set_property PACKAGE_PIN B15 [get_ports {SCL_ADC[12]}]
set_property PACKAGE_PIN A13 [get_ports {SDA_ADC[13]}]
set_property PACKAGE_PIN A16 [get_ports {SCL_ADC[13]}]
set_property PACKAGE_PIN C17 [get_ports {SDA_ADC[0]}]
set_property PACKAGE_PIN D17 [get_ports {SCL_ADC[0]}]
set_property PACKAGE_PIN F18 [get_ports {SDA_ADC[1]}]
set_property PACKAGE_PIN D19 [get_ports {SCL_ADC[1]}]
set_property PACKAGE_PIN A19 [get_ports {SDA_ADC[2]}]
set_property PACKAGE_PIN A18 [get_ports {SCL_ADC[2]}]
set_property PACKAGE_PIN C22 [get_ports {SDA_ADC[3]}]
set_property PACKAGE_PIN C20 [get_ports {SCL_ADC[3]}]
set_property PACKAGE_PIN D22 [get_ports {SDA_ADC[4]}]
set_property PACKAGE_PIN E22 [get_ports {SCL_ADC[4]}]
set_property PACKAGE_PIN F21 [get_ports {SDA_ADC[5]}]
set_property PACKAGE_PIN G22 [get_ports {SCL_ADC[5]}]
set_property PACKAGE_PIN V2 [get_ports {SDA_ADC[6]}]
set_property PACKAGE_PIN U2 [get_ports {SCL_ADC[6]}]
set_property PACKAGE_PIN W1 [get_ports {SDA_ADC[21]}]
set_property PACKAGE_PIN Y2 [get_ports {SCL_ADC[21]}]
set_property PACKAGE_PIN AB1 [get_ports {SDA_ADC[22]}]
set_property PACKAGE_PIN AA1 [get_ports {SCL_ADC[22]}]
set_property PACKAGE_PIN AA5 [get_ports {SDA_ADC[23]}]
set_property PACKAGE_PIN AA3 [get_ports {SCL_ADC[23]}]
set_property PACKAGE_PIN W4 [get_ports {SDA_ADC[24]}]
set_property PACKAGE_PIN V4 [get_ports {SCL_ADC[24]}]
set_property PACKAGE_PIN W6 [get_ports {SDA_ADC[25]}]
set_property PACKAGE_PIN U5 [get_ports {SCL_ADC[25]}]
set_property PACKAGE_PIN T6 [get_ports {SDA_ADC[26]}]
set_property PACKAGE_PIN R6 [get_ports {SCL_ADC[26]}]
set_property PACKAGE_PIN AB7 [get_ports {SDA_ADC[27]}]
set_property PACKAGE_PIN W7 [get_ports {SCL_ADC[27]}]
set_property PACKAGE_PIN AB8 [get_ports {SDA_ADC[28]}]
set_property PACKAGE_PIN AA8 [get_ports {SCL_ADC[28]}]
set_property PACKAGE_PIN U7 [get_ports {SDA_ADC[29]}]
set_property PACKAGE_PIN Y9 [get_ports {SCL_ADC[29]}]
set_property PACKAGE_PIN B2 [get_ports {SDA_ADC[30]}]
set_property PACKAGE_PIN C2 [get_ports {SCL_ADC[30]}]
set_property PACKAGE_PIN G1 [get_ports {SDA_ADC[31]}]
set_property PACKAGE_PIN D2 [get_ports {SCL_ADC[31]}]
set_property PACKAGE_PIN J1 [get_ports {SDA_ADC[32]}]
set_property PACKAGE_PIN K1 [get_ports {SCL_ADC[32]}]
set_property PACKAGE_PIN J5 [get_ports {SDA_ADC[33]}]
set_property PACKAGE_PIN J2 [get_ports {SCL_ADC[33]}]
set_property PACKAGE_PIN G4 [get_ports {SDA_ADC[34]}]
set_property PACKAGE_PIN H4 [get_ports {SCL_ADC[34]}]
set_property PACKAGE_PIN M1 [get_ports {SDA_ADC[35]}]
set_property PACKAGE_PIN K3 [get_ports {SCL_ADC[35]}]
set_property PACKAGE_PIN J6 [get_ports {SDA_ADC[36]}]
set_property PACKAGE_PIN K6 [get_ports {SCL_ADC[36]}]
set_property PACKAGE_PIN R1 [get_ports {SDA_ADC[37]}]
set_property PACKAGE_PIN N3 [get_ports {SCL_ADC[37]}]
set_property PACKAGE_PIN N2 [get_ports {SDA_ADC[38]}]
set_property PACKAGE_PIN P2 [get_ports {SCL_ADC[38]}]
set_property PACKAGE_PIN L6 [get_ports {SDA_ADC[39]}]
set_property PACKAGE_PIN N5 [get_ports {SCL_ADC[39]}]
set_property PACKAGE_PIN AA13 [get_ports {SDA_ADC[40]}]
set_property PACKAGE_PIN AB17 [get_ports {SCL_ADC[40]}]
set_property PACKAGE_PIN AA14 [get_ports {SDA_ADC[41]}]
set_property PACKAGE_PIN Y13 [get_ports {SCL_ADC[41]}]
set_property IOSTANDARD LVCMOS25 [get_ports SDA_ADC*]
set_property IOSTANDARD LVCMOS25 [get_ports SCL_ADC*]
