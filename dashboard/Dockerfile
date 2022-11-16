FROM node:16
WORKDIR /app
ENV dashboard_version v1.1.1
RUN wget -O nebula-dashboard.tar.gz "https://github.com/vesoft-inc/nebula-dashboard/archive/refs/tags/$dashboard_version.tar.gz" \ 
    && tar -xzvf nebula-dashboard.tar.gz && rm -rf nebula-dashboard.tar.gz \
    && cd nebula-dashboard-* && npm install && npm run build && npm run pkg && cd ..\
    && cp nebula-dashboard-*/dashboard /app/ && cp -r nebula-dashboard-*/public /app/ && cp nebula-dashboard-*/vendors/config-release.json /app/config.json \
    && rm -fr nebula-dashboard-*

ENTRYPOINT ["/app/dashboard"]
