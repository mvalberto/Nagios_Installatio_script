				################################################
				#  Instalador Nagios 4,Thruk y Grafana Ubuntu  #
				#  by Albert                                   #
				################################################
				
#########################
#  GPG keys consol lbas #
#########################

curl -s "https://labs.consol.de/repo/stable/RPM-GPG-KEY" | sudo apt-key add -
gpg --keyserver keys.gnupg.net --recv-keys F8C1CA08A57B9ED7
gpg --armor --export F8C1CA08A57B9ED7 | sudo apt-key add -
echo "deb http://labs.consol.de/repo/stable/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/labs-consol-stable.list

###################
#  Prerequisitos  #
###################

apt-get update
apt-get install -y wget build-essential unzip openssl libssl-dev 
apt-get install -y apache2 php libapache2-mod-php php-gd libgd-dev 
apt-get install -y librrd-dev librrd8 libboost-dev libboost-system-dev

#Creamos Usuarios

adduser nagios
groupadd nagcmd
usermod -a -G nagcmd nagios
usermod -a -G nagcmd www-data

####################
#  Instalar Nagios #
####################

#Descargar Nagios en /tmp

cd /tmp/
wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.6.tar.gz
tar -zxvf nagios-4.4.6.tar.gz
cd /tmp/nagios-4.4.6

#Compilar e Instalar Nagios

./configure --with-nagios-group=nagios --with-command-group=nagcmd
make all
make install
make install-init
make install-daemoninit
make install-config
make install-commandmode

#Instalar la Interfaz Web

make install-webconf
make install-exfoliation

#copiar las secuencias de comandos de los controladores de eventos en el directorio libexec.

cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers


# Cambiar Password Por Defecto 

echo -e "\n\n\t${txtylw}${txtbld}Por favor, introduzca la contraseña para el usuario nagiosadmin.${txtrst}"
htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin

#Reiniciar Apache

a2enconf nagios
a2enmod cgi rewrite
service apache2 restart

########################
#  Plugins  Nagios 4   #
########################

#Descarga de Plugins en /tmp

cd /tmp
wget https://nagios-plugins.org/download/nagios-plugins-2.3.3.tar.gz
tar -zxvf nagios-plugins-2.3.3.tar.gz
cd /tmp/nagios-plugins-2.3.3/

#Compilar e Instalar

./configure --with-nagios-user=nagios --with-nagios-group=nagios
make
make install


#####################
#  Arrancar Nagios  #
#####################

#verificar Configuración

/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
service nagios start

#Arrancar Nagios con el Sistema

systemctl enable nagios

#########################
# Instalar Livestatus   #
#########################

apt-get install -y xinetd
cd /tmp
wget https://amartinv.es/check_mk-1.2.8p27.gz
tar xvfz check_mk-1.2.8p27.gz
./configure --with-nagios4
make
make install
ls /usr/local/lib/mk-livestatus
ln -s /usr/local/bin/unixcat /usr/bin/unixcat
sudo sh -c "printf 'broker_module=/usr/local/lib/mk-livestatus/livestatus.o /usr/local/nagios/var/rw/live' >> /usr/local/nagios/etc/nagios.cfg"

#########################
#    Instalar Truk      #
#########################

apt-get update
apt-get install thruk -y
sudo sh -c "printf '<Component Thruk::Backend>\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '    <peer>\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '        name    = nagios\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '        id      = 36a9e\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '        type    = livestatus\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '        <options>\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '            peer          = /usr/local/nagios/var/rw/live\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '        </options>\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '    </peer>\n' >> /etc/thruk/thruk_local.conf"
sudo sh -c "printf '</Component>\n' >> /etc/thruk/thruk_local.conf"

###################
#  Prerequisitos  #
###################

sudo apt-get update
sudo apt-get install -y curl apt-transport-https

#########################
#  Instalar influxDB    #
#########################


curl -s https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/lsb-release
echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
sudo apt-get update && sudo apt-get install influxdb
sudo systemctl daemon-reload
sudo systemctl enable influxdb.service
sudo systemctl start influxdb.service

