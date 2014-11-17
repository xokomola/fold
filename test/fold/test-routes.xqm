xquery version "3.0";

(:~
 : Tests for fold/routes.xqm
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/weavejester/clout
 : @see https://github.com/weavejester/compojure
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

declare default function namespace 'http://xokomola.com/xquery/fold/routes';

import module namespace routes = 'http://xokomola.com/xquery/fold/routes'
    at '../../webapp/fold/routes.xqm';
import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at '../../webapp/fold/response.xqm';
import module namespace mock = 'http://xokomola.com/xquery/fold/utils/mock'
    at '../../webapp/fold/utils/mock.xqm'; 

declare %unit:test function test:path-decode() {
    unit:assert-equals(path-decode('abc'),   'abc'),
    unit:assert-equals(path-decode('a%20c'), 'a c'),
    unit:assert-equals(path-decode('a+c'),   'a+c'),
    unit:assert-equals(path-decode('a/c'),   'a/c'),
    unit:assert-equals(path-decode('a%5Cc'), 'a\c')
};

declare %unit:test function test:path-encode() {
    unit:assert-equals(path-encode('abc'), 'abc'),
    unit:assert-equals(path-encode('a c'), 'a%20c'),
    unit:assert-equals(path-encode('a+c'), 'a+c'),
    unit:assert-equals(path-encode('a/c'), 'a/c'),
    unit:assert-equals(path-encode('a\c'), 'a%5Cc'),
    unit:assert-equals(path-encode('/a/c?a=10'), '/a/c%3Fa=10')
};

declare %unit:test function test:fixed-path() {
    for $path in ('/', '/foo', '/foo/bar', '/foo/bar.html')
    return
        unit:assert-equals(
            matches(compile($path), mock:request('GET', $path)),
            map { } )
};

declare function test:route-assert($path, $request-path, $params) {
    unit:assert-equals(
        matches(
            compile($path),
            mock:request('GET', $request-path)),
        $params)
};

declare %unit:test function test:keyword-paths() {
    test:route-assert('/{x}',       '/foo',     map { 'x': 'foo' }),
    test:route-assert('/foo/{x}',   '/foo/bar', map { 'x': 'bar' }),
    test:route-assert('/a/b/{c}',   '/a/b/c',   map { 'c': 'c' }),
    test:route-assert('/{a}/b/{c}', '/a/b/c',   map { 'a': 'a', 'c': 'c' })
};

declare %unit:test function test:keyword-match-extensions() {
    test:route-assert('/foo.{ext}', '/foo.txt', map { 'ext': 'txt' }),
    test:route-assert('/{x}.{y}',   '/foo.txt', map { 'x': 'foo', 'y': 'txt' })
};

declare %unit:test function test:hyphen-keywords() {
    unit:assert-equals(
        matches(compile('/{foo-bar}'), mock:request('GET', '/baz'))('foo-bar'), 
        'baz'),
    unit:assert-equals(
        matches(compile('/{foo-}'), mock:request('GET', '/baz'))('foo-'), 
        'baz')
};

declare %unit:test function test:underscore-keywords() {
    unit:assert-equals(
        matches(compile('/{foo_bar}'), mock:request('GET', '/baz'))('foo_bar'), 
        'baz'),
    unit:assert-equals(
        matches(compile('/{_foo}'), mock:request('GET', '/baz'))('_foo'), 
        'baz')
};

declare %unit:test function test:urlencoded-keywords() {
    unit:assert-equals(
        matches(compile('/{x}'), mock:request('GET', '/foo%20bar'))('x'), 
        'foo bar'),
    unit:assert-equals(
        matches(compile('/{x}'), mock:request('GET', '/foo+bar'))('x'), 
        'foo+bar'),
    unit:assert-equals(
        matches(compile('/{x}'), mock:request('GET', '/foo%5Cbar'))('x'), 
        'foo\bar')
};

declare %unit:test function test:same-keyword-many-times() {
    test:route-assert('/{x}/{x}/{x}', '/a/b/c', map { 'x': ('a', 'b', 'c') }),
    test:route-assert('/{x}/b/{x}',   '/a/b/c', map { 'x': ('a', 'c') })
};

declare %unit:test function test:non-ascii-keywords() {
    unit:assert-equals(
        matches(compile('/{Ä_ü}'), mock:request('GET', '/foo'))('Ä_ü'), 
        'foo'),
    unit:assert-equals(
        matches(compile('/{äñßOÔ}'), mock:request('GET', '/abc'))('äñßOÔ'), 
        'abc'),
    unit:assert-equals(
        matches(compile('/{ä}/{ش}'), mock:request('GET', '/foo/bar'))('ä'), 
        'foo'),
    unit:assert-equals(
        matches(compile('/{ä}/{ش}'), mock:request('GET', '/foo/bar'))('ش'), 
        'bar'),
    unit:assert-equals(
        matches(compile('/{ä}/{ä}'), mock:request('GET', '/foo/bar'))('ä'), 
        ('foo', 'bar') )
};

declare %unit:test function test:utf8-routes() {
    unit:assert-equals(
        matches(compile('/{x}'), mock:request('GET', '/gro%C3%9Fp%C3%B6sna')), 
        map { 'x': 'großpösna' } )
};

declare %unit:test function test:wildcard-paths() {
    unit:assert-equals(
        matches(compile('/*'), mock:request('GET', '/foo'))('*'), 
        'foo'),
    unit:assert-equals(
        matches(compile('/*'), mock:request('GET', '/foo.txt'))('*'), 
        'foo.txt'),
    unit:assert-equals(
        matches(compile('/*'), mock:request('GET', '/foo/bar'))('*'), 
        'foo/bar'),
    unit:assert-equals(
        matches(compile('/foo/*'), mock:request('GET', '/foo/bar/baz'))('*'), 
        'bar/baz'),
    unit:assert-equals(
        matches(compile('/a/*/d'), mock:request('GET', '/a/b/c/d'))('*'), 
        'b/c')
};

declare %unit:test function test:url-paths() {
    let $match := 
        matches(
            compile('http://localhost/'), 
            map { 
                'scheme': 'http',
                'headers': map { 'host': 'localhost' }, 
                'uri': '/' } )
    return
        unit:assert(map:size($match) ge 0),
    
    let $match := 
        matches(
            compile('//localhost/'), 
            map { 
                'scheme': 'http',
                'headers': map { 'host': 'localhost' }, 
                'uri': '/' } )
    return
        unit:assert(map:size($match) ge 0),
        
    let $match := 
        matches(
            compile('//localhost/'), 
            map { 
                'scheme': 'https',
                'headers': map { 'host': 'localhost' }, 
                'uri': '/' } )
    return
        unit:assert(map:size($match) ge 0)
};

declare %unit:test function test:url-port-paths() {
    let $request := mock:request('GET', 'http://localhost:8080')
    return (
        unit:assert-equals(
            map:size(matches(compile('http://localhost:8080/'), $request)), 
            0),
        unit:assert(
            fn:empty(matches(compile('http://localhost:7070/'), $request))) )
};

declare %unit:test function test:unmatched-paths() {
    unit:assert(
        fn:empty(matches(compile('/foo'), mock:request('GET', '/bar'))) )
};

declare %unit:test function test:path-info-matches() {
    let $request := 
        map:new((mock:request('GET', '/foo/bar'), map { 'path-info': '/bar' } ))
    return
        (: path-info causes a match but with 0 param bindings :)
        unit:assert-equals(
            map:size(matches(compile('/bar'), $request)), 
            0)
};

declare %unit:test function test:custom-matches() {
    let $route := compile(('/foo/{bar}', map { 'bar': '\d+' }))
    return
        unit:assert(
            fn:empty(matches($route, mock:request('GET', '/foo/bar'))) )
};

declare %unit:test("expected", "XPDY0002") function test:unused-regex-keys-1() {
    unit:assert(
        compile(('/{foo}', map { 'foa': '\d+' })) )
};

declare %unit:test("expected", "XPDY0002") function test:unused-regex-keys-2() {
    unit:assert(
        compile(('/{foo}', map { 'foo': '\d+', 'bar': '.*' })) )
};

declare variable $test:routes := (
    GET('/get',         function($request) { res:ok('GET')     }),
    POST('/post',       function($request) { res:ok('POST')    }),
    PUT('/put',         function($request) { res:ok('PUT')     }),
    DELETE('/delete',   function($request) { res:ok('DELETE')  }),
    HEAD('/head',       function($request) { res:ok('HEAD')    }),
    OPTIONS('/options', function($request) { res:ok('OPTIONS') }),
    PATCH('/patch',     function($request) { res:ok('PATCH')   }),
    ANY('/any',         function($request) { res:ok('ANY')     }),
    GET('/a/*/d',       function($request) { res:ok('*')       })
);

declare variable $test:context-routes := (
    GET('/path',        function($request) { res:ok('CONTEXT PATH') })
);

(: Match GET route with exact path :)
declare %unit:test function test:get-route() {
    let $request := mock:request('GET', '/get')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            'GET')
};

