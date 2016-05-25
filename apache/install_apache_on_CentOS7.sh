#!/bin/bash
#Install Zabbix 3.0 On Centos 7
check_id()
{
	if [ $(id -u) -ne 0 ]
	then
		echo 'Error: User is not root. Please login root'
		exit 1
	fi
}

edit_line()
{
	local a=$(sed -n "$1"p $4 | grep -w "$2")
	if [ "$a" != "" ]
	then
		sed -i "$1 s/$2/$3/g" $4
	else
		echo 'Line' $1 'trong file' $4 'Khong the chinh sua' $2 'thanh' $3 >> /tmp/log_error
	fi
}


install_base_package()
{
	#Install apache, httpd 
	yum -y install httpd firewalld
	if [ $? -ne 0 ]
	then
		echo 'Error: Can not install package'
		exit 1
	fi
	clear
}

base_configure_apache()
{
	rm -f /etc/httpd/conf.d/welcome.conf
	edit_line 86 'root@localhost' 'root@meditech.vn' /etc/httpd/conf/httpd.conf
	edit_line 95 '#ServerName www.example.com:80' '#ServerName www.meditech.vn:80' /etc/httpd/conf/httpd.conf
	edit_line 151 'None' 'All' /etc/httpd/conf/httpd.conf
	edit_line 164 'index.html' 'index.html index.cgi index.php' /etc/httpd/conf/httpd.conf
	echo 'ServerTokens Prod' >> /etc/httpd/conf/httpd.conf
	echo 'KeepAlive On' >> /etc/httpd/conf/httpd.conf
}

configure_firewall()
{
	setenforce 0
	edit_line 7 'enforcing' 'permissive' /etc/selinux/config 
	firewall-cmd --add-service=http --permanent 
	firewall-cmd --reload 
}

start_service()
{
	systemctl start httpd 
	systemctl enable httpd 
}

main()
{
	clear
	check_id
	install_base_package
	base_configure_apache
	configure_firewall
	start_service
	echo 'Install Success Full'
}

main