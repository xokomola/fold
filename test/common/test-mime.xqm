xquery version "3.0";

(:~
 : Tests for fold/utils/mime.xqm
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

declare default function namespace 'http://xokomola.com/xquery/common/mime-type';

import module namespace mock = 'http://xokomola.com/xquery/common/mime-type'
    at '../../common/mime.xqm'; 

declare %unit:test function test:ext-mime-type() {
    (: default mime types :)
    unit:assert-equals(ext-mime-type('foo.txt'),   'text/plain'),
    unit:assert-equals(ext-mime-type('foo.html'),  'text/html'),
    unit:assert-equals(ext-mime-type('foo.png'),   'image/png'),
    unit:assert-equals(ext-mime-type('foo.xsl'),   'application/xslt+xml'),
    (: custom mime types :)
    unit:assert-equals(ext-mime-type('foo.bar', map { 'bar': 'application/bar' }), 'application/bar'),
    unit:assert-equals(ext-mime-type('foo.txt', map { 'txt': 'application/text' }), 'application/text'),
    (: case insensitivity :)
    unit:assert-equals(ext-mime-type('FOO.TXT'), 'text/plain'),
    (: paths :)
    unit:assert-equals(ext-mime-type('/foo.bar/foo.txt'), 'text/plain'),    
    unit:assert-equals(ext-mime-type('\foo.bar\foo.txt'), 'text/plain')    
};
