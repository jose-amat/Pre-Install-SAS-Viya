#!/bin/bash
# Run me with superuser privileges

INSTALL_DIRECTORY="/sas/install"
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


if ! ping -q -c 1 8.8.8.8 &> /dev/null; then
    echo -e "${RED}[ERROR] - Your computer has no internet connection.${NO_COLOR}"
    exit 1
else
    echo -e "${GREEN}[INFO] - Internet connection is OK.${NO_COLOR}"
fi


if [ ! -d "$INSTALL_DIRECTORY" ]; then
    echo -e "${YELLOW}[WARN] - The playbook destination was not created.${NO_COLOR} ..."
    echo -e "${GREEN}[INFO] - Creating playbook destination: ${INSTALL_DIRECTORY}${NO_COLOR} ..."
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

sas_as_installer () {
    sas_folder="$(stat -c %U /sas)"
    install_folder="$(stat -c %U /sas/install)"
    if [[ ! "$sas_folder" = "sas" ]]; then
        sudo chown sas:sas /sas
    fi
    
    if [[ "$install_folder" = "sas" ]]; then
        echo -e "${GREEN}[INFO] - sas is owner of ${INSTALL_DIRECTORY}${NO_COLOR}"
    else
        echo -e "${YELLOW}[WARN] - User sas is not owner of ${INSTALL_DIRECTORY}${NO_COLOR}"
        echo -e "${GREEN}[INFO] - Changing the owner of ${INSTALL_DIRECTORY} to sas${NO_COLOR}"
        sudo chown sas:sas /sas/install
    fi
}

install_ansible () {
    if pip freeze &> /dev/null| grep ansible; then
        if ! pip freeze &> /dev/null | grep 'ansible==2.8.10'; then
            echo -e "${GREEN}[INFO] - Installing ansible 2.8.10${NO_COLOR}..."
            sudo pip uninstall ansible --yes &> /dev/null
            yes | sudo pip install ansible==${ANSIBLE_VERSION} &> /dev/null
        fi
    else
        echo -e "${YELLOW}[WARN] - Ansible is not installed on this machine."
        echo -e "${GREEN}[INFO] - Installing ansible 2.8.10${NO_COLOR}..."
        yes | sudo pip install ansible==${ANSIBLE_VERSION} &> /dev/null
        
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
sas_as_installer
install_ansible

