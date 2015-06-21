xquery version "3.0";

(:~
 : Fold codec
 :
 : Functions for encoding and decoding data.
 : Mostly a port of ring-codec. I only ported the functions that are used by Fold.
 :
 : Some of this stuff could have been achieved by Exslt functions but they are
 : not available here.
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring-codec
 :)
module namespace codec = 'http://xokomola.com/xquery/fold/utils/codec';

import module namespace utils = 'http://xokomola.com/xquery/common'
    at '../common/common.xqm';

declare namespace encoder = 'java:java.net.URLEncoder'; 
declare namespace decoder = 'java:java.net.URLDecoder'; 
declare namespace str = 'java:java.lang.String'; 
declare namespace int = 'java:java.lang.Integer'; 

(:~
 : Decode every percent-encoded character in the given string using the specified
 : encoding, or UTF-8 by default.
 :)
declare function codec:percent-decode($encoded as xs:string, $encoding as xs:string) {
    utils:replace($encoded, '(%..)+',
        function($chars) {
            for $char in utils:re-seq($chars, '%..')
            let $code := substring($char,2)
            return
                str:new(bin:from-octets(int:valueOf($code,xs:int(16))))
        }
    )
};

(:~
 : Returns the url-decoded version of the given string, using either a specified
 : encoding or UTF-8 by default. If the encoding is invalid, empty sequence is returned.
 :)
declare function codec:url-decode($encoded as xs:string) {
    codec:percent-decode($encoded, 'UTF-8') 
};

declare function codec:url-decode($encoded as xs:string, $encoding as xs:string) {
    codec:percent-decode($encoded, $encoding) 
};

(:~
 : Encode the supplied value into www-form-urlencoded format, often used in
 : URL query strings and POST request bodies, using the specified encoding.
 : If the encoding is not specified, it defaults to UTF-8.
 :
 : @see https://github.com/ring-clojure/ring-codec
 :)
declare function codec:form-encode($x, $encoding) {
    typeswitch ($x)
        case xs:string
            return encoder:encode($x, $encoding)
        case map(*)
            return string-join(
                for $k in map:keys($x)
                return
                    codec:form-encode($k, $encoding) || 
                    '=' || 
                    codec:form-encode($x($k), $encoding),
                '&amp;')
        default
            return encoder:encode(string($x), $encoding)
};

declare function codec:form-encode($x) {
    codec:form-encode($x, 'UTF-8')
};

(:~
 : Decode the supplied www-form-urlencoded string using the specified encoding,
 : or UTF-8 by default.
 :)
declare function codec:form-decode-str($encoded as xs:string, $encoding as xs:string) {
    try {
        decoder:decode($encoded, $encoding)
    } catch * { 
        ()
    }
};

declare function codec:form-decode-str($encoded as xs:string) {
    codec:form-decode-str($encoded, 'UTF-8')
};

(:~
 : Decode the supplied www-form-urlencoded string using the specified encoding,
 : or UTF-8 by default. If the encoded value is a string, a string is returned.
 : If the encoded value is a map of parameters, a map is returned.
 :)
declare function codec:form-decode($encoded, $encoding as xs:string) {
    if (not(contains($encoded, '='))) then
        codec:form-decode-str($encoded, $encoding)
    else
        map:merge((
            for $pair in tokenize($encoded, '&amp;')
            let $k := codec:form-decode-str(substring-before($pair, '='), $encoding)
            let $v := codec:form-decode-str(substring-after($pair, '='), $encoding)
            return
                map:entry($k, $v) 
        ))
};

declare function codec:form-decode($encoded) {
    codec:form-decode($encoded, 'UTF-8')
};
