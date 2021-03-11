FROM ubuntu:18.04

ENV HORIZON_BASEDIR=/opt/horizon \
    KEYSTONE_URL='http://keystone:5000/v2' \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    APACHE_PID_FILE=/var/run/apache2/apache2.pid \
    APACHE_RUN_DIR=/var/run/apache2 \
    APACHE_LOCK_DIR=/var/lock/apache2 \
    APACHE_LOG_DIR=/var/log/apache2 \
    LANG=C \
    VERSION=stable/victoria

EXPOSE 80

RUN \
  apt update && \
  apt install -y \
    apache2 libapache2-mod-wsgi-py3 \
    python3-pip python3-dev  \
    git cargo python3-dev build-essential

RUN ln -fs /usr/bin/python3 /usr/bin/python

RUN \
  git clone --branch $VERSION --depth 1 https://github.com/openstack/horizon.git ${HORIZON_BASEDIR} && \
  cd /opt && \
  python3 -m pip install -c https://raw.githubusercontent.com/ader1990/requirements/${VERSION}/upper-constraints.txt ./horizon && \
  cd ${HORIZON_BASEDIR} && \
  python3 -m pip install python-memcached && \
  cp openstack_dashboard/local/local_settings.py.example openstack_dashboard/local/local_settings.py && \
  sed -i 's/^DEBUG.*/DEBUG = False/g' $HORIZON_BASEDIR/openstack_dashboard/local/local_settings.py && \
  echo 'COMPRESS_OFFLINE = True' >> $HORIZON_BASEDIR/openstack_dashboard/local/local_settings.py && \
  sed -i 's/^OPENSTACK_KEYSTONE_URL.*/OPENSTACK_KEYSTONE_URL = os\.environ\["KEYSTONE_URL"\]/g' \
    $HORIZON_BASEDIR/openstack_dashboard/local/local_settings.py && \
  printf  "\nALLOWED_HOSTS = ['*', ]\n" >> $HORIZON_BASEDIR/openstack_dashboard/local/local_settings.py && \
  echo 'OPENSTACK_API_VERSIONS = {"identity": os.environ.get("IDENTITY_API_VERSION", 3) }' \
    >> $HORIZON_BASEDIR/openstack_dashboard/local/local_settings.py && \
  printf  "\nSESSION_ENGINE = 'django.contrib.sessions.backends.cache'\n" >> $HORIZON_BASEDIR/openstack_dashboard/local/local_settings.py && \
  printf  "\nCACHES = {    'default': {        'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',        'LOCATION': 'memcached:11211',    },}\n" >> $HORIZON_BASEDIR/openstack_dashboard/local/local_settings.py && \
  python3 ./manage.py collectstatic --noinput && \
  python3 ./manage.py compress --force && \
  python3 ./manage.py make_web_conf --wsgi && \
  rm -rf /etc/apache2/sites-enabled/* && \
  python3 ./manage.py make_web_conf --apache > /etc/apache2/sites-enabled/horizon.conf && \
  sed -i 's/<VirtualHost \*.*/<VirtualHost _default_:80>/g' /etc/apache2/sites-enabled/horizon.conf && \
  chown -R www-data:www-data ${HORIZON_BASEDIR} && \
  python3 -m compileall $HORIZON_BASEDIR && \
  sed -i '/ErrorLog/c\    ErrorLog \/dev\/stderr' /etc/apache2/sites-enabled/horizon.conf && \
  sed -i '/CustomLog/c\    CustomLog \/dev\/stdout combined' /etc/apache2/sites-enabled/horizon.conf && \
  sed -i '/ErrorLog/c\    ErrorLog \/dev\/stderr' /etc/apache2/apache2.conf


CMD /usr/sbin/apache2 -DFOREGROUND
