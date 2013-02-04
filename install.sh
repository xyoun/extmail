#!/bin/bash 
#
#=======================================================================================
#
#                  FILE: install.sh 
#                 USAGE: configure ./config and ./install.sh or sudo ./install.sh 
#
#           DESCRIPTION: this script aim to implement one-click deploy the open source
#                        extmail service.
#
#          REQUIREMENTS: ubuntu 12.04 64bit
#                AUTHOR: Youn Xu
#                E-Mail: youn.xu@corp.globalmarket.com
#               CREATED: 02/02/13 18:48:16 
#
#=======================================================================================
#  
#
#
#PLEASE READ README BEFORE RUN THIS SCRIPT!#



#save currently dir
mydir=`pwd`

#check whether is root or sudo 
if [ `whoami` != "root" ]; then
  sudo bash $0
  exit 0
fi

#import config
source ./config

#check whether config has been assigned.
if [ "$EXTMAIL_DOMAIN" == "" ] || [ "$MYSQL_PASSWD" == "" ] || [ "$PHPMYADMIN_PASSWD" == "" ]; then
	echo "error, please fill up ./config and try again."
	exit 1
fi

#display the information, and enter to continue
cat <<EOF >&1

CAUTIONS!!
please check the following information:

     Extmail domain: $EXTMAIL_DOMAIN
    	 Mysql pass: $MYSQL_PASSWD
    PhpMyAdmin pass: $PHPMYADMIN_PASSWD

EOF
read -p "press enter to continue, Ctrl-C to exit: "

#use 163 source
if [ ! -f /etc/apt/sources.list.bak ]; then
	cp /etc/apt/sources.list /etc/apt/sources.list.bak
fi
cat <<EOF >/etc/apt/sources.list
deb http://mirrors.163.com/ubuntu/ precise main restricted
deb-src http://mirrors.163.com/ubuntu/ precise main restricted
deb http://mirrors.163.com/ubuntu/ precise-updates main restricted
deb-src http://mirrors.163.com/ubuntu/ precise-updates main restricted
deb http://mirrors.163.com/ubuntu/ precise universe
deb-src http://mirrors.163.com/ubuntu/ precise universe
deb http://mirrors.163.com/ubuntu/ precise-updates universe
deb-src http://mirrors.163.com/ubuntu/ precise-updates universe
deb http://mirrors.163.com/ubuntu/ precise multiverse
deb-src http://mirrors.163.com/ubuntu/ precise multiverse
deb http://mirrors.163.com/ubuntu/ precise-updates multiverse
deb-src http://mirrors.163.com/ubuntu/ precise-updates multiverse
deb http://mirrors.163.com/ubuntu/ precise-backports main restricted universe multiverse
deb-src http://mirrors.163.com/ubuntu/ precise-backports main restricted universe multiverse
deb http://mirrors.163.com/ubuntu/ precise-security main restricted
deb-src http://mirrors.163.com/ubuntu/ precise-security main restricted
deb http://mirrors.163.com/ubuntu/ precise-security universe
deb-src http://mirrors.163.com/ubuntu/ precise-security universe
deb http://mirrors.163.com/ubuntu/ precise-security multiverse
deb-src http://mirrors.163.com/ubuntu/ precise-security multiverse
deb http://extras.ubuntu.com/ubuntu precise main
deb-src http://extras.ubuntu.com/ubuntu precise main
EOF

apt-get -y update
if [ "$?" != "0" ]; then
        echo "apt-get update error, check your network."
	exit 1
fi


#configure locale,lang,debconf,chkconfig
apt-get install -y language-pack-en debconf-utils
if [ "$?" != "0" ]; then
        echo "lang pack install error, check your network."
        exit 1
fi

#make a backup for locale
if [ ! -f /etc/default/locale.bak ]; then
cp /etc/default/locale /etc/default/locale.bak
cat <<EOF >/etc/default/locale
LANG="en_US.UTF-8"
LANGUAGE="en_US"
LC_CTYPE=C
EOF
fi

