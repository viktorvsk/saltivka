FROM ruby:3.2.2-alpine AS Builder

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

ADD . /app

################################################################################

FROM ruby:3.2.2-alpine

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

WORKDIR /app

RUN BUILD_STEP=true bundle exec rake assets:precompile

USER app

EXPOSE 3000

CMD bin/web
