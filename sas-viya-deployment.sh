#!/usr/bin/env bash
#
# ----------------------------How to use?--------------------------------------
# Run me with superuser privileges
#
# $ sudo chmod 775 pre_install_sas_viya.sh
# $ sudo ./pre_install_sas_viya.sh
# ------------------------------Info-------------------------------------------
#
# Version:              1.0.0
# Site project:         https://github.com/jose-amat/Pre-Install-SAS-Viya
# Author:               Jose Amat
# E-mail:               jose.amat@sas.com
#
# --------------------------------Description----------------------------------
#
# pre_install_sas_viya.sh: Does the pre configuration for SAS Viya installation
# Run and tested on CentOS 7

INSTALL_DIRECTORY="/sas/install"
VIYA_ARK_DIRECTORY="$INSTALL_DIRECTORY/viya-ark"
SAS_DIRECTORY="/home/sas"
CAS_DIRECTORY="/home/cas"
ANSIBLE_VERSION="2.8.10"
RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
NO_COLOR='\e[0m'
YUM_PACKAGES=(
    systemd
    git
    wget
    acl
    curl
    libpng12
    libXmu
    net-tools
    nss
    numactl
    # X11
    xterm
    libcgroup
    libcgroup-tools
    java-1.8.0-openjdk
    python
    python2-pip
    python-setuptools
    python-devel
    openssl-devel
    gcc
    automake
    libffi-devel
)


if sestatus | grep 'permissive' -iq; then
    echo -e "${GREEN}[INFO] - SELinux status is permissive.${NO_COLOR}"
else
    echo -e "${YELLOW}[WARN] - SELinux status is enforced. ${NO_COLOR}"
    echo -e "${GREEN}[INFO] - Changing SELinux status...${NO_COLOR}"
    sudo setenforce 0
    sudo sed -i.bak -e 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
fi

if ! ping -q -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${RED}[ERROR] - Your computer has no internet connection.${NO_COLOR}"
    exit 1
else
    echo -e "${GREEN}[INFO] - Internet connection is OK.${NO_COLOR}"
fi


if [ ! -d "$INSTALL_DIRECTORY" ]; then
    echo -e "${YELLOW}[WARN] - The playbook destination was not created.${NO_COLOR}"
    echo -e "${GREEN}[INFO] - Creating playbook destination: ${INSTALL_DIRECTORY} ...${NO_COLOR}"
    sudo mkdir -p "$INSTALL_DIRECTORY"
else
    echo -e "${GREEN}[INFO] - Playbook destination is already created: ${INSTALL_DIRECTORY}${NO_COLOR}"
fi


update_repositories () {
    echo -e "${GREEN}[INFO] - Updating repositories...${NO_COLOR}"
    sudo yum update -y &> /dev/null
}

attach_epel_repository () {
    if ! sudo yum repolist | grep 'epel' -qi &> /dev/null; then
        echo -e "${YELLOW}[WARN] - EPEL repository is not attached.${NO_COLOR}"
        echo -e "${GREEN}[INFO] - Attaching the EPEL repository...${NO_COLOR}"
        ## find out which release (6 or 7)
        if grep -q -i "release 6" /etc/redhat-release ; then
            majversion=6
        elif grep -q -i "release 7" /etc/redhat-release ; then
            majversion=7
        else
            echo -e "${RED}[INFO] - Apparently, running neither release 6.x nor 7.x.${NO_COLOR}"
            exit 1
        fi
        ## Attach EPEL
        sudo yum install -y epel-release &> /dev/null
    else
        echo -e "${GREEN}[INFO] - EPEL repository is already attached.${NO_COLOR}"
    fi
}

install_yum_package () {
    for package in ${YUM_PACKAGES[@]}; do
        if ! sudo yum list installed  | grep "^$package" &> /dev/null; then
            echo -e "${GREEN}[INFO] - Installing ${package}...${NO_COLOR}"
            sudo yum install -y "$package" &> /dev/null
        else
            echo -e "${GREEN}[INFO] - The package ${package} is already installed.${NO_COLOR}"
        fi
    done
}

update_yum_package () {
    for package in ${YUM_PACKAGES[@]}; do
        echo -e "${GREEN}[INFO] - Updating ${package}...${NO_COLOR}"
        sudo yum update -y "$package" &> /dev/null
    done
}

create_sas_user () {
    if [[ ! -d "$SAS_DIRECTORY" ]]; then
        echo -e "${GREEN}[INFO] - Creating sas user...${NO_COLOR}"
        sudo adduser sas
    else
        echo -e "${GREEN}[INFO] - sas user already exists.${NO_COLOR}"
    fi
}

