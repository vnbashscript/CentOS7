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

random_pass()
{
	< /dev/urandom tr -dc A-Za-z0-9 | head -c32 && echo
}

install_base_package()
{
	#Install apache, httpd 
	yum -y install mariadb-server firewalld
	if [ $? -ne 0 ]
	then
		echo 'Error: Can not install package'
		exit 1
	fi
	clear
}

base_configure_mariadb()
{
	local passconf=$1
cat > /root/config.sql <<eof
delete from mysql.user where user='';
update mysql.user set password=password("$passconf");
flush privileges;
eof
mysql -u root -e'source /root/config.sql'
rm -rf /root/config.sql
}

configure_firewall()
{
	setenforce 0
	edit_line 7 'enforcing' 'permissive' /etc/selinux/config 
	firewall-cmd --zone=public --add-port=3306/tcp --permanent
	firewall-cmd --reload 
}

start_service()
{
	systemctl start mariadb
	systemctl enable mariadb 
}

main()
{
	clear
	check_id
	install_base_package
	password_msql=$(random_pass)
	start_service
	base_configure_mariadb $password_msql
	clear
	echo $password_msql > ~/.password_db
	echo 'Install Success Full'
	echo "Password Login Defalut: $password_msql"
}

main