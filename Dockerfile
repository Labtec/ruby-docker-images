ARG BASE_IMAGE_TAG
ARG RUBY_VERSION
ARG RUBY_SO_SUFFIX

### build ###
FROM freebsd/freebsd-runtime:$BASE_IMAGE_TAG AS build

ARG BASE_IMAGE_TAG
ARG RUBY_VERSION

ENV LANG C.UTF-8
ENV ASSUME_ALWAYS_YES yes

# XXXJL pkg upgrade -y hangs upgrading FreeBSD-runtime
RUN set -ex && \
    pkg lock -y FreeBSD-runtime && \
    pkg update && \
    pkg upgrade -y && \
    pkg install -y \
            autoconf \
            bison \
            ca_root_nss \
            pkgconf \
            gcc \
            git-tiny \
            libffi \
            gdbm \
            gmp \
            ncurses \
            readline \
            openssl31 \
            libyaml \
            gmake \
            ruby \
            rust \
            wget \
            zutils \
            bash \
            FreeBSD-clibs-dev \
            FreeBSD-libbsm-dev \
            FreeBSD-runtime-dev \
            && \
    pkg clean -ay && \
    ln -sf /usr/local/bin/bash /bin/bash

COPY tmp/ruby /usr/src/ruby
COPY install_ruby.sh /tmp/

RUN set -ex && \
    RUBY_VERSION=3.2.3 PREFIX=/root /tmp/install_ruby.sh
RUN pkg delete -y ruby
COPY tmp/ruby /usr/src/ruby

ARG optflags
ARG debugflags
ARG cppflags

RUN set -ex && \
# skip installing gem documentation
    mkdir -p /usr/local/etc && \
    { \
      echo 'install: --no-document'; \
      echo 'update: --no-document'; \
    } >> /usr/local/etc/gemrc && \
    \
    PATH=/root/bin:$PATH /tmp/install_ruby.sh

### ruby ###
FROM freebsd/freebsd-runtime:$BASE_IMAGE_TAG AS ruby

ARG BASE_IMAGE_TAG
ARG RUBY_VERSION
ARG RUBY_SO_SUFFIX

ENV LANG C.UTF-8
ENV ASSUME_ALWAYS_YES yes

# XXXJL chsh is in FreeBSD-utilities on 14.3 (it is now under FreeBSD-runtime)
RUN set -ex && \
    pkg lock -y FreeBSD-runtime && \
    pkg update && \
    pkg upgrade -y && \
    pkg install -y \
            ca_root_nss \
            libffi \
            gdbm \
            gmp \
            ncurses \
            readline \
            openssl31 \
            libyaml \
            bash \
            pkgconf \
            FreeBSD-utilities \
            && \
    pkg info -x \
      '^(libffi|gdbm|gmp|ncurses|readline|openssl31|libyaml)' \
      | xargs pkg set -A 0 \
      && \
    pkg check -s -a \
            && \
    pkg autoremove -y \
            && \
    pkg clean -ay && \
    ln -sf /usr/local/bin/bash /bin/bash

RUN set -ex && \
    if (id root &>/dev/null); then \
        chsh -s /usr/local/bin/bash; \
    fi
    # XXX FreeBSD only has rootful containers
    # if ! (id freebsd &>/dev/null); then \
    #     adduser -s /usr/local/bin/bash freebsd; \
    # fi

RUN mkdir -p /usr/local/etc

COPY --from=build \
     /usr/local/etc/gemrc /usr/local/etc

COPY --from=build \
     /usr/local/bin/bundle \
     /usr/local/bin/bundler \
     /usr/local/bin/erb \
     /usr/local/bin/gem \
     /usr/local/bin/irb \
     /usr/local/bin/racc \
     /usr/local/bin/rake \
     /usr/local/bin/rdoc \
     /usr/local/bin/ri \
     /usr/local/bin/ruby \
     /usr/local/bin/

COPY --from=build \
     /usr/local/etc/gemrc \
     /usr/local/etc/

COPY --from=build \
     /usr/local/include \
     /usr/local/include

COPY --from=build \
     /usr/local/lib/libruby.so.${RUBY_SO_SUFFIX:-$RUBY_VERSION} \
     /usr/local/lib/

RUN set -ex && \
    RUBY_SO_SUFFIX_MM=$(echo ${RUBY_SO_SUFFIX:-$RUBY_VERSION} | sed -e 's/\.[^.]*$//') && \
    ln -sf libruby.so.${RUBY_SO_SUFFIX:-$RUBY_VERSION} /usr/local/lib/libruby.so

COPY --from=build \
     /usr/local/lib/pkgconfig/ \
     /usr/local/lib/pkgconfig/

COPY --from=build \
     /usr/local/lib/ruby/ \
     /usr/local/lib/ruby/

COPY --from=build \
     /usr/local/share/man/man1/*.* \
     /usr/local/share/man/man1/


### development ###
FROM ruby AS development

RUN set -ex && \
    pkg lock -y FreeBSD-runtime && \
    pkg update && \
    pkg upgrade -y && \
    pkg install -y \
            pkgconf \
            curl \
            gdb \
            git \
            less \
            lv \
            wget \
            bash \
            && \
    pkg clean -ay && \
    ln -sf /usr/local/bin/bash /bin/bash
