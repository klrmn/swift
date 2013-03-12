=======================
SAIO - Swift All In One
=======================

If you need to get going quickly, there's a link at the bottom to a VirtualBox
appliance of a Swift All in One.

---------------------------------------------
Instructions for setting up a development VM
---------------------------------------------

This section documents setting up a virtual machine for doing Swift
development. The virtual machine will emulate running a four node Swift
cluster.

* Get Ubuntu 12.04 LTS (Precise Pangolin) 64 bit server image.

* Create guest virtual machine from the Ubuntu image.
  In addition to the required primary drive, create 4 additional hard disks.
  Set the hostname to `saio` and the initial user to `swift`.

* Run apt-get update; apt-get upgrade

.. note::

    If you choose to use a different hostname or username, be sure to change
    the instructions to match you setup.

Additional information about setting up a Swift development snapshot on other
distributions is available on the wiki at
http://wiki.openstack.org/SAIOInstructions.

-----------------------
Installing dependencies
-----------------------
* With `sudo` on the guest:

  #. `sudo apt-get install python-software-properties curl gcc git memcached
     python-coverage python-dev python-nose python-setuptools python-simplejson
     python-xattr sqlite3 xfsprogs python-eventlet python-greenlet
     python-pastedeploy python-netifaces python-pip python-sphinx`
  #. `sudo pip install mock tox dnspython`
  #. Install anything else you want, like screen, ssh, vim, etc.

-----------------------------
Setting up Drives for Storage
-----------------------------

These instructions are for configuring locally-attached drives as storage
drives. You may choose to use a large file mounted as a loopback device, but
that option is not documented here. The commands in this section should be
executed with sudo.

  #. `mkdir -p /srv/node`
  #. `mkdir -p /srv/node/d{1..4}`
  #. `mkfs.xfs -f -i size=512 -L d1 /dev/sdb`
  #. `mkfs.xfs -f -i size=512 -L d2 /dev/sdc`
  #. `mkfs.xfs -f -i size=512 -L d3 /dev/sdd`
  #. `mkfs.xfs -f -i size=512 -L d4 /dev/sde`
  #. Edit `/etc/fstab` and add::

      # swift data drives
      LABEL=d1  /srv/node/d1  xfs noatime,nodiratime,nobarrier,logbufs=8,inode64 0 0
      LABEL=d2  /srv/node/d2  xfs noatime,nodiratime,nobarrier,logbufs=8,inode64 0 0
      LABEL=d3  /srv/node/d3  xfs noatime,nodiratime,nobarrier,logbufs=8,inode64 0 0
      LABEL=d4  /srv/node/d4  xfs noatime,nodiratime,nobarrier,logbufs=8,inode64 0 0
  #. `mount -a`
  #. `chown -R swift:swift /srv/node/`
  #. Execute the following lines, as well as adding them to `/etc/rc.local`
     (before the `exit 0`)::

      mkdir -p /var/cache/swift /var/cache/swift2 /var/cache/swift3 /var/cache/swift4
      chown swift:swift /var/cache/swift*
      mkdir -p /var/run/swift
      chown swift:swift /var/run/swift

----------------
Setting up rsync
----------------

  #. Create /etc/rsyncd.conf::

      uid = swift
      gid = swift
      log file = /var/log/rsyncd.log
      pid file = /var/run/rsyncd.pid
      address = 127.0.0.1

      [account6012]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/account6012.lock

      [account6022]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/account6022.lock

      [account6032]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/account6032.lock

      [account6042]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/account6042.lock


      [container6011]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/container6011.lock

      [container6021]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/container6021.lock

      [container6031]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/container6031.lock

      [container6041]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/container6041.lock


      [object6010]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/object6010.lock

      [object6020]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/object6020.lock

      [object6030]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/object6030.lock

      [object6040]
      max connections = 5
      path = /srv/node/
      read only = false
      lock file = /var/lock/object6040.lock

  #. Edit the following line in /etc/default/rsync::

      RSYNC_ENABLE=true

  #. `service rsync restart`

------------------
Starting memcached
------------------

Ensure that the following line is on /etc/default/memcached::

    ENABLE_MEMCACHED=yes

If this is not done, tempauth tokens expire immediately and accessing
Swift becomes impossible.

---------------------------------------------------
Optional: Setting up rsyslog for individual logging
---------------------------------------------------

  #. Create /etc/rsyslog.d/10-swift.conf::

      # Uncomment the following to have a log containing all logs together
      local1,local2,local3,local4,local5.*   /var/log/swift/all.log

      # Uncomment the following to have hourly proxy logs for stats processing
      $template HourlyProxyLog,"/var/log/swift/hourly/%$YEAR%%$MONTH%%$DAY%%$HOUR%"
      local1.*;local1.!notice ?HourlyProxyLog

      local1.*;local1.!notice /var/log/swift/proxy.log
      local1.notice           /var/log/swift/proxy.error
      local1.*                ~

      local2.*;local2.!notice /var/log/swift/storage1.log
      local2.notice           /var/log/swift/storage1.error
      local2.*                ~

      local3.*;local3.!notice /var/log/swift/storage2.log
      local3.notice           /var/log/swift/storage2.error
      local3.*                ~

      local4.*;local4.!notice /var/log/swift/storage3.log
      local4.notice           /var/log/swift/storage3.error
      local4.*                ~

      local5.*;local5.!notice /var/log/swift/storage4.log
      local5.notice           /var/log/swift/storage4.error
      local5.*                ~

  #. Edit /etc/rsyslog.conf and make the following change::

      $PrivDropToGroup adm

  #. `mkdir -p /var/log/swift/hourly`
  #. `chown -R syslog.adm /var/log/swift`
  #. `chmod -R g+w /var/log/swift`
  #. `service rsyslog restart`

------------------------------------------------
Getting the code and setting up test environment
------------------------------------------------

Sample configuration files are provided with all defaults in line-by-line
comments.

.. note::

  Some development operations require hard-linking of files, which is not
  available on VirtualBox shared folders. Please plan accordingly.

Do these commands as the user "swift" on the guest VM.

  #. Get the swift source code and install it:

      #. `cd && git clone git://github.com/openstack/swift.git`
      #. `cd ~/swift; sudo python ./setup.py develop`

  #. Get the python-swiftclient source code and install it:

      #. `cd && git clone git://github.com/openstack/python-swiftclient.git`
      #. `cd ~/python-swiftclient; sudo python ./setup.py develop`

  #. `cd && mkdir ~/bin`
  #. Edit`~/.bashrc` and add to the end::

        export SWIFT_TEST_CONFIG_FILE=/etc/swift/test.conf
        export PATH=${PATH}:/home/swift/bin

  #. `source ~/.bashrc`


