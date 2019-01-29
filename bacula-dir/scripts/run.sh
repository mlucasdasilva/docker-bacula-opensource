#!/bin/bash
#
# Copyright (c) 2015-2016 RedCoolBeans <info@redcoolbeans.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Author: J. Lievisse Adriaanse <jasper@redcoolbeans.com>

: ${BACULA_DEBUG:="50"}
: ${DB_USER:="postgres"}
: ${DB_HOST:="bacula-db"}
: ${DB_NAME:="bacula"}
: ${LOG_FILE:="/var/log/bacula/bacula.log"}
: ${DIR_NAME:="bacula"}
: ${MON_NAME:="bacula"}
: ${FD_NAME:="bacula"}

mkdir -p /var/spool/bacula

# Setup bacula-fd.conf if it doesn't exist
if [ ! -f /etc/bacula/bacula-fd.conf ]; then
  # Only one variable is required, FD_PASSWORD. MON_FD_PASSWORD is derived from it.
  if [ -z "${FD_PASSWORD}" ]; then
          echo "==> FD_PASSWORD must be set, exiting"
          exit 1
  fi

  : ${MON_FD_PASSWORD:="${FD_PASSWORD}"}

  CONFIG_VARS=(
    FD_NAME
    FD_PASSWORD
    DIR_NAME
    MON_NAME
    MON_FD_PASSWORD
  )

  cp /root/bacula-fd.conf.orig /etc/bacula/bacula-fd.conf && chmod 600 /etc/bacula/bacula-fd.conf
  for c in ${CONFIG_VARS[@]}; do
    sed -i "s,@@${c}@@,$(eval echo \$$c)," /etc/bacula/bacula-fd.conf
  done
fi

echo "==> Looking for new plugins"
_plugins=`ls -1 /plugins`
echo ${_plugins} | grep -q -E '(\.rpm$)'
if [[ "$?" -eq 0 ]]; then
  for p in ${_plugins}; do
    yum -q --nogpgcheck localinstall -y /plugins/$p
  done
fi

# Give the Postgres container a bit of time to start up, run it's
# initialization scripts before we attempt to connect to it.
echo "==> Checking wether database service at ${DB_HOST} is up"
while true; do ping -c1 ${DB_HOST} > /dev/null && break; done
echo "=> succeeded"

for d in $(seq 10 -1 1); do
  echo "==> Waiting ${d}s for the database service to start"
  sleep 1
done

echo "${DB_HOST}:*:*:${DB_USER}:${DB_PASSWORD}" > /root/.pgpass
chmod 0600 /root/.pgpass

echo "==> Attempting database setup"
if psql -h ${DB_HOST} -U ${DB_USER} -lqt | cut -d\| -f1 | grep -qw ${DB_NAME}; then
    echo "=> Database already setup; skipping."
else
    db_name=${DB_NAME}
    /usr/libexec/bacula/create_postgresql_database -h ${DB_HOST} -U ${DB_USER}
    echo "==> Setting database encoding to SQL_ASCII"
    psql -h ${DB_HOST} -U ${DB_USER} -c "UPDATE pg_database SET encoding = pg_char_to_encoding('SQL_ASCII') WHERE datname = '${DB_NAME}'"
    /usr/libexec/bacula/make_postgresql_tables -h ${DB_HOST} -U ${DB_USER}
    /usr/libexec/bacula/grant_postgresql_privileges -h ${DB_HOST} -U ${DB_USER}
fi

# echo "==> Verifying Bacula DIR configuration"
# /usr/sbin/bacula-dir -c /etc/bacula/bacula-dir.conf -t

# The database setup created the logfile, but bacula-dir running as an unprivileged
# user cannot append to the logfile anymore.
[[ -f "${LOG_FILE}" ]] && chown bacula ${LOG_FILE}

# Update database information in bacula-dir.conf before we clear environment variables
sed -r -i -e "s#^\s+dbname.*#  dbname = \"${DB_NAME}\"; dbuser = \"${DB_USER}\"; dbpassword = \"${DB_PASSWORD}\"; dbaddress = \"${DB_HOST}\"#g" /etc/bacula/bacula-dir.conf

# Clear any environment variables we no longer need, such as passwords.
unset ${DB_PASSWORD}

# Now start both the FD and the DIR forcing them into the background while
# still using -f. This way we can run both commands simultaniously in the
# foreground.
echo "==> Starting Bacula FD"
/usr/sbin/bacula-fd -c /etc/bacula/bacula-fd.conf -d ${BACULA_DEBUG} -f &

echo "==> Starting Bacula DIR"
chown bacula /var/run
chown bacula /var/spool/bacula
[[ -f /etc/bacula/bacula-dir.conf ]] && chown bacula /etc/bacula/bacula-dir.conf
sudo -u bacula /usr/sbin/bacula-dir -c /etc/bacula/bacula-dir.conf -d ${BACULA_DEBUG} -f
