xquery version "3.0";

(:~
 : Fold Responses
 :
 : Create and manipulate HTTP response maps.
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring
 : @see https://github.com/weavejester/compojure
 :)
module namespace res = 'http://xokomola.com/xquery/fold/response';

import module namespace utils = 'http://xokomola.com/xquery/common'
    at '../fold-common/common.xqm';

(:~
 : Generate a response map from a Fold route handler's return value.
 :
 : The response of a Fold route is passed through this function
 : to create a valid response map.
 :
 : @param $response The value to be rendered
 : @param $request The request map
 : @return The response map (or empty sequence)
 :)
declare function res:render($response, $request as map(*))
    as map(*)? {
    typeswitch ($response)
        case map(*)
            return $response
        case document-node()
            return res:content-type(res:response($response), 'application/xml; charset=utf-8')
        case node()
            return res:content-type(res:response($response), 'application/xml; charset=utf-8') 
        case function(*)
            return res:render($response($request), $request)
        case xs:base64Binary
            return res:content-type(res:response($response), 'application/octet-stream') 
        default
            return 
                if (not(empty($response))) then 
                    res:content-type(
                        res:response(string-join(for $s in $response return string($s),'')),
                        'text/plain; charset=utf-8')
                else
                    ()
};

(:~
 : Returns an updated response map with the given status.
 :
 : @param $response The response map
 : @param $status The HTTP status code
 : @return The updated response
 :)
declare function res:status($response as map(*), $status as xs:integer)
    as map(*) {
    map:new((
        $response,
        map { 'status': $status }
    ))
};

(:~
 : Returns an updated response map with the given body.
 :
 : @param $response The response map
 : @param $body The new response body
 : @return The updated response
 : TODO: write test
 :)
declare function res:body($response as map(*), $body)
    as map(*) {
    map:new((
        $response,
        map { 'body': $body }
    ))
};

(:~
 : Returns an updated response map with the specified header added.
 :
 : @param $response The response map
 : @param $name The response header name
 : @param $name The response header value
 : @return The updated response
 :)
declare function res:header($response as map(*), $name as xs:string, $value)
    as map(*) {
    map:new((
        $response, 
        map { 'headers': 
            map:new((
                $response('headers'), 
                map:new((map:entry($name, $value)))
            ))
        }
    ))
};

(:~
 : Returns a response map to serve a static file, or empty seq if an appropriate
 : file does not exist.
 : 
 : Note that it is probably more performant to define static files in web.xml
 : and let the web container handle it.
 :
 : Options:
 : - root: directory path
 : - binary: true, false (default)
 :
 : @param $response The response map
 : @param $name The response header name
 : @param $name The response header value
 : @return The updated response
 :)
(: TODO: compare responses coming from web container static files :)
declare function res:file-response($filepath as xs:string, $options as map(*))
    as map(*)? {
    let $path := res:find-file($filepath, $options)
    let $options := utils:merge(map { 'binary': false() }, $options)
    where $path
    return
        map:new((
            if ($options('binary')) then
                res:response(stream:materialize(file:read-binary($path)))
            else
                res:response(stream:materialize(file:read-text($path))),
            map { 'headers': 
                map { 
                    'Content-Length': file:size($path),
                    'Last-Modified': utils:format-date(file:last-modified($path)) }}
        ))
};

(:~
 : Checks if the path does not go above the $root.
 :)
declare %private function res:is-safe-path($root as xs:string, $path as xs:string) 
    as xs:boolean {
    starts-with(
        file:resolve-path($root || '/' || $path),
        file:resolve-path($root)
    )
};

declare %private function res:find-file($path as xs:string, $options as map(*)) {
    let $path := 
        if (res:is-safe-path($options('root'), $path)) then
            file:resolve-path($options('root') || '/' || $path)
        else 
            $path
    return
        if (file:is-dir($path) and $options('index-files') = true()) then
            res:find-index-file($path)
        else if (file:exists($path)) then
            $path
        else
            ()
};

declare %private function res:find-index-file($path as xs:string)
    as xs:string? {
    let $index := file:list($path, false(), 'index.*')[1]
    where $index
    return
        $path || '/' || $index
};
(:~
 ; Returns an updated response map with the a Content-Type header 
 : corresponding to the given content-type.
 :
 : @param $response The response map
 : @param $content-type The mime type of the content
 : @return The updated response
 :)
declare function res:content-type($response as map(*), $content-type as xs:string)
    as map(*) {
    res:header($response, 'Content-Type', $content-type)
};  

(:~
 : Returns an updated response map with the supplied charset added to the
 : Content-Type header.
 :
 : @param $response The response map
 : @param $charset The response body character encoding
 : @return The updated response
 :)
