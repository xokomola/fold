xquery version "3.0";

(:~
 : Fold test mocks
 :
 : Create mock requests for easier testing. Mostly a port of Clojure ring-mock.
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/weavejester/ring-mock
 :)
module namespace mock = 'http://xokomola.com/xquery/fold/utils/mock';

declare namespace uri = 'java:java.net.URI'; 

import module namespace codec = 'http://xokomola.com/xquery/fold/utils/codec'
    at 'codec.xqm';

(:~
 : Turn a map of parameters into a urlencoded string.
 :
 : @param $params The parameter map
 : @return Url-encoded parameters
 :)
declare %private function mock:encode-params($params as map(*))
    as xs:string? {
    if (map:size($params) gt 0) then
        codec:form-encode($params)
    else
        ()
};

(:~
 : Add a HTTP header to the request map.
 :
 : @param $request The request map
 : @param $header The header string
 : @param $value The header value
 : @return The modified request map 
 :)
declare function mock:header($request as map(*), $header as xs:string, $value)
    as map(*) {
    map:new((
        $request, 
        map { 'headers': 
            map:new((
                $request('headers'),
                map:entry(lower-case($header), $value)
            )) 
        }
    ))
};

(:~
 : Set the content type of the request map.
 :
 : @param $request The request map
 : @param $mime-type The mime-type string
 : @return The modified request map
 :)
declare function mock:content-type($request as map(*), $mime-type as xs:string)
    as map(*) {
    mock:header($request, 'content-type', $mime-type)
};

(:~
 : Set the content length of the request map.
 :
 : @param $request The request map
 : @param $length The length of the request body
 : @return The modified request map
 :)
declare function mock:content-length($request as map(*), $length)
    as map(*) {
    mock:header($request, 'content-length', xs:long($length))
};

(:~
 : Create a query string from a URI and a map of parameters.
 :
 : @param $request The request map
 : @param $params The query string or parameter map
 : @return The new query string
 :)
declare function mock:combined-query($request as map(*), $params) 
    as xs:string? {
    if ($params instance of map(*)) then 
        (: NOTE: Ring uses remove string/blank? to remove empty params :)
        string-join(
            ($request('query-string'), mock:encode-params($params)),
            '&amp;'
        )
    else
        string-join(
            ($request('query-string'), codec:form-encode($params)),
            '&amp;'
        )
};

(:~
 : Merge the supplied parameters into the query string of the request.
 :
 : @param $request The request map
 : @param $params The query string or a parameter map
 : @return The modified request map
 :)
declare function mock:merge-query($request as map(*), $params) 
    as map(*) {
    let $query := mock:combined-query($request, $params)
    return
        if ($query) then
            map:new(($request, map { 'query-string':  $query })) 
        else
            $request
};

(:~
 : Set the query string of the request to a string or a map of parameters.
 :
 : @param $request The request map
 : @param $params A query string or a parameter map
 : @return The modified request map
 :)
declare function mock:query-string($request as map(*), $params)
    as map(*) {
    map:new((
        $request,
        map {
            'query-string': 
            typeswitch($params)
                case map(*)
                    return mock:encode-params($params)
                case xs:string
                    return $params
                default
                    return string($params)
        }
    ))
};

(:~
 : Set the body of the request. The supplied body value can be a string or
 : a map of parameters to be url-encodied.
 :
 : @param $request The request map
 : @param $params A query string or a parameter map
 : @return The modified request map
 :)
declare function mock:body($request as map(*), $params)
    as map(*) {
    let $body := 
        typeswitch ($params)
            case xs:string
                return $params
            case map(*)
                return 
                    if (map:size($params) gt 0) then 
                        mock:encode-params($params)
                    else
                        ()
            default
                return ()
    (: FIXME: this should be in bytes not in characters :)
    let $content-length := string-length($body)
    return
        mock:content-type(
            mock:content-length(
                if ($body) then
                    map:new((
                        $request,
                        map { 'body': $body }
                    ))
                else
                    $request, 
                $content-length
            ),
            'application/x-www-form-urlencoded'
        )
};

(:~
 : Create a minimal valid request map from a HTTP method, a string
 : containing a URI, and an optional map of parameters that will be added to
 : the query string of the URI. The URI can be relative or absolute. Relative
 : URIs are assumed to go to http://localhost.
 :
 : @param $method The HTTP method
 : @param $uri The request URI
 : @param $params A querystring or a map of parameters
 : @return The modified request map
 :)
declare function mock:request($method as xs:string, $uri as xs:string, $params)
    as map(*) {
    let $uri      :=
        if ($uri castable as xs:anyURI) then 
            uri:new($uri) 
        else 
            uri:new('http://localhost')
    let $host     := (uri:get-host($uri), 'localhost')[1]
    let $port     := if (uri:get-port($uri) gt 0) then uri:get-port($uri) else ()
    let $scheme   := uri:get-scheme($uri)
    let $path     := uri:get-raw-path($uri)
    let $query    := uri:get-raw-query($uri)
    let $headers  := map { 'host': if ($port) then $host || ':' || $port else $host }
    let $request  :=
        map:new((
            map:entry('server-port', ($port, 80)[1]),
            map:entry('server-name', $host),
            map:entry('remote-addr', 'localhost'),
            map:entry('uri', if (string-length($path) = 0) then '/' else $path),
            map:entry('scheme', ($scheme, 'http')[1]),
            map:entry('request-method', upper-case($method)),
            map:entry('headers', $headers),
            if (string-length($query) = 0) then
                ()
            else
                map:entry('query-string', $query)
        ))
    return
        if ($request('request-method') = ('GET', 'HEAD')) then
            mock:merge-query($request, $params)
        else
            mock:body($request, $params)
};

declare function mock:request($method as xs:string, $uri as xs:string)
    as map(*) {
    mock:request($method, $uri, map {})
};
