xquery version "3.0";

(:~
 : Fold Middleware
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring
 :)
module namespace wrap = 'http://xokomola.com/xquery/fold/middleware';

import module namespace request = 'http://exquery.org/ns/request';
import module namespace req = 'http://xokomola.com/xquery/fold/request'
    at 'request.xqm';
import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at 'response.xqm';
import module namespace codec = 'http://xokomola.com/xquery/fold/utils/codec'
    at 'utils/codec.xqm';
import module namespace utils = 'http://xokomola.com/xquery/common'
    at '../fold-common/common.xqm';
import module namespace mime = 'http://xokomola.com/xquery/common/mime-type'
    at '../fold-common/mime.xqm';

(:~
 : Parse and assoc parameters from the query string with the request.
 :)
declare function wrap:assoc-query-params($request as map(*), $encoding as xs:string)
    as map(*) {
    let $query-string := $request('query-string')
    let $params := 
        if ($query-string instance of xs:string) then 
            wrap:parse-params($query-string, $encoding)
        else
            ()
    return
        if ($params instance of map(*)) then
            map:merge((
                $request,
                map {
                    'query-params': $params,
                    'params': utils:merge(($request('params'), $params)) 
                }
            ))
        else
            $request
};

(:~
 : Parse and assoc parameters from the request body with the request.
 :
 : NOTE: this body is not provided by RESTXQ. All params are stored in 'basex-params'
 :       so to avoid duplicates we should use either all basex-params or the parsed 
 :       params. Yet, I still want to keep the param parsing code around for now.
 :)
declare function wrap:assoc-form-params($request as map(*), $encoding as xs:string)
    as map(*) {
    let $body := $request('body')
    let $params := 
        if (req:is-urlencoded-form($request) and $body instance of xs:string) then
            wrap:parse-params($body, $encoding)
        else
            ()
    return
        if ($params instance of map(*)) then
            map:merge((
                $request,
                map {
                    'form-params': $params,
                    'params': utils:merge(($request('params'), $params))
                }
            ))
        else
            $request
};

(:~
 : Adds parameters from the query string and the request body to the request
 : map. See: `wrap:params`.
 :
 : NOTE: not sure yet if I should use request:parameter instead of parsing params
 :)
declare %private function wrap:params-request($request as map(*), $options as map(*))
    as map(*) {
    let $encoding := ($options('encoding'), req:character-encoding($request), 'UTF-8')[1]
    let $request :=
        if ($request('form-params')) then
            $request
        else
            wrap:assoc-form-params($request, $encoding)
    return
        if ($request('query-params')) then
            $request
        else
            wrap:assoc-query-params($request, $encoding)
};

declare %private function wrap:params-request($request as map(*)) 
    as map(*) {
    wrap:params-request($request, map {})
};

(:~
 : Middleware to parse urlencoded parameters from the query string and form
 : body (if the request is a url-encoded form). Adds the following keys to
 : the request map:
 :
 : query-params - a map of parameters from the query string
 : form-params  - a map of parameters from the body
 : params       - a merged map of all types of parameter
 :
 : NOTE: we do not get the form body from RESTXQ so we'll use the
 :       provided 'basex-params'.
 :
 : Accepts the following options [TODO]:      
 : 
 : encoding - encoding to use for url-decoding. If not specified, uses
 :            the request character encoding, or "UTF-8" if no request
 :            character encoding is set.
 :)
 declare function wrap:params($handler, $options as map(*)) {
    function($request) { 
        $handler(wrap:params-request($request, $options))
    }    
};

declare function wrap:params($handler) {
    function($request) { 
        $handler(wrap:params-request($request, map {}))
    }    
};

declare %private function wrap:parse-params($params, $encoding)
    as map(*) {
    let $params := codec:form-decode($params)
    return
        if ($params instance of map(*)) then
            $params
        else
            map {}
};

(:~
 : Middleware to simplify replying to HEAD requests.
 :
 : A response to a HEAD request should be identical to a GET request, with the
 : exception that a response to a HEAD request should have an empty body.
 :)
declare function wrap:head($handler) {
    function($request) {
        wrap:head-response(
            $handler(wrap:head-request($request)), 
            $request
        )
    }
};

(:~
 : Turns a HEAD request into a GET.
 :)
declare function wrap:head-request($request as map(*))
    as map(*) {
    if ($request('request-method') = 'HEAD') then
        map:merge(($request, map { 'request-method': 'GET' }))
    else
        $request
};

(:~
 : Returns a empty seq body if original request was a HEAD.
 :)
