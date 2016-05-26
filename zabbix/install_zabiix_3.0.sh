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
	yum -y install httpd php php-mysql php-gd php-xml php-bcmath php-mbstring php-pear  firewalld
	if [ $? -ne 0 ]
	then
		echo 'Error: Can not install package'
		exit 1
	fi
	
	#Install MariaDB
	yum -y install mariadb-server
	if [ $? -ne 0 ]
	then
		echo 'Error: Can not install package'
		exit 1
	fi
	
	#Install Epel-relase
	yum -y install epel-release
	if [ $? -ne 0 ]
	then
		echo 'Error: Can not install package'
		exit 1
	fi
	
	#Install Epel-zabbix
	yum -y install http://repo.zabbix.com/zabbix/3.0/rhel/7/x86_64/zabbix-release-3.0-1.el7.noarch.rpm
	if [ $? -ne 0 ]
	then
		echo 'Error: Can not install package'
		exit 1
	fi
	
	#install zabbix for mysql
	yum -y install zabbix-get zabbix-server-mysql zabbix-web-mysql zabbix-agent 
	if [ $? -ne 0 ]
	then
		echo 'Error: Can not install package'
		exit 1
	fi
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

configure_zabbix()
{
	local pass_db=$1
	local pass_db_zabbix=$2
cat > /root/zabbix.sql <<eof
create database zabbix; 
grant all privileges on zabbix.* to zabbix@'localhost' identified by "$pass_db_zabbix"; 
grant all privileges on zabbix.* to zabbix@'%' identified by "$pass_db_zabbix"; 
eof
mysql -u root -p"$pass_db" -e'source /root/zabbix.sql'
rm -rf /root/zabbix.sql
cd /usr/share/doc/zabbix-server-mysql-*/
gunzip create.sql.gz 
mysql -u zabbix -p"$pass_db_zabbix" zabbix < create.sql 

cp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf.bk
cat > /etc/zabbix/zabbix_server.conf <<eof
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=0
PidFile=/var/run/zabbix/zabbix_server.pid
DBHost=localhost 
DBName=zabbix
DBUser=zabbix
DBPassword=$pass_db_zabbix
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
Timeout=4
AlertScriptsPath=/usr/lib/zabbix/alertscripts
ExternalScripts=/usr/lib/zabbix/externalscripts
LogSlowQueries=3000
eof
cat > /etc/httpd/conf.d/zabbix.conf  <<eof
#
# Zabbix monitoring system php web frontend
#

Alias /zabbix /usr/share/zabbix

<Directory "/usr/share/zabbix">
    Options FollowSymLinks
    AllowOverride None
    Require all granted

    <IfModule mod_php5.c>
        php_value max_execution_time 300
        php_value memory_limit 128M
        php_value post_max_size 16M
        php_value upload_max_filesize 2M
        php_value max_input_time 300
        php_value always_populate_raw_post_data -1
        php_value date.timezone Asia/Ho_Chi_Minh 
    </IfModule>
</Directory>

<Directory "/usr/share/zabbix/conf">
    Require all denied
</Directory>

<Directory "/usr/share/zabbix/app">
    Require all denied
</Directory>

<Directory "/usr/share/zabbix/include">
    Require all denied
</Directory>

<Directory "/usr/share/zabbix/local">
    Require all denied
</Directory>
eof
}

configure_firewall()
{
	setenforce 0
	edit_line 7 'enforcing' 'permissive' /etc/selinux/config 
	firewall-cmd --zone=public --add-port=80/tcp --permanent
	firewall-cmd --zone=public --add-port=443/tcp --permanent
	firewall-cmd --zone=public --add-port=3306/tcp --permanent
	firewall-cmd --reload 
}

start_service()
{
	systemctl start httpd 
	systemctl enable httpd 
	systemctl start mariadb
	systemctl enable mariadb
	systemctl start zabbix-server 
	systemctl enable zabbix-server 
	systemctl start zabbix-agent 
	systemctl enable zabbix-agent 
}



main()
{
	clear
	install_base_package
	password_msql=$(random_pass)
	password_sql_zabbix=$(random_pass)
	systemctl start mariadb
	systemctl enable mariadb
	base_configure_apache
	base_configure_mariadb $password_msql
	configure_zabbix $password_msql $password_sql_zabbix
	configure_firewall
	start_service
	echo $password_msql > ~/.password
	echo $password_sql_zabbix >> ~/.password
}

main