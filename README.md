# Nagios_Installation_script
Automated installation for Nagios Ubuntu, install Nagios, Thruk, Grafana, InfluxDB, NagFlux, Histou

Download file and edit your server IP for Histou configurartion.
Line 202 put your server IP for Histou
 
After install Add in your host service definitions the next line.<br/>
action_url              http://your_host_IP:3000/dashboard/script/histou.js?host=$HOSTNAME$&service=$SERVICEDESC$