declare function wrap:head-response($response as map(*)?, $request as map(*)?)
    as map(*)? {
    if ($response instance of map(*) and $request('request-method') = 'HEAD') then
        map:merge(($response, map { 'body': () } ))
    else
        $response
};

(:~
 : Middleware for parsing and generating cookies.
 :)
 
(:~
 : Parses the cookies in the request map, then assocs the resulting map
 : to the :cookies key on the request.
 :)
declare function wrap:cookies($handler, $options as map(*)) {
    'TODO'
};

declare function wrap:cookies($handler) {
    wrap:cookies($handler, map {})
};

(:~
 : Middleware for automatically adding a content type to response maps.
 :)
 
(:~
 : Middleware that adds a content-type header to the response if one is not
 : set by the handler. If no explicit content-type is specified it uses 
 : the mime:ext-mime-type function to guess the content-type from the file 
 : extension in the URI. If no content-type can be found, it defaults to 
 : 'application/octet-stream'.
 :
 : Accepts the following options:
 :
 : 'mime-types' - a map of filename extensions to mime-types that will be used
 :                in addition to the ones defined in mime:default-mime-types.
 : 'content-type' - a fixed content type (this is useful in routes that match
 :                  a specific file type).
 :)
declare function wrap:content-type($handler as function(*), $options as map(*)?) 
    as function(*) {
    function($request) {
        let $response := $handler($request)
        where $response instance of map(*)
        return
            wrap:content-type-response($response, $request, $options)
    }    
};

declare function wrap:content-type($handler as function(*))
    as function(*) {
    wrap:content-type($handler, ())
};

(:~
 : Adds a content-type header to response. See wrap:content-type.
 :)
declare %private function wrap:content-type-response($response as map(*), $request as map(*), 
    $options as map(*)?) {
    if (res:get-header($response, 'Content-Type')) then
        $response
    else if (($options, map {})[1]('content-type')) then
        res:content-type($response, $options('content-type'))
    else
        let $mime-type := (
            mime:ext-mime-type($request('uri'), ($options, map {})[1]('mime-types')), 
            'application/octet-stream')[1]
        return
            res:content-type($response, $mime-type)
};

(:~
 : Middleware that returns a 304 Not Modified response for responses with
 : Last-Modified headers.
 :)
 
(:~
 : Middleware that returns a 304 Not Modified from the wrapped handler if the
 : handler response has an ETag or Last-Modified header, and the request has a
 : If-None-Match or If-Modified-Since header that matches the response.
 :)
declare function wrap:not-modified($handler as function(*))
    as function(*) {
    function ($request) {
        wrap:not-modified-response($handler($request), $request)
    }
};

(:~
 : Returns 304 or original response based on response and request.
 : See: wrap:not-modified.
 : TODO: investigate if in case of wrap:file responses we should not yet
 :       materialize the file so it is not read in vain, only to be discarded here.
 :)
declare function wrap:not-modified-response($response as map(*), $request as map(*)) 
    as map(*)? {
    if (wrap:is-etag-match($request, $response) or 
        wrap:is-not-modified-since($request, $response)) then
        res:body(
            res:header(
                res:status($response, 304),
                'Content-Length', 0),
            ())
    else
        $response
};

declare %private function wrap:is-etag-match($request as map(*), $response as map(*))
    as xs:boolean {
    res:get-header($response, "ETag") = res:get-header($request, "if-none-match")
};

declare %private function wrap:is-not-modified-since($request as map(*), $response as map(*)) 
    as xs:boolean {
    let $modified-date := wrap:date-header($response, "Last-Modified")
    let $modified-since := wrap:date-header($request, "if-modified-since")
    return
        if (not(empty($modified-date)) and not(empty($modified-since))
             and ($modified-date le $modified-since)) then
            true()
        else
            false()
};

declare %private function wrap:date-header($response, $header) 
    as xs:dateTime? {
    let $http-date := res:get-header($response, $header)
    where $http-date
    return
        utils:parse-http-date($http-date)
};

(:~
 : Middleware that adds multipart params to the request map.
 : RESTXQ supports these already so we only add the information
 : to the request map.
 : 
 : Adds 'multipart-params' and 'params'
 :)

