FROM weygu/cloudshell
USER root
ARG TARGETPLATFORM
RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
      wget https://github.com/vesoft-inc/nebula-console/releases/download/v3.4.0/nebula-console-linux-amd64-v3.4.0 -O /usr/local/bin/nebula-console && \
      chmod +x /usr/local/bin/nebula-console; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      wget https://github.com/vesoft-inc/nebula-console/releases/download/v3.4.0/nebula-console-linux-arm64-v3.4.0 -O /usr/local/bin/nebula-console && \
      chmod +x /usr/local/bin/nebula-console; \
    fi

USER user
