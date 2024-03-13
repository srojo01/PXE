# PXE
Instalación por Red(PXE) OpenSUSE | VirtualBox


```
Curso       : 2023/24
Área        : Sistemas operativos, servidor, instalar, PXE
Descripción : Servidor de instalaciones PXE con OpenSUSE
Requisitos  : GNU/Linux OpenSUSE, VirtualBox
Tiempo      : 8 horas
```

# Servidor de instalaciones PXE con OpenSUSE

> Enlaces de interés:

> * [Puesta en marcha de un servidor PXE con OpenSUSE 15.0](https://es.opensuse.org/SDB:Puesta_en_marcha_de_un_servidor_PXE)
> * [Instalación OpenSUSE mediante TFTP y PXE](https://miguelcarmona.com/articulos/instalacion-de-opensuse-por-red-mediante-tftp-pxe)
> * Vídeo [LINUX: PXE Installation Server](https://youtu.be/59TwMw_CJwQ)
> * Vídeo [LINUX: Installing from the network](https://www.youtube.com/watch?v=mPARmfWizBI)

## Introducción

> Texto extraído del enlace [Puesta en marcha de un servidor PXE con OpenSUSE 15.0](https://es.opensuse.org/SDB:Puesta_en_marcha_de_un_servidor_PXE)`

¿Qué es y para que sirve montar un servidor de instalaciones PXE en nuestra red local?
* Nos permite iniciar la instalación de un sistema operativo a través
de la red sin necesidad de grabar un disco CD/DVD o utilizar un pendrive.
* También nos sirve para iniciar un sistema Live u otras herramientas, en nuestras máquinas sin sistema operativo instalado. En este caso los equipos cliente no requieren de disco duro.

Con un servidor de este tipo en nuestra red, únicamente tendremos que descargar las ISO y conseguimos un método muy rápido de instalación que además prescinde de medios físicos.


**Propuesta de rúbrica:**

| ID  | Criterio               | Bien(2) | Regular(1) | Poco adecuado(0) |
| --- | ---------------------- | ------- | ---------- | ---------------- |
| 2.4 | Comprobar DHCP ||||
| 3.3 | Comprobar TFTP ||||
| 4.3 | Comprobar NFT  ||||
| 5.3 | Comprobar menú desde el cliente ||||
| 6.2 | Comprobar proceso completo ||||

# 1. Preparativos

Abrimos Terminal:
```
sudo zypper install neofetch
neofetch --ascii_distro openSUSE
```
Editamos con:
```
nano ~/.bashrc
```
Introducimos al final del script:
```
neofetch --ascii_distro openSUSE
```
Usaremos 2 MV:

| Id | SSOO | Nombre de host | Interfaz 1 externa | Interfaz 2 interna |
| -- | ---- | -------------- | ---------- | ---------- |
| MV1 |[OpenSUSE](https://download.opensuse.org/distribution/leap/15.5/iso/openSUSE-Leap-15.5-DVD-x86_64-Media.iso) | pxe-serverXX | IP estática (172.18.XX.31/16) | Red interna "netintXX" con IP estática (192.168.XX.31/24) |
| MV2 | Sin sistema operativo | | Red interna "netintXX" ||

![](photos/pxe-esquema.svg)

> OJO👀: La red interna "netint" se configura en VirtualBox.

Todas las tarjetas de red de hoy en día soportan arranque mediante PXE. Es conveniente revisar la EFI/BIOS del equipo para asegurarnos de tenerlo activo. En nuestro caso, lo haremos por VirtualBox.

* Ir a VirtualBox.
* Configurar de la MV 2.
* `VirtualBox -> Sistema -> Arranque -> Red/LAN/PXE`.

Para montar el servicio PXE en la MV1 necesitaremos el servicio DHCP, el servicio TFTP y el servicio NFS. Vamos a ir uno a uno.

*En MV1 Instalar OpenSSH, que está [**src/openssh-install.sh**](https://github.com/srojo01/PXE/blob/main/src/openssh-install.sh):
```
./src/openssh-install.sh
```
Si por algun motivo despues de hacer una conexión no nos deja volver a conectarnos por ssh, es decir se queda pensando la conexión, hacer en el SO que se quiere conectar:
```
systemctl status sshd
sudo systemctl start sshd
sudo firewall-cmd --state
sudo firewall-cmd --add-service=ssh --permanent
sudo firewall-cmd --reload
```
`#addicionalmente`
```
sudo firewall-cmd --list-services
ping <ip-adaptador-usado>
``````

# 2. Servicio DHCP

Será en encargado de ofrecer configuración de red a las máquinas, y de suministrarles el fichero de arranque que necesitan para iniciarse.

## 2.1 Instalar el servicio DHCP

* Ir la MV1.
* Instalamos el servicio DHCP (`zypper in dhcp-server yast2-dhcp-server`) o ejecutamos el archivo **[dhcp-server-install.sh](https://github.com/srojo01/PXE/blob/main/src/dhcp-server-install.sh)** que hay en la carpeta **src** del github
```
./src/dhcp-server-install.sh
```

## INFO 💡💎: Ideas para scripting del apartado anterior

Supongamos que queremos prepararnos para incluir este apartado en un script.
En tal caso nuestro algoritmo sería el siguiente:

```
Si (el paquete dhcp-server no está instalado) entonces
  Instalar el paquete dhcp-server
fin si
```

Lo que debemos hacer es pensar en cómo lo hemos hecho nosotros. Es decir, ¿qué comandos hemos ejecutado para hacerlo? y luego poner esos comandos en un fichero de texto (más o menos)

```shell script
#!/bin/bash

# Nos preguntamos si existe el fichero de configuración
if [ ! -f "/etc/dhcpd.conf" ]; then
  # Si el fichero de configuración no existe... podemos suponer que el paquete no está instalado
  # entonces vamos a instalar el paquete dhcp-server
  zypper install dhcp-server
fi

```

## 2.2 Configurar interfaz de red

Queremos que el servicio PXE sólo se ofrezca por el interfaz de red 2 (El de la red interna).
Recordemos que MV1 tiene 2 interfaces de red.
* Hacemos una copia del fichero antes de modificarlo `cp /etc/sysconfig/dhcpd /etc/sysconfig/dhcp.bak`.
    ```
    ./src/dhcp-backup.sh
    ```
* Edita el archivo `/etc/sysconfig/dhcpd` y en la línea `DHCPD_INTERFACE=""`
añadir el nombre de interfaz que está en la red interna.

🧑‍🏫 _¿Recuerdas el comando para consultar los nombres de las interfaces de red disponibles?_

Con esto estamos diciendo al servicio que sólo trabaje por el interfaz de red que le hemos especificado.

## 2.3 Configurar DHCP

Modificamos el fichero de configuraciób del servicio DHCP.
* Hacemos una copia del fichero antes de modificarlo: `cp /etc/dhcpd.conf /etc/dhcpd.conf.bak`
* 🖥 ¿Qué tal configurar por Yast?
* Edita el fichero `/etc/dhcpd.conf`:

```
option domain-name "CURSO2324";
option domain-name-servers 1.1.1.1, 8.8.4.4;

ddns-updates off;
ddns-update-style none;

# If this DHCP server is the official DHCP server for the local
# network, the authoritative directive should be uncommented.
#authoritative;

# Solamente se atenderán peticiones DHCP de tipo PXE
allow booting;
allow bootp;

# Reglas para identificar peticiones DHCP desde clientes PCE y Etherboot

class "pxe" {
  match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
}
class "etherboot" {
  match if substring (option vendor-class-identifier, 0, 9) = "Etherboot";
}

# Las direcciones de ese tipo quedarán englobadas en esta subnet
subnet 192.168.XX.0 netmask 255.255.255.0 {
  pool {
    # con este rango hay de sobra
    range 192.168.XX.201 192.168.XX.220;
    
    filename "pxelinux.0";
    # Coincide con la IP del servidor
    server-name "192.168.XX.31";
    # Dirección del servidor TFTP         
    next-server 192.168.XX.31;           
    option subnet-mask 255.255.255.0;
    option broadcast-address 192.168.XX.255;
    option routers 192.168.XX.31;
    # permitido sólo para clientes PXE
    allow members of "pxe";              
    # y también para los de etherboot
    allow members of "etherboot";        
  }
}
```

> ⚠️ Si ya hay un servidor DHCP funcionando en tu red, no quites el comentario a la línea #authoritative;

De esta forma, nuestro servidor DHCP sólo atenderá las peticiones del tipo PXE, dejando el resto de peticiones para el sevidor DHCP de nuestra red.

Las peticiones DHCP que nos interesan las filtramos mediante las dos reglas que se han definido.

| Atributo | Descripción |
| -------- | ----------- |
| range    | define que el servidor repartirá un máximo de 20 direcciones simultáneas (Desde la 192.168.XX.201 hasta la 192.168.XX.220) |
| filename | toma el valor pxelinux.0 y los campos server-name y next-server de la IP que le hayamos dado al servidor. |

* Configurar el arranque automático del servicio "dhcpd" en MV1.

> Si cuando inicies el cliente ves que se le asigna una IP... entonces podemos suponer que el servicio DHCP está asignando IP's correctamente.

## 2.4 Comprobar

* `ip a` interfaces de red.
  ```
  ip a
  ```
* `ip route`, puerta de enlace.
  
  ```
  ip route
  ```
* `cat /etc/sysconfig/dhcpd | grep DHCPD_INTERFACE`.
  ```
  cat /etc/sysconfig/dhcpd | grep DHCPD_INTERFACE
  ```
* Comprobar el estado correcto del servicio DHCP (`systemctl status dhcpd`)
  ```
  systemctl status dhcpd
  ```
  Output Command que deberiamos ver:
  > ○ dhcpd.service - ISC DHCPv4 Server <br />
  >    Loaded: loaded (/usr/lib/systemd/system/dhcpd.service; disabled; vendor pr> <br />
  >    **Active: inactive** (dead) <br />
  
  Adicionalmente:`
  ```
  sudo systemctl start dhcpd
  sudo systemctl enable dhcpd
  sudo systemctl status dhcpd
  ```

# 3. Servicio TFTP

## 3.1 Instalar el servicio

* Instalar los paquetes: atftp y yast2-tftp-server con el archivo [**src/atftpANDyast2-tftp-server-install.sh**](https://github.com/srojo01/PXE/blob/main/src/atftpANDyast2-tftp-server-install.sh)

```
./src/atftpANDyast2-tftp-server-install.sh
```
Si por algún motivo no está añadido el paquete en Yast2, hacer lo siguiente:
```
zypper addrepo https://download.opensuse.org/repositories/YaST:/Head/openSUSE_Leap_15.5/YaST:Head.repo
zypper refresh
zypper install yast2-tftp-server
```
Adicionalmente si quiero quitar un repositorio:
```
sudo zypper repos --details
sudo zypper removerepo repo-oss #repo-oss es el nombre del identificador del repositorio
```

Si está  bien instalado tiene que mostrar algo tal que así:
```
   ubu@servidorpxe:~/Downloads/PXE> sudo zypper search atftp
   Cargando datos del repositorio...
   Leyendo los paquetes instalados...
    
   S  | Name              | Summary                             | Type
   ---+-------------------+-------------------------------------+------------
   i+ | atftp             | Servidor y cliente TFTP avanzado    | paquete
      | atftp             | Servidor y cliente TFTP avanzado    | paquete src
      | atftp-debuginfo   | Debug information for package atftp | paquete
      | atftp-debugsource | Debug sources for package atftp     | paquete
   ubu@servidorpxe:~/Downloads/PXE> sudo zypper search tftp-server
   Cargando datos del repositorio...
   Leyendo los paquetes instalados...
    
   S  | Name              | Summary                                  | Type
   ---+-------------------+------------------------------------------+------------
   i+ | yast2-tftp-server | YaST2: configuración de un servidor TFTP | paquete
      | yast2-tftp-server | YaST2: configuración de un servidor TFTP | paquete src

```

## 3.2 Cambiar la configuración

* Editar el archivo `/etc/sysconfig/atftpd` (Hacemos copia de seguridad del fichero antes de modificarlo)
```
cp /etc/sysconfig/atftpd /etc/sysconfig/atftpd.bak
```

```
# daemon user (tftp)
ATFTPD_USER="tftp"
ATFTPD_GROUP="tftp"

# atftpd options
ATFTPD_OPTIONS="--daemon --user tftp -v"

# Use inetd instead of daemon
ATFTPD_USE_INETD="no"

# TFTP directory must be a world readable/writable directory.
# By default /srv/tftpboot is assumed.
ATFTPD_DIRECTORY="/srv/tftpboot"

## Type:    string
## Default: ""
#
#  Whitespace seperated list of IP addresses which ATFTPD binds to.
#  By default atftpd will listen on all available IP addresses/interfaces.
ATFTPD_BIND_ADDRESSES="192.168.XX.31"
```

Con esta configuración:
* El servicio se ejecutará con la cuenta de usuario `tftp` perteneciente al grupo del mismo nombre, asegúrate de que existen.
* Toma nota también del directorio raíz del servidor TFTP, `/srv/tftpboot`.
* Configurar el arranque automático del servicio `atftpd`.
* Iniciar el servicio.

## 3.3 Comprobar
```
cat /etc/sysconfig/atftpd | grep ATFTPD_BIND_ADDRESSES
```
La salida del comando debería ser:
>ATFTPD_BIND_ADDRESSES="192.168.XX.31"
* Comprobar el estado correcto del servicio TFTP.
``` 
sudo systemctl status atftp
```
La salida del comando debería ser:
```    
● atftpd.socket - Advanced tftp Server Activation Socket 
    Loaded: loaded (/usr/lib/systemd/system/atftpd.socket; disabled; vendor preset: disabled) 
    **Active: active (listening)** since Tue 2024-03-05 15:16:31 CET; 22s ago 
    Triggers: ● atftpd.service 
    Listen: 0.0.0.0:69 (Datagram) 
    Tasks: 0 (limit: 4915) 
    CGroup: /system.slice/atftpd.socket 
    
    Mar 27 15:16:31 localhost.localdomain systemd[1]: Listening on Advanced tftp Server Activation Socket.
```
## 3.4 Problemas al iniciar el servicio

**Problema 1**
Si tenemos problemas con los sockets al iniciar el servicio, probamos lo siguiente:

Para iniciar el socket primero:
```
systemctl start atftpd.socket
```
Para Habilitar el servicio.
```
systemctl enable atftpd
```
Para inciiar el servicio.
```
systemctl start atftpd
```
**Problema 2 (server-limit-hit)**
Para resolverlo hacemos lo siguiente:

```
pxe-server12:~ # systemctl status atftpd.socket
● atftpd.socket - Advanced tftp Server Activation Socket                                     
     Loaded: loaded (/usr/lib/systemd/system/atftpd.socket; enabled; vendor preset: disabled)
     Active: failed (Result: service-start-limit-hit) since Thu 2022-06-09 16:21:52 WEST; 16h ago
     Triggers: ● atftpd.service
     Listen: 0.0.0.0:69 (Datagram)
 
Jun 09 09:31:27 pxe-server12 systemd[1]: Listening on Advanced tftp Server Activation Socket.
Jun 09 16:21:52 pxe-server12 systemd[1]: atftpd.socket: Failed with result 'service-start-limit-hit'.

pxe-server12:~ # systemctl reset-failed atftpd.socket  
```

**Problema 3**
* Deshabilitar la línea `ATFTPD_OPTIONS` de la configuración.

# 4. Servicio NFS

Este servicio lo usaremos para tener carpetas compartidas vía red.

## 4.1 Instalar el servicio

* Instalar los paquetes nfs-kernel-server y yast2-nfs-server con [**/src/nfs-yast2-server-install.sh**](https://github.com/srojo01/PXE/blob/main/src/nfs-yast2-server-install.sh).
  ```
  ./src/nfs-yast2-server-install.sh
  ```

## 4.2 Configurar

* Descargamos una ISO en nuestra MV1 (Por ejemplo una de OpenSUSE).

> Si lo prefieres puedes usar una iso de instalación del sistema operativo que prefieras.
> Si usas la iso de instalación desatendida que hiciste en las prácticas anteriores... la instalación en los clientes será muy rápida.

* Crear directorio `/mnt/opensuse.iso.d`. Este directorio lo vamos a usar para leer el contenido del fichero ISO sin tener que desempaquetarlo.

* Cosas a saber antes de montar la ISO:
 
    -Para determinar si tu archivo ISO es de tipo UDF o ISO9660, puedes utilizar la herramienta file:
      ```
      file /ruta/a/la/iso/openSUSE.iso
      ```

   -Si el archivo ISO es de tipo ISO9660, verás algo similar a esto::
  >/path/to/openSUSE.iso: ISO 9660 CD-ROM filesystem data
  
  -Si el archivo ISO es de tipo UDF, verás algo similar a esto:
  >/path/to/openSUSE.iso: ISO 9660 CD-ROM filesystem data (DOS/MBR boot sector) 'SOMELABEL'
          

```
sudo mkdir /mnt/opensuse.iso.d
```
* Queremos acceder al contenido del fichero ISO pero sin "desempaquetarlo".
* Edita el fichero `/etc/fstab` y crea un punto de montaje para la ISO(recuerda poner si es _udf_ o _iso9660_:
```  
/ruta/a/la/iso/openSUSE.iso /mnt/opensuse.iso.d/ udf user,auto,loop 0 0
```
o
```  
/ruta/a/la/iso/openSUSE.iso /mnt/opensuse.iso.d/ iso9660 user,auto,loop 0 0
```

El directorio _/mnt/opensuse.iso.d/_ quedará tal que así:

>![](photos/mount.png)

* `mount -a`, se montan todas las configuraciones definidas en `/etc/fstab`.
* `df -hT`, comprobamos.
```
sudo df -hT
```

🧑‍🏫 _¿Ves el contenido de la ISO en la carpeta creada (punto de montaje)?_

Ahora vamos a exportar ese directorio mediante NFS. De esta forma, el contenido será accesible por la red LAN.
* Editar el archivo `/etc/exports`.
* Añadir `/mnt/opensuse.iso.d   *(ro,no_root_squash,async,no_subtree_check)`
* Configurar el arranque automático del servicio `nfsserver`.
  ```
  sudo systemctl enable nfsserver
  sudo systemctl enable nfsserver
  sudo systemctl start nfsserver
  ```
* Reiniciar el servidor NFS.
  ```
  sudo systemctl restart nfsserver
  sudo systemctl status nfsserver
  ```
## 4.3 Comprobar

* `df -hT | grep iso`
```
df -hT | grep iso
```
* `cat /etc/exports | grep iso`
```
cat /etc/exports | grep iso
```
* Comprobar el estado correcto del servicio (`systemctl status ...`).
```
sudo systemctl status nfs-server
```
>![](photos/nfsserver.png)

# 5. Menú de arranque

Ahora vamos a preparar el menú de arranque PXE que se encontrarán los clientes cuando inicien. En este menú podrán elegir el SO que se quiere instalar.

## 5.1 Preparando el menú

* `zypper in syslinux`, instalamos software. 🧑 _¿Para qué sirve este paquete?_
* En la raíz del servidor TFTP copiamos los siguientes archivos y creamos un par de directorios:

```bash
mkdir /srv/tftpbootp/xelinux.cfg
mkdir /srv/tftpboot/imagesXX
mkdir /srv/tftpboot/pxelinux.cfg
cp /usr/share/syslinux/pxelinux.0 /srv/tftpboot
cp /usr/share/syslinux/menu.c32 /srv/tftpboot
cp /usr/share/syslinux/reboot.c32 /srv/tftpboot
touch /srv/tftpboot/pxelinux.cfg/default
```

En el directorio `imagesXX` crearemos un subdirectorio por cada ISO que queramos arrancar desde la red. En cada uno de ellos almacenaremos el kernel y el ramdisk necesarios.

El archivo `default` será nuestro menú de arranque.

* Editar el archivo `/srv/tftpboot/pxelinux.cfg/default` y añade lo siguiente:

```
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300
ONTIMEOUT 0
NOESCAPE 1

MENU TITLE Menu de arranque - nombre-alumnoXX

LABEL 0
  MENU LABEL ^0. Arrancar desde el disco duro
  LOCALBOOT 0
  TEXT HELP
    Para arrancar desde el disco duro pulsa Enter.
  ENDTEXT

MENU SEPARATOR

LABEL 1
  MENU LABEL ^1. Reiniciar
  COM32 reboot.c32

MENU SEPARATOR
```

* Guardar los cambios al archivo.

## 5.2 TEORÍA

Repasemos un poco la sintaxis del fichero que hemos creado:
* **DEFAULT menu.c32**, define que cargaremos el menú en modo texto.
* **PROMPT 0**, para mostrar esta ventana sin pulsar ninguna tecla desde que cargue el PXE. Prueba a cambiar el 0 por un 1 y ver qué pasa, debes pulsar Enter para que cargue el menú principal.
* **TIMEOUT 300**, define un tiempo de espera de 30 segundos antes de cargar la opción predeterminada.
* **ONTIMEOUT 0**, define cuál será la entrada predeterminada del menú. Elegirá la que he nombrado como 0 (pueden usarse nombres en lugar de números).
* **NOESCAPE 1**, para evitar la salida del menú si se pulsa la tecla Escape. Como he definido entradas para reiniciar y arrancar desde el disco duro local puedo deshabilitar la salida a través de Escape.
* **MENU TITLE Menu de arranque**,  título de la pantalla que aparecerá a modo de cabecera.
* MENU BACKGROUND pxelinux.cfg/wall.jpg ruta y nombre de la imagen que usaremos como fondo del menú. Puede ser distinto para cada ventana, pero recuerda las limitaciones: únicamente cargarán archivos .jpg o .png con una resolución de 640x480 píxeles.
* **LABEL 0**, sirve para dar nombre a una entrada del menú.
* **MENU LABEL ^0**. Arrancar desde el disco duro, etiqueta que se mostrará. El símbolo ^ define una tecla rápida de acceso.
* **LOCALBOOT 0**, con esta orden podemos arrancar la máquina desde el disco duro local.
* **TEXT HELP** y **ENDTEXT** lo que escribamos entre estas dos líneas se mostrará en la parte inferior del menú como texto de ayuda al seleccionar cada entrada del menú.

Veamos qué podemos seguir aprendiendo de la sintaxis de estos ficheros:
* Estas dos líneas nos permiten pasar de una pantalla a otra.
    * KERNEL vesamenu.c32
    * APPEND pxelinux.cfg/default
* **MENU separator**, permite introducir una línea vacía.
* **LABEL empty**, define una entrada del menú no seleccionable.
* Una entrada típica para arrancar un sistema operativo incluirá las siguientes líneas:
   * LABEL nombre que le damos a la entrada.
   * MENU LABEL etiqueta que veremos en la pantalla.
   * KERNEL define la ruta y el nombre del kernel a enviar. También podemos usar la palabra LINUX si vamos a cargar un kernel de Linux.
   * INITRD define la ruta y el nombre del ramdisk que se cargará en memoria.
   * APPEND aquí especificaremos los parámetros adicionales de arranque.

## 5.3. Probando el menú desde el cliente

> OJO👀: Para evitar problemas de conectividad comprobar la configuración del cortafuegos en el servidor.

* Entregar un pequeño vídeo de este apartado.
* Reiniciar una máquina cliente. Puede que tengas que pulsar la tecla F12 durante el arranque para seleccionar el arranque PXE.
* Comprobar que accedemos al menú PXE. Aunque todavía nos faltan más opciones.

# 6. Configurar una imagen para instalar

## 6.1 Preparativos

Usaremos una carpeta dentro del TFTP para almacenar los ficheros que necesita
nuestra imagen para arrancar. Esto es: el kernel y el ramdisk.

Estos ficheros hay que copiarlos dentro de nuestro directorio `/srv/tftpboot/` para que el servidor PXE los envie a los clientes para que puedan arrancar.

En el caso que nos ocupa el kernel es un archivo llamado linuxXXX y el ramdisk initrdXXX. Ambos se encuentran dentro de la ISO en la ruta `boot/x86_64/loader/`.

* Crear subdirectorio y copiar archivos:

```bash
mkdir /srv/tftpboot/imagesXX/opensuse
cp /mnt/opensuse.iso.d/boot/x86_64/loader/linux /srv/tftpboot/imagesXX/opensuse/
cp /mnt/opensuse.iso.d/boot/x86_64/loader/initrd /srv/tftpboot/imagesXX/opensuse/
```

* Editar el fichero `/srv/tftpboot/pxelinux.cfg/default` y añadir lo siguiente:

```
LABEL 2
  MENU LABEL 2. opensuseXX
  LINUX imagesXX/opensuse/linux
  INITRD imagesXX/opensuse/initrd
  APPEND install=nfs://192.168.XX.31/mnt/opensuse.iso.d/ splash=silent ramdisk_size=512000 ramdisk_blocksize=4096 language=es_ES keytable=es quiet quiet showopts
  TEXT HELP
    Instalar openSUSE - nombre-del-alumnoXX
  ENDTEXT
```

## 6.2 Comprobar

**Incluir en la entrega un pequeño vídeo con lo siguiente:**
1. Iniciar MV cliente y comprobar el menú PXE.
2. Instalar SO en MV cliente.

El ramdisk de openSUSE permite acceder al contenido del DVD a través de NFS, lo cual es mucho más óptimo que hacerlo a través de TFTP. Ya veremos que hay casos en los que podemos pasar como parámetro directamente una ruta a la ISO o, si ésta es de pequeño tamaño, cargarla en memoria directamente. Pero en este caso no es lo más eficiente.

# 7. Otra ISO

poner otra ISO de instalación más en el servidor PXE? ¿Qué pasos hay que hacer?

# ANEXO

Enlaces de interés:
* https://graphviz.org/

## A.1 Poner imagen de fondo

* El fichero wall.jpg es una imagen que usaremos de fondo del menú. Se aceptan los archivos de imagen con un tamaño de 640x480 píxeles y extensiones .jpg o .png.
* Si prefieres una interfaz de texto y no quieres cargar una imagen de fondo copia el archivo menu.c32 en lugar de vesamenu.c32.

cp /usr/share/syslinux/vesamenu.c32 .
cp /ruta/al/fichero/wall.jpg pxelinux.cfg/

## A.2 Iniciar ISO clonezilla

```
LABEL 2
        MENU LABEL ^2. Clonezilla Live (64 bits)
        KERNEL imagenes/clonezillaXX/x64/vmlinuz
        INITRD imagenes/clonezillaXX/x64/initrd.img
        APPEND boot=live username=user hostname=saucy live-config quiet union=overlayfs noswap edd=on locales=es_ES.UTF-8 keyboard-layouts=es ocs_live_run="ocs-live-general" ocs_live_batch=no video=uvesafb:mode_option=1024x768-32 ip=frommedia splash netboot=nfs nfsroot=192.168.1.200:/mnt/clonezillax64/
```

## A.3 Ininicar ISO de Debian

* Descarga la ISO de Debian Live del sitio oficial y cópiala al servidor.
* Móntala en un subdirectorio de /mnt y expórtalo mediante NFS:
* `mkdir /mnt/debian.iso.d`
* `echo "/ruta/a/la/iso/debian-live-7.2-amd64-kde-desktop.iso /mnt/debian.iso.d udf,iso9660 user,auto,loop 0 0" >> /etc/fstab`
* `mount -a`
* `echo "/mnt/debian.iso.d *(ro,no_root_squash,async,no_subtree_check)" >> /etc/exports`
* service nfsserver restart
* Crea un subdirectorio debian en `/srv/tftpboot/imagenes/debianXX` y copia dentro los archivos vmlinuz e initrd.img que hay dentro de la ISO:
* mkdir /srv/tftpboot/imagenes/debian-Live
* cp /mnt/debian.iso.d/live/vmlinuz /srv/tftpboot/imagenes/debianXX/
* cp /mnt/debian.iso.d/live/initrd.img /srv/tftpboot/imagenes/debianXX/
* Edita el archivo /srv/tftpboot/pxelinux.cfg/sistemas y añade la siguiente entrada al final:

```
LABEL 2
       MENU LABEL ^2. Debian 7 Live x64
       KERNEL imagenes/debianXX/vmlinuz
       INITRD imagenes/debianXX/initrd.img
       APPEND boot=live config netboot=nfs nfsroot=192.168.XX.31:/mnt/debian.iso.d locales=es_ES.UTF-8 keyboard-layouts=es quiet
       TEXT HELP
         Arranca Debian - nombre-alumnoXX
       ENDTEXT
```

# A.4 Iniciar OpenSUSE en modo Live

```
LABEL 3
       MENU LABEL ^3. openSUSE 13.1 Live x64
       LINUX imagenes/openSUSE-Live/linux
       INITRD imagenes/openSUSE-Live/initrd
       APPEND splash=silent isofrom_device=nfs:192.168.1.200:/ruta/a/la/iso isofrom_system=openSUSE-13.1-KDE-Live-x86_64.iso language=es_ES keytable=es quiet quiet showopts
       TEXT HELP
       Arranca openSUSE en modo Live
       ENDTEXT
```

Los pasos a seguir serían sacar el kernel y el ramdisk a un subdirectorio del servidor TFTP y dejar la ISO en una ruta accesible a través de NFS (no es necesario montarla).
```
# mkdir /tmp/live && mkdir /srv/tftpboot/imagenes/openSUSE-Live
# mount -o loop -t iso9660 /ruta/a/la/iso /tmp/live
# cp /tmp/live/boot/x86_64/loader/linux /srv/tftpboot/imagenes/openSUSE-Live/
# cp /tmp/live/boot/x86_64/loader/initrd /srv/tftpboot/imagenes/openSUSE-Live/
# umount /tmp/live
```

**ANEXO REPOS**:

[Repositorios Necesarios OpenSuse](https://en.opensuse.org/Package_repositories) 
```
ls -la /etc/zypp/repos.d/
```
```
-rw-r--r-- 1 root root  182 mar  6 13:38 Backports_Debug-Update.repo
-rw-r--r-- 1 root root  164 mar  6 13:38 Backports_Update.repo
-rw-r--r-- 1 root root  179 mar  6 13:38 Debug-distribution.repo
-rw-r--r-- 1 root root  156 mar  6 13:38 GNOME:Apps.repo
-rw-r--r-- 1 root root  155 mar  6 13:38 Non-OSS.repo
-rw-r--r-- 1 root root  173 mar  6 13:38 openSUSE-Leap-15.5-1.repo
-rw-r--r-- 1 root root  109 mar  7 09:30 opensuse-oss.repo
-rw-r--r-- 1 root root  143 mar  6 13:38 OSS.repo
-rw-r--r-- 1 root root  244 mar  6 13:38 repo-backports-debug-update.repo
-rw-r--r-- 1 root root  199 mar  6 13:38 repo-backports-update.repo
-rw-r--r-- 1 root root  179 mar  6 13:38 repo-debug-non-oss.repo
-rw-r--r-- 1 root root  157 mar  6 13:38 repo-debug.repo
-rw-r--r-- 1 root root  183 mar  6 13:38 repo-debug-update-non-oss.repo
-rw-r--r-- 1 root root  162 mar  6 13:38 repo-debug-update.repo
-rw-r--r-- 1 root root  178 mar  6 13:38 repo-non-oss.repo
-rw-r--r-- 1 root root  164 mar  6 13:38 repo-openh264.repo
-rw-r--r-- 1 root root  167 mar  6 13:38 repo-oss.repo
-rw-r--r-- 1 root root  222 mar  6 13:38 repo-sle-debug-update.repo
-rw-r--r-- 1 root root  208 mar  6 13:38 repo-sle-update.repo
-rw-r--r-- 1 root root  160 mar  6 13:38 repo-source.repo
-rw-r--r-- 1 root root  183 mar  6 13:38 repo-update-non-oss.repo
-rw-r--r-- 1 root root  165 mar  6 13:38 repo-update.repo
-rw-r--r-- 1 root root  164 mar  6 13:38 SLE_Debug-Update.repo
-rw-r--r-- 1 root root  146 mar  6 13:38 SLE_Update.repo
-rw-r--r-- 1 root root  170 mar  6 13:38 Src-Non-OSS.repo
-rw-r--r-- 1 root root  158 mar  6 13:38 Src-OSS.repo
-rw-r--r-- 1 root root  158 mar  6 13:38 Update_Non-OSS.repo
-rw-r--r-- 1 root root  138 mar  6 13:38 Update.repo
```
Añadir repo en opensuse ChatGPT  
To add the repository http://download.opensuse.org/update/leap/15.5/backports_debug/ to /etc/zypp/repos.d/ in openSUSE, you can create a new repository file in that directory with the following steps:

Open a terminal.
```
sudo nano /etc/zypp/repos.d/opensuse-update-leap-15.5-backports_debug.repo
```
Add the repository configuration to the file. Here's an example of what the configuration might look like
```
[opensuse-update-leap-15.5-backports_debug]
name=OpenSUSE Leap 15.5 Backports Debug
enabled=1
autorefresh=1
baseurl=http://download.opensuse.org/update/leap/15.5/backports_debug/
type=rpm-md
gpgcheck=1
gpgkey=https://download.opensuse.org/update/leap/15.5/backports_debug/repodata/repomd.xml.key
```
Adjust the name, baseurl, and gpgkey according to the specifics of the repository you're adding.

Save the changes and exit the text editor.

Refresh the list of repositories to ensure the newly added repository is recognized:
```
sudo zypper refresh
```

[TFTP-SERVER with Yast2](https://software.opensuse.org/download/package?package=yast2-tftp-server&project=YaST%3AHead)
