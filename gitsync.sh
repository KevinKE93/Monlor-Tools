#!/bin/bash
cd ~/Documents/GitHub/Monlor-Tools
find  .  -name  '.*'  -type  f  -print  -exec  rm  -rf  {} \;
pack() {
	mkdir -p monlor/apps/
	cp -rf config/ monlor/config
	cp -rf scripts/ monlor/scripts
	tar -zcvf monlor.tar.gz monlor/
	#zip -r monlor.zip monlor/
	rm -rf appstore/*
	mv monlor.tar.gz appstore/
	rm -rf monlor/
	cd apps/
	ls | while read line
	do
		tar -zcvf $line.tar.gz $line/
	done 
	cd ..
	mv apps/*.tar.gz appstore/
	[ `uname -s` == "Darwin" ] && md5=md5 || md5=md5sum
	$md5 appstore/* > md5.txt
}

localgit() {
	git add .
	git commit -m "`date +%Y-%m-%d`"
}

github() {
	git remote rm origin
	git remote add origin https://github.com/monlor/Monlor-Tools.git
	git push origin master
}

coding() {
	git remote rm origin
	git remote add origin https://git.coding.net/monlor/Monlor-Tools.git
	git push origin master
}

test() {
	git remote rm origin
	git remote add origin https://git.coding.net/monlor/Monlor-Test.git
	git push origin master
}

case $1 in 
	all) 
		pack
		localgit
		github
		coding
		;;
	github)
		localgit
		github		
		;;
	coding)
		localgit
		coding
		;;
	push)
		localgit
		github
		coding
		;;
	pack) 
		pack
		;;
	test)
		localgit
		test
		;;
esac
