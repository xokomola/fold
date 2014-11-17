xquery version "3.0";

(:~
 : Fold handlers
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 : @see https://github.com/ring-clojure/ring
 :)
module namespace handler = 'http://xokomola.com/xquery/fold/handler';

import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at 'response.xqm';

(:~
 : Shows the information from the request map in the browser and on STDOUT.
 :
 : See also: wrap:sniffer middleware which dumps request/response on STDOUT.
 :)
declare function handler:dump($request as map(*)) 
    as map(*) {
    res:ok(map:serialize(trace($request, 'REQUEST: ')))
};
