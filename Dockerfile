FROM nginx:latest
COPY ./nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY ./nginx/locations.d /etc/nginx/locations.d
COPY ./nginx/upstreams.d /etc/nginx/upstreams.d
