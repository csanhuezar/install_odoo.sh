#!/bin/bash

######################################################################
# Script for install Odoo on Debian 10
# Author: Carlos Sanhueza Ramírez
#---------------------------------------------------------------------
# Script que permite la instalación de Odoo en Debian 10. Permitiendo
# poder tener multiples instancias en un solo VPS.
#---------------------------------------------------------------------
# Pasos que debes realizar si estás intentando configurar por primera 
# vez un VPS.
# 1.- Crear un archivo con vim o nano:
# sudo nano install_odoo.sh
# 2.- Pegar el contenido de éste repo en el archivo creado y 
# luego dar los permisos correspondientes
# sudo nano chmod +x install_odoo.sh
# 3.- Ejecutar el script para instalar Odoo
# ./install_odoo.sh
######################################################################
#---------------------------------------------------------------------
# PARÁMETROS GLOBALES A MODIFICAR PARA LA INSTALACION DE ODOO
#---------------------------------------------------------------------
USER="nombre_usuario" # Puedes modificar el nombre de tu usuario
PATHBASE="/opt/$USER" # No modificar
PATHBASE_EXT="$PATHBASE/odoo-server" # No modificar
#--------------------------------------------------------------------- 
VERSION="14.0" # Version de instalación de Odoo
IS_ENTERPRISE="False" # Estás instalando Odoo Enterprise?
CONFIG="${USER}-server" # Archivo de Configuracion de Odoo
#--------------------------------------------------------------------- 
INSTALL_WKHTMLTOPDF="True" # Instalar Librería Principal para PDF?
PORT="5867" # Elegir puerto para instancia de Odoo
LONGPOLLING_PORT="8072" # Elegir puerto interno Odoo
#--------------------------------------------------------------------- 
PASSWORD_SUPERADMIN="admin" # Password por defecto.
# Si quieres tener un Password aleatorio marca como "True" la opción de
# RANDOM_PASSWORD de lo contraro dejalo en valor "False"
RANDOM_PASSWORD="True"
#--------------------------------------------------------------------- 
WEBSITE_NAME="dominio o subdominio sin WWW" # Elige Dominio o Subdominio a usar
#--------------------------------------------------------------------- 
# Los valores siguientes configuran NGINX + CERBOT
# Entregandote el WEBSITE_NAME con SSL Autofirmado!
INSTALL_NGINX="True"
ENABLE_SSL="True"
ADMIN_EMAIL="name@example.com"
#--------------------------------------------------------------------- 
######################################################################

#---------------------------------------------------------------------
# Seguridad para el VPS
#---------------------------------------------------------------------
echo -e "\n============= Actualizando Puerto SSH ================"
# Cambia puerto por defecto a 5587
sudo sed -i 's/#Port 22/Port 5587/' /etc/ssh/sshd_config 
#sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
#sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

#--------------------------------------------------
# Actualizar Servidor
#--------------------------------------------------
echo -e "\n============= Actualizando Servidor ================"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

sudo apt install -y vim
#### Deshabilitar vim en modo visual en debian Buster ####
sudo echo "set mouse-=a" >> ~/.vimrc

#--------------------------------------------------
# Instalar PostgreSQL Server
#--------------------------------------------------
sudo apt -y install gnupg2
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
sudo apt update
sudo apt install -y postgresql-12 postgresql-client-12
sudo systemctl start postgresql && sudo systemctl enable postgresql

echo -e "\n=========== Creando el Usuario Odoo para PostgreSQL ================="
sudo su - postgres -c "createuser -s $USER" 2> /dev/null || true

#--------------------------------------------------
# Instalacion de Dependencias
#--------------------------------------------------
echo -e "\n=================== Instalando Python 3 + pip3 ============================"
sudo apt install git build-essential python3 python3-pip python3-dev python3-pil python3-lxml python3-dateutil python3-venv python3-wheel \
wget python3-setuptools libfreetype6-dev libpq-dev libxslt-dev libxml2-dev libzip-dev libldap2-dev libsasl2-dev libxslt1-dev node-less gdebi \
zlib1g-dev libtiff5-dev libjpeg62-turbo-dev libopenjp2-7-dev liblcms2-dev libwebp-dev libharfbuzz-dev libfribidi-dev libxcb1-dev fail2ban libssl-dev \
libjpeg-dev libblas-dev libatlas-base-dev libffi-dev libatlas-base-dev default-libmysqlclient-dev software-properties-common xfonts-75dpi -y