(: NOTE: what when there are multiple files uploads, use file:create-temp-file / file:create-temp-dir :)
(: NOTE: how secure is this :)
(: NOTE: is this the best way to deal with these e.g. when uploading multiple files with same names :)
(: NOTE: what about upload limits :)
(: NOTE: should we add more file metadata (mime-type, size, tmp-path, file-name :)
(: http://stackoverflow.com/questions/19145489/multipartconfig-override-in-web-xml :)
(: We can limit file upload size via web.xml but this would raise java exception, can we catch this? :)
(:
      Stopped at /Users/marcvangrootel/data/basex/webapp/fold/middleware.xqm, 203/56:
[bxerr:BASX0000] java.lang.IllegalStateException: Multipart Mime part files exceeds max filesize

Stack Trace:
- /Users/marcvangrootel/data/basex/webapp/fold/middleware.xqm, 219/44
- /Users/marcvangrootel/data/basex/webapp/fold/routes.xqm, 306/37
- /Users/marcvangrootel/data/basex/webapp/fold/routes.xqm, 227/30
:)

(: TODO: The error can be caught to handle it ourselves, maybe be more specific :)

declare %private function wrap:handle-multipart-params($request as map(*)) {
    (: if this is the first location where we use a request function this may trigger a 400 due to file size limit (see web.xml) :)
    let $multipart-param-names :=
        try {
            for $parameter-name in request:parameter-names() (: <<< this is the line where we get the bxerr:BASX0000 error :)
            let $param := request:parameter($parameter-name)
            where $param instance of map(*)
            return
                $parameter-name
        } catch * {
            ()
        }
    return
        if ($multipart-param-names) then
            map:merge((
                for $parameter-name in $multipart-param-names
                let $param := request:parameter($parameter-name)
                return
                    map:entry($parameter-name,
                        map:merge((
                            for $file-name in map:keys($param)
                            let $file-content := $param($file-name)
                            let $file-path := file:temp-dir() || $file-name
                            return (
                                file:write-binary($file-path, $file-content),
                                map:entry($file-name, $file-path)
                            )
                        ))
                    )
            ))
        else
            map { 'error': 'there was an error uploading' }
};

declare function wrap:multipart-params-request($request as map(*))
    as map(*) {
    let $params := wrap:handle-multipart-params($request)
    return
        map:merge((
            $request,
            map { 
                'multipart-params': $params,
                'params': utils:merge(($request('params'), $params))
            }
        ))
};

declare function wrap:multipart-params($handler) {
    function ($request) {
        $handler(wrap:multipart-params-request($request))
    }
};

(:~
 : A middleware handler that dumps request and response on STDOUT without
 : modifying request or response.
 :)
declare function wrap:sniffer($handler) {
    function ($request) {
        let $req-trace := trace($request, 'REQUEST: ')
        let $response := prof:mem(prof:time($handler($request), false(), 'TIME: '), false(), 'MEM: ')
        let $res-trace := trace(res:render($response, $request), 'RESPONSE: ')
        return
            $response  
    }
};

(:~
 : Middleware to serve files.
 : Note that performance is better when using static file directories
 : in web.xml.
 : This middleware has the advantage of serving files out of any directory.
 :)

(:~
 : Ensures that a directory exists at the given path, throwing if one does not.
 :)
declare %private function wrap:ensure-dir($path as xs:string)
    as xs:boolean {
    if (file:is-dir($path)) then
        true()
    else
        error(wrap:DirDoesNotExist, 'directory "' || $path || '" does not exist!')
};

(:~
 : If request matches a static file, returns it in a response. Otherwise
 : returns empty sequence. See: wrap:file.
 :)
declare %private function wrap:file-request($request as map(*), $root-path as xs:string) {
    wrap:file-request($request, $root-path, map { })
};

declare %private function wrap:file-request($request as map(*), $root-path as xs:string, $options as map(*)) {
    let $options := 
        utils:merge(
            map { 'root': $root-path, 'index-files': true(), 'binary': false() },
            $options
        )
    where $request('request-method') = 'GET'
    return
        let $path := substring(codec:url-decode(req:path-info($request)),2)
        return
            res:file-response($path, $options)
};

(:~
 : Wrap a handler such that the directory at the given root-path is checked for
 : a static file with which to respond to the request, proxying the request to
 ; the wrapped handler if such a file does not exist.
 :
 : Options:
 : index-files (boolean) - look for index.* files in directories, defaults to true
 :)
declare function wrap:file($handler, $root-path as xs:string, $options as map(*)) {
    (wrap:ensure-dir($root-path),
        function($request) {
            (
                wrap:head(wrap:file-request(?, $root-path, $options))($request),
                $handler($request)
            )[1] (: take first that succeeds / is this the best way? :)
    })[2] (: need to drop true() from wrap:ensure-dir :)
};

declare function wrap:file($handler, $root-path as xs:string) {
    wrap:file($handler, $root-path, map { })
};
