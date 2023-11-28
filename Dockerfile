FROM ruby:3.3.0-preview3-alpine3.18 AS Builder

ENV BUILD_PACKAGES="build-base postgresql-dev shared-mime-info build-base automake libtool libffi-dev gmp-dev openssl-dev pkgconfig autoconf"

ENV BUNDLER_VERSION="2.4.13"

RUN apk add --no-cache $BUILD_PACKAGES && \
  gem install bundler:$BUNDLER_VERSION && \
  rm -rf /var/cache/apk/*

WORKDIR /app

ADD Gemfile* /app/

RUN  bundle config --local without "development test" && \
     bundle install -j8 --no-cache && \
     bundle clean --force && \
     rm -rf /usr/local/bundle/cache && \
     find /usr/local/bundle/gems/ -name "*.c" -delete && \
     find /usr/local/bundle/gems/ -name "*.o" -delete

RUN wget -O - https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2 | tar -xj && \
    cd jemalloc-5.3.0 && \
    ./configure && \
    make && \
    make install

ADD . /app

################################################################################

FROM ruby:3.3.0-preview3-alpine3.18

ENV EFFECTIVE_PACKAGES="bash tzdata postgresql-client libc6-compat"

ARG CAPROVER_GIT_COMMIT_SHA=${CAPROVER_GIT_COMMIT_SHA}
ENV GIT_COMMIT=${CAPROVER_GIT_COMMIT_SHA}

RUN apk add --no-cache $EFFECTIVE_PACKAGES && \
  ln -s /lib/libc.musl-x86_64.so.1 /lib/ld-linux-x86-64.so.2 && \
  mkdir -p /app/tmp/pids && \
  addgroup -g 1000 -S app && adduser -u 1000 -S app -G app && \
  chown -R app:app /app

COPY --from=Builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=Builder --chown=app:app /app /app
COPY --from=builder /usr/local/lib/libjemalloc.so.2 /usr/local/lib/

ENV LD_PRELOAD=/usr/local/lib/libjemalloc.so.2

WORKDIR /app

RUN BUILD_STEP=true bundle exec rake assets:precompile

USER app

EXPOSE 3000

CMD bin/web