#########################
#  Instalar NagFlux     #
#########################

sudo apt-get install -y golang golang-github-influxdb-usage-client-dev git 
export GOPATH=$HOME/gorepo
mkdir $GOPATH
go get -v -u github.com/griesbacher/nagflux
go build github.com/griesbacher/nagflux 
mkdir -p /opt/nagflux
cp $GOPATH/bin/nagflux /opt/nagflux/
mkdir -p /usr/local/nagios/var/spool/nagfluxperfdata
chown nagios:nagios /usr/local/nagios/var/spool/nagfluxperfdata 
cp $GOPATH/src/github.com/griesbacher/nagflux/nagflux.service /lib/systemd/system/
chmod +x /lib/systemd/system/nagflux.service
systemctl daemon-reload
systemctl enable nagflux.service

#########################
#    Instalar Grfana    #
#########################


wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
sudo apt update
sudo apt install grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server
sudo sh -c "sed -i 's/^;allow_embedding = false/allow_embedding = true/g' /etc/grafana/grafana.ini"

#########################
#    Instalar Histou    #
#########################

cd /tmp
wget -O histou.tar.gz https://github.com/Griesbacher/histou/archive/v0.4.3.tar.gz
sudo mkdir -p /var/www/html/histou
cd /var/www/html/histou
sudo tar xzf /tmp/histou.tar.gz --strip-components 1
sudo cp histou.ini.example histou.ini
sudo cp histou.js /usr/share/grafana/public/dashboards/

#configurar Hitsu poner la ip actual del servidor

sed -i 's/localhost/192.168.0.53/g' /usr/share/grafana/public/dashboards/histou.js

##########################
#   Configurar NagFlux   #
##########################

cd /opt/nagflux
sudo sh -c "printf '[main]\n' > config.gcfg"
sudo sh -c "printf '\tNagiosSpoolfileFolder = \"/usr/local/nagios/var/spool/nagfluxperfdata\"\n' >> config.gcfg"
sudo sh -c "printf '\tNagiosSpoolfileWorker = 1\n' >> config.gcfg"
sudo sh -c "printf '\tInfluxWorker = 2\n' >> config.gcfg"
sudo sh -c "printf '\tMaxInfluxWorker = 5\n' >> config.gcfg"
sudo sh -c "printf '\tDumpFile = \"nagflux.dump\"\n' >> config.gcfg"
sudo sh -c "printf '\tNagfluxSpoolfileFolder = \"/usr/local/nagios/var/nagflux\"\n' >> config.gcfg"
sudo sh -c "printf '\tFieldSeparator = \"&\"\n' >> config.gcfg"
sudo sh -c "printf '\tBufferSize = 10000\n' >> config.gcfg"
sudo sh -c "printf '\tFileBufferSize = 65536\n' >> config.gcfg"
sudo sh -c "printf '\tDefaultTarget = \"all\"\n' >> config.gcfg"
sudo sh -c "printf '\n' >> config.gcfg"
sudo sh -c "printf '[Log]\n' >> config.gcfg"
sudo sh -c "printf '\tLogFile = \"\"\n' >> config.gcfg"
sudo sh -c "printf '\tMinSeverity = \"INFO\"\n' >> config.gcfg"
sudo sh -c "printf '\n' >> config.gcfg"
sudo sh -c "printf '[InfluxDBGlobal]\n' >> config.gcfg"
sudo sh -c "printf '\tCreateDatabaseIfNotExists = true\n' >> config.gcfg"
sudo sh -c "printf '\tNastyString = \"\"\n' >> config.gcfg"
sudo sh -c "printf '\tNastyStringToReplace = \"\"\n' >> config.gcfg"
sudo sh -c "printf '\tHostcheckAlias = \"hostcheck\"\n' >> config.gcfg"
sudo sh -c "printf '\n' >> config.gcfg"
sudo sh -c "printf '[InfluxDB \"nagflux\"]\n' >> config.gcfg"
sudo sh -c "printf '\tEnabled = true\n' >> config.gcfg"
sudo sh -c "printf '\tVersion = 1.0\n' >> config.gcfg"
sudo sh -c "printf '\tAddress = \"http://127.0.0.1:8086\"\n' >> config.gcfg"
sudo sh -c "printf '\tArguments = \"precision=ms&u=root&p=root&db=nagflux\"\n' >> config.gcfg"
sudo sh -c "printf '\tStopPullingDataIfDown = true\n' >> config.gcfg"
sudo sh -c "printf '\n' >> config.gcfg"
sudo sh -c "printf '[InfluxDB \"fast\"]\n' >> config.gcfg"
sudo sh -c "printf '\tEnabled = false\n' >> config.gcfg"
sudo sh -c "printf '\tVersion = 1.0\n' >> config.gcfg"
sudo sh -c "printf '\tAddress = \"http://127.0.0.1:8086\"\n' >> config.gcfg"
sudo sh -c "printf '\tArguments = \"precision=ms&u=root&p=root&db=fast\"\n' >> config.gcfg"
sudo sh -c "printf '\tStopPullingDataIfDown = false\n' >> config.gcfg"
sudo systemctl start nagflux.service
curl -G "http://localhost:8086/query?pretty=true" --data-urlencode "q=show databases"

