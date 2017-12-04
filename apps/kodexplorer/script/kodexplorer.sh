#!/bin/ash /etc/rc.common
source /etc/monlor/scripts/base.sh

START=95
STOP=95
SERVICE_USE_PID=1
SERVICE_WRITE_PID=1
SERVICE_DAEMONIZE=1

service=KodExplorer
appname=kodexplorer
port=81
PHPBIN=/opt/bin/spawn-fcgi
NGINXBIN=/opt/sbin/nginx
NGINXCONF=/opt/etc/nginx/nginx.conf
PHPCONF=/opt/etc/php.ini
WWW=/opt/share/nginx/html
LOG=/var/log/$appname.log
PATH=$(uci get monlor.$appname.path)

set_config() {

	result1=$(uci -q get monlor.entware)
	result2=$(ls /opt | grep etc)
	if [ "$result1" == '0' -o "$result2" == '0' ]; then
		logsh "【$service】" "检测到【Entware】服务未启动"
		exit
	else
		if [ ! -f $PHPBIN ] || [ ! -f $NGINXBIN ]; then
		 	logsh "【$service】" "检测到第一次启动【$appname】服务， 正在安装..."
		 	opkg update
			opkg install php7-cgi php7-mod-curl php7-mod-gd php7-mod-iconv php7-mod-json php7-mod-mbstring php7-mod-opcache php7-mod-session php7-mod-zip nginx spawn-fcgi zoneinfo-core zoneinfo-asia
			#修改nginx配置文件
			logsh "【$service】" "修改nginx配置文件"
			sed -i 's/nobody/root/' $NGINXCONF
			sed -i 's/listen       80;/listen       81;/' $NGINXCONF
			sed -i '45s/index.html/index.php index.html/' $NGINXCONF
			sed -i '65,71s/#//g' $NGINXCONF
			sed -i 's#root           html#root           /opt/share/nginx/html#' $NGINXCONF
			sed -i '65,71s/\/scripts/\$document_root/' $NGINXCONF
			#修改php配置文件
			logsh "【$service】" "修改php配置文件"
			docline=`cat $PHPCONF | grep -n doc_root | cut -d: -f1 | tail -1`
			sed -i ""$docline"s#.*#doc_root = \"/opt/share/nginx/html\"#" $PHPCONF
			sed -i 's/memory_limit = 8M/memory_limit = 20M/' $PHPCONF
			sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 2000M/' $PHPCONF

			echo "<?php phpinfo(); ?>" > $WWW/info.php
			rm -rf $WWW/index.html
		fi
		if [ ! -d /opt/share/nginx/html/app/kod/ ]; then
			logsh "【$service】" "未检测到$appname文件，正在下载"
			curl -sLo /tmp/kodexplorer.zip $monlorurl/temp/kodexplorer.zip
			[ $? -ne 0 ] && logsh "【$service】" "$appname文件下载失败" && exit
			unzip /tmp/kodexplorer.zip -d $WWW
		fi
		mount -o blind $PATH $WWW/data/User/admin/home
	fi

}

start () {

	result=$(ps | grep nginx | grep -v sysa | grep -v grep | wc -l)
    if [ "$result" != '0' ];then
		logsh "【$service】" "$appname已经在运行！"
		exit 1
	fi
	logsh "【$service】" "正在启动$appname服务... "

	set_config
	
	iptables -I INPUT -p tcp --dport $port -m comment --comment "monlor-$appname" -j ACCEPT 
	/opt/etc/init.d/S80nginx start >> /tmp/messages
	if [ $? -ne 0 ]; then
		logsh "【$service】" "启动nginx服务失败！"
		exit
	fi
	service_start $PHPBIN -a 127.0.0.1 -p 9000 -C 2 -f /opt/bin/php-cgi 
	if [ $? -ne 0 ]; then
                logsh "【$service】" "启动php服务失败！"
		exit
        fi

}

stop () {

	logsh "【$service】" "正在停止$appname服务... "
	/opt/etc/init.d/S80nginx stop >> /tmp/messages
	killall php-cgi >> /tmp/messages
	umount $WWW/data/User/admin/home > /dev/null 2>&1
	iptables -D INPUT -p tcp --dport $port -m comment --comment "monlor-$appname" -j ACCEPT > /dev/null 2>&1

}

restart () {

	stop
	sleep 1
	start

}
