-------------------------------------------------------------------------------
-- Title      : Vivadi DDS sin lut for SIRIUS 130M
-- Project    :
-------------------------------------------------------------------------------
-- File       : dds_sin_lut.vhd
-- Author     : aylons  <aylons@LNLS190>
-- Company    :
-- Created    : 2015-04-15
-- Last update: 2016-04-06
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Temporary sine lut for SIRIUS machine with 130M ADC generated
-- through Vivado.
-------------------------------------------------------------------------------
-- Copyright (c) 2015
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2015-04-15  1.0      aylons	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
entity dds_sin_lut is
  port (
    clka  : in  std_logic;
    addra : in  std_logic_vector(8 downto 0);
    douta : out std_logic_vector(15 downto 0)
    );
end entity dds_sin_lut;

architecture str of dds_sin_lut is

  component sin_lut_sirius_98_383 is
    port (
      clka  : in  std_logic;
      addra : in  std_logic_vector(8 downto 0);
      douta : out std_logic_vector(15 downto 0));
  end component sin_lut_sirius_98_383;

begin

  sin_lut_sirius_98_383_1 : sin_lut_sirius_98_383
    port map (
      clka  => clka,
      addra => addra,
      douta => douta);

end architecture str;
