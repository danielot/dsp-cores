------------------------------------------------------------------------------
-- Title      : Swapping Channel Pairs under Counter, Top entity
------------------------------------------------------------------------------
-- Author     : Jos� Alvim Berkenbrock
-- Company    : CNPEM LNLS-DIG
-- Platform   : FPGA-generic
-------------------------------------------------------------------------------
-- Description:  This design uses a counter to divide clock input frequency and
--              apply it as enable signal to swap the switches of rf_ch_swap
--              block. The counting constant is a generic parameter.
--               Is possible to select the blocks independently. This option
--              allow us to compare with x without swiching mode of channels to
--              see how useful is switching mode to mitigate board drifts.
-------------------------------------------------------------------------------
-- Copyright (c) 2013 CNPEM
-- Licensed under GNU Lesser General Public License (LGPL) v3.0
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                Description
-- 2013-01-24  1.0      jose.berkenbrock      Created
-- 2013-01-25  1.1      jose.berkenbrock      Independently mode selection
-- 2013-01-30  1.1      jose.berkenbrock      Core description
-- 2013-02-14  1.2      jose.berkenbrock      Set enable divider as generic
-- 2013-02-18  2.0      jose.berkenbrock      New outputs swap and en_inv[2:1]
-- 2013-02-21  3.0      jose.berkenbrock      New flag output, en_inv supressed
-- 2013-02-22  4.0      jose.berkenbrock      New status out;flag/swap supressed
-- 2013-03-09  5.0      jose.berkenbrock      swap_div_f_i added
-- 2013-07-01  5.1      lucas.russo           Changed to synchronous resets
-------------------------------------------------------------------------------
library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library unisim;
--use unisim.vcomponents.all;

entity swap_cnt_top is
generic(
    --g_en_swap_div : natural := 1023
    g_swap_div_freq_vec_width : natural range 0 to 16 := 10
);
port(
    clk_i                                   : in  std_logic;
    rst_n_i                                 : in  std_logic;

    mode1_i                                 : in  std_logic_vector(1 downto 0);
    mode2_i                                 : in  std_logic_vector(1 downto 0);

    swap_div_f_i                            : in std_logic_vector(g_swap_div_freq_vec_width-1 downto 0);
    swap_div_f_load_i                       : in std_logic;
    swap_div_f_o                            : out std_logic_vector(g_swap_div_freq_vec_width-1 downto 0);
    ext_clk_i                               : in std_logic;
    ext_clk_en_i                            : in std_logic;

    clk_swap_o                              : out std_logic;
    clk_swap_en_i                           : in std_logic;
    --blink_fmc                               : out std_logic;

    status1_o                               : out std_logic;
    status2_o                               : out std_logic;
    ctrl1_o                                 : out std_logic_vector(7 downto 0);
    ctrl2_o                                 : out std_logic_vector(7 downto 0)
  );
end swap_cnt_top;

architecture rtl of swap_cnt_top is

  component rf_ch_swap
  generic(
    g_direct      : std_logic_vector(7 downto 0) := "10100101";
    g_inverted    : std_logic_vector(7 downto 0) := "01011010");
  port(
    clk_i     :   in   std_logic;
    rst_n_i   :   in   std_logic;
    en_swap_i :   in   std_logic;
    mode_i    :   in   std_logic_vector(1 downto 0);
    status_o  :   out  std_logic;
    ctrl_o    :   out  std_logic_vector(7 downto 0)
  );
  end component;

  signal  count                 : natural range 0 to 2**g_swap_div_freq_vec_width-1;
  signal  count_half            : natural range 0 to 1;
  signal  cnst_swap_div_f       : natural range 0 to 2**g_swap_div_freq_vec_width-1;
  signal  swap_div_f_reg        : std_logic_vector(g_swap_div_freq_vec_width-1 downto 0);
  signal  count2                : natural range 0 to 20000000;
  signal  swap                  : std_logic;
  signal  swap_mux              : std_logic;
  signal  swap_mux_r            : std_logic;
  signal  status1, status1_old  : std_logic;
  signal  status2, status2_old  : std_logic;
  signal  status1_out           : std_logic;
  signal  status2_out           : std_logic;

begin

  p_swap_div_load : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        swap_div_f_reg <= (others => '0');
      else
        if swap_div_f_load_i = '1' then
          swap_div_f_reg <= swap_div_f_i;
        end if;
      end if;
  end if;
  end process p_swap_div_load;

  swap_div_f_o <= swap_div_f_reg;

  p_reg_swap_div : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        cnst_swap_div_f <= 0;
      else
        cnst_swap_div_f <= (to_integer(unsigned(swap_div_f_reg))-1);
      end if;
    end if;
  end process p_reg_swap_div;

  ----------------------------------------------------------------
  -- Swapp_ch_rf Components Instantiation
  ----------------------------------------------------------------
  swapp_inst_1: rf_ch_swap
  port map (
    clk_i     => clk_i,
    rst_n_i   => rst_n_i,
    en_swap_i => swap_mux_r,
    mode_i    => mode1_i,
    status_o  => status1,
    ctrl_o    => ctrl1_o
  );

  swapp_inst_2: rf_ch_swap
  port map (
    clk_i     => clk_i,
    rst_n_i   => rst_n_i,
    en_swap_i => swap_mux_r,
    mode_i    => mode2_i,
    status_o  => status2,
    ctrl_o    => ctrl2_o
  );
----------------------------------------------------------------
  p_freq_swap : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        count <= 0;
        swap  <= '1';
      else
        -- Clear SW counter if we received a new SW divider period
        -- This is important to ensure that we don't swap signals
        -- between crossed antennas
        if clk_swap_en_i = '0' or swap_div_f_load_i = '1' then
          count <= 0;
          swap <= '1';
        elsif count = cnst_swap_div_f then
          count <= 0;
          swap  <= not swap;
        else
          count <= count + 1;
        end if;
      end if;
    end if;
  end process p_freq_swap;
----------------------------------------------------------------
-- Use external provided clock or the internal generated one
  swap_mux <= ext_clk_i when ext_clk_en_i = '1' else swap;

  p_swap_reg : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        swap_mux_r <= '0';
      else
        swap_mux_r <= swap_mux;
      end if;
    end if;
  end process p_swap_reg;
----------------------------------------------------------------
  p_status : process(clk_i)
  begin
    if rising_edge(clk_i) then
      if rst_n_i = '0' then
        status1_old <= '0';
        status2_old <= '0';
        status1_out <= '0';
        status2_out <= '0';
      else
        status1_old <= status1;
        status2_old <= status2;

        status1_out <= status1 xor status1_old;
        status2_out <= status2 xor status2_old;
      end if;
    end if;
  end process p_status;
----------------------------------------------------------------
clk_swap_o  <= swap_mux_r;
status1_o   <= status1_out;
status2_o   <= status2_out;

end;
