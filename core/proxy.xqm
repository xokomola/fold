xquery version "3.0";

(:~
 : Fold Proxy
 :
 : This may be the basis for a smarter proxy server module. 
 :
 : TODO: consider if we should allow rewriting request and response via function
 :       handlers so this is configurable.
 :
 : TODO: examples? Simple virtual hosting or an XML db cache?
 : 
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see http://en.wikipedia.org/wiki/Proxy_server
 : @see https://github.com/tailrecursion/ring-proxy
 :
 : TODO: Also deal with exerr conditions.
 :)
module namespace proxy = 'http://xokomola.com/xquery/fold/proxy';

(:~
 : Equivalent of http:send-request but with Flow request and response map.
 :)
declare function proxy:send-request($request as map(*), $href as xs:string)
    as map(*)? {
    proxy:response(
        proxy:request($request)
    )
};

(:~
 : Convert a Fold request map to an http:request element that the http:send-request
 : function expects.
 :)
declare function proxy:request($request as map(*))
    as element(http:request)? {
    'TODO'
};

(:~
 : Convert an http:response with body elements to a Fold response map.
 :)
declare function proxy:response($response as item()+)
    as map(*) {
    let $response as element(http:response) := head($response)
    let $body := tail($response)
    return
        map:new((
            map:entry('status', $response/@status),
            map:entry('headers', map:new((
                for $header in $response/http:header
                return
                    map:entry($header/@name, $header/@value)
            ))),
            map:entry('body', $body)
        ))
};

(:~
 : Takes an original request map, applies the request 'rewriting' options.
 : and returns a new request.
 :
 : TODO: this should avoid loops, so the request should not be equal to the
 :       original request (maybe this use a header to avoid this?)
 :)
declare %private function proxy:rewrite-request($request, $options)
    as map(*) {
    map:new(($request, map { 'uri': $options('uri') }))
};

(:~
 : Take a response received from the forwarded request and apply the
 : 'rewriting' options to modify the returned response.
 :)
declare %private function proxy:rewrite-response($response as map(*), $options as map(*))
    as map(*) {
    $response
};

(:~
 : Forward handler. Use an options map to configure the mapping of original
 : request to forward request.
 :)
declare function proxy:handler($request as map(*), $options as map(*))
    as map(*) {
    proxy:rewrite-response(
        proxy:send-request(
            proxy:rewrite-request($request, $options),
            'TODO'
        ), 
        $options
    )
};

(:~
 : Proxy middleware handler.
 : TODO
 :)
declare function proxy:wrap-proxy($handler, $remote-uri as xs:string, $options as map(*)) {
    function($request) {
        $handler($request)
    }
};
