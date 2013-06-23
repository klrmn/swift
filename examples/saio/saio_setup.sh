#!/bin/bash

#### run me with . ./saio_setup.sh (so the path change will be persistent)

echo "Don\'t go away\! We'll need some info..."

# ----------------------------
# What's in a <your-user-name>
# ----------------------------
#
# Much of the configuration described in this guide requires escalated root
# privileges; however, we assume that administrator logs in an unprivileged
# user. Swift processes also run under a separate user and group, set by
# configuration option, and referred as <your-user-name>:<your-group-name>.
# The default user is `swift`, which may not exist on your system.
#
# There are a number of files refered to on this page that include
# `<your-user-name>` and `<your-group-name>` in the text. Under most
# circumstances, the group name is the same as the user name, and
# this script assumes that.
#
# Some of the code snippets on this page call
# `update_uid_and_gid <directory> <file glob>`.
# This function will find and replace those appearances to the correct user.

function update_uid_and_gid() {
    find $1 -name $2 | xargs sed -i "s/<your-user-name>/${USER}/"
    ## if your group name != your user name, change this
    find $1 -name $2 | xargs sed -i "s/<your-group-name>/${USER}/"
}


# -----------------------
# Installing dependencies
# -----------------------
#
# Different distributions use different installers (apt-get, yum), have
# different selections of software installed by default (pip is a notable
# example), and in some cases, different package names (python-dev vs
# python-devel).

echo "**Installing Dependencies**"

# Figure out installer to use

if [ $(uname -r | grep -c fc) -gt 0 ]; then

    DISTRO=fedora
    INSTALLER=yum
    DISTRO_SPECIFIC="python-devel xinetd sqlite-devel"

elif [ -f /etc/redhat-release ]; then

    DISTRO=redhat
    INSTALLER=yum
    DISTRO_SPECIFIC="python-devel xinetd sudo sqlite-devel"

else

    DISTRO=ubuntu
    INSTALLER=apt-get
    DISTRO_SPECIFIC="python-dev python-pip"

fi

# do the install
export DEBIAN_FRONTEND=noninteractive
sudo $INSTALLER update; sudo $INSTALLER upgrade
sudo $INSTALLER install curl gcc git memcached \
     sqlite3 xfsprogs python-dev python-pip $DISTRO_SPECIFIC

# there are a whole slew of python packages yum can't deliver
if [ "$DISTRO" = "redhat" ]; then
    easy_install pip
fi

# install them using pip
sudo pip install tox setuptools software-properties

# ------------------------------------------------
# Getting the code and setting up test environment
# ------------------------------------------------

echo "**Getting the Code**"
cd && git clone git://github.com/openstack/swift.git
cd && git clone git://github.com/openstack/python-swiftclient.git

# the following three lines should be uncommented if you
# are working on files this script depends on, but which are
# not yet checked in to github

echo "if you need to rsync code changes, this is a good time to do it"
echo "press enter to continue"
read ENTER

echo "**Installing swift**"
cd ~/swift; sudo python ./setup.py develop
echo "**Installing python-swiftclient**"
cd ~/python-swiftclient; sudo python ./setup.py develop

# -----------------------------
# Setting up Drives for Storage
# -----------------------------
#
# These instructions are for configuring locally-attached drives as storage
# drives.

echo "**Setting Up Drives**"

sudo mkdir -p /srv/node
sudo mkdir -p /srv/node/d{1..4}

# if you're using an older kernel, (for example Ubuntu 10.04 Lucid)
# you may want to adjust the inode size with `-i size=1024`.
sudo mkfs.xfs -f -L d1 /dev/sdb
sudo mkfs.xfs -f -L d2 /dev/sdc
sudo mkfs.xfs -f -L d3 /dev/sdd
sudo mkfs.xfs -f -L d4 /dev/sde

echo "# swift data drives" | sudo tee /etc/fstab
echo "LABEL=d1  /srv/node/d1  xfs noatime,nodiratime,nobarrier,logbufs=8,inode64 0 0" | sudo tee -a /etc/fstab
echo "LABEL=d2  /srv/node/d2  xfs noatime,nodiratime,nobarrier,logbufs=8,inode64 0 0" | sudo tee -a /etc/fstab
echo "LABEL=d3  /srv/node/d3  xfs noatime,nodiratime,nobarrier,logbufs=8,inode64 0 0" | sudo tee -a /etc/fstab
echo "LABEL=d4  /srv/node/d4  xfs noatime,nodiratime,nobarrier,logbufs=8,inode64 0 0" | sudo tee -a /etc/fstab
sudo mount -a
sudo chown -R ${USER}:${USER} /srv/node/
sudo mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
sudo mkdir -p /var/run/swift
sudo chown ${USER}:${USER} /var/cache/swift* /var/run/swift

# Adding the following lines to `/etc/rc.local`(before the `exit 0`)::

LCL=cat << EOF
sudo mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
sudo chown ${USER}:${USER} /var/cache/swift*
sudo mkdir -p /var/run/swift
sudo chown ${USER}:${USER} /var/run/swift
EOF

sudo sed -ni "H;\${x;s/exit 0\n/$LCL\n&/;p;}" /etc/rc.local

# ----------------
# Setting up rsync
# ----------------
echo "**Setting up rsyncd**"

# update user and group name in example file and copy it to destination
update_uid_and_gid ~/swift/examples/saio/conf/ rsyncd.conf
sudo cp ~/swift/examples/saio/conf/rsyncd.conf /etc/rsyncd.conf

# restart rsyncd
if [ "$DISTRO" = "ubuntu" ]; then

    # make sure rsync is enabled
    sudo sed -ni 'H;${x;s/RSYNC_ENABLE=.*/RSYNC_ENABLE=true/;p;}' /etc/default/rsync
    sudo service rsync restart

