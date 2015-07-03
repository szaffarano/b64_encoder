library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

------------------------------------------------------------------------------
-- Definición de la entidad,sólo envia y recibe a través de la UART.
------------------------------------------------------------------------------
entity pico_encoder is
  port (
    uart_rx : in  std_logic;
    uart_tx : out std_logic;
    clk_in  : in  std_logic);
end entity;

architecture arch of pico_encoder is

  ------------------------------------------------------------------------------
  -- Componentes
  ------------------------------------------------------------------------------
  -- Encoder B64
  component encoder
    port (
      clk              : in  std_logic;
      rst              : in  std_logic;
      we               : in  std_logic;
      ain              : in  std_logic_vector(5 downto 0);
      din              : in  std_logic_vector(7 downto 0);
      aout             : in  std_logic_vector(6 downto 0);
      dout             : out std_logic_vector(7 downto 0);
      bytes_to_process : in  natural range 1 to 64;
      processed_bytes  : out natural range 1 to 90;
      ready            : out std_logic);
  end component;

  -- PicoBlaze
  component kcpsm6
    generic(
      hwbuild                 : std_logic_vector(7 downto 0)  := X"00";
      interrupt_vector        : std_logic_vector(11 downto 0) := X"3FF";
      scratch_pad_memory_size : integer                       := 64);
    port (
      address        : out std_logic_vector(11 downto 0);
      instruction    : in  std_logic_vector(17 downto 0);
      bram_enable    : out std_logic;
      in_port        : in  std_logic_vector(7 downto 0);
      out_port       : out std_logic_vector(7 downto 0);
      port_id        : out std_logic_vector(7 downto 0);
      write_strobe   : out std_logic;
      k_write_strobe : out std_logic;
      read_strobe    : out std_logic;
      interrupt      : in  std_logic;
      interrupt_ack  : out std_logic;
      sleep          : in  std_logic;
      reset          : in  std_logic;
      clk            : in  std_logic);
  end component;

  -- ROM del programa de PicoBlaze
  component pico_encoder_rom
    generic(
      C_FAMILY             : string  := "7S";
      C_RAM_SIZE_KWORDS    : integer := 2;
      C_JTAG_LOADER_ENABLE : integer := 0);
    port (
      address     : in  std_logic_vector(11 downto 0);
      instruction : out std_logic_vector(17 downto 0);
      enable      : in  std_logic;
      rdl         : out std_logic;
      clk         : in  std_logic);
  end component;

  -- uart_tx
  component uart_tx6
    port (
      data_in             : in  std_logic_vector(7 downto 0);
      en_16_x_baud        : in  std_logic;
      serial_out          : out std_logic;
      buffer_write        : in  std_logic;
      buffer_data_present : out std_logic;
      buffer_half_full    : out std_logic;
      buffer_full         : out std_logic;
      buffer_reset        : in  std_logic;
      clk                 : in  std_logic);
  end component;

  -- uart_rx
  component uart_rx6
    port (
      serial_in           : in  std_logic;
      en_16_x_baud        : in  std_logic;
      data_out            : out std_logic_vector(7 downto 0);
      buffer_read         : in  std_logic;
      buffer_data_present : out std_logic;
      buffer_half_full    : out std_logic;
      buffer_full         : out std_logic;
      buffer_reset        : in  std_logic;
      clk                 : in  std_logic);
  end component;

  -- DCM ejecutando a 50 Mhz
  component dcm_50mhz
    port(
      clk_in : in  std_logic;
      clk    : out std_logic);
  end component;

  ------------------------------------------------------------------------------
  -- Señales
  ------------------------------------------------------------------------------
  -- Señales del encoder
  signal rst              : std_logic;
  signal we               : std_logic;
  signal buff_addr        : std_logic_vector(5 downto 0);
  signal buff_data        : std_logic_vector(7 downto 0);
  signal result_addr      : std_logic_vector(6 downto 0);
  signal result_data      : std_logic_vector(7 downto 0);
  signal bytes_to_process : natural range 1 to 64;
  signal processed_bytes  : natural range 1 to 90;
  signal processed        : std_logic := '0';

  -- Clock a 50Mhz
  signal clk : std_logic;

  -- Señales de PicoBlaze
  signal address        : std_logic_vector(11 downto 0);
  signal instruction    : std_logic_vector(17 downto 0);
  signal bram_enable    : std_logic;
  signal in_port        : std_logic_vector(7 downto 0);
  signal out_port       : std_logic_vector(7 downto 0);
  signal port_id        : std_logic_vector(7 downto 0);
  signal write_strobe   : std_logic;
  signal k_write_strobe : std_logic;
  signal read_strobe    : std_logic;
  signal interrupt      : std_logic := '0';
  signal interrupt_ack  : std_logic;
  signal kcpsm6_sleep   : std_logic;
  signal kcpsm6_reset   : std_logic;
  signal rdl            : std_logic;

  -- Señales para el componente tx
  signal uart_tx_data_in      : std_logic_vector(7 downto 0);
  signal write_to_uart_tx     : std_logic;
  signal pipe_port_id0        : std_logic := '0';
  signal uart_tx_data_present : std_logic;
  signal uart_tx_half_full    : std_logic;
  signal uart_tx_full         : std_logic;
  signal uart_tx_reset        : std_logic;

  -- Señales para el componente rx
  signal uart_rx_data_out     : std_logic_vector(7 downto 0);
  signal read_from_uart_rx    : std_logic := '0';
  signal uart_rx_data_present : std_logic;
  signal uart_rx_half_full    : std_logic;
  signal uart_rx_full         : std_logic;
  signal uart_rx_reset        : std_logic;

  -- Señal usada por el generador de baud rate
  signal baud_rate_counter : integer range 0 to 26 := 0;
  signal en_16_x_baud      : std_logic             := '0';

