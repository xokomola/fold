xquery version "3.0";

(:~
 : Fold adapter for BaseX / RESTXQ
 :
 : Contains the lower-level stuff to interface with BaseX.
 : Also makes dispatches the request to the main routes in
 : routes.xqm fold:route.
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 :)
module namespace fold = 'http://xokomola.com/xquery/fold/adapter';

import module namespace request = 'http://exquery.org/ns/request';
import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at '../../fold/response.xqm'; 
import module namespace service = 'http://xokomola.com/xquery/fold'
    at '../../routes.xqm'; 

declare variable $fold:time := false();
declare variable $fold:time-cache := false();

(:~
 : Route the request through the routes map in apps.
 :
 : Note that this calls the route function in the apps module.
 :
 : @param $request a request map.
 : @return the HTTP response object.
 : @error Foo bar
 : @since 0.1
 : @see foobar
 : @deprecated
 :)

declare function fold:serve($request as map(*)) {
    fold:serve-response(service:routes()($request))
};

declare function fold:timed-serve($request as map(*)) {
    prof:mem(prof:time(fold:serve($request), 
        $fold:time-cache, 'TOTAL TIME: '), 
        $fold:time-cache, 'TOTAL MEM: ')
};

declare variable $fold:handler := 
    if ($fold:time) then 
        fold:timed-serve#1 
    else
        fold:serve#1;

(:~
 : Create the initial request map.
 :
 : @param $segments the segments of the path to be served.
 : @return a request map.
 :)
declare function fold:path($segments as xs:string*)
    as map(*) {
    fold:build-request-map(map { 'path': '/' || string-join($segments, '/')})
};

declare function fold:path($body, $segments as xs:string*)
    as map(*) {
    fold:build-request-map(map { 'body': $body, 'path': '/' || string-join($segments, '/')})
};

(:~
 : Create the initial request map from the HTTP request as provided by request 
 : module.
 :
 : @param $params The initial request which at this point probably only contains
 : the 'path' path of the request
 : @return The fully initialized HTTP request map
 :)
