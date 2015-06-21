xquery version "3.0";

(:~
 : Some common XQuery functions derived from some Clojure functions.
 :
 : What's missing compared to a language like Clojure is macros and lazy-sequences.
 : But even without those these functions can be helpful in XQuery as well.
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 :)
module namespace utils = 'http://xokomola.com/xquery/common';

declare namespace df = 'java:java.text.SimpleDateFormat'; 
declare namespace tz = 'java:java.util.TimeZone'; 
declare namespace lc = 'java:java.util.Locale';
declare namespace d = 'java:java.util.Date';
declare namespace pex = 'java:java.text.ParseException';

(:~
 : Convenience function for use in higher order functions.
 :)
declare function utils:add($a as xs:double, $b as xs:double)
    as xs:double {
    $a + $b
};

declare function utils:sub($a as xs:double, $b as xs:double)
    as xs:double {
    $a - $b
};

(:~
 : Convenience function for use in higher order functions.
 :)
declare function utils:cons($a,$b) {
    ($a,$b)
};

(:~
 : Take a number of items from a sequence.
 :)
declare function utils:take($n as xs:integer, $seq) {
  subsequence($seq, 1, $n)
};

(:~
 : Drop a number of items from a sequence.
 :)
declare function utils:drop($n as xs:integer, $seq) {
  subsequence($seq, $n + 1)
};


(:~
 : Partition a sequence into an array of sequence $n long.
 :)
declare function utils:partition($n as xs:integer, $seq) as array(*)* {
    if (not(empty($seq))) then
        for $i in 1 to (count($seq) idiv $n) + 1
        where count($seq) > ($i -1) * $n
        return
            array { subsequence($seq, (($i -1) * $n) + 1, $n) }
    else
        ()
};

(:~
 : Turns an array back into a regular sequence. If the argument
 : is already a sequence it will be returned unchanged.
 :)
