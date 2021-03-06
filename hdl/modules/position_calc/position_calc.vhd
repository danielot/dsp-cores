-------------------------------------------------------------------------------
-- Title      : Position calc, no sysgen generator
-- Project    :
-------------------------------------------------------------------------------
-- File       : position_calc.vhd
-- Author     : aylons  <aylons@LNLS190>
-- Company    :
-- Created    : 2014-05-06
-- Last update: 2016-05-02
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Position calculation with no sysgen parts
-------------------------------------------------------------------------------
-- Copyright (c) 2014
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2014-05-06  1.0      aylons          Created
-- 2014-10-06  2.0      vfinotti        CreatedHotfix
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

--library UNISIM;
--use UNISIM.vcomponents.all;
library work;
use work.dsp_cores_pkg.all;
use work.genram_pkg.all;

entity position_calc is
  generic(
    -- input sizes
    g_input_width : natural := 16;
    g_mixed_width : natural := 16;
    g_adc_ratio   : natural := 2;

    -- mixer
    g_dds_width  : natural := 16;
    g_dds_points : natural := 35;
    g_sin_file   : string  := "../../../dsp-cores/hdl/modules/position_calc/dds_sin.nif";
    g_cos_file   : string  := "../../../dsp-cores/hdl/modules/position_calc/dds_cos.nif";

    -- CIC setup
    g_tbt_cic_delay   : natural := 1;
    g_tbt_cic_stages  : natural := 2;
    g_tbt_ratio       : natural := 35;  -- ratio between
    g_tbt_decim_width : natural := 32;

    g_fofb_cic_delay   : natural := 1;
    g_fofb_cic_stages  : natural := 2;
    g_fofb_ratio       : natural := 980;  -- ratio between adc and fofb rates
    g_fofb_decim_width : natural := 32;

    g_monit1_cic_delay  : natural := 1;
    g_monit1_cic_stages : natural := 1;
    g_monit1_ratio      : natural := 100;  --ratio between fofb and monit 1
    g_monit1_cic_ratio  : positive := 8;

    g_monit2_cic_delay  : natural := 1;
    g_monit2_cic_stages : natural := 1;
    g_monit2_ratio      : natural := 100;  -- ratio between monit 1 and 2
    g_monit2_cic_ratio  : positive := 8;

    g_monit_decim_width : natural := 32;

    -- Cordic setup
    g_tbt_cordic_stages       : positive := 12;
    g_tbt_cordic_iter_per_clk : positive := 3;
    g_tbt_cordic_ratio        : positive := 4;

    g_fofb_cordic_stages       : positive := 15;
    g_fofb_cordic_iter_per_clk : positive := 3;
    g_fofb_cordic_ratio        : positive := 4;

    -- width of K constants
    g_k_width : natural := 24;

    --width for IQ output
    g_IQ_width : natural := 32
    );

  port(
    adc_ch0_i : in std_logic_vector(g_input_width-1 downto 0);
    adc_ch1_i : in std_logic_vector(g_input_width-1 downto 0);
    adc_ch2_i : in std_logic_vector(g_input_width-1 downto 0);
    adc_ch3_i : in std_logic_vector(g_input_width-1 downto 0);

    clk_i : in std_logic;  -- clock period = 4.44116091946435 ns (225.16635135135124 Mhz)
    rst_i : in std_logic;               -- clear signal

    ksum_i : in std_logic_vector(g_k_width-1 downto 0);
    kx_i   : in std_logic_vector(g_k_width-1 downto 0);
    ky_i   : in std_logic_vector(g_k_width-1 downto 0);

    mix_ch0_i_o : out std_logic_vector(g_IQ_width-1 downto 0);
    mix_ch0_q_o : out std_logic_vector(g_IQ_width-1 downto 0);
    mix_ch1_i_o : out std_logic_vector(g_IQ_width-1 downto 0);
    mix_ch1_q_o : out std_logic_vector(g_IQ_width-1 downto 0);
    mix_ch2_i_o : out std_logic_vector(g_IQ_width-1 downto 0);
    mix_ch2_q_o : out std_logic_vector(g_IQ_width-1 downto 0);
    mix_ch3_i_o : out std_logic_vector(g_IQ_width-1 downto 0);
    mix_ch3_q_o : out std_logic_vector(g_IQ_width-1 downto 0);
    mix_valid_o : out std_logic;
    mix_ce_o    : out std_logic;

    tbt_decim_ch0_i_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_decim_ch0_q_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_decim_ch1_i_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_decim_ch1_q_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_decim_ch2_i_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_decim_ch2_q_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_decim_ch3_i_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_decim_ch3_q_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_decim_valid_o   : out std_logic;
    tbt_decim_ce_o      : out std_logic;

    tbt_amp_ch0_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_amp_ch1_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_amp_ch2_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_amp_ch3_o : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_amp_valid_o : out std_logic;
    tbt_amp_ce_o    : out std_logic;

    tbt_pha_ch0_o      : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_pha_ch1_o      : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_pha_ch2_o      : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_pha_ch3_o      : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_pha_valid_o : out std_logic;
    tbt_pha_ce_o    : out std_logic;

    fofb_decim_ch0_i_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_decim_ch0_q_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_decim_ch1_i_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_decim_ch1_q_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_decim_ch2_i_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_decim_ch2_q_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_decim_ch3_i_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_decim_ch3_q_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_decim_valid_o   : out std_logic;
    fofb_decim_ce_o      : out std_logic;

    fofb_amp_ch0_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_amp_ch1_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_amp_ch2_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_amp_ch3_o : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_amp_valid_o : out std_logic;
    fofb_amp_ce_o    : out std_logic;

    fofb_pha_ch0_o      : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_pha_ch1_o      : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_pha_ch2_o      : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_pha_ch3_o      : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_pha_valid_o : out std_logic;
    fofb_pha_ce_o    : out std_logic;

    monit_amp_ch0_o   : out std_logic_vector(g_monit_decim_width-1 downto 0);
    monit_amp_ch1_o   : out std_logic_vector(g_monit_decim_width-1 downto 0);
    monit_amp_ch2_o   : out std_logic_vector(g_monit_decim_width-1 downto 0);
    monit_amp_ch3_o   : out std_logic_vector(g_monit_decim_width-1 downto 0);
    monit_amp_valid_o : out std_logic;
    monit_amp_ce_o    : out std_logic;

    tbt_pos_x_o        : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_pos_y_o        : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_pos_q_o        : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_pos_sum_o      : out std_logic_vector(g_tbt_decim_width-1 downto 0);
    tbt_pos_valid_o : out std_logic;
    tbt_pos_ce_o   : out std_logic;

    fofb_pos_x_o        : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_pos_y_o        : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_pos_q_o        : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_pos_sum_o      : out std_logic_vector(g_fofb_decim_width-1 downto 0);
    fofb_pos_valid_o : out std_logic;
    fofb_pos_ce_o    : out std_logic;

    monit_pos_x_o        : out std_logic_vector(g_monit_decim_width-1 downto 0);
    monit_pos_y_o        : out std_logic_vector(g_monit_decim_width-1 downto 0);
    monit_pos_q_o        : out std_logic_vector(g_monit_decim_width-1 downto 0);
    monit_pos_sum_o      : out std_logic_vector(g_monit_decim_width-1 downto 0);
    monit_pos_valid_o : out std_logic;
    monit_pos_ce_o    : out std_logic
    );