declare function fold:build-request-map($params as map(*))
    as map(*) {
    map:new((
        (: TODO: also add content-type and content-length (lower-case) on root map :)
        map:entry('server-port', request:port()),
        map:entry('server-name', request:hostname()),
        map:entry('remote-addr', request:remote-hostname() || ':' || request:remote-port()),
        map:entry('uri', request:path()),
        map:entry('query-string', request:query()),
        map:entry('scheme', request:scheme()),
        map:entry('request-method', upper-case(request:method())),
        map:entry('context', request:context-path()),
        (: TODO: check if it is better to leave this one out when no value :)
        map:entry('ssl-client-cert', request:attribute('javax.servlet.request.X509Certificate')),
        (: Basex request module doesn't differentiate between query string, form params etc. :)
        (: We'll add them here so fold wrap:params can deal with them and included them in the params :)
        map:entry('basex-params',
            map:new((
                for $param in request:parameter-names()
                return
                    map:entry(fn:lower-case($param), request:parameter($param))
            ))
        ),
        map:entry('headers', 
            map:new(( 
                for $header in request:header-names()
                return 
                    map:entry(fn:lower-case($header), request:header($header))
            ))
        ),
        if ($params('body')) then
            map:entry('body', $params('body'))
        else
            ()
    ))
};

(:~
 : Renders the response map into the final HTTP response.
 :
 : It assumes that this is a valid response map containing
 : all needed to render a response.
 : 
 : @see response.xqm render.xqm#1 for more
 :
 : @param $response the final response map.
 : @return the HTTP response object.
 :)
declare function fold:serve-response($response as map(*)) {
    (<rest:response>
        {
            let $content-type-header := res:get-header($response, 'Content-Type')
            where $content-type-header
            return
                <output:serialization-parameters>
                    <output:media-type value="{ tokenize(res:get-header($response, 'Content-Type'), ';')[1] }"/>
                </output:serialization-parameters>
        }
        <http:response status="{ $response('status') }">{
            for $header in map:keys($response('headers'))
            return
                <http:header name="{ $header }" value="{ res:get-header($response, $header) }"/>
        }</http:response>
    </rest:response>,
    $response('body'))
};

(:~
 : Map all REST requests to serve via a proxy function.
 : Note that this adapter only covers the standard HTTP methods except PATCH, TRACE and CONNECT
 : and also that POST and PUT are using a different function
 : because RESTXQ will process the request body for POST and PUT
 : and this should not happen with the other methods (even though
 : the HTTP specs allow it) and Roy says it's bad.
 :
 : I also rely on MIXUPDATES because I don't think db:output() is flexible
 : enough to handle all situations (I think).
 :
 : Having a %rest:ANY annotation would be helpful here.
 :
 : @param $s1 to $s10 The individual path segments as receveived from RESTXQ
 : @return The final HTTP response
 :
 : It's rather clumsy but maps paths to a reasonable depth.
 :)

declare %rest:path("/") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy() { $fold:handler(fold:path(())) };

declare %rest:path("/{$s1}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1) { $fold:handler(fold:path(($s1))) };

declare %rest:path("/{$s1}/{$s2}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2) { $fold:handler(fold:path(($s1,  $s2))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2, $s3) { $fold:handler(fold:path(($s1, $s2, $s3))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2, $s3, $s4) { $fold:handler(fold:path(($s1, $s2, $s3, $s4))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2, $s3, $s4, $s5) { $fold:handler(fold:path(($s1, $s2, $s3, $s4, $s5))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2, $s3, $s4, $s5, $s6) { $fold:handler(fold:path(($s1, $s2, $s3, $s4, $s5, $s6))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2, $s3, $s4, $s5, $s6, $s7) { $fold:handler(fold:path(($s1, $s2, $s3, $s4, $s5, $s6, $s7))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8) { $fold:handler(fold:path(($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}/{$s9}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9) { $fold:handler(fold:path(($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}/{$s9}/{$s10}") %rest:GET %rest:DELETE %rest:HEAD %rest:OPTIONS
function fold:proxy($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9, $s10) { $fold:handler(fold:path(($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9, $s10))) };

(: POST :)
declare %rest:path("/") %rest:POST("{$body}")
function fold:proxy_post($body) { $fold:handler(fold:path($body, ())) };

declare %rest:path("/{$s1}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1) { $fold:handler(fold:path($body, ($s1))) };

declare %rest:path("/{$s1}/{$s2}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1, $s2) { $fold:handler(fold:path($body, ($s1, $s2))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1, $s2, $s3) { $fold:handler(fold:path($body, ($s1, $s2, $s3))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1, $s2, $s3, $s4) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1, $s2, $s3, $s4, $s5) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1, $s2, $s3, $s4, $s5, $s6) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}") %rest:POST("{$body}") 
function fold:proxy_post($body,$s1, $s2, $s3, $s4, $s5, $s6, $s7) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6, $s7))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}/{$s9}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}/{$s9}/{$s10}") %rest:POST("{$body}")
function fold:proxy_post($body,$s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9, $s10) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9, $s10))) };

(: PUT :)
declare %rest:path("/") %rest:PUT("{$body}")
function fold:proxy_put($body) { $fold:handler(fold:path($body, ())) };

declare %rest:path("/{$s1}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1) { $fold:handler(fold:path($body, ($s1))) };

declare %rest:path("/{$s1}/{$s2}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1, $s2) { $fold:handler(fold:path($body, ($s1, $s2))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1, $s2, $s3) { $fold:handler(fold:path($body, ($s1, $s2, $s3))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1, $s2, $s3, $s4) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1, $s2, $s3, $s4, $s5) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1, $s2, $s3, $s4, $s5, $s6) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}") %rest:PUT("{$body}") 
function fold:proxy_put($body,$s1, $s2, $s3, $s4, $s5, $s6, $s7) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6, $s7))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}/{$s9}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9))) };

declare %rest:path("/{$s1}/{$s2}/{$s3}/{$s4}/{$s5}/{$s6}/{$s7}/{$s8}/{$s9}/{$s10}") %rest:PUT("{$body}")
function fold:proxy_put($body,$s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9, $s10) { $fold:handler(fold:path($body, ($s1, $s2, $s3, $s4, $s5, $s6, $s7, $s8, $s9, $s10))) };
