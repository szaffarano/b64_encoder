library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.txt_util.all;

entity pico_encoder_bench is
end entity;

architecture bench of pico_encoder_bench is
  constant period : time := 20 ns;

  component pico_encoder is
    port (
      uart_rx : in  std_logic;
      uart_tx : out std_logic;
      clk_in  : in  std_logic);
  end component;


  signal clk : std_logic;
  signal tx, rx             : std_logic;

  signal stop_bench : boolean := false;
begin

  pico_encoder_bench : pico_encoder
    port map (
      clk_in   => clk,
      uart_rx => rx,
      uart_tx  => open);

  clock : process
  begin
    if not stop_bench then
      clk <= '1';
      wait for period / 2;
      clk <= '0';
      wait for period / 2;
    end if;
  end process;


  estimulo : process
  begin
    wait for period * 2000;

    stop_bench <= true;
    wait;
  end process estimulo;
end architecture;
