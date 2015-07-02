# Encoder Base64

Implementación hecha con [PicoBlaze](http://www.xilinx.com/products/intellectual-property/picoblaze.html) de un encoder base 64.

## Puertos de Pico Encoder

Los puertos que se definieron para interactuar desde un programa pico blaze son:

### Puertos de entrada

#### 0x00: Estado de la UART

Expone el estado de la UART en los siguientes bytes

 * [0]: TX data present
 * [1]: TX half full
 * [2]: TX full
 * [3]: RX data present
 * [4]: RX half full
 * [5]: Rx full
 * [6:7]: Sin uso

#### 0x01: Lectura de datos

Mediante este puerto se reciben datos de la UART

 * [0-7]: Byte recibido desde uart_rx.

#### 0x02: Cantidad de bytes procesados

 * [6:0]: Una vez disparada la excepción de finalización del procesamiento, en este registro
 se expone la cantidad de bytes que el encoder procesó y que están disponibles para leer
 en el buffer de resultado.  Máximo 89 bytes dado el límite de 64 bytes en la entrada.

#### 0x03: Dato leido del buffer de resultado del encoder

 * [7:0]: Dato que se leyó de la posición de memoria de resultado indicada en el puerto de salida 0x06.

### Puertos de salida

#### 0x00: Control de la UART

Este puerto está mapeado también al puerto optimizado de constantes (k_write) ya que los 
valores que se manejan en general son constantes, pero de todas formas también permite
escribirlo desde un registro o posición dememoria.

 * [0]: Cuando se pone a uno resetea el TX.
 * [1]: Cuando se pone a uno resetea el RX.
 * [2-7]: Sin uso.

#### 0x01: Escritura de datos

Mediante este puerto se envían datos a la UART

 * [0-7]: Byte a escribir en uart_tx.

#### 0x02: Registro de control del encoder

También está mapeado tanto al puerto de escritura normal como al optimizado por constantes (k_write).
Para más información ver el manual de KCPSM6.

 * [0]: Reset del encoder.
 * [1]: Habilita escritura en la memoria del encoder para escribir los datos a encodear.
 * [2:7]: Sin uso.

#### 0x03: Dirección a escribir en el buffer de memoria del encoder

 * [0:5]: Dirección dentro del buffer de memoria del encoder donde se va a escribir.
 * [6:7]: Sin uso.  Procesa hasta 64 bytes, con 6 bits se maneja todo el espacio de memoria.

#### 0x04: Byte a escribir en el encoder

 * [0:7]: Byte que se va a escribir en la posición de memoria del encoder especificada en el puerto 0x03.

#### 0x05: Cantidad de bytes a procesar

 * [0:5]: Se interpreta como un entero sin signo de rango 1 a 64 y representa la cantidad de bytes,
 leidos de la memoria buffer del encoder, a procesar.  El hecho de escribir el valor es condición
 necesaria y suficiente para que el encoder comience a procesar.  Finaliza disparando una excepción.

#### 0x06: Dirección a leer del buffer de resultado del encoder

 * [0:6]: Dirección de memoria en el buffer de resultado para leer.  Como máximo podrán leerse 89 bytes
 producto de codificar el máximo de 64 bytes de entrada.