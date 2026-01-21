FROM nix-docker.registry.twcstorage.ru/base/redhat/ubi10-minimal:10.1000-1766033715@sha256:05edf453b46e8f615ddad5bbeb3acebc4fbe3d467e2642d14cf43defd2b9465d

LABEL org.opencontainers.image.authors="wizardy.oni@gmail.com"

# Install prerequisites, git, python, pip, ansible
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
    && ansible --version \
    && jinja2 --version

# Install sops
ARG SOPS_VERSION=3.11.0
RUN curl -kLso sops-v${SOPS_VERSION}.linux.amd64 "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" \
    && install -o root -g root -m 0755 sops-v${SOPS_VERSION}.linux.amd64 /usr/local/bin/sops \
    && sops --check-for-updates --version

# Install age
ARG AGE_VERSION=1.2.1
RUN curl -kLso age-v${AGE_VERSION}-linux-amd64.tar.gz "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" \
    && tar -zxvf age-v${AGE_VERSION}-linux-amd64.tar.gz \
    && install -o root -g root -m 0755 age/age /usr/local/bin/age \
    && install -o root -g root -m 0755 age/age-keygen /usr/local/bin/age-keygen \
    && age --version \
    && age-keygen --version

# Install helm with plugins
ARG HELM_VERSION=3.19.0-linux-amd64 \
    HELM_DIFF_VERSION=3.13.0 \
    HELM_SECRETS_VERSION=4.6.10
ENV HELM_PLUGINS=/etc/helm/plugins
# hadolint ignore=SC2086
RUN curl -kLso helm-v${HELM_VERSION}.tar.gz "https://get.helm.sh/helm-v${HELM_VERSION}.tar.gz" \
    && tar -zxvf helm-v${HELM_VERSION}.tar.gz \
    && install -o root -g root -m 0755 linux-amd64/helm /usr/local/bin/helm \
    && helm version \
    && helm plugin install --version=${HELM_DIFF_VERSION} https://github.com/databus23/helm-diff \
    && helm plugin install --version=${HELM_SECRETS_VERSION} https://github.com/jkroepke/helm-secrets \
    && helm plugin list \
    && helm diff version \
    && helm secrets version

# Install yq
ARG YQ_VERSION=4.47.2
RUN curl -kLso yq_linux_amd64.tar.gz "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_amd64.tar.gz" \
    && tar -zxvf yq_linux_amd64.tar.gz \
    && install -o root -g root -m 0755 yq_linux_amd64 /usr/local/bin/yq \
    && yq --version

# Install kubectl
ARG KUBECTL_VERSION=1.34.0
RUN curl -kLso kubectl "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && kubectl version --client --output=yaml \
    && rm -rf /etc/tools

ENV HELM_DRIVER=configmap \
    PYTHONWARNINGS=ignore \
    HOME=/home/jenkins/agent

USER jenkins