begin
  -- Encoder
  enc : encoder
    port map (
      clk              => clk,
      rst              => rst,
      we               => we,
      ain              => buff_addr,
      din              => buff_data,
      aout             => result_addr,
      dout             => result_data,
      bytes_to_process => bytes_to_process,
      processed_bytes  => processed_bytes,
      ready            => processed);

  -- PicoBlaze
  processor : kcpsm6
    generic map (hwbuild                 => X"41",  -- 41 hex is ASCII Character "A"
                 interrupt_vector        => X"7FF",
                 scratch_pad_memory_size => 64)
    port map(address        => address,
             instruction    => instruction,
             bram_enable    => bram_enable,
             port_id        => port_id,
             write_strobe   => write_strobe,
             k_write_strobe => k_write_strobe,
             out_port       => out_port,
             read_strobe    => read_strobe,
             in_port        => in_port,
             interrupt      => interrupt,
             interrupt_ack  => interrupt_ack,
             sleep          => kcpsm6_sleep,
             reset          => kcpsm6_reset,
             clk            => clk);

  -- conecto el reset con rdl de la rom para que funcione jtag loader
  kcpsm6_reset <= rdl;

  -- Señales no usadas, se puentean para que ISE no de warnings...
  kcpsm6_sleep <= write_strobe and k_write_strobe;

  -- Instanciar la ROM de PicoBlaze
  program_rom : pico_encoder_rom
    generic map(C_FAMILY             => "7S",
                C_RAM_SIZE_KWORDS    => 2,
                C_JTAG_LOADER_ENABLE => 1)
    port map(address     => address,
             instruction => instruction,
             enable      => bram_enable,
             rdl         => rdl,
             clk         => clk);

  -- Instanciar UART TX
  tx : uart_tx6
    port map (
      data_in             => uart_tx_data_in,
      en_16_x_baud        => en_16_x_baud,
      serial_out          => uart_tx,
      buffer_write        => write_to_uart_tx,
      buffer_data_present => uart_tx_data_present,
      buffer_half_full    => uart_tx_half_full,
      buffer_full         => uart_tx_full,
      buffer_reset        => uart_tx_reset,
      clk                 => clk);

  -- Instanciar UART RX
  rx : uart_rx6
    port map (
      serial_in           => uart_rx,
      en_16_x_baud        => en_16_x_baud,
      data_out            => uart_rx_data_out,
      buffer_read         => read_from_uart_rx,
      buffer_data_present => uart_rx_data_present,
      buffer_half_full    => uart_rx_half_full,
      buffer_full         => uart_rx_full,
      buffer_reset        => uart_rx_reset,
      clk                 => clk);

  -- Instanciar DCM
  clock : dcm_50mhz
    port map(
      clk_in => clk_in,
      clk    => clk);

  --
  -- Generador del baud rate (ver referencia del componente)
  -- Hay que enviar a en_16_x_baud un pulso alto en flanco ascendente
  -- cada 16 x baud rate hz.  Con un reloj a 50 Mhz y una velocidad de TX
  -- de 115200, entonces: 50.000.000 / (16 x 115200) = ~26
  -- Lo que da un error de 0.5% que está dentro de lo aceptable.
  -- Modificar esta lógica si cambia:
  --      BAUD RATE: 115200 bps
  --      CLK: 50Mhz
  baud_rate : process(clk)
  begin
    if clk'event and clk = '1' then
      if baud_rate_counter = 26 then
        baud_rate_counter <= 0;
        en_16_x_baud      <= '1';
      else
        baud_rate_counter <= baud_rate_counter+1;
        en_16_x_baud      <= '0';
      end if;
    end if;
  end process baud_rate;

  ------------------------------------------------------------------------------
  -- Manejo de puertos de Entrada
  -- Ver archivo Readme.md
  ------------------------------------------------------------------------------
  input_ports : process(clk)
  begin
    if clk'event and clk = '1' then
      case port_id(1 downto 0) is

        when "00" =>
          in_port(0) <= uart_tx_data_present;
          in_port(1) <= uart_tx_half_full;
          in_port(2) <= uart_tx_full;
          in_port(3) <= uart_rx_data_present;
          in_port(4) <= uart_rx_half_full;
          in_port(5) <= uart_rx_full;

        when "01" =>
          in_port <= uart_rx_data_out;

        when "10" =>
          in_port <= std_logic_vector(to_unsigned(processed_bytes, in_port'length));

        when "11" =>
          in_port <= result_data;

        when others => 
          in_port <= "XXXXXXXX";
      end case;

      -- Mandar un pulso a buffer_read para indicarle a la UART que se
      -- realizó una lectura (solo si leyeron -read_strobe- en el puerto 1).
      if (read_strobe = '1') and (port_id(0) = '1') then
        read_from_uart_rx <= '1';
      else
        read_from_uart_rx <= '0';
      end if;
    end if;
  end process input_ports;

  ------------------------------------------------------------------------------
  -- Manejo de puertos de Salida
  --  Ver archivo Readme.md en el proyecto
  ------------------------------------------------------------------------------
  output_ports : process(clk)
  begin
    if rising_edge(clk) then
      if write_strobe = '1' then
        case port_id(2 downto 0) is
--          when "001" =>
--            uart_tx_data_in  <= out_port;
--            write_to_uart_tx <= '1';
          when "010" =>
            rst <= out_port(0);
            we  <= out_port(1);
          when "011" =>
            buff_addr <= out_port(5 downto 0);
          when "100" =>
            buff_data <= out_port;
          when "101" =>
            bytes_to_process <= to_integer(unsigned(out_port(6 downto 0)));
          when "110" =>
            result_addr <= out_port(6 downto 0);
          when others =>
          --  write_to_uart_tx <= '0';
        end case;
      --else
       -- write_to_uart_tx <= '0';
      end if;
    end if;
  end process output_ports;

  uart_tx_data_in <= out_port;
  write_to_uart_tx  <= '1' when (write_strobe = '1') and (port_id(2 downto 0) = "001")
                           else '0';                     

  -- Reset de la uart, también por puerto 1
  constant_output_ports : process(clk)
  begin
    if clk'event and clk = '1' then
      if k_write_strobe = '1' then

        if port_id(0) = '1' then
          uart_tx_reset <= out_port(0);
          uart_rx_reset <= out_port(1);
        end if;

      end if;
    end if;
  end process constant_output_ports;

  --
  -- Manejo de interrupt e interrupt_ack por "closed loop"
  -- Ver manual de KCPSM6.  Es para evitar perder una interrupción que está
  -- alta menos de dos ciclos o durante sleep del procesador. 
  --
  interrupt_control : process(clk)
  begin
    if rising_edge(clk) then
      if interrupt_ack = '1' then
        interrupt <= '0';
      else
        if processed = '1' then
          interrupt <= '1';
        else
          interrupt <= interrupt;
        end if;
      end if;
    end if;
  end process;
end architecture;