create_cas_user () {
    if [[ ! -d "$CAS_DIRECTORY" ]]; then
        sudo adduser cas
        echo -e "${GREEN}[INFO] - Creating cas user...${NO_COLOR}"
    else
        echo -e "${GREEN}[INFO] - cas user already exists.${NO_COLOR}"
    fi
}

add_cas_user_to_sas_group () {
    if ! groups cas | grep sas -q; then
        sudo usermod -g sas cas
        sudo groupdel cas
        echo -e "${GREEN}[INFO] - Adding cas user to sas group...${NO_COLOR}"
    else
        echo -e "${GREEN}[INFO] - User cas is already in the group sas.${NO_COLOR}"
    fi
}

sas_as_sudoer () {
    if ! sudo cat /etc/sudoers | grep sas -q; then
        sudo echo "sas ALL=(ALL)   NOPASSWD:   ALL" >> /etc/sudoers
        echo -e "${GREEN}[INFO] - Setting user sas as a sudoer.${NO_COLOR}"
    else
        echo -e "${GREEN}[INFO] - User sas is already configured as sudoer.${NO_COLOR}"
    fi
}

install_ansible () {
    if pip freeze | grep ansible -q; then
        if ! pip freeze | grep 'ansible==${ANSIBLE_VERSION}' -q; then
            echo -e "${GREEN}[INFO] - Installing ansible ${ANSIBLE_VERSION}${NO_COLOR}..."
            sudo pip uninstall ansible --yes &> /dev/null
            yes | sudo pip install ansible==${ANSIBLE_VERSION} &> /dev/null
        fi
    else
        echo -e "${YELLOW}[WARN] - Ansible is not installed on this machine."
        echo -e "${GREEN}[INFO] - Installing ansible ${ANSIBLE_VERSION}${NO_COLOR}..."
        yes | sudo pip install ansible==${ANSIBLE_VERSION} &> /dev/null
        
    fi
}

download_viya_ark () {
    if [[ ! -d "$VIYA_ARK_DIRECTORY" ]]; then
        echo -e "${GREEN}[INFO] - Downloading Viya Ark...${NO_COLOR}"
        cd /sas/install
        git clone https://github.com/sassoftware/viya-ark.git &> /dev/null
    else
        echo -e "${GREEN}[INFO] - Viya Ark has already been downloaded.${NO_COLOR}"
    fi
}

download_mirrormgr () {
    if [[ ! -f "$INSTALL_DIRECTORY/mirrormgr-linux.tgz" ]]; then
        echo -e "${GREEN}[INFO] - Downloading SAS Mirror Manager...${NO_COLOR}"
        cd /sas/install
        sudo wget https://support.sas.com/installation/viya/35/sas-mirror-manager/lax/mirrormgr-linux.tgz &> /dev/null
    else
        echo -e "${GREEN}[INFO] - SAS Mirror Manager has already been downloaded.${NO_COLOR}"
    fi
}

download_sas_orchestration () {
    if [[ ! -f "$INSTALL_DIRECTORY/sas-orchestration-linux.tgz" ]]; then
        echo -e "${GREEN}[INFO] - Downloading SAS Orchestration CLI...${NO_COLOR}"
        cd /sas/install
        sudo wget https://support.sas.com/installation/viya/35/sas-orchestration-cli/lax/sas-orchestration-linux.tgz &> /dev/null
    else
        echo -e "${GREEN}[INFO] - SAS Orchestration CLI has already been downloaded.${NO_COLOR}"
    fi
}

extract_tgz_file () {
    if ls "$INSTALL_DIRECTORY"/*.tgz &> /dev/null; then
        echo -e "${GREEN}[INFO] - Extracting tgz files...${NO_COLOR}"
        cd /sas/install
        for f in *.tgz; do tar xf "$f" &> /dev/null; done
    else
        echo -e "${RED}[ERROR] - There are no tgz files.${NO_COLOR}"
    fi
}

sas_as_installer () {
    sas_folder="$(stat -c %U /sas)"
    if [[ ! "$sas_folder" = "sas" ]]; then
        echo -e "${YELLOW}[WARN] - User sas is not owner of ${INSTALL_DIRECTORY}${NO_COLOR}"
        echo -e "${GREEN}[INFO] - Changing the owner of ${INSTALL_DIRECTORY} to sas${NO_COLOR}"
        sudo chown sas:sas /sas -R
    else
        echo -e "${GREEN}[INFO] - sas is owner of ${INSTALL_DIRECTORY}${NO_COLOR}"
    fi
}


# Executing
update_repositories
attach_epel_repository
install_yum_package
update_yum_package
create_sas_user
create_cas_user
add_cas_user_to_sas_group
sas_as_sudoer
install_ansible
download_viya_ark
download_mirrormgr
download_sas_orchestration
extract_tgz_file
sas_as_installer
