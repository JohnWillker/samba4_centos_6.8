#!/bin/sh
#Install samba4 on centos 6.8
#update
#Url https://goo.gl/RKNQKI or
#https://raw.githubusercontent.com/JohnWillker/samba4_centos_6.8/master/samba4_centos6.8.sh
echo "###############################################################"
echo "Install Samba 4"
echo "Create by John Willker 04/01/2017"
echo "Name of Domain: "
read DOMAIN
echo "Ip of server: "
read IP_ADDR
echo "Hostname: "
read HOSTNAME

#hosts
echo "$IP_ADDR $HOSTNAME$DOMAIN $DOMAIN" >> /etc/hosts

echo "Update ..."
sleep 2
yum -y update

#Install tools
echo "Install Tools .."
sleep 2
yum -y install zsh git vim wget mlocate epel-release htop

#Default shell
echo "export SHELL=/bin/zsh
exec /bin/zsh -l" >> ~/home/$USER/.bash_profile
#Install oh-my-zsh
sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

cd /home/admin/
wget https://raw.githubusercontent.com/JohnWillker/dotfiles/master/.vimrc

#Disable Firewall
echo "Disable Firewall ..."
sleep 2
service iptables save
service iptables stop
chkconfig iptables off
#Disable SElinux
echo "Disable SElinux ..."
sleep 2
sed -i -e 's/^#\?SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
#Install Dependences Samba 4
echo "Install samba 4 dependencies ..."
yum -y install perl gcc attr libacl-devel libblkid-devel \
    gnutls-devel readline-devel python-devel gdb pkgconfig \
    krb5-workstation zlib-devel setroubleshoot-server libaio-devel \
    setroubleshoot-plugins policycoreutils-python \
    libsemanage-python perl-ExtUtils-MakeMaker perl-Parse-Yapp \
    perl-Test-Base popt-devel libxml2-devel libattr-devel \
    keyutils-libs-devel cups-devel bind-utils libxslt \
    docbook-style-xsl openldap-devel autoconf python-crypto pam-devel

#NTP
echo "# Relogio Local
server 127.127.1.0
fudge 127.127.1.0 stratum 10
# Configurações adicionais para o Samba 4
ntpsigndsocket /var/lib/samba/ntp_signd/
restrict default mssntp" >> /etc/ntp.conf
service ntpd restart
service ntpd restart
ntpq -p

#download
cd /usr/src
wget https://ftp.samba.org/pub/samba/samba-4.5.3.tar.gz
tar -xzvf samba-4.5.3.tar.gz
cd samba-4.5.3
#configure
./configure --enable-debug --enable-selftest --prefix=/opt/samba
#Compile and install
make && make install
#Clean libs cache
ldconfig
#
echo "#!/bin/bash
#
# samba4        This shell script takes care of starting and stopping
#               samba4 daemons.
#
# chkconfig: - 58 74
# description: Samba 4.0 will be the next version of the Samba suite
# and incorporates all the technology found in both the Samba4 alpha
# series and the stable 3.x series. The primary additional features
# over Samba 3.6 are support for the Active Directory logon protocols
# used by Windows 2000 and above.

### BEGIN INIT INFO
# Provides: samba4
# Required-Start: $network $local_fs $remote_fs
# Required-Stop: $network $local_fs $remote_fs
# Should-Start: $syslog $named
# Should-Stop: $syslog $named
# Short-Description: start and stop samba4
# Description: Samba 4.0 will be the next version of the Samba suite
# and incorporates all the technology found in both the Samba4 alpha
# series and the stable 3.x series. The primary additional features
# over Samba 3.6 are support for the Active Directory logon protocols
# used by Windows 2000 and above.
### END INIT INFO

# Source function library.
. /etc/init.d/functions


# Source networking configuration.
. /etc/sysconfig/network


prog=samba
prog_dir=/opt/samba/sbin/
lockfile=/var/lock/subsys/$prog


start() {
        [ "$NETWORKING" = "no" ] && exit 1
#       [ -x /usr/sbin/ntpd ] || exit 5

                # Start daemons.
                echo -n $"Starting samba4: "
                daemon $prog_dir/$prog -D
        RETVAL=$?
                echo
        [ $RETVAL -eq 0 ] && touch $lockfile
        return $RETVAL
}


stop() {
        [ "$EUID" != "0" ] && exit 4
                echo -n $"Shutting down samba4: "
        killproc $prog_dir/$prog
        RETVAL=$?
                echo
        [ $RETVAL -eq 0 ] && rm -f $lockfile
        return $RETVAL
}


# See how we were called.
case "$1" in
start)
        start
        ;;
stop)
        stop
        ;;
status)
        status $prog
        ;;
restart)
        stop
        start
        ;;
reload)
        echo "Not implemented yet."
        exit 3
        ;;
*)
        echo $"Usage: $0 {start|stop|status|restart|reload}"
        exit 2
esac" >> /etc/rc.d/init.d/samba-ad-dc
chmod 777 /etc/rc.d/init.d/samba-ad-dc
chkconfig --add samba-ad-dc
chkconfig samba-ad-dc on
service status samba-ad-dc
service restart samba-ad-dc

#provision
/opt/samba/bin/samba-tool domain provision --use-rfc2307 --interactive
#Kerberos
cp /opt/samba/private/krb5.conf /etc
#tests DNS
host -t A $DOMAIN
host -t SRV _kerberos._udp.$DOMAIN
host -t SRV _ldap._tcp.$DOMAIN
#Autentic Kerberos
kinit administrator@$DOMAIN
klist

/opt/samba/bin/smbclient -L localhost -U%
