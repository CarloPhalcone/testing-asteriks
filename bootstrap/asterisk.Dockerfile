# Используем базовый образ Ubuntu 20.04
FROM ubuntu:20.04

# Устанавливаем переменную окружения для избежания интерактивных запросов
ENV DEBIAN_FRONTEND=noninteractive

# Настраиваем часовой пояс
RUN ln -fs /usr/share/zoneinfo/Asia/Almaty /etc/localtime \
    && echo "Asia/Almaty" > /etc/timezone

# Настраиваем libvpb1
RUN echo "libvpb1 vpb-driver-region 7" | debconf-set-selections

# Обновляем источники на архивные
RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
    && sed -i 's|http://security.ubuntu.com/ubuntu|http://old-releases.ubuntu.com/ubuntu|g' /etc/apt/sources.list

# Устанавливаем зависимости
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    wget \
    build-essential \
    git \
    autoconf \
    subversion \
    pkg-config \
    libssl-dev \
    libncurses5-dev \
    libnewt-dev \
    libxml2-dev \
    libsqlite3-dev \
    uuid-dev \
    libjansson-dev \
    libssl1.1 \
    libncurses5 \
    libnewt0.52 \
    libxml2 \
    libsqlite3-0 \
    uuid \
    libjansson4 \
    && apt-get clean \
    && apt-get autoremove -y

# Создаем пользователя и группу для Asterisk
RUN groupadd -r asterisk && useradd -r -g asterisk -d /var/lib/asterisk asterisk

# Создаем необходимые директории
RUN mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk

# Переходим в рабочий каталог
WORKDIR /usr/src

# Скачиваем и распаковываем Asterisk
ARG ASTERISK_VERSION=18.23.0
RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz \
    && tar -zxvf asterisk-${ASTERISK_VERSION}.tar.gz \
    && rm asterisk-${ASTERISK_VERSION}.tar.gz

# Переходим в каталог Asterisk
WORKDIR /usr/src/asterisk-${ASTERISK_VERSION}

# Выполняем скрипты, если они есть
RUN if [ -d "contrib/scripts" ]; then \
        chmod +x contrib/scripts/get_mp3_source.sh contrib/scripts/install_prereq; \
        contrib/scripts/get_mp3_source.sh; \
        contrib/scripts/install_prereq install; \
    else \
        echo "Warning: contrib/scripts directory not found, skipping optional scripts"; \
    fi

# Конфигурируем и компилируем Asterisk
RUN ./configure \
    && make menuselect.makeopts \
    && menuselect/menuselect --enable CORE-SOUNDS-RU-WAV --enable CORE-SOUNDS-RU-ULAW \
    && make -j$(nproc) \
    && make install \
    && make samples \
    && make config

# Настраиваем владельца директорий
RUN chown -R asterisk:asterisk /var/run/asterisk /var/lib/asterisk /var/spool/asterisk /var/log/asterisk /usr/lib/asterisk /etc/asterisk

# Настраиваем Asterisk для запуска от пользователя asterisk
RUN sed -i 's/#AST_USER="asterisk"/AST_USER="asterisk"/g' /etc/default/asterisk \
    && sed -i 's/#AST_GROUP="asterisk"/AST_GROUP="asterisk"/g' /etc/default/asterisk

# Указываем команду по умолчанию
USER asterisk
CMD ["/bin/bash", "-c", "/usr/sbin/asterisk -f -vvv"]