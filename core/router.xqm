xquery version "3.0";

(:~
 : Fold routes
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/weavejester/clout
 : @see https://github.com/weavejester/compojure
 :)
(: TODO: refactor routes with args :)

module namespace router = 'http://xokomola.com/xquery/fold/router';

declare namespace encoder = 'java:java.net.URLEncoder'; 
declare namespace decoder = 'java:java.net.URLDecoder'; 

import module namespace handler = 'http://xokomola.com/xquery/fold/handler'
    at 'handler.xqm';
import module namespace req = 'http://xokomola.com/xquery/fold/request'
    at 'request.xqm';
import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at 'response.xqm';
import module namespace wrap = 'http://xokomola.com/xquery/fold/middleware'
    at 'middleware.xqm';
import module namespace utils = 'http://xokomola.com/xquery/common'
    at '../common/common.xqm';

(:~
 : Escape all special regex chars in a string.
 :)
declare %private function router:re-escape($string as xs:string)
    as xs:string {
    let $regexp-chars :=  ('.','*','+','|','?','(',')','[',']','{','}','^')
    return
        (: Note that '\' and '$' in the fold caused invalid pattern errors therefore put them in separate replace :)
        fold-left(
            $regexp-chars, 
            replace(replace($string, '\\', '\\\\'), '\$', '\\\$'), 
            function($a, $b) {
                replace($a, '\'||$b, '\\'||$b )
            }
        )
};

(:~
 : Unescape all characters that may appear in a URL unescaped.
 :)
declare %private function router:url-unescape($string as xs:string)
    as xs:string {
    let $url-chars-map := 
        map { '%40': '@', '%21': '!', '%24': '\$', '%27': "'", '%28': '(', '%29': ')', 
              '%2A': '*', '%2B': '+', '%2C': ',', '%3B': ';', '%3D': '=', '%2F': '/' }
    return
        fold-left(
            map:keys($url-chars-map),
            $string,
            function($s, $char) {
                replace($s, $char, $url-chars-map($char))
            }
        )
};

(:~
 : Decode a path segment in a URI. Uses UTF-8 encoding.
 :
 : @param $path The path to decode
 : @return The decoded path
 :)
declare function router:path-decode($path as xs:string)
    as xs:string {
    router:path-decode($path, 'UTF-8')
};

(:~
 : Decode a path segment in a URI using a specified encoding.
 :
 : @param $path The path to decode
 : @param $encoding The character encoding
 : @return The decoded path
 :)
declare function router:path-decode($path as xs:string, $encoding as xs:string)
    as xs:string {
    decoder:decode(
        replace($path, '\+', encoder:encode('+', $encoding)),
        $encoding
    )
};

(:~
 : Encode a path to make it suitable to be placed in a URI. Uses UTF-8 encoding.
 :
 : @param $path The path to encode
 : @return The URI encoded path
 :)
declare function router:path-encode($path as xs:string?)
    as xs:string {
    router:url-unescape(encode-for-uri(($path, '')[1]))
};

(:~
 : True if the path contains an absolute or scheme-relative URL.
 :
 : @param $path The path to test
 : @return True if $path is absolute
 :)
declare %private function router:is-absolute-url($path as xs:string) {
    matches($path, '^(https?:)?//.*')
};

(:~
 : Compile a path string using the routes syntax into a uri-matching map
 : This map contains a regexp and a param map for binding the regexp-groups
 : to.
 :
 : Example:
 :
 : '/foo/{x}/bar/{y}' => ('/foo/(...)/bar/(...)', map { 'x': 1, 'y': 2 })
 :)

(:~
 : Regex pattern for parsing path template variables.
 :)
declare %private variable $router:re-group := '[\p{L}_][\p{L}_0-9-]*';

(:~
 : Compile a route into a uri-matcher map. The route can either be
 : a simple string (path) or a sequence of a string and a map (custom regular 
 : expressions for path variables).
 :
 : @param $route The route (path or path and matchers)
 : @return A compiled route (map)
 :)
declare function router:compile($route)
    as map(*) {
    let $path as xs:string := $route[1]
    let $custom-matchers as map(*) := ($route[2], map { })[1]
    let $route :=
        map { 
            're': router:regexp($path, $custom-matchers), 
            'keys': router:group-map($path), 
            'is-absolute': router:is-absolute-url($path)
        }
    let $path-keys := map:keys($route('keys'))
    let $custom-keys := map:keys($custom-matchers)
    return
        if (count(distinct-values(($path-keys, $custom-keys))) le count($path-keys)) then
            $route
        else
            fn:error(router:UnusedRegexps, 'Unused custom regexps')
};

(:~
 : Build a route matching regular expression from a path template.
 :)
declare %private function router:regexp($path as xs:string) 
    as xs:string {
    router:regexp($path, map { })
};

(:~
 : Build a route matching regular expression from a path template
 : using custom regular expressions for path template variables.
 :)
declare %private function router:regexp($path as xs:string, $custom-matchers as map(*)) 
    as xs:string {
    string-join((
        let $group-matcher as element(fn:analyze-string-result) :=
            analyze-string($path, '(\{' || $router:re-group || '\}|\*)')
        for $token in $group-matcher/*
        let $name := translate($token, '{}', '')
        return
            switch($token)
                case '*'
                    return '(.*)' 
                case $token/fn:group
                    return '(' || ($custom-matchers($name), '[^/,;?]+')[1] || ')'
                case $token/self::fn:non-match
                    return router:re-escape($token)
                default 
                    return 'PARSE-ERROR'
        ),
        ''
    )
};

(:~
 : Builds a map from path template variables to regular expression group numbers.
 :)
declare %private function router:group-map($path as xs:string) 
    as map(*) {
    let $group-matcher := analyze-string($path, '\{(' || $router:re-group || ')\}|(\*)')
    let $groups := for $group in $group-matcher//fn:group return string($group)
    return
        map:merge((
            for $group in distinct-values($groups)
            return
                map:entry($group, index-of($groups, $group))
        ))
};

(:~ 
 : Associate the route parameters with the request map.
 :)
declare %private function router:assoc-route-params($request as map(*), $params as map(*))
    as map(*) {
    map:merge(($request, 
        map { 
            'params': router:merge-map-values($request('params'), $params) 
        }
    ))
};

(: ~
 : Combine the values of map n with map m, if a value exists
 : combine them into a sequence.
 :)
declare %private function router:merge-map-values($m as map(*)?, $n as map(*))
    as map(*) {
    map:merge(
        for $key in distinct-values((map:keys(($m, map {})[1]), map:keys($n)))
        return
            map:entry($key, (($m, map {})[1]($key), $n($key)))
    )
};

(:~
 : Returns a function that evaulates the handler when a request matches
 : the route method.
 :)
declare %private function router:if-method($method as xs:string?, $handler as function(map(*))
    as map(*)?) {
    function($request) {
        if (empty($method) or $request('request-method') eq $method) then
            $handler($request)
        else
            if ($method eq 'GET' and $request('request-method') eq 'HEAD') then
                map:merge(($handler($request), map { 'body': () }))
            else
                () 
    }
};

(:~
 : Returns a function that evaluates the handler when a request matches this
 : route path.
 :)
declare %private function router:if-route($route as map(*), $handler as function(map(*))
    as map(*)?) {
    function($request) {
        let $params := router:matches($route, $request)
        return
            if (empty($params)) then
                () (: not a match :)
            else
                if (map:size($params) gt 0) then
                    (: merge route params with request params :)
                    $handler(router:assoc-route-params($request, $params))
                else
                    (: route doesn't have params :)
                    $handler($request)
    }
};

(:~ 
 : If the route matches the supplied request, the matched keywords
 : are returned as a map. If the path does not contain any parameters
 : but is matched return empty map. Otherwise, the empty sequence is returned.
 :
 : @param $route-matcher The compiled route map
 : @param $request The request map
 : @return A map if this request matches the route, empty-sequence if not
 :)
declare function router:matches($route-matcher as map(*), $request as map(*))
    as map(*)? {
    let $route-regexp := $route-matcher('re')
    let $route-groups := $route-matcher('keys')
    let $url := 
        if ($route-matcher('is-absolute')) then
            req:request-url($request)
        else
            req:path-info($request)
    let $result := analyze-string(router:path-decode($url), $route-regexp)
    let $groups := $result/fn:match/fn:group
    where $result/fn:match
    return
        map:merge((
            for $key in map:keys($route-groups)
            let $group-nrs := $route-groups($key)
            return
                map:entry($key, 
                    for $group-nr in $group-nrs
                    return
                        string($groups[$group-nr])
                )
        ))
};

(:~
 : Create a route handler.
 :
 : TODO: check what happens if no route left ()
 :
 : @param $routes the routing map
 : @return the first map result of calling the routes handler (a request map)
 :)
declare function router:route($routes) {
    function($request as map(*)) as map(*)? {
        hof:until(
            function($routes) { head($routes) instance of map(*) or empty(head($routes)) },
            function($routes) {
                let $fn := head($routes)
                return
                    (
                        if ($fn instance of function(*)) then
                            $fn($request)
                        else 
                            (),
                        tail($routes)
                    )
            },
            $routes
        )[1]
    }
};

(:~
 : Defines a route.
 :)
declare %private function router:def($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def((), $route, $handler)
};

(:~
 : Defines a route.
 :
 : Returns a handler that will call the handler if the method
 : and route matches otherwise return empty sequence.
 :
 : @param $method HTTP method.
 : @param $path route path.
 : @param $handler handler function.
 : @return The result of calling the handler or empty sequence.
 :)
 (: TODO: refactor - merge the code for these two :)
declare function router:def($method as xs:string?, $route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:if-method($method,
        router:if-route(
            router:compile($route),
            function($request as map(*)) {
                res:render($handler($request), $request)
            }
        )
    )
};

(:~
 : Defines a route with extra argument bindings so we can wrap handlers 
 : and provide only the arguments needed.
 :)
declare function router:def($method as xs:string?, $route as item()+, $args as xs:string*, $handler as function(*))
    as function(map(*)) as item()* {
    router:if-method($method,
        router:if-route(
            router:compile($route),
            function($request as map(*)) {
                let $arg-list := router:bind-handler-args($args, $request)
                return
                    res:render(apply($handler, array { $arg-list }), $request)
            }
        )
    )
};

declare %private function router:bind-handler-args($args as xs:string*, $request as map(*)) {
    utils:destructure-map($request, $args, 'params')
};

(:~
 : GET route
 :)
declare function router:GET($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def('GET', $route, $handler)
};

declare function router:GET($route as item()+, $args as xs:string*, $handler as function(*))
    as function(map(*)) as item()* {
    router:def('GET', $route, $args, $handler)
};

(:~
 : POST route
 :)
declare function router:POST($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def('POST', $route, $handler)
};

(:~
 : PUT route
 :)
declare function router:PUT($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def('PUT', $route, $handler)
};

(:~
 : DELETE route
 :)
declare function router:DELETE($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def('DELETE', $route, $handler)
};

(:~
 : HEAD route
 :)
declare function router:HEAD($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def('HEAD', $route, $handler)
};

(:~
 : OPTIONS route
 :)
declare function router:OPTIONS($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def('OPTIONS', $route, $handler)
};

(:~
 : PATCH route
 :)
declare function router:PATCH($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def('PATCH', $route, $handler)
};

(:~
 : ANY route
 :)
declare function router:ANY($route as item()+, $handler as function(map(*)) as item()*)
    as function(map(*)) as item()* {
    router:def($route, $handler)
};

(:~
 : not-found route
 :
 : Route that will always succeed by returning a not-found response.
 :
 : @param $body The not found response body
 : @return A 404 response map
 :)
declare function router:not-found($body) {
    wrap:head(
        function($request as map(*)) {
            res:render(res:not-found($body), $request)
        }
    )
};

declare %private function router:remove-suffix($path, $suffix) {
    substring($path, 1, string-length($path) - string-length($suffix))
};

declare %private function router:path-normalize($path) {
    router:path-encode(router:path-decode($path))
};

(:~
 : Context route.
 :
 : @param $routes seq of routes for this context
 : @param $context the context path fragment (starting with '/'). 
 : @return The routing handler function
 :)
declare function router:context($route as item()+, $routes as item()+) {
    router:if-route(
        router:compile(
            ($route[1] || '{__path-info}', 
                map:merge((
                    ($route[2], map {})[1], 
                    map { '__path-info': '/.*|.*' }
                ))
            )
        ),
        router:wrap-context(
            function($request as map(*)) as map(*)? {
                router:route($routes)($request) 
            }
        )
    )
};

declare %private function router:wrap-context($handler as function(map(*)) as item()*) {
    function($request as map(*)) as map(*)? {
        let $uri := router:path-normalize($request('uri'))
        let $path := ($request('path-info'), $uri)[1]
        let $context := ($request('context'), '')[1]
        let $subpath := router:path-encode(($request('params'), map {})[1]('__path-info'))
        return
            $handler(
                map:merge((
                    map:merge(($request, map { 'params': map:remove(($request('params'), map {})[1], '__path-info') })),
                    map { 
                        'uri': $uri,
                        'path-info': if ($subpath) then $subpath else '/',
                        'context': router:remove-suffix($uri, $subpath)
                    }
                ))
            )
    }
};