#añadir comandos en /usr/local/nagios/etc/nagios.cfg

sudo sh -c "sed -i 's/^process_performance_data=0/process_performance_data=1/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file=/host_perfdata_file=/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file_template=.*/host_perfdata_file_template=DATATYPE::HOSTPERFDATA\\\\tTIMET::\$TIMET\$\\\\tHOSTNAME::\$HOSTNAME\$\\\\tHOSTPERFDATA::\$HOSTPERFDATA\$\\\\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file_mode=/host_perfdata_file_mode=/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file_processing_interval=.*/host_perfdata_file_processing_interval=15/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file_processing_command=.*/host_perfdata_file_processing_command=process-host-perfdata-file-nagflux/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file=/service_perfdata_file=/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file_template=.*/service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\\\\tTIMET::\$TIMET\$\\\\tHOSTNAME::\$HOSTNAME\$\\\\tSERVICEDESC::\$SERVICEDESC\$\\\\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\\\\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file_mode=/service_perfdata_file_mode=/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file_processing_interval=.*/service_perfdata_file_processing_interval=15/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file_processing_command=.*/service_perfdata_file_processing_command=process-service-perfdata-file-nagflux/g' /usr/local/nagios/etc/nagios.cfg"

#añadir comandos en /usr/local/nagios/etc/objects/commands.cfg

sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo 'define command {' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    command_name    process-host-perfdata-file-nagflux' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    command_line    /bin/mv /usr/local/nagios/var/host-perfdata /usr/local/nagios/var/spool/nagfluxperfdata/\$TIMET\$.perfdata.host' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    }' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo 'define command {' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    command_name    process-service-perfdata-file-nagflux' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    command_line    /bin/mv /usr/local/nagios/var/service-perfdata /usr/local/nagios/var/spool/nagfluxperfdata/\$TIMET\$.perfdata.service' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    }' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/commands.cfg"

#verificar si Nagflux funciona

curl -G "http://localhost:8086/query?db=nagflux&pretty=true" --data-urlencode "q=show series"

#verificar nagios config

sudo /usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg
systemctl restart nagios.service
systemctl restart influxdb.service
systemctl restart nagflux.service
service thruk restart
systemctl restart grafana-server

##############
# Firewall   #
##############

#apt install -y firewalld
#firewall-cmd --permanent --add-service=http
#firewall-cmd --permanent --add-service=https
#firewall-cmd --permanent --add-port=6557/tcp # Puerto Livestatus 
#firewall-cmd --permanent --add-port=3000/tcp # Puerto grafana
#firewall-cmd --permanent --add-port=5666/tcp # nrpe
#firewall-cmd --reload


#Datasource Grafana

#Name: nagflux
#Type: InfluxDB
#HTTP
#URL: http://localhost:8086
#Access: server
#Auth: dejarlo tal cual por defecto
#InfluxDB Details
#Database: nagflux
#User & Password: en blanco
