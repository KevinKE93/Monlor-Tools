#!/bin/ash
#copyright by monlor
logger -p 1 -t "【Tools】" "插件管理脚本appmanage.sh启动..."
source /etc/monlor/scripts/base.sh

addtype=`echo $2 | grep -E "/|\." | wc -l`
apppath=$(dirname $2) 
appname=$(basename $2 | cut -d'.' -f1) 

[ `checkuci tools` -ne 0 ] && logsh "【Tools】" "工具箱配置文件未创建！" && exit

add() {

	[ `checkuci $appname` -eq 0 ] && logsh "【Tools】" "插件【$appname】已经安装！" && exit
	if [ "$addtype" == '0' ]; then #检查是否安装在线插件
		#下载插件
		logsh "【Tools】" "正在安装【$appname】在线插件..."
		result=`$monlorpath/scripts/wget.sh "/tmp/$appname.tar.gz" "$monlorurl/appstore/$appname.tar.gz"`
		if [ "$result" != '0' ]; then
			logsh "【Tools】" "下载【$appname】文件失败！"
			exit
		fi
	else
		logsh "【Tools】" "正在安装【$appname】离线插件..."
		[ ! -f "$apppath/$appname.tar.gz" ] && logsh "【Tools】" "未找到离线安装包" && exit
		cp $apppath/$appname.tar.gz /tmp > /dev/null 2>&1
		[ `checkuci $appname` -eq 0 ] && logsh "【Tools】" "插件【$appname】已经安装！" && exit
	fi

	tar -zxvf /tmp/$appname.tar.gz -C /tmp > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		logsh "【Tools】" "解压【$appname】文件失败！" 
		exit
	fi
	
	if [ "$model" == "arm" ]; then
		rm -rf /tmp/$appname/bin/*_mips
	elif [ "$model" == "mips" ]; then
		ls /tmp/$appname/bin | grep -v mips | while read line
		do
			mv /tmp/$appname/bin/$line_mips /tmp/$appname/bin/$line
		done
	else 
		logsh "【Tools】" "不支持你的路由器！"
		exit
	fi
	mv /tmp/$appname $monlorpath/apps
	chmod +x -R $monlorpath/apps/$appname
	#配置添加到工具箱配置文件
	result=`cat $monlorconf | grep -i "【$appname】" | wc -l`
	if [ "$result" == '0' ]; then
		cat $monlorpath/apps/$appname/install/monlor.conf >> $monlorconf
	fi
	#初始化uci配置
	uci set monlor.$appname=config
	$monlorconf
	echo " [ \`uci get monlor.$appname.enable\` -eq 1 ] && $monlorpath/apps/$appname/script/$appname.sh restart" >> $monlorpath/scripts/dayjob.sh
	#检查配置文件中的install
	result=$(cat $monlorconf | grep install_$appname | wc -l)
	if [ "$result" == '0' ]; then
		addline=$(cat $monlorconf | grep -n "【Tools】" | tail -1 | cut -d: -f1)
		[ ! -z $addline ] && sed -i ""$addline"i\\\$uciset.install_$appname=\"1\"" $monlorconf
	fi
	#修改配置文件install配置
	install_line=`cat $monlorconf | grep -n install_$appname | cut -d: -f1`
	[ ! -z "$install_line" ] && sed -i ""$install_line"s/0/1/" $monlorconf
	#清除临时文件
	rm -rf $monlorpath/apps/$appname/install/
	# rm -rf /tmp/$appname
	rm -rf /tmp/$appname.tar.gz
	logsh "【Tools】" "插件安装完成"

}

upgrade() {
	
	[ `checkuci $appname` -ne 0 ] && logsh "【Tools】" "【$appname】插件未安装！" && exit
	#检查更新
	rm -rf /tmp/version.txt
	curl -skLo /tmp/version.txt $monlorurl/apps/$appname/config/version.txt 
	[ $? -ne 0 ] && logsh "【Tools】" "检查更新失败！" && exit
	newver=$(cat /tmp/version.txt)
	oldver=$(cat $monlorpath/apps/$appname/config/version.txt) > /dev/null 2>&1
	[ $? -ne 0 ] && logsh "【Tools】" "$appname文件出现问题，请卸载后重新安装" && exit
	logsh "【Tools】" "当前版本$oldver，最新版本$newver"
	[ "$newver" == "$oldver" ] && logsh "【Tools】" "【$appname】已经是最新版！" && exit
	logsh "【Tools】" "版本不一致，正在更新$appname插件... "
	#检查服务状态
	result=$(uci -q get monlor.$appname.enable)
        if [ "$result" == '1' ]; then
        	logsh "【Tools】" "关闭【$appname】服务"
        	$monlorpath/apps/$appname/script/$appname.sh stop
        fi
	logsh "【Tools】" "删除旧的配置文件"
	uci del monlor.$appname > /dev/null 2>&1
	rm -rf $monlorpath/apps/$appname
	sed -i "/script\/$appname/d" $monlorpath/scripts/dayjob.sh
	#安装服务
	add $appname > /dev/null 2>&1
	$monlorconf
	uci commit monlor
	logsh "【Tools】" "插件更新完成"
	result=$(uci -q get monlor.$appname.enable)
    if [ "$result" == '1' ]; then
    	logsh "【Tools】" "正在启动【$appname】服务"
    	$monlorpath/apps/$appname/script/$appname.sh start
    fi
}

del() {

	if [ `checkuci $appname` -ne 0 ]; then
		echo -n "【$appname】插件未安装！继续卸载？[y/n] "
		read answer
		[ "$answer" == "n" ] && exit
	fi
	$monlorpath/apps/$appname/script/$appname.sh stop > /dev/null 2>&1
	#删除插件的配置
	logsh "【Tools】" "正在卸载【$appname】插件..."
	uci del monlor.$appname > /dev/null 2>&1
	uci commit monlor
	rm -rf $monlorpath/apps/$appname > /dev/null 2>&1
	sed -i "/script\/$appname/d" $monlorpath/scripts/dayjob.sh
	ssline1=$(cat $monlorconf | grep -ni "【$appname】" | head -1 | cut -d: -f1)
	ssline2=$(cat $monlorconf | grep -ni "【$appname】" | tail -1 | cut -d: -f1)
	[ ! -z "$ssline1" -a ! -z "$ssline2" ] && sed -i ""$ssline1","$ssline2"d" $monlorconf > /dev/null 2>&1
	install_line=`cat $monlorconf | grep -n install_$appname | cut -d: -f1`           
        [ ! -z "$install_line" ] && sed -i ""$install_line"s/1/0/" $monlorconf 
        logsh "【Tools】" "插件卸载完成"

}
 

case $1 in
	add) add ;;
	upgrade) upgrade ;;
	del) del ;;
	*) echo "Usage: $0 {add|upgrade|del}"
esac
