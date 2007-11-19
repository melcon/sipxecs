#!/bin/bash
#
# Copyright (C) 2007 Pingtel Corp., certain elements licensed under a Contributor Agreement.  
# Contributors retain copyright to elements licensed under a Contributor Agreement.
# Licensed to the User under the LGPL license.

Action=RUN

: ${ServiceDir:=/etc/init.d}
: ${Chown:=chown}
: ${SubstituteUser:=su}
: ${Psql:=psql}

# This function determines the correct service name for Postgres.
postgresService() {
    # If the user has already specified $Service, do not modify it.
    if test -n "$POSTGRES_SERVICE"
    then
        echo -e "$POSTGRES_SERVICE"

    elif [ -f /etc/init.d/rhdb ]
    then
        # Red Hat Enterprise / Fedora / CentOS use the name rhdb
        echo -e rhdb

    elif [ -f /etc/init.d/postgresql-* ]
    then
        # Debian uses a service name appended with the version number
        # E.g. postgresql-7.4 or postgresql-8.2
        echo -e `ls /etc/init.d/postgresql-* | sed -e 's/\/etc\/init.d\///'`

    else
        # SUSE and others use the name postgresql
        echo -e postgresql
    fi
}

# Configure postgres to accept TCP connections for communication
# from Java
postgresSetup() {

  # Set up the server.
  Service=`postgresService`

  # May not by running, so test first
  if ! ${ServiceDir}/${Service} status | egrep "stopped|unused" > /dev/null
  then 
      ${ServiceDir}/${Service} stop 2>&1 1> /dev/null
  fi

  # Custom
  if test -z $PGDATA
  # $PGDATA is set as an env variable for user postgres, but not for root
  then
      if test -d /var/lib/postgresql/data
      then
          # Gentoo
          PGDATA=/var/lib/postgresql/data
      elif test -d /var/lib/pgsql/data
      then
          # Redhat, Fedora, CentOS & SUSE
          PGDATA=/var/lib/pgsql/data
      else
          # Debian Etch
          # Set PGDATA to the configuration directory. On Debian the database is already
          # initialized and there is no initdb command
          PGDATA=`ls -d /etc/postgresql/*.*/main`
      fi
  fi

  # Postgres db is initialized on startup on Redhat, but not on other
  # distros so unless we put a "if distro=rh"  we need to init here
  if [ ! -f $PGDATA/PG_VERSION ] || [ ! -d $PGDATA/base ]
  then
      if [ -f /usr/bin/initdb ]
      # Most distributions use a separate command "initdb" to initialize the db
      # Fedora 8 uses "service postgresql initdb"
      # Debian Etch initializes the DB during installation
      then
          if ${Psql} --version | grep '7.4' > /dev/null
          then
              $SubstituteUser - postgres -c "initdb --pgdata=$PGDATA" > /dev/null
          else
              $SubstituteUser - postgres -c "initdb --pgdata=$PGDATA --auth=trust" > /dev/null
          fi
      else
          ${ServiceDir}/$Service initdb > /dev/null
      fi
  fi

  # Create backup file (possibly) requiring update
  if [ ! -f $PGDATA/pg_hba.conf-sipx.bak ]
  then
     cp $PGDATA/pg_hba.conf $PGDATA/pg_hba.conf.sipx.bak
  fi

  # Will allow this script to add user.  Needs to be listed before
  # other permission or it will not take effect.
  if ! grep '^local *all *all *trust\b' $PGDATA/pg_hba.conf >/dev/null
  then
     echo "local all all trust" > $PGDATA/pg_hba.conf.tmp
     cat $PGDATA/pg_hba.conf >> $PGDATA/pg_hba.conf.tmp
     mv $PGDATA/pg_hba.conf.tmp $PGDATA/pg_hba.conf
  fi

  # Will allow jdbc to connect.  Needs to be listed before
  # other permission or it will not take effect.
  if ! grep '^host *all *all *127.0.0.1\/32 *trust\b' $PGDATA/pg_hba.conf >/dev/null
  then
     echo "host all all 127.0.0.1/32 trust" > $PGDATA/pg_hba.conf.tmp
     cat $PGDATA/pg_hba.conf >> $PGDATA/pg_hba.conf.tmp
     mv $PGDATA/pg_hba.conf.tmp $PGDATA/pg_hba.conf
  fi

  # Open up TCP/IP connections
  sed -i-sipx.bak -e 's/\#tcpip_socket\s=\sfalse/tcpip_socket = true/g' \
          $PGDATA/postgresql.conf
  ${Chown} postgres:postgres $PGDATA/postgresql.conf

  # Postmaster to allow connections
  echo "-i" > $PGDATA/postmaster.opts.default
  chmod 664 $PGDATA/postmaster.opts.default
  ${Chown} postgres:postgres $PGDATA/postmaster.opts.default

  ${ServiceDir}/$Service start
  # Wait 3 seconds to allow slow systems to start the db server
  sleep 3
}

# Have postgres start automatically with system reboot
setPostgresRunlevels() {
    # Arrange for Postgres to be started automatically in runlevels 3
    # and 5.
    # Check if we can use chkconfig.
    if [ -f /sbin/chkconfig ]
    then
        # We have to specify the runlevels because the default set of
        # runlevels for Postgres is empty.
        /sbin/chkconfig --level 35 $Service on
    elif test ! -f "/sbin/insserv" && test ! -f "/etc/debian_version"; then
        # On SUSE and Debian postgres is put into runlevel automatically
        echo "Check whether $Service starts automatically after reboot."
    fi
}

while [ $# -ne 0 ]
do
    case ${1} in
        -h|--help|*)
            Action=HELP
            ;;
    esac           

    shift # always consume 1
done

if [ ${Action} = RUN ]
then
  postgresSetup
  setPostgresRunlevels
elif [ ${Action} = HELP ]
then
cat <<USAGE
Usage: pgpatch.sh [-h|--help]
                     
Patches PostgresSQL cinfuguration file to initialize postgresql for communicating 
with sipxconfig and sipxproxy and create initial database. Will most likely need 
root permissions.

Notable environment variables:

    POSTGRES_SERVICE   a guess is made to determine the name for the
                       Postgres service.
                       If the guess is incorrect, then set this to the name of
                       the script in /etc/init.d that starts/stops
                       the Postgres database.  The possibilities that
                       we are aware of are "postgresql" and "rhdb".

USAGE

fi
