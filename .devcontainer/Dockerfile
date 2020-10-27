FROM alpine:3.11

ARG BASH_VERSION=5.0.11-r1
ARG BATS_VERSION=v0.4.0
ARG SHELLCHECK_VERSION=v0.5.0
ARG SHFMT_VERSION=v2.6.4

ARG USER_UID=1000
ARG USER_NAME=dev

ARG COMMITIZEN_VER=4.0.3
ARG CZ_EMOJI_VER=1.1.2

RUN apk update && \
  apk add git bash=${BASH_VERSION} openssh nodejs sudo yarn && \
  wget "https://storage.googleapis.com/shellcheck/shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" && \
  tar --xz -xvf shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz && \
  cp shellcheck-${SHELLCHECK_VERSION}/shellcheck /usr/bin/ && \
  rm -rf shellcheck-* && \
  git clone https://github.com/bats-core/bats-core.git && \
  cd bats-core && \
  git checkout -b work ${BATS_VERSION} && \ 
  ./install.sh /usr/local && \
  cd ../ && \
  rm -rf bats-core && \ 
  wget https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_amd64 -O shfmt && \
  chmod 755 shfmt && \
  mv shfmt /usr/local/bin && \
  rm -rf /var/cache/apk/*

RUN adduser -D -u ${USER_UID} -s /bin/bash ${USER_NAME} && \
  echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
  
RUN yarn global add commitizen@${COMMITIZEN_VER} cz-emoji@${CZ_EMOJI_VER}
RUN echo '{ "path": "cz-emoji" }' > /home/${USER_NAME}/.czrc && chown ${USER_NAME} /home/${USER_NAME}/.czrc