echo -e "\n================== Instalando python packages/requirements ============================"
wget https://raw.githubusercontent.com/odoo/odoo/${VERSION}/requirements.txt
sudo -H pip3 install --upgrade pip
sudo pip3 install setuptools wheel
sudo pip3 install -r requirements.txt

echo -e "\n=========== Instalando nodeJS NPM y rtlcss para soporte LTR =================="
sudo curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt install nodejs -y
sudo ln -s /usr/bin/nodejs /usr/bin/node
sudo npm install -g less-plugin-clean-css
sudo npm install -g rtlcss

#--------------------------------------------------
# Instalar libería Wkhtmltopdf si es necesario
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Instalando Wkhtmltopdf y configurando para Odoo 14 ----"
###  WKHTMLTOPDF links de descarga
## === Debian Buster x64 === ( Para otras distribuciones, reemplace este enlace,
## para tener instalada la versión correcta de wkhtmltopdf, si necesitas ayuda, consulta
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/14.0/setup/install.html#debian-ubuntu

wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_amd64.deb
sudo apt install ./wkhtmltox_0.12.6-1.buster_amd64.deb -y
sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf no se instaló, debido a la elección del usuario.!"
fi

#--------------------------------------------------
# Creacion del usuario para Odoo
#--------------------------------------------------
echo -e "\n======== Creando el usuario para Odoo =========="
sudo adduser --system --quiet --shell=/bin/bash --home=$PATHBASE --gecos 'ODOO' --group $USER
# El usuario también debe agregarse al grupo sudoers
sudo adduser $USER sudo

#--------------------------------------------------
# Creacion del directorio para el Log
#--------------------------------------------------
echo -e "\n=========== Creando el Directorio Log ====================="
sudo mkdir /var/log/$USER
sudo chown $USER:$USER /var/log/$USER

#--------------------------------------------------
# Instalar Odoo desde los Orígenes
#--------------------------------------------------

echo -e "\n==== Instalando el Servidor de ODOO ===="
sudo git clone --depth 1 --branch $VERSION https://www.github.com/odoo/odoo $PATHBASE_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Instalar Odoo Enterprise!
    sudo pip3 install psycopg2-binary pdfminer.six
    echo -e "\n========== Crear enlace simbólico para nodejs ===================="
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $USER -c "mkdir $PATHBASE/enterprise"
    sudo su $USER -c "mkdir $PATHBASE/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $VERSION https://www.github.com/odoo/enterprise "$PATHBASE/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Autentificación"* ]]; do
        echo "\n====================== WARNING ============================="
        echo "Tu autenticación con Github ha fallado! Inténtalo de nuevo."
        printf "Para clonar e instalar la versión empresarial de Odoo, \necesita ser un socio oficial de Odoo y necesita acceso a\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Presiona ctrl+c para parar el script."
        echo "\n==========================================================="
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $VERSION https://www.github.com/odoo/enterprise "$PATHBASE/enterprise/addons" 2>&1)
    done

    echo -e "\n======== Código de empresa agregado en $PATHBASE/enterprise/addons ==========="
    echo -e "\n========== Instalando Librerías Específicas ==============="
    sudo pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    sudo npm install -g less-plugin-clean-css
fi
# Creando Directorio para los módulos externos
echo -e "\n======== Creando Directorio para los módulos externos ================"
sudo su $USER -c "mkdir $PATHBASE/addons"
sudo su $USER -c "mkdir $PATHBASE/config"
sudo su $USER -c "mkdir $PATHBASE/addons/extra-addons"
sudo su $USER -c "mkdir $PATHBASE/addons/oca"
sudo su $USER -c "mkdir $PATHBASE/addons/themes"