#install all package, use debconf-set-selections to auto-configure
debconf-set-selections <<EOF
mysql-server-5.5 mysql-server/root_password password $MYSQL_PASSWD
mysql-server-5.5 mysql-server/root_password_again password $MYSQL_PASSWD
mysql-server-5.5 mysql-server/start_on_boot boolean true
postfix postfix/main_mailer_type select Internet Site
postfix postfix/root_address string root@$EXTMAIL_DOMAIN
postfix postfix/mailname string $EXTMAIL_DOMAIN
postfix postfix/relayhost string 
postfix postfix/destinations string $(hostname -f), localhost
phpmyadmin phpmyadmin/app-password-confirm password 
phpmyadmin phpmyadmin/dbconfig-install boolean true
phpmyadmin phpmyadmin/mysql/admin-pass $MYSQL_PASSWD
phpmyadmin phpmyadmin/mysql/app-pass password $PHPMYADMIN_PASSWD
phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2
courier-base courier-base/webadmin-configmode boolean false

EOF
DEBIAN_FRONTEND=noninteractive apt-get install -y postfix mailutils mysql-server phpmyadmin postfix-mysql postfix-doc mysql-client courier-authdaemon courier-authlib-mysql courier-pop courier-pop-ssl courier-imap courier-imap-ssl libsasl2-modules libsasl2-modules-sql sasl2-bin libpam-mysql openssl phpmyadmin apache2 libapache2-mod-fastcgi libfcgi-perl libapache2-mod-php5 php5 php5-mysql build-essential libtool libnet-server-perl libnet-cidr-perl libberkeleydb-perl arc zoo lzop liblzo2* libstdc++5 libgd-gd2-perl libfile-tail-perl libdigest-sha-perl libdigest-HMAC-perl libnet-ip-perl libnet-dns-perl libhtml-tagset-perl libhtml-parser-perl libio-stringy-perl libio-multiplex-perl libio-socket-ssl-perl libio-zlib-perl libnet-ssleay-perl libunix-syslog-perl libtimedate-perl libmailtools-perl libconvert-binhex-perl libconvert-tnef-perl libconvert-uulib-perl libcompress-raw-zlib-perl libarchive-zip-perl libarchive-tar-perl perl apache2-suexec maildrop mailgraph
if [ "$?" != "0" ]; then
        echo "package install error, check your network."
        exit 1
fi

#add parameters into main.cf to speed up translation
grep smtpd_error_sleep_time /etc/postfix/main.cf
if [ "$?" != "0" ]; then 
cat <<EOF >>/etc/postfix/main.cf
# response immediately
smtpd_error_sleep_time = 0s

# Message and return code control
message_size_limit = 5242880
mailbox_size_limit = 5242880
show_user_unknown_table_name = no

# Queue lifetime control
bounce_queue_lifetime = 1d
maximal_queue_lifetime = 1d
EOF
fi

#configure mydestination in postfix 
sed -i -e "s/mydestination.*/mydestination = $(hostname -f), localhost.localdomain, localhost/g" /etc/postfix/main.cf

#reload postfix
/etc/init.d/postfix restart

#add parameters into apache2.conf to support php
grep application/x-httpd-php /etc/apache2/apache2.conf
if [ "$?" != "0" ]; then 
cat <<EOF >>/etc/apache2/apache2.conf
AddType application/x-httpd-php .php .htm .html
AddDefaultCharset UTF-8
ServerName 127.0.0.1
<IfModule dir_module>
DirectoryIndex index.htm index.html index.php
</IfModule>
EOF
fi
#restart services
/etc/init.d/apache2 restart
/etc/init.d/mysql restart

#create user and group to run all service with id 2000, not allow to login
groupadd -g 2000 vgroup
useradd -g vgroup -u 2000 -m -s /usr/sbin/nologin -d /home/vuser vuser

#unzip extmail and extman
mkdir -p /var/www/extsuite
rm -rf /var/www/extsuite/extmail
rm -rf /var/www/extsuite/extman
tar xvf extmail-1.2.tar.gz
tar xvf extman-1.1.tar.gz
mv extmail-1.2 /var/www/extsuite/extmail
mv extman-1.1 /var/www/extsuite/extman

