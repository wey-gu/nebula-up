FROM zephinzer/cloudshell
USER root
RUN wget https://github.com/vesoft-inc/nebula-console/releases/download/v3.4.0/nebula-console-linux-amd64-v3.4.0 -O /usr/local/bin/nebula-console && \
    chmod +x /usr/local/bin/nebula-console
# RUN echo "echo -e '\e[1;34m'" >> /etc/profile
# RUN echo "echo 'Welcome to NebulaGraph Playground'" >> /etc/profile
# RUN echo "echo 'Run:'" >> /etc/profile
# RUN echo "echo 'nebula-console -addr graphd -port 9669 -user root -p nebula'" >> /etc/profile
# RUN echo "echo ' '" >> /etc/profile
# RUN echo "echo -e '\e[0m'" >> /etc/profile

USER user