echo -e "\n======= Establecer permisos en la carpeta PATHBASE ============="
# Establecer permisos en la carpeta PATHBASE
sudo chown -R $USER:$USER $PATHBASE/*

echo -e "\n=============================================================================="
echo -e "\n============== Creando archivo de configuracion del servidor ================="
echo -e "\n=============================================================================="
# Crea archivo de configuracion de Odoo
sudo touch $PATHBASE/config/${CONFIG}.conf

echo -e "\n=============================================================================="
echo -e "\n=========== Creando configuracion de archivo del servidor =================="
echo -e "\n=============================================================================="

sudo su root -c "printf '[options] \n; Esta es la contraseña que permite las operaciones de la base de datos:\n' >> $PATHBASE/config/${CONFIG}.conf"
if [ $RANDOM_PASSWORD = "True" ]; then
    echo -e "*** Generando contraseña de administrador aleatoria ***"
    PASSWORD_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${PATHBASE}/enterprise/addons,${PATHBASE_EXT}/addons\n' >> $PATHBASE/config/${CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${PATHBASE_EXT}/addons,${PATHBASE}/addons/extra-addons,$PATHBASE/addons/oca,$PATHBASE/addons/themes\n' >> $PATHBASE/config/${CONFIG}.conf"
fi
sudo su root -c "printf 'admin_passwd = ${PASSWORD_SUPERADMIN}\n' >> $PATHBASE/config/${CONFIG}.conf"
if [ $VERSION >= "12.0" ]; then
    sudo su root -c "printf 'http_port = ${PORT}\n' >> $PATHBASE/config/${CONFIG}.conf"
else
    sudo su root -c "printf 'xmlrpc_port = ${PORT}\n' >> $PATHBASE/config/${CONFIG}.conf"
fi
sudo su root -c "printf 'logfile = /var/log/${USER}/${CONFIG}.log\n' >> $PATHBASE/config/${CONFIG}.conf"

sudo chown $USER:$USER $PATHBASE/config/${CONFIG}.conf
sudo chmod 640 $PATHBASE/config/${CONFIG}.conf

#--------------------------------------------------
# Agregar Odoo como Demonio (Systemd)
#--------------------------------------------------

#TESTEAR DEMONIO ANTES DE UNIFICAR
echo -e "\n================= Creando archivo systemd para Odoo ======================="
cat <<EOF > /lib/systemd/system/$USER.service
[Unit]
Description=Odoo Open Source ERP and CRM
Requires=postgresql.service
After=network.target postgresql.service
[Service]
Type=simple
PermissionsStartOnly=true
SyslogIdentifier=odoo-server
User=$USER
Group=$USER
ExecStart=$PATHBASE_EXT/odoo-bin --config $PATHBASE/config/${CONFIG}.conf  --logfile /var/log/${USER}/${CONFIG}.log
KillMode=mixed
StandardOutput=journal+console
[Install]
WantedBy=multi-user.target
EOF

sudo chmod 755 /lib/systemd/system/$USER.service
sudo chown root: /lib/systemd/system/$USER.service

echo -e "\n========= Iniciando el archivo Demonio para Odoo ===================="
sudo systemctl daemon-reload
sudo systemctl enable $USER.service
sudo systemctl start $USER.service


#--------------------------------------------------
# Instalar Nginx si es necesario
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo -e "\n======== Instalando y configurando Nginx ========="
  sudo apt install -y nginx
  sudo systemctl enable nginx
  sudo systemctl start nginx

  cat <<EOF > /etc/nginx/sites-available/$WEBSITE_NAME
# odoo server
upstream odoo {
 server 127.0.0.1:$PORT;
}
upstream odoochat {
 server 127.0.0.1:$LONGPOLLING_PORT;
}
server {
    listen 80;
    server_name $WEBSITE_NAME;

   # Especifica el tamaño máximo aceptado de una solicitud de cliente,
   # Como se indica en el encabezado de la solicitud Content-Length.
   client_max_body_size 300m;

   # Log
   access_log /var/log/nginx/$USER-access.log;
   error_log /var/log/nginx/$USER-error.log;

   # Agregar configuraciones específicas de ssl
   keepalive_timeout    90;

   # Aumentar el búfer de proxy para manejar solicitudes web de Odoo
   proxy_buffers 16 64k;
   proxy_buffer_size 128k;

   # Configuracion general del proxy
   proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;

   # Establecer encabezados
   proxy_set_header Host \$host;
   proxy_set_header X-Real-IP \$remote_addr;
   proxy_set_header X-Forward-For \$proxy_add_x_forwarded_for;
   proxy_set_header Host \$http_x_forwarded_host;

   # Informe al servicio web de Odoo que estamos usando HTTPS; de lo contrario
   # generará URL usando http:// y no https://
   proxy_set_header X-Forwarded-Proto http;
   proxy_set_header X-Forwarded-Host \$host;
   proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
 
   # Por defecto, no reenviar nada
   proxy_redirect off;
   proxy_buffering off;

   # Redirigir solicitudes al servidor backend de Odoo
   location / {
     proxy_pass http://odoo;
   }
   # Redirigir las solicitudes de longpoll al puerto de odoo longpolling port
   location /longpolling {
       proxy_pass http://odoochat;
   }
   # Almacenar en caché algunos datos estáticos en la memoria durante 90 minutos
   # bajo carga pesada, esto debería aliviar un poco el estrés en la interfaz web de Odoo.
   location ~* /web/static/ {
       proxy_cache_valid 200 90m;
       proxy_buffering    on;
       expires 864000;
       proxy_pass http://odoo;
  }
  # gzip 
    gzip_types text/css text/scss text/plain text/xml application/xml application/json application/javascript;
    gzip on;
}
    
EOF

  sudo mv ~/$WEBSITE_NAME /etc/nginx/sites-available/
  sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
  sudo rm /etc/nginx/sites-enabled/default
  sudo rm /etc/nginx/sites-available/default
# Recargamos nuevamente el servicio de nginx
  sudo systemctl reload nginx
  sudo su root -c "printf 'proxy_mode = True\n' >> $PATHBASE/config/${CONFIG}.conf"
  echo "Listo! El servidor Nginx está en funcionamiento. La configuración se puede revisar en /etc/nginx/sites-available/$WEBSITE_NAME"
else
  echo "Nginx no se instaló, debido a la elección del usuario!"
fi

#--------------------------------------------------
# Activar SSL con CERTBOT
#--------------------------------------------------

if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "name@example.com" ]  && [ $WEBSITE_NAME != "example.com" ];then
  sudo apt install snapd -y
  sudo apt-get remove certbot
  
  sudo snap install core
  sudo snap refresh core
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo systemctl reload nginx
  
  echo "\n============ SSL/HTTPS está Activado! ========================"
else
  echo "\n==== SSL/HTTPS no se instaló, debido a las elecciones del usuario! ======"
fi

#--------------------------------------------------
# UFW Firewall
#--------------------------------------------------
echo -e "\n=========== Instalando Firewall =============="
sudo apt install -y ufw 
sudo ufw allow 5587/tcp
sudo ufw allow 80,443,6010,5432,$PORT,8072/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 6010/tcp
sudo ufw allow 5432/tcp
sudo ufw allow $PORT/tcp
sudo ufw allow 8072/tcp
sudo ufw enable

echo "\n===================================================================="
echo -e "\n=========== Status del Servicio Odoo =============="
sudo systemctl status $USER
echo "\n===================================================================="
echo "Listo! El servidor de Odoo está en funcionamiento. Especificaciones:"
echo "Puerto: $PORT"
echo "Servicio Usuario: $USER"
echo "Usuario PostgreSQL: $USER"
echo "Carpeta de Addons: $USER/$CONFIG/addons/"
echo "Contraseña Superusuario (base de datos): $PASSWORD_SUPERADMIN"
echo "Iniciar Servicio Odoo: sudo systemctl start $CONFIG"
echo "Detener Servicio Odoo: sudo systemctl stop $CONFIG"
echo "Reiniciar Servicio Odoo: sudo systemctl restart $CONFIG"
echo "\n====================================================================="
echo -e "\n=========== DISFRUTA DE TU INSTALACION DE ODOO =============="
echo "\n====================================================================="