#replace localhost with 127.0.0.1 in mysql_virtual* to prevent mistakes
sed -i -e "s/localhost/127.0.0.1/g" /var/www/extsuite/extman/docs/mysql_virtual*

#copy to postfix to invoke
cp /var/www/extsuite/extman/docs/mysql_virtual_*.cf /etc/postfix/

#fix permission
chmod 755 /etc/postfix/mysql_virtual*
chgrp postfix /etc/postfix/mysql_virtual*
chown -R vuser:vgroup /var/www/extsuite/extmail/cgi/
chown -R vuser:vgroup /var/www/extsuite/extman/cgi/ 
mv /var/www/extsuite/extmail/webmail.cf.default /var/www/extsuite/extmail/webmail.cf
mv /var/www/extsuite/extman/webman.cf.default /var/www/extsuite/extman/webman.cf


#edit extmail parameters
sed -i -e "s/SYS_USER_LANG.*/SYS_USER_LANG = zh_CN/g" /var/www/extsuite/extmail/webmail.cf
sed -i -e "s/SYS_USER_CHARSET.*/SYS_USER_CHARSET = gb2312/g" /var/www/extsuite/extmail/webmail.cf
sed -i -e "s/SYS_MYSQL_USER.*/SYS_MYSQL_USER = extmail/g" /var/www/extsuite/extmail/webmail.cf
sed -i -e "s/SYS_MYSQL_PASS.*/SYS_MYSQL_PASS = extmail/g" /var/www/extsuite/extmail/webmail.cf
sed -i -e "s/SYS_MYSQL_SOCKET.*/SYS_MYSQL_SOCKET = \/var\/run\/mysqld\/mysqld.sock/g" /var/www/extsuite/extmail/webmail.cf
sed -i -e "s/SYS_AUTHLIB_SOCKET.*/SYS_AUTHLIB_SOCKET = \/var\/run\/courier\/authdaemon\/socket/g" /var/www/extsuite/extmail/webmail.cf
sed -i -e "s/SYS_MAILDIR_BASE.*/SYS_MAILDIR_BASE = \/home\/vuser/g" /var/www/extsuite/extmail/webmail.cf
sed -i -e "s/SYS_G_ABOOK_FILE_CHARSET.*/SYS_G_ABOOK_FILE_CHARSET = gb2312/g" /var/www/extsuite/extmail/webmail.cf
sed -i -e "s/localhost/127.0.0.1/g" /var/www/extsuite/extmail/webmail.cf

#edit extmail parameters
sed -i -e "s/SYS_CAPTCHA_ON.*/SYS_CAPTCHA_ON = 0/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/SYS_MAILDIR_BASE.*/SYS_MAILDIR_BASE = \/home\/vuser/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/SYS_DEFAULT_UID.*/SYS_DEFAULT_UID = 2000/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/SYS_DEFAULT_GID.*/SYS_DEFAULT_GID = 2000/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/SYS_MYSQL_USER.*/SYS_MYSQL_USER = webman/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/SYS_MYSQL_PASS.*/SYS_MYSQL_PASS = webman/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/localhost/127.0.0.1/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/SYS_MYSQL_SOCKET.*/SYS_MYSQL_SOCKET = \/var\/run\/mysqld\/mysqld.sock/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/SYS_LANG.*/SYS_LANG = zh_CN/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/extmail.org/$EXTMAIL_DOMAIN/g" /var/www/extsuite/extman/webman.cf
sed -i -e "s/value=root@extmail.org/value=root@$EXTMAIL_DOMAIN/g" /var/www/extsuite/extman/html/default/index.html

#edit the initial data in mysql
sed -i -e "s/1000/2000/g" /var/www/extsuite/extman/contrib/passwd2ext.pl
sed -i -e "s/1000/2000/g" /var/www/extsuite/extman/docs/extmail.sql
sed -i -e "s/1000/2000/g" /var/www/extsuite/extman/docs/init.sql
sed -i -e "s/1000/2000/g" /var/www/extsuite/extman/docs/init.ldif
sed -i -e "s/1000/2000/g" /var/www/extsuite/extman/tools/userctl.pl

