xquery version "3.0";

(:~
 : Tests for fold/test/mock.xqm
 :
 : Mostly a port of Clojure ring-mock test.
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/weavejester/ring-mock
 : @see https://github.com/ring-clojure/ring-codec
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

declare default function namespace 'http://xokomola.com/xquery/fold/utils/mock';

import module namespace mock = 'http://xokomola.com/xquery/fold/utils/mock'
    at '../../utils/mock.xqm'; 

declare %unit:test function test:request-relative-uri() {
    unit:assert-equals(
        request('GET', '/foo'),
        map {
            'server-port':     80,
            'server-name':     'localhost',
            'remote-addr':     'localhost',
            'uri':             '/foo',
            'scheme':          'http',
            'request-method':  'GET',
            'headers': map { 'host': 'localhost' } } )
};

declare %unit:test function test:request-absolute-uri() {
    unit:assert-equals(
        request('POST', 'https://example.com:8443/foo?bar=baz', map { 'quux': 'zot' }),
        map {
            'server-port':     8443,
            'server-name':     'example.com',
            'remote-addr':     'localhost',
            'uri':             '/foo',
            'query-string':    'bar=baz',
            'scheme':          'https',
            'request-method':  'POST',
            'body':            'quux=zot',
            'headers': map {
                'host': 'example.com:8443',
                'content-type': 'application/x-www-form-urlencoded',
                'content-length': 8 } } )
};

declare %unit:test function test:empty-path() {
    unit:assert-equals(
        request('GET', 'http://example.com')('uri'), 
        '/')
};

declare %unit:test function test:get-only-params() {
    unit:assert-equals(
        request('GET', '/?a=b')('query-string'), 
        'a=b')
};

declare %unit:test function test:get-added-params() {
    unit:assert-equals(
        request('GET', '/', map { 'x': 'y', 'z': 'n' } )('query-string'), 
        'x=y&amp;z=n'),
    unit:assert-equals(
        request('GET', '/?a=b', map { 'x': 'y' } )('query-string'), 
        'a=b&amp;x=y'),
    unit:assert-equals(
        request('GET', '/?', map { 'x': 'y' } )('query-string'), 
        'x=y'),
    unit:assert-equals(
        request('GET', '/', map { 'x': 'a b' } )('query-string'), 
        'x=a+b')
};

declare %unit:test function test:post-added-params() {
    let $request := request('POST', '/', map { 'x': 'y', 'z': 'n' } )
    return (
        unit:assert-equals(
            $request('body'), 
            'x=y&amp;z=n'),
        unit:assert-equals(
            map:contains($request, 'query-string'), 
            fn:false()) ),
    
    let $request := request('POST', '/?a=b', map { 'x': 'y' } )
    return (
        unit:assert-equals(
            $request('body'), 
            'x=y'),
        unit:assert-equals(
            $request('query-string'), 
            'a=b') ),
    
    let $request := request('POST', '/?', map { 'x': 'y' } )
    return (
        unit:assert-equals(
            $request('body'), 'x=y'),
        unit:assert-equals(
            map:contains($request, 'query-string'),
            fn:false()) ),
    
    let $request := request('POST', '/', map { 'x': 'a b' } )
    return (
        unit:assert-equals(
            $request('body'), 
            'x=a+b'),
        unit:assert-equals(
            map:contains($request, 'query-string'), 
            fn:false()) ),
    
    let $request := request('POST', '/?a=b')
    return (
        unit:assert(
            fn:not(map:contains($request, 'body'))),
        unit:assert-equals(
            $request('query-string'),
            'a=b') )  
};

declare %unit:test function test:put-added-params() {
    let $request := request('PUT', '/', map { 'x': 'y', 'z': 'n' })
    return
        unit:assert-equals(
            $request('body'), 
            'x=y&amp;z=n')
};

declare %unit:test function test:header() {
    unit:assert-equals(
        header(map { }, 'X-Foo', 'Bar'),
        map { 'headers': map { 'x-foo': 'Bar' }} )
};

declare %unit:test function test:content-type() {
    unit:assert-equals(
        content-type(map { }, 'text/html'),
        map { 'headers': map { 'content-type': 'text/html' }} )
};

declare %unit:test function test:content-length() {
    unit:assert-equals(
        content-length(map { }, 10),
        map { 'headers': map { 'content-length': 10 }} )
};

declare %unit:test function test:query-string() {
    (: string :)
    unit:assert-equals(
        query-string(map { }, "a=b"),
        map { 'query-string': 'a=b' } ),
    
    (: map of params :)    
    unit:assert-equals(
        query-string(map { }, map { 'a': 'b' } ),
        map { 'query-string': 'a=b' } ),
       
    (: overwriting :)
    unit:assert-equals(
        query-string(
            query-string(map { }, map { 'a': 'b' }),
            map { 'c': 'd' } ),
        map { 'query-string': 'c=d' } )

};

declare %unit:test function test:invalid-url() {
    let $request := request('GET', 'this-is-not-a-url')
    return
        (: when url cannot be turned into a request use 'http://localhost' :)
        unit:assert-equals(
            $request('headers')('host'), 
            'localhost')
};
