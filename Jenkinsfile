@Library('libpipelines@master') _

hose {
    EMAIL = 'none@stratio.com'
    BUILDTOOL = 'make'
    VERSIONING_TYPE = 'stratioVersion-3-3'
    UPSTREAM_VERSION = '1.6.1'
    DEPLOYONPRS = true
    DEVTIMEOUT = 30
    ANCHORE_POLICY = "production"
    GRYPE_TEST = true

    BUILDTOOL_MEMORY_REQUEST = "1024Mi"
    BUILDTOOL_MEMORY_LIMIT = "4096Mi"

    DEV = { config ->
        doDocker(conf:config, dockerfile: 'Dockerfile', image:'cluster-api-gcp-controller')
    }
}
