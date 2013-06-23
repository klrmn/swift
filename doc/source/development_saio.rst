=======================
SAIO - Swift All In One
=======================

---------------------------------------------
Instructions for setting up a development VM
---------------------------------------------

This section documents setting up a virtual machine for doing Swift
development. The virtual machine will emulate running a four node Swift
cluster.

* Get Ubuntu 12.04 LTS (Precise Pangolin) 64 bit server image. Fedora 16 or
  later works too, but this guide is focused on Ubuntu. Substitute your
  local commands to suit, e.g. "yum update" for "apt-get update".

* Create guest virtual machine from the Ubuntu image.
  In addition to the required primary drive, create 4 additional hard disks.
  Instructions below presume that they are visible in the VM as emulated
  SCSI drives /dev/sdX. Substitute /dev/vdX if necessary.

.. warning::

    Some development operations require hard-linking of files, which is not
    available on VirtualBox shared folders. Please plan accordingly.

* [Ubuntu] Set the hostname to `saio` and the initial user to `swift`.
* [CentoOS] install sudo.
* [Fedora] Create user `swift` and make administrator (add to `wheel` group).

Optional
++++++++

* [Ubuntu] give the user password-less sudo permission
* put the host's `~/.ssh/id_rsa.pub` into the VM's `~/.ssh/authorized_hosts`
* Install any development tools you want, like screen, ssh, vim, etc.

Networking
++++++++++

* set up NAT (and know how to use it with rsynch and ssh)

or

* set up Host-Only networking with a static IP address on the VM.

Additional information about setting up a Swift development snapshot on other
distributions is available on the wiki at
http://wiki.openstack.org/SAIOInstructions.

---------------
Automated Setup
---------------

In attempt to make this process foolproof, a bash script has been developed
to setup a Swift All In One VM. It has been tested on Ubuntu but not Fedora.

From your host machine, scp examples/saio/saio_setup.sh to the VM.
On the VM, run the script with `. ./saio_setup.sh` and answer any questions.

.. literalinclude:: ../../examples/saio/saio_setup.sh
    :language: bash
    :linenos:

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
