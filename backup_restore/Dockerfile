FROM alpine
WORKDIR /root
ENV BR_VERSION=0.6.1
ENV AGENT_VERSION=0.1.1
RUN wget https://github.com/vesoft-inc/nebula-br/releases/download/v$BR_VERSION/br-$BR_VERSION-linux-amd64 -O br && chmod +x br && mv br /usr/local/bin/br && \
    wget https://github.com/vesoft-inc/nebula-agent/releases/download/v$AGENT_VERSION/agent-$AGENT_VERSION-linux-amd64 -O agent && chmod +x agent && mv agent /usr/local/bin/agent
RUN apk add --no-cache bash docker && rm -rf /var/cache/apk/*

ENTRYPOINT ["/usr/local/bin/agent"]
