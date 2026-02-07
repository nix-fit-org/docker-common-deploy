FROM --platform=${BUILDPLATFORM} nix-docker.registry.twcstorage.ru/base/redhat/ubi10-minimal:10.1002-1766033715 as tools

# Install tools on native platform https://github.com/tonistiigi/binfmt/issues/285 https://github.com/moby/buildkit/issues/6475
WORKDIR /etc/tools

# hadolint ignore=DL3002
USER root

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install openssl \
                                                git \
                                                tar \
                                                gzip \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum

ARG TARGETOS
ARG TARGETARCH

# Install kubectl
ARG KUBECTL_VERSION=1.34.0
RUN curl -kLso kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${TARGETOS}/${TARGETARCH}/kubectl"

# Install yq
ARG YQ_VERSION=4.47.2
RUN curl -kLso yq_${TARGETOS}_${TARGETARCH}.tar.gz "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_${TARGETOS}_${TARGETARCH}.tar.gz" \
    && tar -zxvf yq_${TARGETOS}_${TARGETARCH}.tar.gz --no-same-owner --no-same-permissions \
    && mv yq_${TARGETOS}_${TARGETARCH} yq \
    && rm -rf yq_${TARGETOS}_${TARGETARCH}.tar.gz

FROM nix-docker.registry.twcstorage.ru/base/redhat/ubi10-minimal:10.1002-1766033715

LABEL org.opencontainers.image.authors="wizardy.oni@gmail.com"

# Install other tools
WORKDIR /etc/tools

RUN microdnf -y --refresh \
                --setopt=install_weak_deps=0 \
                --setopt=tsflags=nodocs install openssl \
                                                git \
                                                tar \
                                                gzip \
                                                python3.12 \
                                                python3.12-pip \
    && microdnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum \
    && git --version \
    && python3.12 --version \
    && python3.12 -m pip --version \
    && groupadd -g 1000 jenkins \
    && useradd -u 1000 -g 1000 -m -d /home/jenkins/agent -s /bin/bash jenkins \
    && chown -R 1000:1000 /home/jenkins/agent

COPY requirements.txt .

RUN python3.12 -m pip install --no-cache-dir -r requirements.txt \
    && ansible --version

# Install yq, kubectl
COPY --from=tools --chmod=755 /etc/tools/kubectl /usr/local/bin/kubectl
COPY --from=tools /etc/tools/yq /usr/local/bin/yq
RUN kubectl version --client --output=yaml \
    && yq --version

ENV PYTHONWARNINGS=ignore \
    HOME=/home/jenkins/agent

USER jenkins