#some parameters has been changed in mysql 5.5, edit TYPE to ENGINE
sed -i -e "s/TYPE=MyISAM/ENGINE=MyISAM/g" /var/www/extsuite/extman/docs/extmail.sql

#change domain in init.sql
sed -i -e "s/extmail.org/$EXTMAIL_DOMAIN/g" /var/www/extsuite/extman/docs/init.sql

#increase the mailbox_size_limit to 5G, not just 5M
sed -i -e "s/'5242880'/'5368709120'/g" /var/www/extsuite/extman/docs/init.sql
sed -i -e "s/1073741824/100073741824/g" /var/www/extsuite/extman/docs/init.sql

#import data to mysql
mysql -uroot -p$MYSQL_PASSWD < /var/www/extsuite/extman/docs/extmail.sql
mysql -uroot -p$MYSQL_PASSWD < /var/www/extsuite/extman/docs/init.sql

#touch a .rc file to auto-run after reboot
cat <<EOF >/etc/rc.extmail
#!/bin/bash

#extman need a tmp dir, create it in tmp file
if [ ! -d /tmp/extman ]; then
mkdir /tmp/extman
chown -R vuser:vgroup /tmp/extman
fi
EOF

chmod a+x /etc/rc.extmail

#there is a 'exit 0' in rc.local, delete it
sed -i -e "s/exit.*//g" /etc/rc.local

#add rc.extmail into rc.local
grep rc.extmail /etc/rc.local
if [ "$?" != "0" ]; then 
echo "/etc/rc.extmail" >> /etc/rc.local
fi

/etc/rc.local

#create postmaster@example.com mailbox
/var/www/extsuite/extman/tools/maildirmake.pl /home/vuser/$EXTMAIL_DOMAIN/postmaster/Maildir
chown -R vuser:vgroup /home/vuser/$EXTMAIL_DOMAIN/

#alias mailbox in postfix
grep virtual_alias_maps /etc/postfix/main.cf
if [ "$?" != "0" ]; then 
cat <<EOF >>/etc/postfix/main.cf
virtual_alias_maps = mysql:/etc/postfix/mysql_virtual_alias_maps.cf
virtual_mailbox_domains = mysql:/etc/postfix/mysql_virtual_domains_maps.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql_virtual_mailbox_maps.cf
EOF
fi

#restart postfix
/etc/init.d/postfix restart

#configure apache2
rm /etc/apache2/sites-enabled/000-default

#configure virtualhost 
touch /etc/apache2/sites-enabled/extmail
cat <<EOF >/etc/apache2/sites-enabled/extmail
<VirtualHost *:80>
ServerAdmin webmaster@localhost
DocumentRoot /var/www/extsuite/extmail/html/

Alias /extmail/cgi/ /var/www/extsuite/extmail/dispatch.fcgi/
Alias /extmail /var/www/extsuite/extmail/html/


ScriptAlias /extman/cgi/ /var/www/extsuite/extman/cgi/
Alias /extman/ /var/www/extsuite/extman/html/

Alias /phpmyadmin /usr/share/phpmyadmin/

</VirtualHost>
EOF

#use vuser.vgroup to run apache2
sed -i -e "s/^User.*/User vuser/g" /etc/apache2/apache2.conf
sed -i -e "s/^Group.*/Group vgroup/g" /etc/apache2/apache2.conf

#fix permission
chmod 777 /var/lib/apache2/fastcgi
chmod 777 /var/lib/apache2/fastcgi/dynamic

#add parameters into apache2 to support suexec
grep FastCgiExternalServer /etc/apache2/apache2.conf
if [ "$?" != "0" ]; then 
cat <<EOF >>/etc/apache2/apache2.conf

