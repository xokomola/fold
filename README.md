# Fold 0.1

![Fold](logo.png)

Fold is a web application library for XQuery. It currently works with the BaseX
database server (8.0) but can probably be made to work on any other XML database that 
supports XQuery 3.0.

Fold is largely a port of the [Ring][ring] and [Compojure][compojure] Clojure
libraries. These libraries in turn are inspired by Python's [WSGI][wsgi] and
Ruby's [Rack][rack] libraries.

Currently, Fold is implemented in pure XQuery code (on top of [RESTXQ][restxq]).

IMPORTANT: This library is not yet ready for production use, far from it. It
does not perform well and I hope that by publishing it I can gather feedback
for improving it. Or, it may be a bad idea altogether. Don't know yet.

## Features

- Fold provides a unified API for programming web applications or REST services.

## Requirements

- BaseX 8.0 or higher

## Getting Started

TODO

[wsgi]: http://wsgi.readthedocs.org/en/latest
[rack]: http://rack.github.io
[restxq]: http://exquery.github.io/exquery/exquery-restxq-specification/restxq-1.0-specification.html
[ring]: https://github.com/ring-clojure/ring
[compojure]: https://github.com/weavejester/compojure
