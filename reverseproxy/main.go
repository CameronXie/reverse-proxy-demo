package main

import (
	"flag"
	"fmt"
	"net/http"
	"net/http/httputil"
	"net/url"

	"go.uber.org/zap"
)

var (
	port = flag.String("port", "80", "reverse proxy port number")
	addr = flag.String("addr", "https://httpbin.org", "address to redirect the request to")
)

func setupLogger() *zap.Logger {
	logger, _ := zap.NewProduction()
	return logger
}

func reverseProxyHandler(proxy *httputil.ReverseProxy, host string, l *zap.Logger) http.HandlerFunc {
	return func(w http.ResponseWriter, req *http.Request) {
		l.Info(fmt.Sprintf("received request: %v %v", req.Method, req.URL.Path))
		req.Host = host
		proxy.ServeHTTP(w, req)
	}
}

func healthCheckHandler(l *zap.Logger) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l.Info(fmt.Sprintf("health check %s", r.URL))
		w.WriteHeader(http.StatusNoContent)
	}
}

func main() {
	flag.Parse()

	l := setupLogger()
	u, uErr := url.Parse(*addr)
	if uErr != nil {
		l.Fatal(uErr.Error())
	}

	l.Info(fmt.Sprintf("listen address :%s, redirect requests to %s", *port, *addr))

	http.HandleFunc("/", reverseProxyHandler(httputil.NewSingleHostReverseProxy(u), u.Host, l))
	http.HandleFunc("/healthcheck", healthCheckHandler(l))

	if err := http.ListenAndServe(fmt.Sprintf(":%v", *port), nil); err != nil {
		l.Fatal(err.Error())
	}
}