end position_calc;

architecture rtl of position_calc is

  -------------
  --Constants--
  -------------

-- full ratio is the accumulated ratio between data and clock.
  constant c_adc_ratio_full    : natural := g_adc_ratio;
  constant c_tbt_ratio_full    : natural := g_tbt_ratio*c_adc_ratio_full;
  constant c_fofb_ratio_full   : natural := g_fofb_ratio*c_adc_ratio_full;
  constant c_monit1_ratio_full : natural := g_monit1_ratio*c_fofb_ratio_full;
  constant c_monit2_ratio_full : natural := g_monit2_ratio*c_monit1_ratio_full;


  -- width for decimation counters
  constant c_cic_fofb_width   : natural := f_log2_size(g_fofb_ratio);
  constant c_cic_monit1_width : natural := f_log2_size(g_monit1_ratio);
  constant c_cic_monit2_width : natural := f_log2_size(g_monit2_ratio);
  constant c_cic_tbt_width    : natural := f_log2_size(g_tbt_ratio);
  constant c_adc_width        : natural := f_log2_size(g_adc_ratio);

  -- width for ce counters
  constant c_adc_ce_width         : natural := f_log2_size(c_adc_ratio_full);
  constant c_tbt_ce_width         : natural := f_log2_size(c_tbt_ratio_full);
  constant c_fofb_ce_width        : natural := f_log2_size(c_fofb_ratio_full);
  constant c_monit1_ce_width      : natural := f_log2_size(c_monit1_ratio_full);
  constant c_monit2_ce_width      : natural := f_log2_size(c_monit2_ratio_full);
  constant c_tbt_cordic_ce_width  : natural := f_log2_size(g_tbt_cordic_ratio);
  constant c_fofb_cordic_ce_width : natural := f_log2_size(g_fofb_cordic_ratio);
  constant c_monit1_cic_ce_width  : natural := f_log2_size(g_monit1_cic_ratio);
  constant c_monit2_cic_ce_width  : natural := f_log2_size(g_monit2_cic_ratio);


  constant c_fofb_ratio_slv : std_logic_vector(c_cic_fofb_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_fofb_ratio, c_cic_fofb_width));

  constant c_tbt_ratio_slv : std_logic_vector(c_cic_tbt_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_tbt_ratio, c_cic_tbt_width));

  constant c_monit1_ratio_slv : std_logic_vector(c_cic_monit1_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_monit1_ratio, c_cic_monit1_width));

  constant c_monit2_ratio_slv : std_logic_vector(c_cic_monit2_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_monit2_ratio, c_cic_monit2_width));

  constant c_adc_ratio_slv : std_logic_vector(c_adc_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_adc_ratio, c_adc_width));

  constant c_adc_ratio_slv_full : std_logic_vector(c_adc_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(c_adc_ratio_full, c_adc_ce_width));

  constant c_tbt_ratio_slv_full : std_logic_vector(c_tbt_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(c_tbt_ratio_full, c_tbt_ce_width));

  constant c_fofb_ratio_slv_full : std_logic_vector(c_fofb_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(c_fofb_ratio_full, c_fofb_ce_width));

  constant c_monit1_ratio_slv_full : std_logic_vector(c_monit1_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(c_monit1_ratio_full, c_monit1_ce_width));

  constant c_monit2_ratio_slv_full : std_logic_vector(c_monit2_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(c_monit2_ratio_full, c_monit2_ce_width));

  constant c_tbt_cordic_ratio_slv : std_logic_vector(c_tbt_cordic_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_tbt_cordic_ratio, c_tbt_cordic_ce_width));

  constant c_fofb_cordic_ratio_slv : std_logic_vector(c_fofb_cordic_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_fofb_cordic_ratio, c_fofb_cordic_ce_width));

  constant c_monit1_cic_ratio_slv : std_logic_vector(c_monit1_cic_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_monit1_cic_ratio, c_monit1_cic_ce_width));

  constant c_monit2_cic_ratio_slv : std_logic_vector(c_monit2_cic_ce_width-1 downto 0)
    := std_logic_vector(to_unsigned(g_monit2_cic_ratio, c_monit2_cic_ce_width));

  --Cordic
  constant c_tbt_cordic_xy_width : natural := g_tbt_decim_width+f_log2_size(g_tbt_cordic_stages)+2;  -- internal width of cordic: input_width + right padding + left padding
  constant c_tbt_cordic_ph_width : natural := g_tbt_decim_width+f_log2_size(g_tbt_cordic_stages);  -- right padding for cordic stages

  constant c_fofb_cordic_xy_width : natural := g_fofb_decim_width+f_log2_size(g_fofb_cordic_stages)+2;  -- internal width of cordic: input_width + right padding + left padding
  constant c_fofb_cordic_ph_width : natural := g_fofb_decim_width+f_log2_size(g_fofb_cordic_stages);  -- right padding for cordic stages



  -----------
  --Signals--
  -----------
  type t_input is array(3 downto 0) of std_logic_vector(g_input_width-1 downto 0);
  signal adc_input : t_input := (others => (others => '0'));

  type t_mixed is array(3 downto 0) of std_logic_vector(g_mixed_width-1 downto 0);
  signal full_i, full_q : t_mixed := (others => (others => '0'));

  -- decimated data
  type t_tbt_data is array(3 downto 0) of std_logic_vector(g_tbt_decim_width-1 downto 0);
  signal tbt_i, tbt_q, tbt_mag, tbt_phase : t_tbt_data := (others => (others => '0'));

  type t_tbt_signed is array (3 downto 0) of signed(g_tbt_decim_width-1 downto 0);  -- for cordic output
  signal tbt_signed_mag, tbt_signed_phase : t_tbt_signed := (others => (others => '0'));

  type t_fofb_data is array(3 downto 0) of std_logic_vector(g_fofb_decim_width-1 downto 0);
  signal fofb_i, fofb_q, fofb_mag, fofb_phase : t_fofb_data := (others => (others => '0'));

  type t_fofb_signed is array (3 downto 0) of signed(g_fofb_decim_width-1 downto 0);  -- for cordic output
  signal fofb_signed_mag, fofb_signed_phase : t_fofb_signed := (others => (others => '0'));

  type t_monit_data is array(3 downto 0) of std_logic_vector(g_monit_decim_width-1 downto 0);
  signal monit1_mag, monit2_mag : t_monit_data := (others => (others => '0'));

  --after deltasigma
  signal fofb_x_pre, fofb_y_pre, fofb_q_pre, fofb_sum_pre :
    std_logic_vector(g_fofb_decim_width-1 downto 0) := (others => '0');

  signal tbt_x_pre, tbt_y_pre, tbt_q_pre, tbt_sum_pre :
    std_logic_vector(g_tbt_decim_width-1 downto 0) := (others => '0');

  signal monit_x_pre, monit_y_pre, monit_q_pre, monit_sum_pre :
    std_logic_vector(g_monit_decim_width-1 downto 0) := (others => '0');

  ----------------------------
  --Clocks and clock enables--
  ----------------------------
  type ce_sl is array(3 downto 0) of std_logic;

  signal valid_tbt, valid_tbt_cordic, valid_fofb, valid_fofb_cordic, valid_monit1, valid_monit2 : ce_sl := (others => '0');
  signal ce_adc, ce_monit1, ce_monit2, ce_tbt_cordic, ce_fofb_cordic           : ce_sl := (others => '0');

  signal valid_fofb_ds, valid_tbt_ds : std_logic;

  attribute max_fanout                                                  : string;
  attribute max_fanout of ce_adc, ce_monit1, ce_monit2 : signal is "50";

