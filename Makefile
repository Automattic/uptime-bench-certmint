BINARY := uptime-bench-certmint
CMD := ./cmd/certmint

.PHONY: build test vet fmt clean

build:
	@mkdir -p bin
	go build -o bin/$(BINARY) $(CMD)

test:
	go test ./...

vet:
	go vet ./...

fmt:
	gofmt -w $$(find . -name '*.go' -not -path './bin/*')

clean:
	rm -rf bin coverage.out
