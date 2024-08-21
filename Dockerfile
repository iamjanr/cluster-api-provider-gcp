# Build the manager binary
FROM golang:1.21.9@sha256:ff6cfbd291c157a5b67e121b050e80a646a88b55de5c489a5c07acb9528a1feb as builder
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

# Install necessary tools in the final image
RUN apk add --no-cache \
    git \
    go \
    python3 \
    py3-pip \
    curl \
    && pip3 install --upgrade pip \
    && apk add --no-cache google-cloud-sdk

WORKDIR /
COPY --from=builder /workspace/manager .
USER nobody
ENTRYPOINT ["/manager"]