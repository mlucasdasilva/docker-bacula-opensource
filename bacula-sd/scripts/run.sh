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

# Volume path for disk-based backups.
chown bacula /backups
chown bacula /var/run
mkdir -p /var/spool/bacula && chown bacula /var/spool/bacula

echo "==> Looking for new plugins"
_plugins=`ls -1 /plugins`
echo ${_plugins} | grep -q -E '(\.rpm$)'
if [[ "$?" -eq 0 ]]; then
  for p in ${_plugins}; do
    yum -q --nogpgcheck localinstall -y /plugins/$p
  done
fi

echo "==> Starting Bacula SD"
[[ -f /etc/bacula/bacula-sd.conf ]] && chown bacula /etc/bacula/bacula-sd.conf
sudo -u bacula /usr/sbin/bacula-sd -c /etc/bacula/bacula-sd.conf -d ${BACULA_DEBUG} -f
