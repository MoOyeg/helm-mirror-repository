FROM registry.access.redhat.com/ubi8@sha256:44d75007b39e0e1bbf1bcfd0721245add54c54c3f83903f8926fb4bef6827aa2
ARG helm_binary='https://get.helm.sh/helm-v3.15.3-linux-amd64.tar.gz'
ENV env_var_name=$helm_binary

USER 0
WORKDIR /mirror
COPY . .
RUN dnf install -y tar skopeo 
RUN echo $helm_binary && curl -L $helm_binary -o helm.tar.gz \
    && tar -zxvf helm.tar.gz \
    && mv linux-amd64/helm /usr/local/bin/helm \
    && rm -rf linux-amd64 helm.tar.gz \
    && mkdir /inputs \
    && chgrp -R 0 /mirror \
    && chmod -R g=u /mirror \
    && chgrp -R 0 /inputs \
    && chmod -R g=u /inputs \
    &&chmod +x ./mirror.sh
USER 1001
ENTRYPOINT ["/usr/local/bin/helm"]


