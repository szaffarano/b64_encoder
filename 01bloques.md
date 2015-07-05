---
layout: page
title: Diagrama de bloques
permalink: /bloques/
categories: doc
tags: doc vhdl
---

* TOC
{:toc}

## B64_encoder

La entidad `b64_encoder` es el encoder propiamente dicho, quién realiza la lógica de conversión de una cadena de bytes a Base64.  Está definida por:

{% highlight vhdl %}
entity b64_encoder is
  port (
    clk, rst, en, we : in  std_logic;
    din              : in  std_logic_vector(7 downto 0);
    busy             : out std_logic;
    ready            : out std_logic;
    dout             : out std_logic_vector(7 downto 0));
end entity;
{% endhighlight %}

Su funcionamiento consiste en recibir los bytes a través del puerto `din` y escribir los bytes codificados al puerto `dout`.  La señal `en` lo activa, de forma tal que al pasar a uno comenzará a procesar lo que lea de su entrada, y a la vez cuando `we` esté en uno leerá datos, caso contrario quedará en *standby* hasta que dicha señal vuelva a estar en uno.  Por último, como luego de finalizar la escritura de bytes (y por ende poner en cero la señal `en`) aún habrá bytes en el bus de salida (recordar que por cada 3 bytes de entrada el periférico "devuelve" cuatro), recién se dará por finalizada la codificación cuando la señal `ready` esté en uno.

{% include image.html src="../assets/rtl/rtl4.png" width="30%" %}

## Encoder

Esta entidad utiliza a la definida previamente, agregando además sendos *buffers* de memoria, los cuales van a usarse para escribir los datos a codificar y los datos codificados propiamente dichos.  El código VHDL que la define es:

{% highlight vhdl %}
entity encoder is
  port (
    clk              : in  std_logic;
    rst              : in  std_logic;
    we               : in  std_logic;
    ain              : in  std_logic_vector(5 downto 0);
    din              : in  std_logic_vector(7 downto 0);
    aout             : in  std_logic_vector(6 downto 0);
    dout             : out std_logic_vector(7 downto 0);
    bytes_to_process : in  std_logic_vector(6 downto 0);
    processed_bytes  : out std_logic_vector(6 downto 0);
    ready            : out std_logic);
end entity;
{% endhighlight %}

Los dos bloques de memoria están implementados utilizando la IP [Block Memory Generator V7.3][memory] provista por Xilinx, y configurados como *dual port*, esto es, dos buses de lectura independientes y sólo uno de escritura.

En el siguiente esquema se puede observar la interacción entre los componentes mencionados previamente:

{% include image.html src="../assets/rtl/rtl3.png" width="100%" %}

Para realizar una codificación hay que seguir una serie de pasos:

1. Poner en uno la señal `we`, la cual permite escribir en el buffer de entrada, llamado `ram_buffer` en el diagrama de más arriba.
1. Indicar en `ain` la dirección en donde se quiere escribir.
1. Escribir el byte en `din`.
1. Repetir los dos pasos previos tantas veces como bytes tena la cadena a codificar.  Al finalizar poner a cero `we`.
1. Escribir en el registro `bytes_to_process` la cantidad de bytes que se desean codificar.  Tener en cuenta que se comienza a codificar desde la posición 0x00 de memoria.
1. Aguardar a que la señal `ready` se ponga en uno.
1. En el registro `processed_bytes` estará la cantidad de bytes que representa el resultado de la codificación.
1. Escribiendo en `aout` la dirección que se quiere leer y leyéndola de `dout` se obtendrá el resultado (ubicado en el bloque de memoria `ram_result`).

## Pico Encoder

La tercera entidad, `pico_encoder` es quien expone el periférico antes descrito para ser manejado por un microprocesador [PicoBlaze][picoblaze].  La define el siguiente códifo VHDL:

{% highlight vhdl %}
entity pico_encoder is
  port (
    uart_rx : in  std_logic;
    uart_tx : out std_logic;
    clk_in  : in  std_logic);
end entity;
{% endhighlight %}

Observar que sólo expone registros para interactuar mediante una interfaz RS232.  Internamente se mapearán algunos puertos de E/S del microcontrolador de forma tal que el programa desarrollado para PicoBlaze pueda, por un lado acceder a los registros del encoder, y por el otro interactuar con el *mundo exterior* mediante la *UART*.

El siguiente diagrama de bloques muestra cómo se relacionan los diversos componentes de la entidad:

{% include image.html src="../assets/rtl/rtl2.png" width="100%" %}

Notar que además del encoder, descrito en apartados anteriores, y el picoblaze propiamente dicho, componente `kcpsm6`, también se ve la ROM usada para almacenar el programa ensamblador usado para manejar el encoder y la UART.  También se ven los componentes de transmisión y recepción de la UART, `uart_tx6` y `uart_rx6` respectivamente.  Y por último también se observa un DCM, también generado a partir de la IP [LogiCore Clock Generator V3.6][dcm] provista por Xilinx, `dcm_50mhz`, usado para manejar el reloj interno de todos los componentes a 50 MHz.

Remitirse a la página de [Puertos de E/S](/es) para un detalle del mapeo de puertos en PicoBlaze.

[memory]: 		http://www.xilinx.com/products/intellectual-property/block_memory_generator.html
[picoblaze]:    http://www.xilinx.com/products/intellectual-property/picoblaze.html
[dcm]: 			http://www.xilinx.com/support/documentation/ip_documentation/clk_wiz/v4_2/pg065-clk-wiz.pdf