(: Match GET route with extra path :)
declare %unit:test function test:get-route-extra-path() {
    let $request := mock:request('GET', '/get/a/b/c')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            'GET')
};

(: Match POST route with exact path :)
declare %unit:test function test:post-route() {
    let $request := mock:request('POST', '/post')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            'POST' )
};

(: Match PUT route with exact path :)
declare %unit:test function test:put-route() {
    let $request := mock:request('PUT', '/put')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            'PUT' )
};

(: Match DELETE route with exact path :)
declare %unit:test function test:delete-route() {
    let $request := mock:request('DELETE', '/delete')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            'DELETE' )
};

(: Match HEAD route with exact path (HEAD has no body) :)
declare %unit:test function test:head-route() {
    let $request := mock:request('HEAD', '/head')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            ())
};

(: Match OPTIONS route with exact path :)
declare %unit:test function test:options-route() {
    let $request := mock:request('OPTIONS', '/options')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            'OPTIONS' )
};

(: Match PATCH route with exact path :)
declare %unit:test function test:patch-route() {
    let $request := mock:request('PATCH', '/patch')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            'PATCH' )
};

(: Match ANY route with exact path :)
declare %unit:test function test:any-route() {
    let $request := mock:request('PATCH', '/any')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            'ANY' )
};

(: Match GET route with splat (*) path :)
declare %unit:test function test:splat-route() {
    let $request := mock:request('GET', '/a/b/c/d')
    let $response := route($test:routes)($request)
    return
        unit:assert-equals(
            $response('body'), 
            '*' )
};