<Ifmodule mod_fastcgi.c>
FastCgiExternalServer /var/www/extsuite/extmail/dispatch.fcgi -host 127.0.0.1:8888                    
</Ifmodule>
EOF
fi

#start the services
/var/www/extsuite/extmail/dispatch-init restart
/etc/init.d/apache2 restart


#add dispatch-init to auto-run
grep dispatch-init /etc/rc.extmail
if [ "$?" != "0" ]; then 
echo "/var/www/extsuite/extmail/dispatch-init start" >> /etc/rc.extmail
fi


#================
#!confirmed, this is not a bug. but the mechanism has been changed in ubuntu 12.04.
#================
#there is a bug in ubuntu 12.04, downgrade saslauthd to ubuntu 11.04.
#apt-get install -y libsqlite0 db4.8-util libssl0.9.8
#
#rm -rf /tmp/sasl
#mkdir /tmp/sasl
#cd /tmp/sasl 
#wget http://repo.percona.com/apt/pool/main/p/percona-server-5.1/libmysqlclient16_5.1.67-rel14.3-506.precise_amd64.deb http://archive.ubuntu.com/ubuntu/pool/main/c/cyrus-sasl2/libsasl2-2_2.1.23.dfsg1-5ubuntu3_amd64.deb http://archive.ubuntu.com/ubuntu/pool/main/c/cyrus-sasl2/libsasl2-modules_2.1.23.dfsg1-5ubuntu3_amd64.deb http://archive.ubuntu.com/ubuntu/pool/main/c/cyrus-sasl2/libsasl2-modules-sql_2.1.23.dfsg1-5ubuntu3_amd64.deb http://archive.ubuntu.com/ubuntu/pool/main/c/cyrus-sasl2/libsasl2-dev_2.1.23.dfsg1-5ubuntu3_amd64.deb http://archive.ubuntu.com/ubuntu/pool/main/c/cyrus-sasl2/sasl2-bin_2.1.23.dfsg1-5ubuntu3_amd64.deb
#if [ "$?" != "0" ]; then
#        echo "download, check your network."
#	exit 1
#fi
#dpkg -i --force-all *.deb
#cd $mydir
#===============
#end
#===============

#use saslauthd to implement SASL smtp authentication
sed -i -e "s/START=no/START=yes/g" /etc/default/saslauthd
sed -i -e "s/OPTIONS.*/OPTIONS=\"-c -m \/var\/spool\/postfix\/var\/run\/saslauthd -r\"/g" /etc/default/saslauthd

#pam for stmp
cat <<EOF >/etc/pam.d/smtp
auth required pam_mysql.so user=extmail passwd=extmail host=127.0.0.1 db=extmail table=mailbox usercolumn=username passwdcolumn=password crypt=1
account sufficient pam_mysql.so user=extmail passwd=extmail host=127.0.0.1 db=extmail table=mailbox usercolumn=username passwdcolumn=password crypt=1
EOF

#create chroot dir cause postfix run in chroot mode
mkdir -p /var/spool/postfix/var/run/saslauthd

#since ubuntu 11.10, the mechanism has been changed, refer to: #57 https://bugs.launchpad.net/ubuntu/+source/cyrus-sasl2/+bug/875440
cat <<EOF >/etc/postfix/sasl/smtpd.conf
pwcheck_method: saslauthd
mech_list: plain login cram-md5 digest-md5 pam
log_level: 7
allow_plaintext: true
auxprop_plugin: sql
sql_engine: mysql
sql_hostnames: 127.0.0.1
sql_user: extmail
sql_passwd: extmail
sql_database: extmail
sql_select: SELECT password FROM mailbox WHERE username='%u@%r' and domain='%r'
EOF

#add parameters to support SASL in postfix
grep broken_sasl_auth_clients /etc/postfix/main.cf
if [ "$?" != "0" ]; then
cat <<EOF >>/etc/postfix/main.cf
###########SASL######################
broken_sasl_auth_clients = yes
smtpd_sasl_auth_enable = yes
smtpd_sasl_local_domain = \$myhostname
smtpd_sasl_security_options = noanonymous

