xquery version "3.0";

(:~
 : Example Fold App
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold-app
 :)
module namespace app ='http://xokomola.com/xquery/fold-app';

declare default function namespace 'http://xokomola.com/xquery/fold/routes';

import module namespace route = 'http://xokomola.com/xquery/fold/routes'
    at '../fold/routes.xqm';

(: ---- /math service ---- :)

declare variable $app:routes := (
    context('/math', $app:sum-routes)  
);

declare variable $app:sum-routes := (
    GET(('/sum/{a}/{b}', map { 'a': '\d+', 'b': '\d+' }),
        ('a|integer', 'b|integer'),
        app:sum#2)
);

declare function app:sum($x as xs:integer, $y as xs:integer) { 
    'Sum is: ' || $x + $y
};