elif [ "$DISTRO" = "redhat" ]; then

    # make sure rsync is enabled
    ## NEED REDHAT VERSION OF ABOVE
    sudo service rsyncd restart

elif [ "$DISTRO" = "fedora" ]; then

    ## UNTESTED
    # make sure rsync is enabled
    sudo sed -ni 'H;${x;s/disable = .*/disable = no/;p;}' /etc/xinetd.d/rsync

fi

# test rsync
rsync rsync://pub@localhost/

# ------------------
# Starting memcached
# ------------------
#
# If this is not done, tempauth tokens expire immediately and accessing
# Swift becomes impossible.

echo "**Turning on memcached**"

if [ "$DISTRO" = "ubuntu" ]; then

    # make sure ENABLE_MEMCACHED=yes in /etc/default/memcached
    sudo sed -ni 'H;${x;s/ENABLE_MEMCACHED=.*/ENABLE_MEMCACHED=yes/;p;}' /etc/default/memcached

elif [ "$DISTRO" = "redhat" ]; then

    ## UNTESTED
    service memcached start
    chkconfig memcached on

elif [ "$DISTRO" = "fedora" ]; then

    ## UNTESTED
    systemctl enable memcached.service
    systemctl start memcached.service

fi

# ---------------------------------------------------
# Optional: Setting up rsyslog for individual logging
# ---------------------------------------------------

echo "Optional: Setting up rsyslog for individual logging [y/N]: "
read INDIV_SYSLOG

if [ "$INDIV_SYSLOG" != "y" ] && [ "$INDIV_SYSLOG" != "Y" ]; then
    echo "**Setting up Individual Syslog**"

    # remove the 2nd, 4th, and 5th lines from example file
    sed -ni "2i#" ~/swift/examples/saio/conf/10-swift.conf
    sed -ni "4i#" ~/swift/examples/saio/conf/10-swift.conf
    sed -ni "5i#" ~/swift/examples/saio/conf/10-swift.conf

    # copy the example file to /etc/rsyslog.d/
    sudo cp ~/swift/examples/saio/conf/10-swift.conf /etc/rsyslog.d/

    # make sure `PrivDropToGroup adm` in /etc/rsyslog.conf
    sudo sed -ni 'H;${x;s/$PrivDropToGroup .*/$PrivDropToGroup adm/;p;}' /etc/rsyslog.conf

    # set up the logs
    sudo mkdir -p /var/log/swift/hourly
    sudo chown -R syslog.adm /var/log/swift
    sudo chmod -R g+w /var/log/swift

    # restart rsyslog
    sudo service rsyslog restart
fi

# ---------------------
# Configuring each node
# ---------------------
#
# Sample configuration files that have all defaults in line-by-line
# comments are provided in the ``etc`` directory of the swift source code.
# Configuration files suitable for the Swift All In One virtual machine can
# be found in the ``etc\saio`` directory.

echo "**Configuring Each Node**"
sudo mkdir -p /etc/swift
sudo chown ${USER}:${USER} /etc/swift
update_uid_and_gid ~/swift/etc/saio/ *.conf
cp -R ~/swift/etc/saio/* /etc/swift/

# creating /etc/swift/swift.conf
SUFF=`python -c 'import uuid; print uuid.uuid4().hex'`
cat <<EOF >/etc/swift/swift.conf
[swift-hash]
swift_hash_path_suffix = $SUFF
EOF

# ------------------------------------
# Setting up scripts for running Swift
# ------------------------------------
echo "**Create Scripts**"

# If you did not set up rsyslog for individual logging, remove the
# `find /var/log/swift...` line from `examples/saio/bin/resetswift`.

if [ "$INDIV_SYSLOG" != "y" ] && [ "$INDIV_SYSLOG" != "Y" ]; then

    sed -ni 'H;${x;s/.* \/var\/log\/swift .*//;p;}' ~/swift/examples/saio/bin/resetswift

fi

cd && mkdir -p ~/bin
update_uid_and_gid ~/swift/examples/saio/bin/ resetswift
cp ~/swift/examples/saio/bin/* ~/bin/
chmod +x ~/bin/*

echo "**Setting Some Environmental Variables**"
echo 'export PATH=${PATH}:/home/swift/bin' >> ~/.bashrc
export PATH=${PATH}:/home/swift/bin

# ----------------------
# Test Your Installation
# ----------------------

cp ~/swift/test/sample.conf /etc/swift/test.conf
echo "export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf" >> ~/.bashrc
export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf
echo "Optional: Run Tests [Y/n]: "
read TEST
if [ "$TEST" != "n" ] && [ "$TEST" != "N" ]; then
    cd ~/swift; sudo pip install -r test-requirements.txt
    echo "**Running Tests to Validate Setup**"
    echo "Each set of tests should report OK"
    remakerings
    cd ~/swift; ./.unittests
    startmain
    startrest
    cd ~/swift; ./.functests
    cd ~/swift; ./.probetests
    stopall
    remakerings
    startmain
    startrest
    echo "**swift should work too**"
    swift -A http://127.0.0.1:8080/auth/v1.0 -U test:tester -K testing stat
fi

# You may also want to test using curl::
#  1. Get an `X-Storage-Url` and `X-Auth-Token`:
#     `curl -i -H 'X-Storage-User: test:tester' -H 'X-Storage-Pass: testing' http://127.0.0.1:8080/auth/v1.0`
#  2. Check that you can GET account:
#     `curl -i -H 'X-Auth-Token: <token-from-x-auth-token-above>' <url-from-x-storage-url-above>`