declare function res:charset($response as map(*), $charset as xs:string)
    as map(*) {
    let $content-type-header := res:get-header($response, 'Content-Type')
    let $content-type := 
        if ($content-type-header) then
            head(tokenize($content-type-header, ';'))
        else
            'application/xml'
    let $new-content-type-header := $content-type || '; charset=' || $charset
    return
        map:new((
            $response, 
            map { 'headers': 
                map:new((
                    $response('headers'), 
                    map { 'Content-Type': $new-content-type-header }
                ))
            }
        ))
};

(:~
 : Sets a cookie on the response. Requires the handler to be wrapped in the
 : wrap-cookies middleware.
 :
 : @param $response The response map
 : @param $name The response header name
 : @param $name The response header value
 : @return The updated response
 :)
declare function res:set-cookie($response as map(*), $name as xs:string)
    as map(*) {
    res:set-cookie($response, $name, map {})
};

declare function res:set-cookie($response as map(*), $name as xs:string, $options as map(*))
    as map(*) {
    'TODO'
};

(:~
 : Is this a valid response map?
 :
 : @param $response The response map
 : @return True if the supplied value is a valid response map
 :)
declare function res:is-response($response as map(*))
    as xs:boolean {
    map:contains($response, 'status')
    and $response('status') castable as xs:integer 
    and map:contains($response, 'headers')
    and $response('headers') instance of map(*)
};

(:~
 : Returns a response map to serve an xml database resource, or nil if the
 : resource does not exist.
 :
 : This function takes a map with extra options.
 :
 : Options:
 : - root: take the resource relative to this root
 :
 : @param $db The database collection name
 : @param $path The response header name
 : @return The requested file or not-found response
 :)
declare function res:xml-response($db as xs:string, $path as xs:string)
    as map(*) {
    res:xml-response($db, $path, map {})
};

declare function res:xml-response($db as xs:string, $path as xs:string, $options as map(*))
    as map(*) {
    let $path := 
        replace(
            replace(
                ($options('root'), '')[1] || '/' || $path,
                '//',
                '/'
            ),
            '^/',
            ''
        )
    return
        res:ok(db:open($db, $path))
};

(:~
 : Returns a response map to serve a binary database resource, or the empty 
 : sequence if the resource does not exist.
 :
 : This function takes a map with extra options [TODO].
 :
 : Options:
 : - root: take the resource relative to this root
 : - stream: materialize as stream
 :
 : @param $db The database collection name
 : @param $path The response header name
 : @return The requested binary file or not-found response
 :)
declare function res:binary-response($db as xs:string, $path as xs:string)
    as map(*) {
    res:binary-response($db, $path, map {})
};

declare function res:binary-response($db as xs:string, $path as xs:string, $options as map(*))
    as map(*) {
    let $path := 
        replace(
            replace(
                ($options('root'), '')[1] || '/' || $path,
                '//', 
                '/'
            ),
            '^/', 
            ''
        )
    return
        if ($options('stream')) then
            res:ok(stream:materialize(db:retrieve($db, $path)))
        else
            res:ok(db:retrieve($db, $path))
};

(:~
 : Look up a header in a Fold response (or request) case insensitively,
 : returning the value of the header.
 :
 : @param $response The response map
 : @param $header-name The response header name to return
 : @return The HTTP header value or the empty-sequence
 :)
declare function res:get-header($response as map(*), $header-name as xs:string) 
    as xs:string? {
    let $headers := $response('headers')
    let $header-names := map:keys(($headers, map {})[1])
    return ( 
        for $header in $header-names
        where lower-case($header-name) eq lower-case($header)
        return
            (: TODO: verify if Content-Length header is better left as xs:integer?, Ring uses all strings for header values  :)
            string($headers($header)))[1]
};

(: Standard HTTP response maps :)

(: Helper functions that provide good defaults for content type etc. :)
declare function res:response($body) {
    res:response(200, $body)
};

declare function res:response($status as xs:integer, $body) {
    map:new((
        map:entry('status', $status),
        (: TODO: This duplicates what res:render already does :)
        typeswitch($body)
            case xs:string
                return
                    map:entry('headers', map { 'Content-Type': 'text/plain' })
            case node()+
                return 
                    map:entry('headers', map { 'Content-Type': 'application/xml' })
            default 
                return
                    (),
        map:entry('body', $body)
    ))
};


declare function res:redirect($location) {
    res:redirect(302, $location)
};

declare function res:redirect($status as xs:integer, $location) {
    res:redirect($status, $location, ())
};

declare function res:redirect($status as xs:integer, $location, $body) {
    map:new((
        map:entry('status', $status),
        map:entry('headers', map { 'Location': $location }),
        map:entry('body', $body)
    ))
};

