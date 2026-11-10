sudo DEBIAN_FRONTEND=noninteractive apt-get install supervisor -y

sudo systemctl enable supervisor

sudo systemctl start supervisor
