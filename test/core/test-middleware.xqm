xquery version "3.0";

(:~
 : Tests for fold/middleware.xqm
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

import module namespace wrap = 'http://xokomola.com/xquery/fold/middleware'
    at '../../core/middleware.xqm';
import module namespace req = 'http://xokomola.com/xquery/fold/request'
    at '../../core/request.xqm';
import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at '../../core/response.xqm';
import module namespace utils = 'http://xokomola.com/xquery/common'
    at '../../common/common.xqm';

(:~
 : wrap:params
 :)

declare %unit:test function test:wrap-params-query-params-only() {
    let $req := map { 'query-string': 'foo=bar&amp;biz=bat%25' }
    let $res := wrap:params(function($request) { $request })($req)
    return (
        unit:assert-equals(
            $res('query-params'),
            map { 'foo': 'bar', 'biz': 'bat%' } ),
            
        unit:assert(fn:empty($res('form-parameters'))),
        
        unit:assert-equals(
            $res('params'),
            map { 'foo': 'bar', 'biz': 'bat%' } ) )
};

declare %unit:test function test:wrap-params-query-and-form-params() {
    let $req := 
        map { 
            'query-string': 'foo=bar',
            'headers': map { 'content-type': 'application/x-www-form-urlencoded' },
            'body': 'biz=bat%25' }
    let $res := wrap:params(function($request) { $request })($req)
    return (
        unit:assert-equals(
            $res('query-params'),
            map { 'foo': 'bar' } ),

        unit:assert-equals(
            $res('form-params'),
            map { 'biz': 'bat%' } ),
            
        unit:assert-equals(
            $res('params'),
            map { 'foo': 'bar', 'biz': 'bat%' } ) )
};

declare %unit:test function test:wrap-params-not-form-encoded() {
    let $req := 
        map { 
            'headers': map { 'content-type': 'application/json' },
            'body': '{foo: "bar"}' }
    let $res := wrap:params(function($request) { $request })($req)
    return (
        unit:assert-equals(
            $res('form-params'),
            ()),
        unit:assert-equals(
            $res('params'),
            ()) )
};

declare %unit:test function test:wrap-params-always-assocs-maps() {
    let $req := 
        map {
            'query-string': '',
            'headers': map { 'content-type': 'application/x-www-form-urlencoded' },
            'body': '' }
    let $res := wrap:params(function($request) { $request })($req)
    return (
        unit:assert-equals(
            $res('query-params'),
            map {}),
        unit:assert-equals(
            $res('form-params'),
            map {}),
        unit:assert-equals(
            $res('params'),
            map {}) )
};

declare %unit:test function test:wrap-params-encoding() {
    let $req := 
        map {
            'headers': map { 'content-type': 'application/x-www-form-urlencoded;charset=UTF-16' },
            'body': 'hello=world' }
    let $res := wrap:params(function($request) { $request })($req)
    return (
        unit:assert-equals(
            $res('form-params'),
            map { 'hello': 'world' }),
        unit:assert-equals(
            $res('params'),
            map { 'hello': 'world' }) )
};

(: wrap:not-modified :)
declare %private function test:handler-etag($etag) {
    utils:constantly(
        map { 'status': 200, 'headers': map { 'etag': $etag }, 'body': () })
};

declare %private function test:handler-modified($modified) {
    utils:constantly(
        map { 'status': 200, 'headers': map { 'last-modified': $modified }, 'body': () })
};

declare %private function test:etag-request($etag) {
    map { 'headers': map { 'if-none-match': $etag }}
};

declare %private function test:modified-request($modified-date) {
    map { 'headers': map { 'if-modified-since': $modified-date }}
};

declare %unit:test function test:wrap-not-modified() {
    let $req := test:modified-request('Sun, 23 Sep 2012 11:00:00 GMT')
    let $handler := test:handler-modified('Jan, 23 Sep 2012 11:00:00 GMT')
    return
        unit:assert-equals(
            $handler($req),
            wrap:not-modified($handler)($req)
        )
};

declare %unit:test function test:not-modified-response-etag-match() {
    let $known-etag := 'known-etag'
    let $request := map { 'headers': map { 'if-none-match': $known-etag }}
    let $h-resp :=
        function($etag) { 
            map { 'status': 200, 'headers': map { 'etag': $etag }, 'body': ()} 
        }
    return (
        unit:assert-equals(
            wrap:not-modified-response($h-resp($known-etag), $request)('status'),
            304
        ),
        unit:assert-equals(
            wrap:not-modified-response($h-resp('unknown-etag'), $request)('status'),
            200
        )
    )
};

declare %unit:test function test:not-modified-response-not-modified() {
    let $last-modified := 'Sun, 23 Sep 2012 11:00:00 GMT'
    let $request :=
        function($modified) {
            map { 'headers': map { 'if-modified-since': $modified } }
        }
    let $h-resp :=
        map { 'status': 200, 'headers': map { 'Last-Modified': $last-modified }, 'body': () } 
    return (
        unit:assert-equals(
            wrap:not-modified-response($h-resp, $request($last-modified))('status'),
            304
        ),
        unit:assert-equals(
            wrap:not-modified-response($h-resp, $request('Sun, 23 Sep 2012 11:52:50 GMT'))('status'),
            304
        ),
        unit:assert-equals(
            wrap:not-modified-response($h-resp, $request('Sun, 23 Sep 2012 10:00:50 GMT'))('status'),
            200
        )
    )
};

declare %unit:test function test:not-modified-response-body-content-length() {
    let $last-modified := 'Sun, 23 Sep 2012 11:00:00 GMT'
    let $request :=
        function($modified) {
            map { 'headers': map { 'if-modified-since': $modified } }
        }
    let $h-resp :=
        map { 'status': 200, 'headers': map { 'Last-Modified': $last-modified }, 'body': 'bla bla' }
    let $resp := wrap:not-modified-response($h-resp, $request($last-modified))
    return (
        unit:assert(empty($resp('body'))),
        unit:assert-equals(
            res:get-header($resp, 'Content-Length'),
            '0'
        )
    )
};

declare %unit:test function test:wrap-not-modified-no-modification-info() {
    let $response := map { 'status': 200, 'headers': map {}, 'body': () }
    return (
        unit:assert-equals(
            wrap:not-modified-response($response, test:etag-request('"12345"'))('status'),
            200
        ),
        unit:assert-equals(
            wrap:not-modified-response($response, test:modified-request('Sun, 23 Sep 2012 10:00:00 GMT'))('status'),
            200
            
        )
    )
};

declare %unit:test function test:wrap-not-modified-header-case-insensitivity() {
    let $h-resp := map { 'status': 200, 'headers':
                            map {
                                'LasT-ModiFied': 'Sun, 23 Sep 2012 11:00:00 GMT',
                                'EtAg': '"123456abcdef"'
                            } }
    return (
        unit:assert-equals(
            wrap:not-modified-response($h-resp, map { 'headers': map { 'if-modified-since': 'Sun, 23 Sep 2012 11:00:00 GMT'}})('status'),
            304
        ),
        unit:assert-equals(
            wrap:not-modified-response($h-resp, map { 'headers': map { 'if-none-match': '"123456abcdef"'}})('status'),
            304
        )
    )
        
};


(: wrap:head middleware :)

declare %private function test:head-handler($request) {
    map {
        'status': 200,
        'headers': map { 'X-method': $request('request-method') },
        'body': 'Foobar' }
};

declare %unit:test function test:wrap-head() {
    let $res := wrap:head(test:head-handler#1)( map { 'request-method': 'HEAD' })
    return (
        unit:assert-equals(
            $res('body'),
            () ),
        unit:assert-equals(
            $res('headers')('X-method'),
            'GET' ) ),
            
    let $res := wrap:head(test:head-handler#1)( map { 'request-method': 'POST' })
    return (
        unit:assert-equals(
            $res('body'),
            'Foobar' ),
        unit:assert-equals(
            $res('headers')('X-method'),
            'POST' ) )      
};

(: wrap:sniffer middleware :)

declare %unit:test function test:sniffer() {
    let $res := wrap:sniffer(function($r) { 'Hello' })(map {})
    return
        unit:assert-equals($res, 'Hello')
};

(: wrap:file middleware :)

declare variable $test:public-dir := file:base-dir() || 'assets';
declare variable $test:app := wrap:file(function($req) { 'RESPONSE' }, $test:public-dir);
declare variable $test:index-html := file:read-text($test:public-dir || '/index.html');
declare variable $test:foo-html := file:read-text($test:public-dir || '/foo.html');

declare %unit:test function test:wrap-file-unsafe-method() {
    unit:assert-equals(
        $test:app(map { 'request-method': 'GET', 'uri': '/foo' }),
        'RESPONSE'     
    )
};

declare %unit:test function test:wrap-file-forbidden-url() {
    unit:assert-equals(
        $test:app(map { 'request-method': 'GET', 'uri': '/../foo' }),
        'RESPONSE'     
    )
};

declare %unit:test function test:wrap-file-no-file() {
    unit:assert-equals(
        $test:app(map { 'request-method': 'GET', 'uri': '/dynamic' }),
        'RESPONSE'     
    )
};


declare %unit:test function test:wrap-file-directory() {
    let $response := $test:app(map { 'request-method': 'GET', 'uri': '/' })
    return (
        unit:assert-equals(
            $response('status'),
            200),
        unit:assert(
            every $key in map:keys($response('headers'))
            satisfies $key = ('Content-Length', 'Last-Modified')),
        unit:assert-equals(
            $response('body'),
            $test:index-html)
    )
};

declare %unit:test function test:wrap-file-with-extension() {
    let $response := $test:app(map { 'request-method': 'GET', 'uri': '/foo.html' })
    return (
        unit:assert-equals(
            $response('status'),
            200),
        unit:assert(
            every $key in map:keys($response('headers'))
            satisfies $key = ('Content-Length', 'Last-Modified')),
        unit:assert-equals(
            $response('body'),
            $test:foo-html)    
    )
};

(: wrap:content-type middleware :)

declare %unit:test function test:wrap-content-type-without-content-type() {
    let $response := map { 'headers': map {}}
    let $handler := wrap:content-type(utils:constantly($response))
    return (
        unit:assert-equals(
            $handler(map { 'uri': '/foo/bar.png' })('headers')('Content-Type'),
            'image/png'),
        unit:assert-equals(
            $handler(map { 'uri': '/foo/bar.txt' })('headers')('Content-Type'),
            'text/plain')
    )
};

declare %unit:test function test:wrap-content-type-with-content-type() {
    let $response := map { 'headers': map { 'Content-Type': 'application/x-foo' }}
    let $handler := wrap:content-type(utils:constantly($response))
    return
        unit:assert-equals(
            $handler(map { 'uri': '/foo/bar.png' })('headers')('Content-Type'),
            'application/x-foo')
};

declare %unit:test function test:wrap-content-type-unknown-file-extension() {
    let $response := map { 'headers': map {}}
    let $handler := wrap:content-type(utils:constantly($response))
    return (
        unit:assert-equals(
            $handler(map { 'uri': '/foo/bar.xxxaaa' })('headers')('Content-Type'),
            'application/octet-stream'),
        unit:assert-equals(
            $handler(map { 'uri': '/foo/bar' })('headers')('Content-Type'),
            'application/octet-stream')
    )
};

declare %unit:test function test:wrap-content-type-with-content-type-option() {
    let $response := map { 'headers': map {}}
    let $handler := 
        wrap:content-type(utils:constantly($response),
            map { 'content-type': 'application/x-foo' })
    return
        unit:assert-equals(
            $handler(map { 'uri': '/foo/bar.png' })('headers')('Content-Type'),
            'application/x-foo')
};

declare %unit:test function test:wrap-content-type-with-mime-types-option() {
    let $response := map { 'headers': map {}}
    let $handler :=
        wrap:content-type(utils:constantly($response), 
            map { 'mime-types':  map { 'edn': 'application/edn' }})
    return
        unit:assert-equals(
            $handler(map { 'uri': '/all.edn' })('headers')('Content-Type'),
            'application/edn')
};

declare %unit:test function test:wrap-content-type-empty-response() {
    let $response := map { 'headers': map {}}
    let $handler := wrap:content-type(utils:constantly(()))
    return
        unit:assert(
            empty($handler(map { 'uri': '/foo/bar.txt' })))
};


declare %unit:test function test:wrap-content-type-response-header-case-insensitivity() {
    let $response := map { 'headers': map { 'CoNteNt-typE': 'application/x-overridden' }}
    let $handler := wrap:content-type(utils:constantly($response))
    return
        unit:assert(
            $handler(map { 'uri': '/foo/bar.png' })('headers')('CoNteNt-typE'),
            'application/x-overridden')
};
