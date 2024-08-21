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
FROM golang:1.21.9@sha256:ff6cfbd291c157a5b67e121b050e80a646a88b55de5c489a5c07acb9528a1feb as builder

# Install git and gcloud
RUN apt-get update && apt-get install -y \
    git \
    python3 \
    python3-pip \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    && pip3 install --upgrade pip \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - \
    && apt-get update && apt-get install -y google-cloud-sdk \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Ensure go, git, and gcloud are installed
RUN go version && git --version && gcloud --version

# Run this with docker build --build_arg $(go env GOPROXY) to override the goproxy
ARG goproxy=https://proxy.golang.org
ENV GOPROXY=$goproxy

# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN  --mount=type=cache,target=/root/.local/share/golang \
     --mount=type=cache,target=/go/pkg/mod \
     go mod download -x

# Copy the sources
COPY ./ ./

# Ensure script has execution permissions
RUN chmod +x hack/custom/change-version.sh

# Build
ARG ARCH
ARG LDFLAGS
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.local/share/golang \
    CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} \
    go build -a -trimpath -ldflags "${LDFLAGS} -extldflags '-static'" \
    -o manager .

# Use Alpine for the final image to minimize the size
FROM alpine:3.18
WORKDIR /

# Copy the manager binary from the builder stage
COPY --from=builder /workspace/manager .

# Use a non-root user for security
USER nobody

# Set the entrypoint to the manager binary
ENTRYPOINT ["/manager"]
