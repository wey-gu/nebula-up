FROM zephinzer/cloudshell
USER root
RUN wget https://github.com/vesoft-inc/nebula-console/releases/download/v3.4.0/nebula-console-linux-amd64-v3.4.0 -O /usr/local/bin/nebula-console && \
    chmod +x /usr/local/bin/nebula-console
RUN echo "figlet 'Welcome to NebulaGraph Playground'" > /etc/motd
RUN echo "echo '\033[34m'" >> /etc/motd
RUN echo "toilet -f standard -F metal 'Welcome to NebulaGraph Playground'" >> /etc/motd
RUN echo "echo '\033[0m'" >> /etc/motd
RUN echo "echo 'Run:'" >> /etc/motd
RUN echo "echo 'nebula-console -addr graphd -port 9669 -user root -p nebula'" >> /etc/motd

USER user

