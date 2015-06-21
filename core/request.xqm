xquery version "3.0";

(:~
 : Fold Requests
 :
 : Functions for augmenting and pulling information from request maps.
 : 
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring
 :)
module namespace req = 'http://xokomola.com/xquery/fold/request';

import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at 'response.xqm';

(:~
 : Return the full URL of the request.
 :
 : @param $request The request map
 : @return The request URL
 :)
declare function req:request-url($request as map(*)) 
    as xs:string {
    let $querystring :=
        if ($request('query-string')) then
            '?' || $request('query-string')
        else
            ''
    let $uri := 
        if ($request('uri')) then
            $request('uri')
        else
            '/'
    return
        $request('scheme') || '://' || res:get-header($request, 'host') || 
            $uri || $querystring        
};

(:~
 : Content-type of the request.
 :
 : @param $request The request map
 : @return The content-type or empty sequence if not set.
 :)
declare function req:content-type($request as map(*))
    as xs:string? {
    let $content-type-header := res:get-header($request, 'Content-Type')
    where $content-type-header
    return
        (: TODO: use analyze-string :)
        head(tokenize($content-type-header, ';')) 
};

(:~
 : Content-length of the request.
 :
 : @param $request The request map
 : @return The content-length or empty sequence if not set.
 :)
declare function req:content-length($request as map(*))
    as xs:long? {
    let $content-length-header := res:get-header($request, 'Content-Length')
    where $content-length-header
    return
        xs:long($content-length-header)
};

declare variable $req:re-token := "[!#$%&amp;'*\-+.0-9A-Z\^_`a-z\|~]+";
declare variable $req:re-quoted := '"[^"]*"';
declare variable $req:re-value := $req:re-token || '|' || $req:re-quoted;
declare variable $req:charset-pattern := ';.*\s?charset=(' || $req:re-value || ')\s*[;|$]?';

(:~
 : Character encoding of the request.
 :
 : @param $request The request map
 : @return The character encoding or empty sequence if not set.
 :)
declare function req:character-encoding($request as map(*)) 
    as xs:string? {
    let $m :=
        let $content-type-header := res:get-header($request, 'Content-Type')
        where $content-type-header
        return
            analyze-string(
                $content-type-header,
                $req:charset-pattern
            )/fn:match
    where $m
    return 
        string($m/fn:group[@nr = '1'])
};

(:~
 : Does the request contain a urlencoded form in the body?
 :
 : @param $request The request map
 : @return true() if the request contains urlencoded form data
 :)
declare function req:is-urlencoded-form($request)
    as xs:boolean {
    starts-with(
        req:content-type($request), 
        'application/x-www-form-urlencoded'
    )
};

(:~
 : Request body.
 :
 : @param $request The request map
 : @return The request body
 :)
declare function req:body($request as map(*))
    as item()? {
    $request('body')
};

(:~
 : Relative path of the request.
 :
 : @param $request The request map
 : @return The relative path ('path-info' or 'uri')
 :)
declare function req:path-info($request as map(*))
    as xs:string {
    ($request('path-info'), $request('uri'))[1]
};

(:~
 : Is the URI of the request a subpath of the supplied context?
 :
 : @param $request The request map
 : @param $context The context string
 : @return true() if the request uri starts with the given context
 :)
declare function req:is-in-context($request as map(*), $context as xs:string) 
    as xs:boolean {
    starts-with($request('uri'), $context)
};

(:~
 : Associate a context and path-info with the  request. The request URI must be
 : a subpath of the supplied context.
 :
 : @param $request The request map
 : @param $context The context string
 : @return The new request map, unmodified if request is not part of context.
 : @error req:NotInContext
 :)
declare function req:set-context($request as map(*), $context as xs:string) {
    if (req:is-in-context($request, $context)) then
        map:merge((
            $request,
            map {
                'context': string-join(($request('context'), $context), ''), 
                'path-info': substring-after($request('uri'), $context) 
            }
        ))
    else
        error(req:NotInContext, 'Cannot set context to ' || $context)
};

(:~
 : HTTP method of the request.
 :
 : @param $request The request map
 : @return The HTTP method/verb (uppercase)
 :)
declare function req:method($request as map(*))
    as xs:string {
    $request('request-method')
};

(:~
 : Get a parameter from the request.
 :
 : @param $request The request map
 : @param $param The name of the parameter (case-sensitive)
 : @return The value of the parameter, or empty-sequence if not set
 :)
declare function req:get-param($request as map(*), $param as xs:string) {
    req:get-in-map($request, 'params', $param)
};

(:~
 : Safely get a map entry from within a map.
 :)
declare function req:get-in-map($map as map(*), $key as xs:string, $subkey as xs:string) {
    let $submap := $map($key)
    where $submap instance of map(*)
    return
        $submap($subkey)
};
