FROM centos:7

MAINTAINER "romracer" <romracer@gmail.com>
ENV BACULA_VERSION "7.4.3"
LABEL com.baculasystems.bacula.version="${BACULA_VERSION}" \
      com.redcoolbeans.image.version="1.0.1"

ENV BACULA_COMPONENTS "bacula-libs bacula-common bacula-libs-sql bacula-client bacula-director bacula-console"

# Install customer's repository information
RUN mkdir -p /tmp/bacula
ADD bacula-common/configs/ /tmp/bacula

RUN rpm -Uvh https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-7-x86_64/pgdg-centos96-9.6-3.noarch.rpm

RUN yum -q -y update && \
    yum -q -y install postgresql96 sudo
RUN for b in ${BACULA_COMPONENTS}; do yum -y --nogpgcheck localinstall /tmp/bacula/$b-${BACULA_VERSION}*.rpm; done

RUN sed -i -e "s/Defaults    requiretty.*/ #Defaults    requiretty/g" /etc/sudoers

# Cleanup caches and repository information
RUN yum clean all; rm -rf /tmp/bacula

# Add and save a copy of the FD config file. We'll populate it first boot.
ADD bacula-fd/configs/bacula-fd.conf /root/bacula-fd.conf.orig
RUN rm -f /etc/bacula/bacula-fd.conf

# Add Bacula to path so running 'docker exec -ti ... bconsole' works
ENV PATH=$PATH:/usr/sbin

ADD bacula-dir/scripts/run.sh /

RUN chmod +x /run.sh

ENTRYPOINT ["/run.sh"]

EXPOSE 9101
