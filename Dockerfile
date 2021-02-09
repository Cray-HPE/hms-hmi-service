# MIT License
#
# (C) Copyright [2018-2021] Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# Dockerfile for building hms-hmi-service.

# Build base just has the packages installed we need.
FROM dtr.dev.cray.com/baseos/golang:1.14-alpine3.12 AS build-base

RUN set -ex \
    && apk update \
    && apk add build-base

# Base copies in the files we need to test/build.
FROM build-base AS base

# Copy all the necessary files to the image.
COPY cmd $GOPATH/src/stash.us.cray.com/HMS/hms-hmi-service/cmd
COPY vendor $GOPATH/src/stash.us.cray.com/HMS/hms-hmi-service/vendor


### UNIT TEST Stage ###
FROM base AS testing

# Run unit tests...
CMD ["sh", "-c", "set -ex && go test -v stash.us.cray.com/HMS/hms-hmi-service/cmd/hmi-service"]


### COVERAGE Stage ###
FROM base AS coverage

# Run test coverage...
CMD ["sh", "-c", "set -ex && go test -cover -v stash.us.cray.com/HMS/hms-hmi-service/cmd/hmi-service"]


### Build Stage ###
FROM base AS builder

RUN set -ex && go build -v -i -o /usr/local/bin/hbtd stash.us.cray.com/HMS/hms-hmi-service/cmd/hmi-service


### Final Stage ###
FROM dtr.dev.cray.com/baseos/alpine:3.12
LABEL maintainer="Cray, Inc."
EXPOSE 28500
STOPSIGNAL SIGTERM

RUN set -ex \
    && apk update \
    && apk add --no-cache curl

# Copy the final binary.  To use hmi-service as the daemon name rather
# than 'hbtd':
#   COPY --from=builder go/hmi-service /usr/local/bin

COPY --from=builder /usr/local/bin/hbtd /usr/local/bin

# Run the daemon

ENV DEBUG=0
ENV ERRTIME=20
ENV WARNTIME=10
ENV SM_URL="https://api-gateway.default.svc.cluster.local/apis/smd/hsm/v1"
ENV USE_TELEMETRY=1
ENV TELEMETRY_HOST="cluster-kafka-bootstrap.sma.svc.cluster.local:9092:cray-hmsheartbeat-notifications"

# If KV_URL is set to empty the Go code will determine the URL from env vars.
# This is due to the fact that in Dockerfiles you CANNOT create an env var 
# using other env vars.

ENV KV_URL=

CMD ["sh", "-c", "hbtd --debug=$DEBUG --errtime=$ERRTIME --warntime=$WARNTIME --sm_url=$SM_URL --kv_url=$KV_URL --use_telemetry=$USE_TELEMETRY --telemetry_host=$TELEMETRY_HOST" ]
