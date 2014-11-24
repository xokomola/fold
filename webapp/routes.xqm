xquery version "3.0";

(:~
 : Fold Router
 :
 : This is being called into by the fold adapters fold:serve#1 function.
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold-app
 :)
module namespace fold ='http://xokomola.com/xquery/fold';

import module namespace routes = 'http://xokomola.com/xquery/fold/routes'
    at 'fold/routes.xqm';

import module namespace app = 'http://xokomola.com/xquery/fold-app'
    at 'fold-app/routes.xqm';

(:~
 : Main routing handler.
 :
 : @return the response map.
 :)
declare function fold:routes() {
    function($request) { routes:route($fold:routes)($request) }
};

(:~
 : The actual routing table.
 :)
declare variable $fold:routes := (
    $app:routes,
    $fold:not-found
);

(:~ 404 response :)
declare variable $fold:not-found := 
    routes:not-found(<error code="404">Could not route request</error>);

