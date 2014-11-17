xquery version "3.0";

(:~
 : Tests for apply function (using xquery:eval) contributed by
 : Rob Stapper in answer to my proposal for adding
 : apply to XQuery 3.1.
 :
 : @see https://www.w3.org/Bugs/Public/show_bug.cgi?id=26585
 :)
module namespace test = 'http://xokomola.com/xquery/common/tests';

declare default function namespace 'http://xokomola.com/xquery/common/apply';

import module namespace apply = 'http://xokomola.com/xquery/common/apply'
    at '../../webapp/fold-common/apply.xqm'; 

declare %private function test:sum($a,$b) { $a + $b };
declare %private function test:mult($a,$b) { $a * $b };

declare %unit:test function test:apply-concat() {
    unit:assert-equals(
        apply(
            fn:concat#3, ('a', 'b', 'c')
        ), 
        'abc'
    )
};

declare %unit:test function test:apply-addition() {
    unit:assert-equals(
        apply(
            function($a, $b, $c) {
                $a + $b + $c
            },
            (1, 2, 3)
        ), 
        6
    )
};

declare %unit:test function test:apply-cast-to-string() {
    unit:assert-equals(
        apply(
            function($a, $b) {
                $a || fn:string($b)
            },
            ('number_', 2)
        ), 
        'number_2'
    )
};

declare %unit:test function test:apply-array() {
    unit:assert-equals(
        apply(test:sum#2, [2,4]),
        6
    )
};

declare %unit:test function test:apply-array-with-seq() {
    unit:assert-equals(
        apply(
            function($a,$b) {
                ($a[1] * $a[2]) + ($b[1] * $b[2])
            }, [(1,2),(3,4)]
        ),
        14
    )
};
