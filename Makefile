.DEFAULT_GOAL := help
.PHONY: help envoy envoy-docker httpbin

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'


httpbin: ## run httpbin with access logs
	docker run --rm -p 8080:80 -e GUNICORN_CMD_ARGS="--capture-output --error-logfile - --access-logfile - --access-logformat '%(h)s %(t)s %(r)s %(s)s Host: %({Host}i)s'" kennethreitz/httpbin

envoy-docker: ## run Envoy in Docker with QUIC
	docker run --rm \
		-p 10000:10000/udp \
		-p 10000:10000/tcp \
		-p 9901:9901 \
		-v ${PWD}/envoy-local.yaml:/tmp/envoy.yaml \
		-v ${PWD}/example_com_cert.pem:/tmp/example_com_cert.pem \
		-v ${PWD}/example_com_key.pem:/tmp/example_com_key.pem \
		envoyproxy/envoy:v1.22.0 -c /tmp/envoy.yaml -l trace


envoy: ## run Envoy with QUIC
	envoy -c envoy/envoy-local.yaml