declare function utils:seq($array) {
    typeswitch ($array)
        case array(*)
            return array:fold-left($array, (), utils:cons#2)
        default
            return $array
};

(:~
 : Returns a sequence of the first item of the first sequence and the first item of the second sequence etc.
 :)
declare function utils:interleave($seq1, $seq2) {
    for $i in 1 to max((count($seq1),count($seq2)))
    return
        ($seq1[$i],$seq2[$i])
};

(:~
 : Returns a map that consists of merging the maps
 : provided in the argument. If the resulting map
 : is empty it will return the empty sequence.
 :)
declare function utils:merge($maps as map(*)*) 
    as map(*)? {
    if (some $map in $maps satisfies $map instance of map(*)) then
        map:merge($maps)
    else
        ()
};

(:~
 : Convenience function so we can use merge#2 with merge-with#2.
 :)
declare function utils:merge($m1 as map(*), $m2 as map(*)) 
    as map(*) {
    utils:merge(($m1, $m2))
};

(:~
 : Returns a map that consists of merging the maps
 : provided in the argument. If a key occurs in more than
 : one map, the mapping(s) from the latter (left-to-right)
 : will be comined with the mapping in
 : the result by calling $fn( $former, $latter)
 :
 : Similar to map:for-each-entry#3
 :
 : TODO: use map:for-each-entry
 :)
declare function utils:merge-with($fn as function(*), $maps as map(*)*)
    as map(*)? {
    if (some $map in $maps satisfies $map instance of map(*)) then
        fold-left(reverse($maps), map {},
            function($m1, $m2) {
                fold-left(map:keys($m2), $m1,
                    function($map, $key) {
                        utils:insert-with($fn, $key, $m2($key), $map)
                    }
                )
            }
        )
    else
        ()
};

(:~ COPIED from https://github.com/BaseXdb/xq-modules/blob/master/src/main/xquery/modules/map2.xqm
 :
 : Inserts with a combining function. <code>insert-with($f, $key, $value, $map)</code>
 : will insert <code>map:entry($key, $value)</code> into <code>$map</code> if
 : <code>$key</code> does not exist in the map. If the key does exist, the function
 : will insert <code>$f($new-value, $old-value)</code>.
 :
 : @param $f combining function
 : @param $key key to insert
 : @param $value value to insert
 : @param $map map to insert into
 : @return new map where the entry is inserted
 :)
declare function utils:insert-with(
    $f as function(item()*, item()*) as item()*,
    $key as item(),
    $value as item()*,
    $map as map(*)) 
    as map(*) {
    map:merge((
        $map,
        map:entry(
            $key,
            if (map:contains($map, $key)) then
                $f($value, $map($key))
            else 
                $value
        )
    ))
};

(:~
 : Returns a map with the keys mapped to the corresponding values.
 :)
declare function utils:zipmap($keys as xs:anyAtomicType*, $vals) as map(*) {
    map:merge((
        for $i in 1 to count($keys)
        return
            map:entry($keys[$i], $vals[$i]) 
    ))
};

(:~
 : Returns a function that feeds the result of calling the first
 : into the second and so-on, effectively creating a kind of pipeline
 : where the single argument is fed into the first function and at
 : the end the transformed result comes out.
 :
 : Inspiration came from Clojure's threading macros that can also
 : be traced back to the compose function in the Dylan programming
 : language. It revolves around a reduce aka fold.
 : 
 : @see http://blog.fogus.me/2009/09/04/understanding-the-clojure-macro
 :
 : Example:
 :
 :   comp((f1(?),f2(?)))(10)
 :
 : With XQuery 3.1 arrow operator this can be described more pleasingly with
 :
 :   10 => comp((f1(?),f2(?)))
 :
 : Experimental: I added apply() for array arguments to get closer to Clojure
 : semantics.
 :)
declare function utils:comp($fns) {
    function($input) {
        typeswitch ($input)
            case array(*)
                return
                    fold-left(
                        tail($fns), 
                        apply(head($fns), $input),
                        function($args, $fn) {
                            $fn($args)
                        }
                    )
            default
                return
                    fold-left($fns, $input,
                          function($args, $fn) { 
                                $fn($args) 
                          }
                    ) 
    }
};

(:~
 : Just a convenience function for passing the first element of the sequence
 : to the composed function that is created from the rest.
 :)
declare function utils:thread($fns) {
    utils:comp(tail($fns))(head($fns))
};

declare function utils:get-in($map as map(*), $kws as xs:anyAtomicType*) {
    utils:get-in($map, $kws, ())
};

declare function utils:get-in($map as map(*), $kws as xs:anyAtomicType*, $not-found) {
    let $head := head($kws)
    let $tail := tail($kws)
    return
        if (not(empty($tail))) then
            if ($map($head) instance of map(*)) then
                utils:get-in($map($head), $tail, $not-found)
            else
                $not-found
        else
            ($map($head), $not-found)[1]
};

(:~
 : TODO: check if using get-in() isn't a better, more generic, solution? 
 : Used to pull specific values from a map and return them as a sequence.
 : Also handles casting of strings to atomic value types using notation.
 : Can pull values from nested maps too via a simple path syntax.
 :
 : Examples:
 : ('foo', '/params/foo', '/uri|anyURI', '/params/foo|integer') 
 :)

declare function utils:destructure-map($map, $destruct-seq) {
    utils:destructure-map($map, $destruct-seq, ())
};

declare function utils:destructure-map($map, $destruct-seq, $ctx as xs:string?) {
    (: TODO: ctx is not generic and only works for first level of map :)
    let $ctx := if ($ctx) then $map($ctx) else $map
    for $expr in $destruct-seq
    let $lookup := if (starts-with($expr,'/')) then $map else $ctx
    let $tokens := tokenize($expr,'\|')
    let $type := $tokens[2]
    let $path := tokenize(if (starts-with($tokens[1],'/')) then substring-after($tokens[1],'/') else $tokens[1], '/')
    let $value := fold-left($path, $lookup, function($map, $key) { $map($key) })
    return
        switch ($type)
            case () return $value
            case 'boolean' return xs:boolean($value)
            case 'float' return xs:float($value)
            case 'integer' return xs:integer($value)
            case 'string' return xs:string($value)
            case 'decimal' return xs:decimal($value)
            case 'long' return xs:long($value)
            case 'int' return xs:int($value)
            case 'short' return xs:short($value)
            case 'byte' return xs:byte($value)
            case 'double' return xs:double($value)
            case 'date-time' return xs:dateTime($value)
            case 'date' return xs:date($value)
            default return $value
};

(:~
 : A function string replace function. On every match apply a function to the
 : match for the replacement.
 :)
declare function utils:replace($str as xs:string, $re as xs:string, $fn as function(xs:string) as xs:string) {
    string-join(
        let $m := analyze-string($str, $re)
        return
            for $n in $m/*
            return
                typeswitch ($n)
                    case element(fn:match)
                        return string($fn(string($n)))
                    default
                        return string($n)
    ,'')
};

(:~
 : Returns a sequence based on the matched portions of a string.
 :)
declare function utils:re-seq($str as xs:string, $re as xs:string)
    as xs:string* {
        let $m := analyze-string($str, $re)
        return
            for $n in $m/*
            return
                typeswitch ($n)
                    case element(fn:match)
                        return string($n)
                    default
                        return ()
    
};

(:~
 : Transforms a data structure into XML
 :
 : TODO: add more tests with mixed patterns
 :)

(: DOES NOT EXIST on 8.0 snapshot :)
(: 
declare function utils:to-xml($item)
    {
    typeswitch ($item)
        case map(*)
            return
                utils:map-to-xml($item)
        case array(*)
            return
                utils:array-to-xml($item)
        default
            return
                if (count($item) gt 1) then
                    utils:seq-to-xml($item)
                else
                    $item
};

declare %private function utils:map-to-xml($map)
    as element(map) {
    <map>{
        map:for-each-entry($map,
            function($k,$v) {
                <entry key="{ $k }">{
                    utils:to-xml($v)
                }</entry>
            }
        )
    }</map>
};

declare function utils:to-compact-xml($item) {
    let $xml := utils:to-xml($item)
    return
      'TODO'
};

declare %private function utils:array-to-xml($array as array(*)) 
    as element(array) {
    <array>{
        for $k in 1 to array:size($array)
        let $v := $array($k)
        return <entry>{
            utils:to-xml($v)
        }</entry>
    }</array>
};

declare %private function utils:seq-to-xml($seq) 
    as element(seq) {
    <seq>{
        for $item in $seq
        return
            <item>{ utils:to-xml($item) }</item>
    }</seq>
};
:)

(:~
 : Typical Clojure function. Returns a function that always
 : returns the same value.
 : However, it only takes one argument, whereas Clojure's takes any
 : number of args.
 :)
declare function utils:constantly($x) as function(*) {
    function($arg) {
        $x
    }
};

(:~
 : Attempt to parse a HTTP date. Returns empty sequence if unsuccessful.
 :
 : @see http://tools.ietf.org/html/rfc7231#section-7.1.1.2
 : @see https://www.mnot.net/blog/2014/06/07/rfc2616_is_dead
 : @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html
 :)
 
declare function utils:parse-http-date($http-date) {
    let $http-date := replace($http-date, "^'|'$", '')
    let $parsed-dates :=
        for $format in map:keys($utils:http-date-formats)
        return
            utils:attempt-parse($http-date, $format)
    return
        $parsed-dates[1]
};

declare variable $utils:http-date-formats := 
    map {
        'rfc1123': "EEE, dd MMM yyyy HH:mm:ss zzz",
        'rfc1036': "EEEE, dd-MMM-yy HH:mm:ss zzz",
        'asctime': "EEE MMM d HH:mm:ss yyyy"
    };
    
declare function utils:formatter($format) {
    let $df := df:new($utils:http-date-formats($format), lc:new("en","US"))
    let $void := df:setTimeZone($df, tz:getTimeZone('GMT'))
    return
        $df
};

declare function utils:attempt-parse($date, $format)
    as xs:dateTime? {
    let $df := df:new("yyyy-MM-dd'T'HH:mm:ss'Z'")
    let $void := df:setTimeZone($df, tz:getTimeZone('GMT'))
    let $date := 
        try {
            df:parse(utils:formatter($format), $date)
        (: TODO: use ParseException exception instead of * :)
        } catch * {
            ()
        }
    where $date
    return
        xs:dateTime(df:format($df, $date))        
};

declare function utils:format-date($date as xs:dateTime) {
    let $df := df:new("yyyy-MM-dd'T'HH:mm:ss'Z'")
    let $void := df:setTimeZone($df, tz:getTimeZone('GMT'))
    let $d := df:parse($df, string($date))
    return
        df:format(utils:formatter('rfc1123'), $d)
};
