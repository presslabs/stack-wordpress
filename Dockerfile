ARG PHP_VERSION=7.3.3
FROM php:${PHP_VERSION}-fpm-stretch as php
ARG FLAVOUR=minimal
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV PATH="/usr/local/docker/bin:${PATH}"
ENV PHP_VERSION=${PHP_VERSION}
ENV FLAVOUR=${FLAVOUR}
ENV COMPOSER_VERSION=1.7.2
ENV SUPERVISORD_VERSION=0.5
ENV DOCKERIZE_VERSION=1.2.0
# https://github.com/grpc/grpc/issues/13412
ENV GRPC_ENABLE_FORK_SUPPORT=1
ENV GRPC_POLL_STRATEGY=epoll1

RUN set -ex \
    && apt-get update \
    && apt-get install --no-install-recommends -y gnupg2 \
    && curl -s https://openresty.org/package/pubkey.gpg | apt-key add - \
    && echo "deb http://openresty.org/package/debian stretch openresty" > /etc/apt/sources.list.d/openresty.list \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
        ssmtp=2.64* unzip=6.0* openresty=1.13* libyaml-0-2=0.1* libyaml-dev=0.1* \
        less=481* git=1:2.11* openssh-client=1:7.4* \
    # we need yaml support for installing extensions
    && pecl install yaml \
    && docker-php-ext-enable --ini-name 50-docker-php-ext-yaml.ini yaml \
    && apt-get autoremove --purge -y libyaml-dev \
    && rm -rf /var/lib/apt/lists/* \
    && chown -R www-data:www-data /var/www/html

COPY hack/docker/build-scripts /usr/local/docker/build-scripts

RUN set -ex \
    && apt-get update \
    && /usr/local/docker/build-scripts/install-composer \
    && /usr/local/docker/build-scripts/install-dockerize \
    && /usr/local/docker/build-scripts/install-supervisord \
    && /usr/local/docker/build-scripts/install-php-extensions /usr/local/docker/build-scripts/php-extensions.${FLAVOUR}.yaml \
    && rm -rf /var/lib/apt/lists/* /tmp/pear/*

# prepare rootfs
RUN set -ex \
    # symlink generated php.ini
    && ln -sf /usr/local/docker/etc/php.ini /usr/local/etc/php/conf.d/zz-01-custom.ini \
    # symlink php.ini from /var/run/secrets/presslabs.org/instance
    && ln -sf /var/run/secrets/presslabs.org/instance/php.ini /usr/local/etc/php/conf.d/zz-90-instance.ini \
    # our dummy index
    && { \
       echo "<?php phpinfo(); "; \
    } | tee /var/www/html/index.php >&2 \
    && mkdir -p /var/lib/nginx/log \
    && ln -sf /dev/stderr /var/lib/nginx/log/error.log \
    && chown -R www-data:www-data /var/www \
    && chown -R www-data:www-data /run \
    && chown -R www-data:www-data /var/lib/nginx

COPY --chown=www-data:www-data hack/docker /usr/local/docker
COPY --chown=www-data:www-data ./nginx-lua /usr/local/docker/lib/nginx/lua/
USER www-data:www-data

EXPOSE 8080
ENTRYPOINT ["/usr/local/docker/bin/docker-php-entrypoint"]
CMD ["supervisord", "-c", "/usr/local/docker/etc/supervisor.conf"]


FROM php as wordpress-builder
RUN rm -rf /var/www/html
COPY --chown=www-data:www-data wordpress /var/www/wordpress
COPY --chown=www-data:www-data hack/var-www-skel /var/www
WORKDIR /var/www
RUN set -ex \
    && composer install --no-ansi --prefer-dist --no-dev \
    && find html -type f -name '.gitkeep' -delete \
    && rm -rf wordpress .composer

FROM php as wordpress
ENV WP_HOME=http://localhost:8080
ENV WP_CLI_VERSION=2.1.0

USER root
RUN set -ex \
    && rm -rf /var/www/html \
    && /usr/local/docker/build-scripts/install-wp-cli

COPY --from=wordpress-builder --chown=www-data:www-data /var/www /var/www
USER www-data:www-data