(: Informational :)

declare function res:continue()                             { res:response(100, ()) };
declare function res:switching-protocols()                  { res:response(101, ()) };
declare function res:processing()                           { res:response(102, ()) };

(: Success :)

declare function res:ok($body)                              { res:response(200, $body) };
declare function res:created($url)                          { res:created($url, ()) }; 
declare function res:created($url, $body)                   { res:redirect(201, $url, $body) };
declare function res:accepted($body)                        { res:response(202, $body) };
declare function res:non-authoritative-information($body)   { res:response(203, $body) };
declare function res:no-content()                           { res:response(204, ()) };
declare function res:reset-content($body)                   { res:response(205, $body) };
declare function res:partial-content($body)                 { res:response(206, $body) };
declare function res:multi-status($body)                    { res:response(207, $body) };
declare function res:already-reported($body)                { res:response(208, $body) };
declare function res:im-used($body)                         { res:response(209, $body) };

(: Redirection :)

declare function res:multiple-choices($url)                 { res:redirect(300, $url) };
declare function res:moved-permanently($url)                { res:redirect(301, $url) };
declare function res:found($url)                            { res:redirect(302, $url) };
declare function res:see-other($url)                        { res:redirect(303, $url) };
declare function res:not-modified($url)                     { res:redirect(304, $url) };
declare function res:use-proxy($url)                        { res:redirect(305, $url) };
declare function res:temporary-redirect($url)               { res:redirect(307, $url) };
declare function res:permanent-redirect($url)               { res:redirect(308, $url) };

(: Client Error :)

declare function res:bad-request($body)                     { res:response(400, $body) };
declare function res:unauthorized($body)                    { res:response(401, $body) };
declare function res:payment-required($body)                { res:response(402, $body) };
declare function res:forbidden($body)                       { res:response(403, $body) };
declare function res:not-found($body)                       { res:response(404, $body) };
declare function res:method-not-allowed($body)              { res:response(405, $body) };
declare function res:not-acceptable($body)                  { res:response(406, $body) };
declare function res:proxy-authentication-required($body)   { res:response(407, $body) };
declare function res:request-timeout($body)                 { res:response(408, $body) };
declare function res:conflict($body)                        { res:response(409, $body) };
declare function res:gone($body)                            { res:response(410, $body) };
declare function res:length-required($body)                 { res:response(411, $body) };
declare function res:precondition-failed($body)             { res:response(412, $body) };
declare function res:request-entity-too-large($body)        { res:response(413, $body) };
declare function res:request-uri-too-long($body)            { res:response(414, $body) };
declare function res:unsupported-media-type($body)          { res:response(415, $body) };
declare function res:requested-range-not-satisfiable($body) { res:response(416, $body) };
declare function res:expectation-failed($body)              { res:response(417, $body) };
declare function res:enhance-your-calm($body)               { res:response(420, $body) };
declare function res:unprocessable-entity($body)            { res:response(422, $body) };
declare function res:locked($body)                          { res:response(423, $body) };
declare function res:failed-dependency($body)               { res:response(424, $body) };
declare function res:unordered-collection($body)            { res:response(425, $body) };
declare function res:upgrade-required($body)                { res:response(426, $body) };
declare function res:precondition-required($body)           { res:response(428, $body) };
declare function res:too-many-requests($body)               { res:response(429, $body) };
declare function res:request-header-fields-too-large($body) { res:response(431, $body) };
declare function res:retry-with($body)                      { res:response(449, $body) };
declare function res:blocked-by-parental-controls($body)    { res:response(450, $body) };
declare function res:unavailable-for-legal-reasons($body)   { res:response(451, $body) };

(: Server Error :)
declare function res:internal-server-error($body)           { res:response(500, $body) };
declare function res:not-implemented($body)                 { res:response(501, $body) };
declare function res:bad-gateway($body)                     { res:response(502, $body) };
declare function res:service-unavailable($body)             { res:response(503, $body) };
declare function res:gateway-timeout($body)                 { res:response(504, $body) };
declare function res:http-version-not-supported($body)      { res:response(505, $body) };
declare function res:variant-also-negotiates($body)         { res:response(506, $body) };
declare function res:insufficient-storage($body)            { res:response(507, $body) };
declare function res:loop-detected($body)                   { res:response(508, $body) };
declare function res:bandwidth-limit-exceeded($body)        { res:response(509, $body) };
declare function res:not-extended($body)                    { res:response(510, $body) };
declare function res:network-authentication-required($body) { res:response(511, $body) };
declare function res:network-read-timeout($body)            { res:response(598, $body) };
declare function res:network-connect-timeout($body)         { res:response(599, $body) };
