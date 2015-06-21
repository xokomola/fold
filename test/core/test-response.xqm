xquery version "3.0";

(:~
 : Tests for fold/response.xqm
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring
 : @see https://github.com/weavejester/compojure
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

declare namespace f = 'java:java.io.File';

declare default function namespace 'http://xokomola.com/xquery/fold/response';

import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at '../../webapp/fold/response.xqm';

declare %unit:test function test:render-empty() {
    unit:assert-equals(
        res:render((), map { }), 
        ())
};

declare %unit:test function test:render-string() {
    let $response := res:render('Foo', map { })
    return (
        unit:assert-equals(
            $response('body'), 
            'Foo'),
        unit:assert-equals(
            $response('headers')('Content-Type'), 
            'text/plain; charset=utf-8'),
        unit:assert-equals(
            $response('status'),
            200) )
};

declare %unit:test function test:render-strings() {
    let $response := res:render(('Foo', 'bar'), map { })
    return (
        unit:assert-equals(
            $response('body'),
            'Foobar'),
        unit:assert-equals(
            $response('headers')('Content-Type'), 
            'text/plain; charset=utf-8'),
        unit:assert-equals(
            $response('status'),
            200) )
};

declare %unit:test function test:render-nodes() {
    let $response := res:render(<foo><bar/></foo>, map { })
    return (
        unit:assert-equals(
            $response('body'), 
            <foo><bar/></foo>),
        unit:assert-equals(
            $response('headers')('Content-Type'), 
            'application/xml; charset=utf-8'),
        unit:assert-equals(
            $response('status'),
            200) )
};

declare %unit:test function test:render-function() {
    let $response := res:render(function($req) { <foo><bar/></foo> }, map { })
    return (
        unit:assert-equals(
            $response('body'), 
            <foo><bar/></foo>),
        unit:assert-equals(
            $response('headers')('Content-Type'), 
            'application/xml; charset=utf-8'),
        unit:assert-equals(
            $response('status'),
            200) )
};

declare %unit:test function test:render-map() {
    let $response := res:render(map { 'body': 'foo' }, map { })
    return (
        unit:assert-equals(
            $response('body'),
            'foo'),
        unit:assert-equals(
            map:size($response), 
            1) )
};

declare %unit:test function test:redirect() {
    unit:assert-equals(
        map { 
            'status': 302, 
            'headers': map { 'Location': 'http://google.com' }, 
            'body': () },
        found("http://google.com") )
};

declare %unit:test function test:redirect-after-post() {
    unit:assert-equals(
        map { 
            'status': 303,
            'headers': map { 'Location': 'http://example.com' }, 
            'body': () },
        see-other("http://example.com") )
};

declare %unit:test function test:not-found() {
    unit:assert-equals(
        map { 
            'status': 404,
            'headers': map { 'Content-Type': 'text/plain' },
            'body': 'Not found' },
        not-found("Not found") )
};

declare %unit:test function test:created() {
    (: with location and without body :)
    unit:assert-equals(
        map {
            'status': 201, 
            'headers': map { 'Location': 'foobar/location' }, 
            'body': () },
        created("foobar/location") ),
    
    (: with body and with location :)    
    unit:assert-equals(
        map { 
            'status': 201, 
            'headers': map { 'Location': 'foobar/location' },
            'body': 'foobar' },
        created("foobar/location", "foobar") )   
};

declare %unit:test function test:response-string() {
    unit:assert-equals(
        map { 'status': 200, 'headers': map { 'Content-Type': 'text/plain' }, 'body': 'foobar' },
        ok("foobar") )
};

declare %unit:test function test:response-node() {
    unit:assert-equals(
        map { 'status': 200, 'headers': map { 'Content-Type': 'application/xml' }, 'body': <foobar/> },
        ok(<foobar/>) )
};

declare %unit:test function test:status() {
    unit:assert-equals(
        map { 'status': 200, 'body': () },
        status(map { 'status': (), 'body': () }, 200) )    
};

declare %unit:test function test:content-type() {
    unit:assert-equals(
        get-header(
            content-type(
                map {
                    'status': 200, 
                    'headers': map { 'Content-Length': 10 } },
                'text/html'), 
            'Content-Type'),
        'text/html')
};

declare %unit:test function test:charset() {
    (: add charset :)
    unit:assert-equals(
        get-header(
            charset( 
                map { 
                    'status': 200, 
                    'headers': map { 'Content-Type': 'text/html' } },
                'UTF-8'),
            'Content-Type'),
        'text/html; charset=UTF-8'),
        
    (: replace existing charset :)
    unit:assert-equals(
        get-header(
            charset(
                map {
                    'status': 200,
                    'headers': map { 'Content-Type': 'text/html; charset=UTF-16' } }, 
                'UTF-8'), 
            'Content-Type'),
        'text/html; charset=UTF-8'),

    (: default content-type :)
    unit:assert-equals(
        get-header(
            charset(
                map {
                    'status': 200, 
                    'headers': map {} }, 
                'UTF-8'),
            'Content-Type'),
        'application/xml; charset=UTF-8')
};

declare %unit:test function test:header() {
    unit:assert-equals(
        get-header(
            header(map { 'status': 200, 'headers': map {}}, 'X-Foo', 'Bar'),
            'X-Foo'),
        'Bar')
};

declare %unit:test function test:is-response() {
    unit:assert(
        is-response( map { 'status': 200, 'headers': map {}}) ),
    unit:assert(
        is-response( map { 'status': 200, 'headers': map {}, 'body': 'Foo' }) ),
    unit:assert(
        fn:not(is-response( map {})) ),
    unit:assert(
        fn:not(is-response( map { 'users': () })) )
};

declare %unit:test function test:get-header() {
    unit:assert-equals(
        get-header( map { 'headers': map { 'Content-Type': 'text/plain' }}, 'Content-Type'), 
        'text/plain'),
    unit:assert-equals(
        get-header( map { 'headers': map { 'content-type': 'text/plain' }}, 'Content-Type'), 
        'text/plain'),
    unit:assert-equals(
        get-header( map { 'headers': map { 'Content-typE': 'text/plain' }}, 'content-type'), 
        'text/plain'),
    unit:assert-equals(
        get-header( map { 'headers': map { 'Content-Type': 'text/plain' }}, 'content-length'), 
        () ),
    unit:assert-equals(
        get-header( map { }, 'content-length'), 
        () )  
};

declare %unit:test function test:file-response-map-text() {
    let $resp := file-response("foo.html", map { 'root': file:base-dir() || 'assets' })
    return (
        unit:assert-equals(
            $resp('status'), 
            200),
        unit:assert(
            every $key in map:keys($resp('headers'))
            satisfies $key = ('Content-Length', 'Last-Modified')),
        unit:assert-equals(
            $resp('headers')('Content-Length'),
            3),
        unit:assert-equals(
            $resp('body'),
            'foo')
    )
};

declare %unit:test function test:file-response-map-binary() {
    let $resp :=
        file-response(
            "foo.html", 
            map { 'root': file:base-dir() || 'assets', 'binary': fn:true() }
        )
    return (
        unit:assert-equals(
            $resp('status'), 
            200),
        unit:assert(
            every $key in map:keys($resp('headers'))
            satisfies $key = ('Content-Length', 'Last-Modified')),
        unit:assert-equals(
            $resp('headers')('Content-Length'),
            3),
        unit:assert-equals(
            $resp('body'),
            xs:base64Binary('Zm9v')) (: 'foo' in base64 binary encoding :)
    )
};

declare %unit:test function test:file-response-no-parent-dir() {
    unit:assert(
        fn:empty(
            file-response('../../../foo.xml', map { 'root': file:base-dir() || 'assets' })
        )
    )   
};