---------------------
Configuring each node
---------------------

Sample configuration files that have all defaults in line-by-line
comments are provided in the ``etc`` directory of the swift source code.
Configuration files suitable for the Swift All In One virtual machine can
be found in the ``etc\saio`` directory.

  #. `sudo mkdir -p /etc/swift`
  #. `sudo chown swift:swift /etc/swift`
  #. `cp -R ~/swift/etc/saio/* /etc/swift/`

------------------------------------
Setting up scripts for running Swift
------------------------------------

  #. Create `~/bin/resetswift`::

      #!/bin/bash

      swift-init all stop

      sudo umount /dev/sdb
      sudo mkfs.xfs -f -i size=512 -L d1 /dev/sdb

      sudo umount /dev/sdc
      sudo mkfs.xfs -f -i size=512 -L d2 /dev/sdc

      sudo umount /dev/sdd
      sudo mkfs.xfs -f -i size=512 -L d3 /dev/sdd

      sudo umount /dev/sde
      sudo mkfs.xfs -f -i size=512 -L d4 /dev/sde

      sudo mount -a

      sudo chown -R swift:swift /srv/node/

      sudo rm -rf /var/log/swift
      sudo mkdir -p /var/log/swift/hourly
      sudo chown -R syslog:adm /var/log/swift

      sudo mkdir /var/cache/swift
      sudo chown -R swift:swift /var/cache/swift

      find /var/cache/swift* -type f -name *.recon -exec rm -f {} \;

      sudo service rsyslog restart
      sudo service memcached restart

  #. Create `~/bin/remakerings`::

      #!/bin/bash

      cd /etc/swift

      rm -f *.builder *.ring.gz backups/*.builder backups/*.ring.gz

      swift-ring-builder object.builder create 12 3 1
      swift-ring-builder object.builder add z1-127.0.0.1:6010/d1 1
      swift-ring-builder object.builder add z2-127.0.0.1:6020/d2 1
      swift-ring-builder object.builder add z3-127.0.0.1:6030/d3 1
      swift-ring-builder object.builder add z4-127.0.0.1:6040/d4 1
      swift-ring-builder object.builder rebalance
      swift-ring-builder container.builder create 12 3 1
      swift-ring-builder container.builder add z1-127.0.0.1:6011/d1 1
      swift-ring-builder container.builder add z2-127.0.0.1:6021/d2 1
      swift-ring-builder container.builder add z3-127.0.0.1:6031/d3 1
      swift-ring-builder container.builder add z4-127.0.0.1:6041/d4 1
      swift-ring-builder container.builder rebalance
      swift-ring-builder account.builder create 12 3 1
      swift-ring-builder account.builder add z1-127.0.0.1:6012/d1 1
      swift-ring-builder account.builder add z2-127.0.0.1:6022/d2 1
      swift-ring-builder account.builder add z3-127.0.0.1:6032/d3 1
      swift-ring-builder account.builder add z4-127.0.0.1:6042/d4 1
      swift-ring-builder account.builder rebalance

  #. Create `~/bin/startmain`::

      #!/bin/bash

      if [ ! -d /var/run/swift ]; then
        sudo mkdir -p /var/run/swift
        sudo chown -R swift:swift /var/run/swift
      fi

      swift-init main start

  #. Create `~/bin/startrest`::

        #!/bin/bash

        swift-init rest start

  #. `chmod +x ~/bin/*`
  #. `remakerings`
  #. `cd ~/swift; ./.unittests` (This will generate a lot of output, but one of
     the last lines of the output should be "OK".)
  #. `startmain` (The ``Unable to increase file descriptor limit.  Running as non-root?`` warnings are expected and ok.)
  #. `startrest`
  #. Get an `X-Storage-Url` and `X-Auth-Token`:
     `curl -i -H 'X-Storage-User: test:tester' -H 'X-Storage-Pass: testing' http://127.0.0.1:8080/auth/v1.0`
  #. Check that you can GET account:
     `curl -i -H 'X-Auth-Token: <token-from-x-auth-token-above>' <url-from-x-storage-url-above>`
  #. Check that `swift` works:
     `swift -A http://127.0.0.1:8080/auth/v1.0 -U test:tester -K testing stat`
  #. `cd ~/swift; ./.functests` (Note: functional tests will first delete
     everything in the configured accounts.)
  #. `cd ~/swift; ./.probetests` (Note: probe tests will reset your
     environment as they call `resetswift` for each test.)

----------------
Debugging Issues
----------------

If all doesn't go as planned, and tests fail, or you can't auth, or something
doesn't work, here are some good starting places to look for issues:

#. Everything is logged using system facilities -- usually in /var/log/syslog,
   but possibly in /var/log/messages on e.g. Fedora -- so that is a good first
   place to look for errors (most likely python tracebacks).
#. When using the ``catch-errors`` middleware (as in the instuctions above),
   all external requests will have the same transaction ID logged. This allows
   you to easily search all of your log files to see all log messages
   associated with a particular request.
#. Make sure all of the server processes are running.  For the base
   functionality, the Proxy, Account, Container, and Object servers
   should be running.
#. If one of the servers are not running, and no errors are logged to syslog,
   it may be useful to try to start the server manually, for example:
   `swift-object-server /etc/swift/object-server/1.conf` will start the
   object server.  If there are problems not showing up in syslog,
   then you will likely see the traceback on startup.
#. If you need to, you can turn off syslog for unit tests. This can be
   useful for environments where /dev/log is unavailable, or which
   cannot rate limit (unit tests generate a lot of logs very quickly).
   Open the file SWIFT_TEST_CONFIG_FILE points to, and change the
   value of fake_syslog to True.
