#!/bin/ash /etc/rc.common
source /etc/monlor/scripts/base.sh

START=95
STOP=95
SERVICE_USE_PID=1
SERVICE_WRITE_PID=1
SERVICE_DAEMONIZE=1

service=EasyExplorer
appname=easyexplorer
EXTRA_COMMANDS=" status  version"
EXTRA_HELP="        status  Get $appname status
        version Get $appname version"
port=8890
BIN=$monlorpath/apps/$appname/bin/$appname
CONF=$monlorpath/apps/$appname/config/$appname.conf
LOG=/var/log/$appname.log

set_config() {

	path=$(uci -q get monlor.$appname.share_path)
	[ -z "$path" ] && logsh "【$service】" "未配置$appname的共享目录"
	[ ! -d "$path" ] && mkdir -p $path 
	token=$(uci -q get monlor.$appname.token)
	[ -z "$token" ] && logsh "【$service】" "未配置$appname的密钥"

}

start () {

	if [ "$model" != "arm" ]; then
		logsh "【$service】" "$appname服务仅支持arm路由器，准备卸载" 
		$monlorpath/scripts/appmanage.sh del $appname 
		exit
	fi
	result=$(ps | grep $BIN | grep -v grep | wc -l)
    	if [ "$result" != '0' ];then
		logsh "【$service】" "$appname已经在运行！"
		exit 1
	fi
	logsh "【$service】" "正在启动$appname服务... "

	set_config
	
	#iptables -I INPUT -p tcp --dport $port -m comment --comment "monlor-$appname" -j ACCEPT 
	service_start $BIN -fe 0.0.0.0:$port -u $token -share $path
	if [ $? -ne 0 ]; then
        logsh "【$service】" "启动$appname服务失败！"
		exit
    fi
    logsh "【$service】" "启动$appname服务完成！"

}

stop () {

	logsh "【$service】" "正在停止$appname服务... "
	service_stop $BIN
	ps | grep $BIN | grep -v grep | awk '{print$1}' | xargs kill -9 > /dev/null 2>&1
	#iptables -D INPUT -p tcp --dport $port -m comment --comment "monlor-$appname" -j ACCEPT > /dev/null 2>&1

}

restart () {

	stop
	sleep 1
	start

}

status() {

	result=$(ps | grep $BIN | grep -v grep | wc -l)
	if [ "$result" == '0' ]; then
		echo -e "0\c"
	else
		echo -e "1\c"
	fi

}

version() {

	echo $(cat $monlorpath/apps/$appname/config/version.txt)

}