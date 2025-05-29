# Используем базовый образ Ubuntu 22.04 (LTS, поддержка до 2027 года)
FROM ubuntu:22.04

# Устанавливаем переменную окружения для избежания интерактивных запросов
ENV DEBIAN_FRONTEND=noninteractive

# Обновляем список пакетов и устанавливаем зависимости, включая tzdata и libedit-dev
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
    tzdata \
    libedit-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Настраиваем часовой пояс
RUN ln -fs /usr/share/zoneinfo/Asia/Almaty /etc/localtime \
    && echo "Asia/Almaty" > /etc/timezone \
    && dpkg-reconfigure -f noninteractive tzdata

# Создаем пользователя и группу для Asterisk
RUN groupadd -r asterisk && useradd -r -g asterisk -d /var/lib/asterisk asterisk

# Создаем необходимые директории
RUN mkdir -p /var/run/asterisk /var/log/asterisk /var/spool/asterisk/voicemail /etc/asterisk \
    && chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk \
    && chmod -R 750 /var/run/asterisk /var/log/asterisk /var/spool/asterisk /etc/asterisk

# Переходим в рабочий каталог
WORKDIR /usr/src

# Скачиваем и распаковываем Asterisk
ARG ASTERISK_VERSION=18.23.0
RUN wget -O asterisk.tar.gz https://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-${ASTERISK_VERSION}.tar.gz \
    && tar -zxvf asterisk.tar.gz \
    && rm asterisk.tar.gz \
    && mv asterisk-${ASTERISK_VERSION} asterisk

# Переходим в каталог Asterisk
WORKDIR /usr/src/asterisk

# Устанавливаем дополнительные зависимости и звуковые файлы
RUN ./contrib/scripts/install_prereq install || echo "Skipping prereq install" \
    && ./contrib/scripts/get_mp3_source.sh || echo "Skipping mp3 source"

# Конфигурируем и компилируем Asterisk
RUN ./configure
RUN make menuselect.makeopts
RUN menuselect/menuselect --enable CORE-SOUNDS-RU-WAV --enable CORE-SOUNDS-RU-ULAW
RUN make -j2
RUN make install
RUN make samples
RUN make config

# Настраиваем владельца для установленных файлов Asterisk
RUN chown -R asterisk:asterisk /usr/lib/asterisk /var/lib/asterisk /var/spool/asterisk /var/log/asterisk /var/run/asterisk /etc/asterisk

# Настраиваем Asterisk для запуска от пользователя asterisk
RUN sed -i 's/#AST_USER="asterisk"/AST_USER="asterisk"/g' /etc/default/asterisk \
    && sed -i 's/#AST_GROUP="asterisk"/AST_GROUP="asterisk"/g' /etc/default/asterisk

# Открываем порты для Asterisk (SIP и RTP)
EXPOSE 5060/udp 10000-20000/udp

# Указываем том для хранения записей
VOLUME /var/spool/asterisk/voicemail

# Указываем команду по умолчанию
USER asterisk
CMD ["/usr/sbin/asterisk", "-f", "-vvv"]