smtpd_recipient_restrictions = 
        permit_mynetworks,
        permit_sasl_authenticated,
        reject_non_fqdn_hostname,
        reject_non_fqdn_sender,
        reject_non_fqdn_recipient,
        reject_unauth_destination,
        reject_unauth_pipelining,
        reject_invalid_hostname,
smtpd_sender_restrictions =
        permit_mynetworks,
        reject_sender_login_mismatch,
        reject_authenticated_sender_login_mismatch,
        reject_unauthenticated_sender_login_mismatch
smtpd_sender_login_maps =
        mysql:/etc/postfix/mysql_virtual_sender_maps.cf,
        mysql:/etc/postfix/mysql_virtual_alias_maps.cf

EOF
fi

adduser postfix sasl

/etc/init.d/postfix restart
/etc/init.d/saslauthd restart

#use courier to implement pop authentication
sed -i -e "s/^authmodulelist.*/authmodulelist=\"authmysql\"/g" /etc/courier/authdaemonrc
if [ ! -f /etc/courier/authmysqlrc_orig ];then
cp /etc/courier/authmysqlrc /etc/courier/authmysqlrc_orig
fi
cat <<EOF > /etc/courier/authmysqlrc
MYSQL_SERVER 127.0.0.1
MYSQL_USERNAME extmail
MYSQL_PASSWORD extmail
MYSQL_SOCKET /var/run/mysqld/mysqld.sock
MYSQL_PORT 3306
MYSQL_OPT 0
MYSQL_DATABASE extmail
MYSQL_USER_TABLE mailbox
MYSQL_CRYPT_PWFIELD password
MYSQL_UID_FIELD uidnumber
MYSQL_GID_FIELD gidnumber
MYSQL_LOGIN_FIELD username
MYSQL_HOME_FIELD homedir
MYSQL_NAME_FIELD name
MYSQL_MAILDIR_FIELD maildir
MYSQL_QUOTA_FIELD quota
MYSQL_SELECT_CLAUSE SELECT username,password,"",uidnumber,gidnumber,\
CONCAT('/home/vuser/',homedir), \
CONCAT('/home/vuser/',maildir), \
quota, \
name, \
CONCAT("disablesmtpd=",disablesmtpd, \
",disablesmtp=",disablesmtp, \
",disablewebmail=",disablewebmail, \
",disablenetdisk=",disablenetdisk, \
",disableimap=",disableimap, \
",disablepop3=",disablepop3, \
",netdiskquota=",netdiskquota) \
FROM mailbox \
WHERE username = '\$(local_part)@\$(domain)'
EOF

#chage the default mailbox dir
sed -i -e "s/^MAILDIRPATH.*/MAILDIRPATH=\/home\/vuser\//g" /etc/courier/pop3d
sed -i -e "s/^MAILDIRPATH.*/MAILDIRPATH=\/home\/vuser\//g" /etc/courier/imapd

#courier doesn't not support imap, disable it.
sed -i -e "s/^IMAPDSTART.*/IMAPDSTART=NO/g" /etc/courier/imapd
sed -i -e "s/^IMAPDSSLSTART.*/IMAPDSSLSTART=NO/g" /etc/courier/imapd-ssl

/etc/init.d/courier-authdaemon restart
/etc/init.d/courier-imap restart
/etc/init.d/courier-imap-ssl restart
/etc/init.d/courier-pop restart
/etc/init.d/courier-pop-ssl restart

#configure maildrop
cat <<EOF >/etc/maildropmysql.config
hostname 127.0.0.1
port 3306
database extmail
dbuser extmail
dbpw extmail
dbtable mailbox
default_uidnumber 2000
default_gidnumber 2000
uidnumber_field uidnumber
gidnumber_field gidnumber
uid_field username
homedirectory_field concat('/home/vuser/',homedir,'/')
maildir_field concat('/home/vuser/',maildir)
quota_field quota
mailstatus_field active
EOF

grep logfile /etc/maildroprc 
if [ "$?" != "0" ]; then
cat <<EOF >>/etc/maildroprc 
logfile "/var/log/maildrop.log"
EOF
fi

