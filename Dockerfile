# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build the manager binary
FROM golang:1.21.9 AS builder
WORKDIR /workspace

# Run this with docker build --build_arg $(go env GOPROXY) to override the goproxy
ARG goproxy=https://proxy.golang.org
ENV GOPROXY=$goproxy

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the sources
COPY ./ ./

# Build the binary
ARG ARCH
ARG LDFLAGS
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} \
    go build -a -trimpath -ldflags "${LDFLAGS} -extldflags '-static'" \
    -o manager .

# Final stage with Alpine
FROM alpine:3.18

# Install dependencies
RUN apk add --no-cache \
    git \
    python3 \
    py3-pip \
    curl \
    bash \
    libc6-compat

# Install Google Cloud SDK
RUN curl -LO https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-428.0.0-linux-x86_64.tar.gz \
    && tar -xzvf google-cloud-sdk-428.0.0-linux-x86_64.tar.gz \
    && rm google-cloud-sdk-428.0.0-linux-x86_64.tar.gz \
    && ./google-cloud-sdk/install.sh -q

# Update PATH to include the Google Cloud SDK directory
ENV PATH="/google-cloud-sdk/bin:${PATH}"

# Install Python dependencies for gcloud
RUN pip3 install --upgrade pip \
    && pip3 install -U crcmod \
    && pip3 install cryptography==43.0.0

WORKDIR /
COPY --from=builder /workspace/manager .
USER nobody
ENTRYPOINT ["/manager"]