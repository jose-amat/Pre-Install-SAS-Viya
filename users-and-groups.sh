#!/bin/bash
# Run me with superuser privileges

SAS_DIRECTORY="/home/sas"
CAS_DIRECTORY="/home/cas"
ANSIBLE_VERSION="2.8.10"
RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
NO_COLOR='\e[0m'


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
        echo -e "${GREEN}[INFO] - User cas was already in the group sas.${NO_COLOR}"
    fi
}

sas_as_sudoer () {
    if ! sudo cat /etc/sudoers | grep sas -q; then
        sudo echo "sas ALL=(ALL)   NOPASSWD:   ALL" >> /etc/sudoers
        echo -e "${GREEN}[INFO] - Setting user sas as a sudoer.${NO_COLOR}"
    else
        echo -e "${GREEN}[INFO] - User sas was already configured as sudoer.${NO_COLOR}"
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
create_sas_user
create_cas_user
add_cas_user_to_sas_group
sas_as_sudoer
install_ansible
