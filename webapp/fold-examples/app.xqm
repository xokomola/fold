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

import module namespace handler = 'http://xokomola.com/xquery/fold/handler'
    at '../fold/handler.xqm';
import module namespace route = 'http://xokomola.com/xquery/fold/routes'
    at '../fold/routes.xqm';
import module namespace wrap = 'http://xokomola.com/xquery/fold/middleware'
    at '../fold/middleware.xqm';
import module namespace res = 'http://xokomola.com/xquery/fold/response'
    at '../fold/response.xqm';
import module namespace req = 'http://xokomola.com/xquery/fold/request'
    at '../fold/request.xqm';

import module namespace request = "http://exquery.org/ns/request";

declare option db:chop 'false';

(:~
 : Main routing handler. Called by fold:serve#1.
 :
 : @return the response map.
 :)
declare function app:serve() {
    function($request) { route($app:routes)($request) }
};

declare variable $app:routes := (
    $app:not-found
);

(:~ 404 response :)
declare variable $app:not-found := not-found(<not-found>No more examples for you!</not-found>);
