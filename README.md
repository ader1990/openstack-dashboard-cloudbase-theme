# openstack-dashboard-cloudbase-theme
Cloudbase Solutions theme for **openstack/horizon**

## Run with Docker

```bash
docker build -t custom/horizon -f Dockerfile .

docker run -d -p 11211:11211 --name memcached memcached
docker run -d -p 1000:80 \
    --link memcached:memcached \
    -e KEYSTONE_URL='http://192.168.17.5:5000/v3' custom/horizon

```