#touch the log file
touch /var/log/maildrop.log
chown vuser:vgroup /var/log/maildrop.log
chmod 766 /var/log/maildrop.log
chmod a+s /usr/bin/maildrop

#logratate it
cat <<EOF >/etc/logrotate.d/maildrop
/var/log/maildrop.log {
daily
notifempty
missingok
rotate 5
compress
create 766 vuser vgroup
sharedscripts
}
EOF

sed -i -e "s/flags=DRhu user=vmail.*/flags=DRhu user=vuser argv=maildrop -w 90 -d \${user}@\${nexthop} \${recipient} \${user} \${extension} {nexthop}/g" /etc/postfix/master.cf

#configure postfix to drop mails to maildrop
grep maildrop_destination /etc/postfix/main.cf
if [ "$?" != "0" ]; then
cat <<EOF >>/etc/postfix/main.cf
maildrop_destination_recipient_limit = 1
virtual_transport = maildrop:
EOF
fi

#quota warn messages
cat <<EOF >/etc/quotawarnmsg
X-Comment: Rename/Copy this file to quotawarnmsg, and make appropriate changes
X-Comment: See deliverquota man page for more information
From: Mail Delivery System <Mailer-Daemon@example.com>
Reply-To: support@example.com
To: Valued Customer:;
Subject: Mail quota warning
Mime-Version: 1.0
Content-Type: text/plain; charset=iso-8859-1
Content-Transfer-Encoding: 7bit

Your mailbox on the server is now more than 90% full. So that you can continue
to receive mail you need to remove some messages from your mailbox.
EOF

#configure mailgraph to display graph information on the websites
cp -r /var/www/extsuite/extman/addon/mailgraph_ext/ /usr/local/mailgraph_ext
sed -i -e "s/MAIL_LOG=\/var\/log\/maillog/MAIL_LOG=\/var\/log\/mail.log/g" /usr/local/mailgraph_ext/mailgraph-init 

/usr/local/mailgraph_ext/mailgraph-init restart

#display system information on the websites
/var/www/extsuite/extman/daemon/cmdserver --daemon

#auto-run after reboot
grep mailgraph-init /etc/rc.extmail
if [ "$?" != "0" ]; then
echo "/usr/local/mailgraph_ext/mailgraph-init start" >>/etc/rc.extmail
echo "/var/www/extsuite/extman/daemon/cmdserver --daemon" >>/etc/rc.extmail
fi

#fix a bug
grep authdaemon /etc/rc.extmail
if [ "$?" != "0" ]; then
echo "chmod 777 /var/run/courier/authdaemon" >>/etc/rc.extmail
fi

#restart service 
/etc/init.d/saslauthd restart 
/etc/init.d/postfix restart
/etc/init.d/apache2 restart

cd $mydir 
echo
echo

#done

cat <<EOF >&1

Service information:
    Extmail:   http://$(hostname -f)
    	    or http://$(hostname -f)/extmail/cgi/index.cgi  
     ExtMan:   http://$(hostname -f)/extman/cgi/index.cgi
                  admin user: root@$EXTMAIL_DOMAIN
                  admin pass: extmail*123*
 PhpMyAdmin:   http://$EXTMAIL_DOMAIN/phpmyadmin
                  mysql user: root 
                  mysql pass: $MYSQL_PASSWD
                  admin pass: $PHPMYADMIN_PASSWD

You can use mail-client like thunderbird to recieve and send mails:
	POP3: pop3.$EXTMAIL_DOMAIN 
	      port: '110 without ssl' or '995 with ssl'
	(Extmail does not support IMAP.)
	
	SMTP: smtp.$EXTMAIL_DOMAIN
	      port: '25 with ssl'

ps. You need to configure the following in your DNS server to point to your mail-server's ip-address:
	$EXTMAIL_DOMAIN
	pop3.$EXTMAIL_DOMAIN
	smtp.$EXTMAIL_DOMAIN

enjoy it!
EOF
