-------------------------------------------------------------------------------
-- Title      : Testbench for design "wb_stream_sink"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : wb_stream_sink_tb.vhd
-- Author     : Vitor Finotti Ferreira  <finotti@finotti-Inspiron-7520>
-- Company    : 
-- Created    : 2015-07-22
-- Last update: 2015-07-31
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015     

-- This program is free software: you can redistribute it and/or
-- modify it under the terms of the GNU Lesser General Public License
-- as published by the Free Software Foundation, either version 3 of
-- the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- Lesser General Public License for more details.
--
-- You should have received a copy of the GNU Lesser General Public
-- License along with this program. If not, see
-- <http://www.gnu.org/licenses/>.
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2015-07-22  1.0      vfinotti Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;
use work.wb_stream_pkg.all;
use work.test_pkg.all;

-------------------------------------------------------------------------------

entity wb_stream_sink_tb is
end entity wb_stream_sink_tb;

architecture tb of wb_stream_sink_tb is

  -- Test_pkg constants
  constant c_CLK_FREQ        : real    := 100.0e6;  -- input clock frequency
  constant c_CYCLES_TO_RESET : natural := 4;  -- number of clock cycles before reset
  constant c_CYCLES_TO_CE    : natural := 20;  -- number of clock cycles before reset

  constant c_INPUT_WIDTH : positive := 32;
  constant c_INPUT_FILE  : string   := "input_sink.samples";

  -- Test_pkg signals
  signal clk : std_ulogic := '0';       -- clock signal
  signal rst : std_ulogic := '1';       -- reset signal
  signal ce  : std_ulogic := '0';       -- clock enable

  signal sink_ready  : std_ulogic;      -- negated snk_o.stall
  signal end_of_file : std_ulogic;

  -- component generics
  constant g_dat_width : natural := 32;
  constant g_adr_width : natural := 4;
  constant g_tgd_width : natural := 4;

  -- component ports
  signal snk_i   : t_wbs_sink_in;
  signal snk_o   : t_wbs_sink_out;
  signal adr     : std_logic_vector(g_adr_width-1 downto 0);
  signal dat     : std_logic_vector(g_dat_width-1 downto 0);
  signal tgd     : std_logic_vector(g_tgd_width-1 downto 0);
  signal dvalid  : std_logic;
  signal busy    : std_logic := '0';
  signal ce_core : std_logic := '0';

  -- auxiliar signals

  signal snk_i_tgd_s : std_logic_vector(c_INPUT_WIDTH-1 downto 0);
  signal snk_i_dat_s : std_logic_vector(c_INPUT_WIDTH-1 downto 0);
  signal snk_i_adr_s : std_logic_vector(c_INPUT_WIDTH-1 downto 0);

  signal ce_counter      : natural   := 0;  -- count number of ce events
  signal ce_core_counter : natural   := 0;
  signal valid_out       : std_logic := '0';


  component wb_stream_sink is
    generic (
      g_dat_width : natural;
      g_adr_width : natural;
      g_tgd_width : natural);
    port (
      clk_i     : in  std_logic;
      rst_i     : in  std_logic;
      ce_i      : in  std_logic;
      snk_i     : in  t_wbs_sink_in;
      snk_o     : out t_wbs_sink_out;
      adr_o     : out std_logic_vector(g_adr_width-1 downto 0);
      dat_o     : out std_logic_vector(g_dat_width-1 downto 0);
      tgd_o     : out std_logic_vector(g_tgd_width-1 downto 0);
      dvalid_o  : out std_logic;
      busy_i    : in  std_logic;
      ce_core_i : in  std_logic);
  end component wb_stream_sink;
  
begin  -- architecture test

  p_clk_gen (
    clk    => clk,
    c_FREQ => c_CLK_FREQ);

  p_rst_gen (
    clk      => clk,
    rst      => rst,
    c_CYCLES => 2);

  p_ce_gen (
    clk      => clk,
    ce       => ce,
    rst      => rst,
    c_CYCLES => c_CYCLES_TO_CE);

  sink_ready <= not(snk_o.stall);

  p_read_tsv_file_std_logic_vector (
    c_INPUT_FILE_NAME  => c_INPUT_FILE,
    c_SAMPLES_PER_LINE => 3,              -- number of inputs
    c_OUTPUT_WIDTH     => c_INPUT_WIDTH,  --input for the testbench, output for
                                          --the procedure
    clk                => clk,
    rst                => rst,
    ce                 => ce,
    req                => sink_ready,
    sample(0)          => snk_i_tgd_s,
    sample(1)          => snk_i_adr_s,
    sample(2)          => snk_i_dat_s,
    valid              => valid_out,
    end_of_file        => end_of_file);

  -- Convert from signed to std_logic_vector

  snk_i.tgd <= snk_i_tgd_s(g_tgd_width-1 downto 0);
  snk_i.dat <= snk_i_dat_s(g_dat_width-1 downto 0);
  snk_i.adr <= snk_i_adr_s(g_adr_width-1 downto 0);


  -- purpose: generates snk_i.cyc signal, changing only when EOF happens
  -- type   : sequential
  -- inputs : valid_out, rst_i
  -- outputs: snk_i.cyc
  cyc_assert : process (valid_out, end_of_file, rst) is
  begin  -- process cyc_assert
    if rst = '1' then
      snk_i.cyc <= '0';
    elsif end_of_file = '1' then        -- asynchronous reset (active low)
      snk_i.cyc <= '0';
    elsif valid_out'event and valid_out = '1' then  -- rising clock edge
      snk_i.cyc <= '1';
    end if;
  end process cyc_assert;

  -- As cyc and stb happens always at the same time: 
  snk_i.stb <= snk_i.cyc;

  -- purpose: asserts "busy" after a determined number of ce cycles 
  -- type   : sequential
  -- inputs : ce, ce, ce_counter
  -- outputs: busy
  busy_interrupt : process (ce) is
  begin  -- process busy_interrupt
    if ce'event and ce = '1' then       -- rising clock edge
      if ce_counter = 5 then
        busy <= '1';
      elsif ce_counter = 8 then
        busy <= '0';
      end if;
      ce_counter <= ce_counter + 1;     -- increments variable
    end if;
  end process busy_interrupt;

  -- purpose: generates signal to ce_core_i
  -- type   : sequential
  -- inputs : clk, rst
  -- outputs: ce_core
  ce_core_logic : process (clk, rst) is
  begin  -- process ce_core_logic
    if rst = '1' then                 -- asynchronous reset (active low)
      ce_core <= '0';
    elsif rising_edge(clk) then       -- rising clock edge
      if ce_core_counter = 5 then
        ce_core <= '1';
        ce_core_counter <= 0;
      else
        ce_core_counter <= ce_core_counter + 1;
        ce_core <= '0';
      end if;
    end if;
  end process ce_core_logic;

  -- component instantiation
  DUT : wb_stream_sink
    generic map (
      g_dat_width => g_dat_width,
      g_adr_width => g_adr_width,
      g_tgd_width => g_tgd_width)
    port map (
      clk_i     => clk,
      rst_i     => rst,
      ce_i      => ce,
      snk_i     => snk_i,
      snk_o     => snk_o,
      adr_o     => adr,
      dat_o     => dat,
      tgd_o     => tgd,
      dvalid_o  => dvalid,
      busy_i    => busy,
      ce_core_i => ce_core);

end architecture tb;

-------------------------------------------------------------------------------
