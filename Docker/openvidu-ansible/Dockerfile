FROM ubuntu:18.04

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get install -y gnupg2 python3-pip sshpass git openssh-client && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

RUN python3 -m pip install --upgrade pip cffi && \
    pip install ansible && \
    pip install mitogen ansible-lint && \
    pip install --upgrade pywinrm && \
    ansible-galaxy install geerlingguy.docker

RUN mkdir /ansible && \
    mkdir -p /etc/ansible && \
    echo 'localhost' > /etc/ansible/hosts

COPY ansible.cfg /etc/ansible/ansible.cfg

WORKDIR /ansible

CMD [ "ansible-playbook", "--version" ]
