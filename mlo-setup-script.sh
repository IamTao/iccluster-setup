#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

##### CHECK OS #####
lowercase(){
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

OS=`lowercase \`uname\``
KERNEL=`uname -r`
MACH=`uname -m`

if [ "{$OS}" == "windowsnt" ]; then
    OS=windows
elif [ "{$OS}" == "darwin" ]; then
    OS=mac
else
    OS=`uname`
    if [ "${OS}" = "SunOS" ] ; then
        OS=Solaris
        ARCH=`uname -p`
        OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
    elif [ "${OS}" = "AIX" ] ; then
        OSSTR="${OS} `oslevel` (`oslevel -r`)"
    elif [ "${OS}" = "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            DistroBasedOn='RedHat'
            DIST=`cat /etc/redhat-release |sed s/\ release.*//`
            PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/SuSE-release ] ; then
            DistroBasedOn='SuSe'
            PSUEDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
            REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
        elif [ -f /etc/mandrake-release ] ; then
            DistroBasedOn='Mandrake'
            PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/debian_version ] ; then
            DistroBasedOn='Debian'
            DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
            PSUEDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
            REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
        fi
        OS=`lowercase $OS`
        DistroBasedOn=`lowercase $DistroBasedOn`
        readonly OS
        readonly DIST
        readonly DistroBasedOn
        readonly PSUEDONAME
        readonly REV
        readonly KERNEL
        readonly MACH
    fi

fi

## Check OS and do the install 
# Remove spaces
DISTRIB=${DIST// /-} 					

# Check OS
case "$DISTRIB" in
"Ubuntu") echo $DISTRIB

#########################################
apt-get update

#########################################
# Install LDAP + Autmount
curl -s http://install.iccluster.epfl.ch/scripts/it/ldapAutoMount.sh  >> ldapAutoMount.sh ; chmod +x ldapAutoMount.sh ; ./ldapAutoMount.sh
echo "+ : root pagliard (mlologins) (MLO-unit) (IC-IT-unit): ALL" >> /etc/security/access.conf
echo "- : ALL : ALL" >> /etc/security/access.conf
systemctl stop autofs
systemctl disable autofs
echo "session    required    pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session


#########################################
#PAM Mount
apt-get install -y libpam-mount cifs-utils ldap-utils
# Backup
cp /etc/security/pam_mount.conf.xml /etc/security/pam_mount.conf.xml.orig
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.orig
cd /
wget -P / install.iccluster.epfl.ch/scripts/it/pam_mount.tar.gz
tar xzvf pam_mount.tar.gz
rm -f /pam_mount.tar.gz
sed -i.bak '/and here are more per-package modules/a auth    optional      pam_exec.so /usr/local/bin/login.pl common-auth' /etc/pam.d/common-auth
# Custom Template
wget install.iccluster.epfl.ch/scripts/mlo/template_.pam_mount.conf.xml -O /etc/security/.pam_mount.conf.xml

echo manual | sudo tee /etc/init/autofs.override

echo "unix" >> /var/lib/pam/seen
pam-auth-update --force --package

#########################################
# Create /scratch 
curl -s http://install.iccluster.epfl.ch/scripts/it/scratchVolume.sh  >> scratchVolume.sh ; chmod +x scratchVolume.sh ; ./scratchVolume.sh
chmod 775 /scratch
chown root:MLO-unit /scratch

#########################################
# Create and mount mlodata1 (you can manage the access from groups.epfl.ch) 
mkdir /mlodata1
echo "#mlodata1" >> /etc/fstab
echo "ic1files.epfl.ch:/ic_mlo_1_files_nfs/mlodata1      /mlodata1     nfs     soft,intr,bg 0 0" >> /etc/fstab


#########################################
# Install CUDA !!! INSTALL APRES REBOOT !!!
echo '#!/bin/sh -e' > /etc/rc.local

echo '
FLAG="/var/log/firstboot.cuda.log"
if [ ! -f $FLAG ]; then
	touch $FLAG
        curl -s http://install.iccluster.epfl.ch/scripts/soft/cuda/cuda_8.0.27.sh  >> /tmp/cuda.sh ; chmod +x /tmp/cuda.sh; /tmp/cuda.sh;
fi' >> /etc/rc.local

echo 'exit 0' >> /etc/rc.local
chmod +x /etc/rc.local

#########################################
# export LC_ALL
export LC_ALL=C

########################################
## Install Docker
curl -sSL https://get.docker.com/ | sh

#########################################
# Some basic necessities
apt-get install -y emacs tmux htop mc git subversion vim iotop dos2unix wget screen zsh software-properties-common pkg-config zip g++ zlib1g-dev unzip

#########################################
# Compiling related
apt-get install -y gdb cmake cmake-curses-gui autoconf gcc gcc-multilib g++-multilib 

#########################################
# Python related stuff
apt-get install -y python-pip python-dev python-setuptools build-essential python-numpy python-scipy python-matplotlib ipython ipython-notebook python-pandas python-sympy python-nose python3 python3-pip python3-dev python-wheel python3-wheel python-boto

#########################################
# bazel
## JAVA
add-apt-repository ppa:webupd8team/java -y
apt-get update
echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections
apt-get install -y oracle-java8-installer
## Next
wget -P /tmp https://github.com/bazelbuild/bazel/releases/download/0.4.1/bazel-0.4.1-installer-linux-x86_64.sh
chmod +x /tmp/bazel-0.4.1-installer-linux-x86_64.sh
/tmp/bazel-0.4.1-installer-linux-x86_64.sh 


#########################################
# Python packages using pip
# ipython in apt-get is outdated
pip install ipython --upgrade 

########################################
# NLTK
pip install -U nltk

#########################################
# python3 as default
update-alternatives --install /usr/bin/python python /usr/bin/python3 2
update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 2

	;;
"CentOS-Linux") echo $DISTRIB
    ;;
*) echo "Invalid OS: " $DISTRIB
   ;;
esac

rm -- "$0"