(: Test path parameters :)
declare %unit:test function test:route-parameters() {
    let $response :=
        GET('/foo/{x}/{y}',
            function($request) {
                $request
            }
        )(mock:request('GET', '/foo/bar/baz'))
    return (
        unit:assert-equals(
            $response('params')('x'), 
            'bar'),
        unit:assert-equals(
            $response('params')('y'), 
            'baz')
    )
};

declare %unit:test function test:route-arg-binding() {
    let $response :=
        GET('/foo/{x}/{y}',
            ('x','y'),
            function($x, $y) {
                fn:upper-case($y || $x)
            }
        )(mock:request('GET', '/foo/bar/baz'))
    return 
        unit:assert-equals(
            $response('body'), 
            'BAZBAR')
};

declare %unit:test function test:context-keyword-matching() {
    let $handler := 
        context('/foo/{id}', GET('/', function($request) { $request }))
    return (
        unit:assert(
            $handler(mock:request('GET', '/foo/10')) instance of map(*) ),
        unit:assert(
            fn:empty($handler(mock:request('GET', '/bar/10'))) ) 
        )
};

declare %unit:test function test:context-regex-matching() {
    let $handler := 
        context(
            ('/foo/{id}', map { 'id': '\d+' } ), 
            GET('/', function($request) { $request }) )
    return (
        unit:assert(
            $handler(mock:request('GET', '/foo/10')) instance of map(*) ),
        unit:assert(
            fn:empty($handler(mock:request('GET', '/foo/ab'))) )
        )
};

declare %unit:test function test:context-key() {
    let $handler := 
        context(
            '/foo/{id}', 
            GET('/', function($request) { $request }) )
    return (
        unit:assert-equals(
            $handler(mock:request('GET', '/foo/10'))('context'), 
            '/foo/10'),
        unit:assert-equals(
            $handler(mock:request('GET', '/foo/10/bar'))('context'), 
            '/foo/10'),
        unit:assert-equals(
            $handler(mock:request('GET', '/foo/10/b%20r'))('context'), 
            '/foo/10'),
        unit:assert-equals(
            $handler(mock:request('GET', '/bar/10')), 
            () ) )
};