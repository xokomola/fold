xquery version "3.0";

(:~
 : Tests for fold/adapter/basex-restxq.xqm
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

declare default function namespace 'http://xokomola.com/xquery/fold/adapter';

import module namespace apps = 'http://xokomola.com/xquery/fold/adapter'
    at '../../webapp/fold/adapter/basex-restxq.xqm'; 
import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at '../../webapp/fold/response.xqm';

(: A response without a header :)
declare %unit:test function test:serve-response-1() {
    let $rest-response := 
        serve-response(
            map { 'status': 200, 'headers': map {}, 'body': <foobar/> })
    return (
        unit:assert-equals(
            fn:count($rest-response/http:response/http:header), 
            0),
        unit:assert-equals(
            xs:string($rest-response/http:response/@status), 
            '200'),
        unit:assert-equals(
            fn:count($rest-response), 
            2),
        unit:assert(
            $rest-response[2]/self::foobar) )
};

(: A response with a Location header :)
declare %unit:test function test:serve-response-2() {
    let $rest-response :=
        serve-response(res:created('http://example.com', <foobar/>))
    return (
        unit:assert-equals(
            fn:count($rest-response/http:response/http:header), 
            1),
        unit:assert(
            $rest-response/http:response/http:header[@name = 'Location']/@value = 'http://example.com'),
        unit:assert(
            $rest-response[2]/self::foobar) )
};

(: A response with a custom header :)
declare %unit:test function test:serve-response-3() {
    let $rest-response := 
        serve-response(res:header(res:ok(<foobar/>), 'X-Foo', 'Bar'))
    return (
        unit:assert-equals(
            fn:count($rest-response/http:response/http:header), 
            2),
        unit:assert(
            $rest-response/http:response/http:header[@name = 'X-Foo']/@value = 'Bar'),
        unit:assert(
            $rest-response[2]/self::foobar) )
};
