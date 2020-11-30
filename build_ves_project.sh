#!/bin/bash

#Script to build coontainers for ves-collectro project

#Check package dependencies 

if ! which docker > /dev/null; then
   echo -e "Docker not found, please install docker from https://docs.docker.com/engine/install/ubuntu" \n
   exit;
fi

if ! which collectd > /dev/null; then
   echo -e "Collectd not found, please install collectd using sudo apt-get install -y collectd" \n
   exit;
fi

if ! which git > /dev/null; then
   echo -e "git not installed, please install git  using sudo apt-get install -y git" \n
   exit;
fi

#get local ip address of VM from first interface

local_ip=`/sbin/ip -o -4 addr list enp0s3 | awk '{print $4}' | cut -d/ -f1`
kafka_host=$local_ip
kafka_port=9092 #use same port number in "run_ves_demo.sh" file.

mkdir -p $PWD/ves-project

#checkout influxdb, grafana, kafdrop from docker hub.
sudo docker pull grafana/grafana
sudo docker pull influxdb
sudo docker pull zookeeper
sudo docker pull obsidiandynamics/kafdrop

#Clone the ves project from git
cd $PWD/ves-project
git clone https://github.com/xor-shrinivas/ves.git

cd $PWD/ves-project/ves/build
chmod +x *.sh
./ves-collector.sh
./ves-kafka.sh
./ves-agent.sh

#Configure local Linux VM collectd service to send local events to ves-kafka server.
sudo mv /etc/collectd/collectd.conf /etc/collectd/collectd.conf.moved_original
sudo touch /etc/collectd/collectd.conf
sudo cat <<EOM > /etc/collectd/collectd.conf
#Configuration for VES Dashboard
FQDNLookup true
LoadPlugin syslog
<Plugin syslog>
        LogLevel info
</Plugin>
LoadPlugin cpu
<Plugin cpu>
  ReportByCpu true
  ReportByState true
  ValuesPercentage true
</Plugin>
LoadPlugin interface
LoadPlugin load
LoadPlugin memory
LoadPlugin logfile
<Plugin logfile>
  LogLevel debug
  File STDOUT
  Timestamp true
  PrintSeverity false
</Plugin>

LoadPlugin target_set
LoadPlugin match_regex
<Chain "PreCache">
  <Rule "mark_memory_as_host">
    <Match "regex">
      Plugin "^memory$"
    </Match>
    <Target "set">
      PluginInstance "host"
    </Target>
  </Rule>
</Chain>

LoadPlugin write_kafka
<Plugin write_kafka>
  Property "metadata.broker.list" "$kafka_host:$kafka_port"
  <Topic "collectd">
    Format JSON
  </Topic>
</Plugin>

LoadPlugin csv
<Plugin csv>
 DataDir "/tmp/csv"
 StoreRates false
</Plugin>

<Include "/etc/collectd/collectd.conf.d">
        Filter "*.conf"
</Include>

EOM

sudo systemctl restart collectd 