begin

  adc_input(0) <= adc_ch0_i;
  adc_input(1) <= adc_ch1_i;
  adc_input(2) <= adc_ch2_i;
  adc_input(3) <= adc_ch3_i;

  gen_ddc : for chan in 3 downto 0 generate

    -- Generate clock enable
    cmp_ce_adc : strobe_gen
      generic map (
        g_maxrate   => c_adc_ratio_full,
        g_bus_width => c_adc_ce_width)
      port map (
        clock_i  => clk_i,
        reset_i  => '0',
        ce_i     => '1',
        ratio_i  => c_adc_ratio_slv_full,
        strobe_o => ce_adc(chan));

    cmp_ce_tbt_cordic : strobe_gen
      generic map (
        g_maxrate   => g_tbt_cordic_ratio,
        g_bus_width => c_tbt_cordic_ce_width)
      port map (
        clock_i  => clk_i,
        reset_i  => '0',
        ce_i     => '1',
        ratio_i  => c_tbt_cordic_ratio_slv,
        strobe_o => ce_tbt_cordic(chan));

    cmp_ce_fofb_cordic : strobe_gen
      generic map (
        g_maxrate   => g_fofb_cordic_ratio,
        g_bus_width => c_fofb_cordic_ce_width)
      port map (
        clock_i  => clk_i,
        reset_i  => '0',
        ce_i     => '1',
        ratio_i  => c_fofb_cordic_ratio_slv,
        strobe_o => ce_fofb_cordic(chan));

    cmp_ce_monit1 : strobe_gen
      generic map (
        g_maxrate   => g_monit1_cic_ratio,
        g_bus_width => c_monit1_cic_ce_width)
      port map (
        clock_i  => clk_i,
        reset_i  => '0',
        ce_i     => '1',
        ratio_i  => c_monit1_cic_ratio_slv,
        strobe_o => ce_monit1(chan));

    cmp_ce_monit2 : strobe_gen
      generic map (
        g_maxrate   => g_monit2_cic_ratio,
        g_bus_width => c_monit2_cic_ce_width)
      port map (
        clock_i  => clk_i,
        reset_i  => '0',
        ce_i     => '1',
        ratio_i  => c_monit2_cic_ratio_slv,
        strobe_o => ce_monit2(chan));

    -- Position calculation

    cmp_mixer : mixer
      generic map (
        g_sin_file         => g_sin_file,
        g_cos_file         => g_cos_file,
        g_number_of_points => g_dds_points,
        g_input_width      => g_input_width,
        g_dds_width        => g_dds_width,
        g_output_width     => g_mixed_width)
      port map (
        reset_i  => rst_i,
        clock_i  => clk_i,
        ce_i     => ce_adc(chan),
        signal_i => adc_input(chan),
        I_out    => full_i(chan),
        Q_out    => full_q(chan));

    cmp_tbt_cic : cic_dual
      generic map (
        g_input_width  => g_mixed_width,
        g_output_width => g_tbt_decim_width,
        g_stages       => g_tbt_cic_stages,
        g_delay        => g_tbt_cic_delay,
        g_max_rate     => g_tbt_ratio,
        g_bus_width    => c_cic_tbt_width)
      port map (
        clock_i => clk_i,
        reset_i => rst_i,
        ce_i    => ce_adc(chan),
        valid_i => '1',
        I_i     => full_i(chan),
        Q_i     => full_q(chan),
        ratio_i => c_tbt_ratio_slv,
        I_o     => tbt_i(chan),
        Q_o     => tbt_q(chan),
        valid_o => valid_tbt(chan));

    cmp_tbt_cordic : cordic_iter_slv
      generic map (
        g_input_width        => g_tbt_decim_width,
        g_xy_calc_width      => c_tbt_cordic_xy_width,
        g_x_output_width     => g_tbt_decim_width,
        g_phase_calc_width   => c_tbt_cordic_ph_width,
        g_phase_output_width => g_tbt_decim_width,
        g_stages             => g_tbt_cordic_stages,
        g_iter_per_clk       => g_tbt_cordic_iter_per_clk,
        g_rounding           => true)
      port map (
        clk_i     => clk_i,
        ce_data_i => ce_adc(chan),
        valid_i   => valid_tbt(chan),
        ce_i      => ce_tbt_cordic(chan),
        x_i       => tbt_i(chan),
        y_i       => tbt_q(chan),
        mag_o     => tbt_mag(chan),
        phase_o   => tbt_phase(chan),
        valid_o   => valid_tbt_cordic(chan));

    cmp_fofb_cic : cic_dual
      generic map (
        g_input_width  => g_mixed_width,
        g_output_width => g_fofb_decim_width,
        g_stages       => g_fofb_cic_stages,
        g_delay        => g_fofb_cic_delay,
        g_max_rate     => g_fofb_ratio,
        g_bus_width    => c_cic_fofb_width)
      port map (
        clock_i => clk_i,
        reset_i => rst_i,
        ce_i    => ce_adc(chan),
        valid_i => '1',
        I_i     => full_i(chan),
        Q_i     => full_q(chan),
        ratio_i => c_fofb_ratio_slv,
        I_o     => fofb_i(chan),
        Q_o     => fofb_q(chan),
        valid_o => valid_fofb(chan));

    cmp_fofb_cordic : cordic_iter_slv
      generic map (
        g_input_width        => g_fofb_decim_width,
        g_xy_calc_width      => c_fofb_cordic_xy_width,
        g_x_output_width     => g_fofb_decim_width,
        g_phase_calc_width   => c_fofb_cordic_ph_width,
        g_phase_output_width => g_fofb_decim_width,
        g_stages             => g_fofb_cordic_stages,
        g_iter_per_clk       => g_fofb_cordic_iter_per_clk,
        g_rounding           => true)
      port map (
        clk_i     => clk_i,
        ce_data_i => ce_adc(chan),
        valid_i   => valid_fofb(chan),
        ce_i      => ce_fofb_cordic(chan),
        x_i       => fofb_i(chan),
        y_i       => fofb_q(chan),
        mag_o     => fofb_mag(chan),
        phase_o   => fofb_phase(chan),
        valid_o   => valid_fofb_cordic(chan));

    cmp_monit1_cic : cic_dyn
      generic map (
        g_input_width   => g_fofb_decim_width,
        g_output_width  => g_monit_decim_width,
        g_stages        => 1,
        g_delay         => 1,
        g_max_rate      => g_monit1_ratio,
        g_bus_width     => c_cic_monit1_width,
        g_with_ce_synch => true)
      port map (
        clock_i  => clk_i,
        reset_i  => rst_i,
        ce_i     => ce_fofb_cordic(chan),
        ce_out_i => ce_monit1(chan),
        valid_i  => valid_fofb_cordic(chan),
        data_i   => fofb_mag(chan),
        ratio_i  => c_monit1_ratio_slv,
        data_o   => monit1_mag(chan),
        valid_o  => valid_monit1(chan));

    cmp_monit2_cic : cic_dyn
      generic map (
        g_input_width   => g_monit_decim_width,
        g_output_width  => g_monit_decim_width,
        g_stages        => 1,
        g_delay         => 1,
        g_max_rate      => g_monit2_ratio,
        g_bus_width     => c_cic_monit2_width,
        g_with_ce_synch => true)
      port map (
        clock_i  => clk_i,
        reset_i  => rst_i,
        ce_i     => ce_monit1(chan),
        ce_out_i => ce_monit2(chan),
        valid_i  => valid_monit1(chan),
        data_i   => monit1_mag(chan),
        ratio_i  => c_monit2_ratio_slv,
        data_o   => monit2_mag(chan),
        valid_o  => valid_monit2(chan));


  end generate gen_ddc;

  cmp_fofb_ds : delta_sigma
    generic map (
      g_width   => g_fofb_decim_width,
      g_k_width => g_k_width)
    port map (
      a_i     => fofb_mag(0),
      b_i     => fofb_mag(1),
      c_i     => fofb_mag(2),
      d_i     => fofb_mag(3),
      kx_i    => kx_i,
      ky_i    => ky_i,
      ksum_i  => ksum_i,
      clk_i   => clk_i,
      ce_i    => ce_fofb_cordic(0),
      valid_i => valid_fofb_cordic(0),
      valid_o => valid_fofb_ds,
      rst_i   => rst_i,
      x_o     => fofb_pos_x_o,
      y_o     => fofb_pos_y_o,
      q_o     => fofb_pos_q_o,
      sum_o   => fofb_pos_sum_o);

  -- Wiring intermediate signals to outputs

  mix_ch0_i_o <= std_logic_vector(resize(signed(full_i(0)), g_IQ_width));
  mix_ch0_q_o <= std_logic_vector(resize(signed(full_q(0)), g_IQ_width));
  mix_ch1_i_o <= std_logic_vector(resize(signed(full_i(1)), g_IQ_width));
  mix_ch1_q_o <= std_logic_vector(resize(signed(full_q(1)), g_IQ_width));
  mix_ch2_i_o <= std_logic_vector(resize(signed(full_i(2)), g_IQ_width));
  mix_ch2_q_o <= std_logic_vector(resize(signed(full_q(2)), g_IQ_width));
  mix_ch3_i_o <= std_logic_vector(resize(signed(full_i(3)), g_IQ_width));
  mix_ch3_q_o <= std_logic_vector(resize(signed(full_q(3)), g_IQ_width));
  mix_valid_o <= '1';
  mix_ce_o    <= ce_adc(0);

  tbt_decim_ch0_i_o <= tbt_i(0);
  tbt_decim_ch0_q_o <= tbt_q(0);
  tbt_decim_ch1_i_o <= tbt_i(1);
  tbt_decim_ch1_q_o <= tbt_q(1);
  tbt_decim_ch2_i_o <= tbt_i(2);
  tbt_decim_ch2_q_o <= tbt_q(2);
  tbt_decim_ch3_i_o <= tbt_i(3);
  tbt_decim_ch3_q_o <= tbt_q(3);
  tbt_decim_valid_o   <= valid_tbt(0);
  tbt_decim_ce_o      <= ce_adc(0);

  tbt_amp_ch0_o <= tbt_mag(0);
  tbt_amp_ch1_o <= tbt_mag(1);
  tbt_amp_ch2_o <= tbt_mag(2);
  tbt_amp_ch3_o <= tbt_mag(3);
  tbt_amp_valid_o <= valid_tbt_cordic(0);
  tbt_amp_ce_o    <= ce_tbt_cordic(0);

  tbt_pha_ch0_o      <= tbt_phase(0);
  tbt_pha_ch1_o      <= tbt_phase(1);
  tbt_pha_ch2_o      <= tbt_phase(2);
  tbt_pha_ch3_o      <= tbt_phase(3);
  tbt_pha_valid_o <= valid_tbt_cordic(0);
  tbt_pha_ce_o    <= ce_tbt_cordic(0);

  fofb_decim_ch0_i_o <= fofb_i(0);
  fofb_decim_ch0_q_o <= fofb_q(0);
  fofb_decim_ch1_i_o <= fofb_i(1);
  fofb_decim_ch1_q_o <= fofb_q(1);
  fofb_decim_ch2_i_o <= fofb_i(2);
  fofb_decim_ch2_q_o <= fofb_q(2);
  fofb_decim_ch3_i_o <= fofb_i(3);
  fofb_decim_ch3_q_o <= fofb_q(3);
  fofb_decim_valid_o   <= valid_fofb(0);
  fofb_decim_ce_o      <= ce_adc(0);

  fofb_amp_ch0_o <= fofb_mag(0);
  fofb_amp_ch1_o <= fofb_mag(1);
  fofb_amp_ch2_o <= fofb_mag(2);
  fofb_amp_ch3_o <= fofb_mag(3);
  fofb_amp_valid_o <= valid_fofb_cordic(0);
  fofb_amp_ce_o    <= ce_fofb_cordic(0);

  fofb_pha_ch0_o      <= fofb_phase(0);
  fofb_pha_ch1_o      <= fofb_phase(1);
  fofb_pha_ch2_o      <= fofb_phase(2);
  fofb_pha_ch3_o      <= fofb_phase(3);
  fofb_pha_valid_o <= valid_fofb_cordic(0);
  fofb_pha_ce_o    <= ce_fofb_cordic(0);

  monit_amp_ch0_o   <= monit2_mag(0);
  monit_amp_ch1_o   <= monit2_mag(1);
  monit_amp_ch2_o   <= monit2_mag(2);
  monit_amp_ch3_o   <= monit2_mag(3);
  monit_amp_valid_o <= valid_monit2(0);
  monit_amp_ce_o    <= ce_monit2(0);

  fofb_pos_valid_o <= valid_fofb_ds;
  fofb_pos_ce_o    <= ce_fofb_cordic(0);

  tbt_pos_valid_o <= '0';
  tbt_pos_ce_o    <= '0';

  monit_pos_valid_o <= '0';
  monit_pos_ce_o    <= '0';

  -- Removed to speed synthesis during test
  tbt_pos_x_o   <= (others => '0');
  tbt_pos_y_o   <= (others => '0');
  tbt_pos_q_o   <= (others => '0');
  tbt_pos_sum_o <= (others => '0');

  monit_pos_x_o   <= (others => '0');
  monit_pos_y_o   <= (others => '0');
  monit_pos_q_o   <= (others => '0');
  monit_pos_sum_o <= (others => '0');

end rtl;
