xquery version "3.0";

(:~
 : Tests for fold/utils/codec.xqm
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring-codec
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

declare default function namespace 'http://xokomola.com/xquery/fold/utils/codec';

import module namespace mock = 'http://xokomola.com/xquery/fold/utils/codec'
    at '../../webapp/fold/utils/codec.xqm'; 

declare %unit:test function test:url-decode() {
    unit:assert-equals(url-decode('foo%2Fbar'), 'foo/bar'),
    unit:assert-equals(url-decode('foo%20bar'), 'foo bar'),
    (: Test below fails with Invalid XML character '&amp;#x0; :)
    (: unit:assert-equals(url-decode('foo%FE%FF%00%2Fbar', 'UTF-16'), 'foo/bar') :)
    unit:assert-equals(url-decode('%'), '%')
};

declare %unit:test function test:form-encode-strings() {
    unit:assert-equals(
        form-encode('foo bar'), 
        'foo+bar'),
    unit:assert-equals(
        form-encode('foo+bar'), 
        'foo%2Bbar'),
    unit:assert-equals(
        form-encode('foo/bar'), 
        'foo%2Fbar')
};

declare %unit:test function test:form-encode-maps() {
    unit:assert-equals(
        form-encode(map { 'a': 'b' }), 
        'a=b'),
    unit:assert-equals(
        form-encode(map { 'a': 1 }), 
        'a=1'),
    unit:assert-equals(
        form-encode(map { 'a': 'b', 'c': 'd' }), 
        'a=b&amp;c=d'),
    unit:assert-equals(
        form-encode(map { 'a': 'b c' }), 
        'a=b+c')
};

declare %unit:test function test:form-encode-encoding() {
    (: isn't the BOM platform specific (big/little endian)? :)
    unit:assert-equals(
        form-encode(map { 'a': 'foo/bar' }, 'UTF-16'), 
        'a=foo%FE%FF%00%2Fbar')
};

declare %unit:test function test:form-decode-str() {
    unit:assert-equals(
        form-decode-str('foo=bar+baz'),
        'foo=bar baz' ),    
    unit:assert-equals(
        form-decode-str('%D'),
        () )
};

declare %unit:test function test:form-decode() {
    unit:assert-equals(
        form-decode('foo'),
        'foo' ),
    unit:assert-equals(
        form-decode('a=b'),
        map { 'a': 'b' } ),
    unit:assert-equals(
        form-decode('a=b&amp;c=d'),
        map { 'a': 'b', 'c': 'd' } ),
    unit:assert-equals(
        form-decode('foo+bar'),
        'foo bar' ),
    unit:assert-equals(
        form-decode('a=b+c'),
        map { 'a': 'b c' } ),
    unit:assert-equals(
        form-decode('a=b%2Fc'),
        map { 'a': 'b/c' } ),
    (: This would be illegal, but if it happens deal with it :)
    unit:assert-equals(
        form-decode('a=b=c'),
        map { 'a': 'b=c' } ),
    unit:assert-equals(
        form-decode('a=foo%FE%FF%00%2Fbar', 'UTF-16'),
        map { 'a': 'foo/bar' } )
};
