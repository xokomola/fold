xquery version "3.0";

(:~
 : Tests for fold/request.xqm
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring 
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

declare default function namespace 'http://xokomola.com/xquery/fold/request';

import module namespace req = 'http://xokomola.com/xquery/fold/request'
    at '../../webapp/fold/request.xqm';
import module namespace mock = 'http://xokomola.com/xquery/fold/utils/mock'
    at '../../webapp/fold/utils/mock.xqm'; 

declare %unit:test function test:request-url() {
    unit:assert-equals(
        request-url(map { 
            'scheme': 'http', 
            'uri': '/foo/bar', 
            'headers': map { 'host': 'example.com' },
            'query-string': 'x=y' }),
        "http://example.com/foo/bar?x=y"),
        
    unit:assert-equals(
        request-url(map {
            'scheme': 'http', 
            'uri': '/', 
            'headers': map { 'host': 'localhost:8080' } }),
        "http://localhost:8080/"),
        
    unit:assert-equals(
        request-url(map {
            'scheme': 'https', 
            'uri': '/index.html', 
            'headers': map { 'host': 'www.example.com' } }),
        "https://www.example.com/index.html")   
};

declare %unit:test function test:content-type() {
    (: no content type :)
    unit:assert-equals(
        content-type(map { 'headers': map { }}),
        ()),
        
    (: content type with no charset :)
    unit:assert-equals(
        content-type(map { 
            'headers': map { 'content-type': 'text/plain' } }),
        "text/plain"),
        
    (: content type with charset :)
    unit:assert-equals(
        content-type(map { 
            'headers': map { 'content-type': 'text/plain; charset=UTF-8' } }),
        "text/plain")
};

declare %unit:test function test:method() {
    unit:assert-equals(
        method(map { 'request-method': 'GET' }),
        'GET'),
        
    unit:assert-equals(
        method(map { 'request-method': 'FOOBAR' }),
        'FOOBAR')
};

declare %unit:test function test:content-length() {
    (: no content-length header :)
    unit:assert-equals(
        content-length( map { 'headers': map { }}),
        () ),
        
    (: a content-length header :)
    unit:assert-equals(
        content-length(map { 'headers': map { 'content-length': '1337' }}),
        1337)
};

declare %unit:test function test:character-encoding() {
    (:no content-type :)
    unit:assert-equals(
        character-encoding(map { 
            'headers': map { }}),
        () ),
    
    (: content-type with no charset :)
    unit:assert-equals(
        character-encoding(map { 
            'headers': map { 'content-type': 'text/plain' }}),
        () ),
        
    (: conten-type with charset :)
    unit:assert-equals(
        character-encoding(map { 
            'headers': map { 'content-type': 'text/plain; charset=UTF-8' }}),
        "UTF-8"),

    unit:assert-equals(
        character-encoding(map { 
            'headers': map { 'content-type': 'text/plain;charset=UTF-8' }}),
        "UTF-8")
};

declare %unit:test function test:is-urlencoded-form() {
    (: urlencoded form :)
    unit:assert(
        is-urlencoded-form(
            map { 'headers': map { 'content-type': 'application/x-www-form-urlencoded' } })),
    unit:assert(
        is-urlencoded-form(
            map { 'headers': map { 'content-type': 'application/x-www-form-urlencoded; charset=UTF-8' } })),
        
    (: other content type :)
    unit:assert(
        fn:not(is-urlencoded-form(
            map { 'headers': map { 'content-type': 'application/json' } }))),
        
    (: no content type :)
    unit:assert(
        fn:not(is-urlencoded-form(
            map { 'headers': map { } })))
};

declare %unit:test function test:body() {
    (: nil body :)
    unit:assert-equals(
        body( map { 'body': () }),
        () ),
        
    (: string body :)
    unit:assert-equals(
        body( map { 'body': 'foo' }),
        'foo'),
        
    (: xml body :)
    unit:assert-equals(
        body( map { 'body': <foobar/> }),
        <foobar/>),

    (: namespace xml body :)
    unit:assert-equals(
        body( map { 'body': <test:foobar/> }),
        <test:foobar/>)     
};

declare %unit:test function test:is-in-context() {
    unit:assert(
        is-in-context( map { 'uri': '/foo/bar' }, '/foo' )),
    unit:assert(
        fn:not(is-in-context( map { 'uri': '/foo/bar' }, '/bar' )))
};

declare %unit:test function test:set-context() {
    let $result := set-context(map { 'uri': '/foo/bar' }, '/foo')
    return (
          unit:assert-equals(
            $result('uri'),
            '/foo/bar'),
          unit:assert-equals(
            $result('path-info'), 
            '/bar'),
          unit:assert-equals(
            $result('context'), 
            '/foo') )
};

declare %unit:test("expected", "XPDY0002") function test:set-context-error() {
    unit:assert(
        set-context( map { 'uri': '/foo/bar' }, '/bar' ))
};

declare %unit:test function test:get-param() {
    unit:assert-equals(
        get-param( map { 'params': map { 'a': 10 }}, 'a'), 
        10),
    unit:assert-equals(
        get-param( map { 'params': map { 'b': 10 }}, 'a'),
        ()),
    unit:assert-equals(
        get-param( map { }, 'a'),
        ())
};
