FROM ubuntu:20.04

# 时区设置
ARG timezone
ARG php_exec_mode

# 环境变量
ENV APP_ENV="production" \
    PHP_VERSION="7.4.3" \
    REDIS_VERSION="5.3.2" \
    SWOOLE_VERSION="4.5.2" \
    PHP_ROOT_DIR="/usr/local/php" \
    PHP_EXEC_MODE=${php_exec_mode:-"fpm"} \
    TIMEZONE=${timezone:-"Asia/Shanghai"}

ENV PHPIZE_DEPS gcc g++ make autoconf file dpkg-dev libc-dev pkg-config re2c

ENV PHP_FPM_CONF=${PHP_ROOT_DIR}/etc \
    PHP_SOURCE_URL=https://www.php.net/distributions/php-${PHP_VERSION}.tar.gz \
    DEBIAN_FRONTEND=noninteractive

COPY php-boot /usr/local/bin/php-boot

RUN apt-get update \
 #安装依赖
 && apt-get install -y --no-install-recommends $PHPIZE_DEPS ca-certificates curl xz-utils \
 && cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime \
 && echo ${TIMEZONE} > /etc/timezone \
 #安装目录
 && [ ! -d /home/www ]; mkdir /home/www \
 && [ ! -d $PHP_ROOT_DIR/conf.d ]; mkdir -p $PHP_ROOT_DIR/conf.d \
 #其他配置
 && chmod +x /usr/local/bin/php-boot \
 #清理工作
 && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
 && apt-get install -y --no-install-recommends libxml2-dev libsqlite3-dev libssl-dev libreadline-dev zlib1g-dev libcurl4-openssl-dev libonig-dev libzip-dev \
    libpng-dev libjpeg-dev libwebp-dev libfreetype-dev \
 #php下载安装
 && curl -o /usr/local/src/php-${PHP_VERSION}.tar.gz ${PHP_SOURCE_URL} \
 && tar -xvf /usr/local/src/php-${PHP_VERSION}.tar.gz -C /usr/local/src \
 && cd /usr/local/src/php-${PHP_VERSION} \
 && ./configure --prefix=${PHP_ROOT_DIR} \
        --with-config-file-path=${PHP_ROOT_DIR} \
        --with-config-file-scan-dir=${PHP_ROOT_DIR}/conf.d \
        --with-pdo-mysql=shared,mysqlnd --enable-shared --enable-mysqlnd \
        --enable-gd --with-webp --with-jpeg --with-freetype \
        --with-openssl \
        --with-zlib \
        --with-curl \
        --with-pear \
        --with-zip \
        --with-readline \
        --enable-fpm \
        --enable-mbstring \
        --enable-pcntl \
        --enable-sockets \
        --enable-session \
        --enable-bcmath \
 && make && make install && make clean \
 && ln -s $PHP_ROOT_DIR/bin/* /usr/local/bin \
 && ln -s $PHP_ROOT_DIR/sbin/* /usr/local/sbin \
 && pecl update-channels \
 #php配置
  && cp -v php.ini-* $PHP_ROOT_DIR/ \
  && cp -v php.ini-production $PHP_ROOT_DIR/php.ini \
  && sed -i "s/;extension=pdo_mysql/extension=pdo_mysql/g" $PHP_ROOT_DIR/php.ini \
  && cp -v $PHP_FPM_CONF/php-fpm.conf.default $PHP_FPM_CONF/php-fpm.conf \
  && sed -i "s/;pid = run\/php-fpm.pid/pid = run\/php-fpm.pid/g" $PHP_FPM_CONF/php-fpm.conf \
  && cp $PHP_FPM_CONF/php-fpm.d/www.conf.default $PHP_FPM_CONF/php-fpm.d/www.conf \
  && sed -i "s/listen = 127.0.0.1:9000/listen = 0.0.0.0:9000/g" $PHP_FPM_CONF/php-fpm.d/www.conf \
  && sed -i "s/group = nobody/group = nogroup/g" $PHP_FPM_CONF/php-fpm.d/www.conf \
  #清理工作
  && rm -rf /usr/local/src/*.tar.gz \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/pear ~/.pearrc

#扩展与依赖管理
RUN apt update \
 && apt install -y zip \
 #redis
 && pecl install http://pecl.php.net/get/redis-${REDIS_VERSION}.tgz \
 && echo "extension=redis.so" >> ${PHP_ROOT_DIR}/conf.d/extension.ini \
 #swoole
 && curl -L -o /usr/local/src/swoole-${SWOOLE_VERSION}.zip https://gitee.com/swoole/swoole/repository/archive/v${SWOOLE_VERSION} \
 && cd /usr/local/src && unzip swoole-${SWOOLE_VERSION}.zip -d /usr/local/src \
 && cd swoole-v${SWOOLE_VERSION} \
 && phpize && ./configure --enable-openssl --enable-http2 --enable-sockets \
 && make && make install \
 && echo "extension=swoole.so" >> ${PHP_ROOT_DIR}/conf.d/extension.ini \
 && rm -rf /usr/local/src/swoole* \
 #composer
 && curl -o /usr/local/bin/composer https://mirrors.aliyun.com/composer/composer.phar \
 && chmod u+x /usr/local/bin/composer \
 #clean
 && rm -rf /var/lib/apt/lists/*

 EXPOSE 9000

 WORKDIR ${PHP_ROOT_DIR}

 ENTRYPOINT ["php-boot"]
