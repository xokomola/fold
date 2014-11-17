xquery version "3.0";

(:~
 : Tests for fold/utils/common.xqm
 :
 : @version 0.1
 : @author Marc van Grootel
 : @see https://github.com/xokomola/fold
 :)
module namespace test = 'http://xokomola.com/xquery/fold/tests';

declare default function namespace 'http://xokomola.com/xquery/common';

import module namespace utils = 'http://xokomola.com/xquery/common'
    at '../../webapp/fold-common/common.xqm';

declare %unit:test function test:add() {
    unit:assert-equals(add(1,1), 2),
    unit:assert-equals(add(1,-1), 0)
};

declare %unit:test function test:sub() {
    unit:assert-equals(sub(1,1), 0),
    unit:assert-equals(sub(1,-1), 2)
};

declare %unit:test function test:cons() {
    unit:assert-equals(cons(1,()), 1),
    unit:assert-equals(cons(1,(2,3)), (1,2,3)),
    unit:assert-equals(cons((1,2),(3,4)), (1,2,3,4))
};

declare %unit:test function test:take() {
    unit:assert-equals(
        take(0, (1,2,3)),
        ()
    ),
    unit:assert-equals(
        take(1, (1,2,3)),
        (1)
    ),
    unit:assert-equals(
        take(2, (1,2,3)),
        (1,2)
    ),        
    unit:assert-equals(
        take(3, (1,2,3)),
        (1,2,3)
    ),        
    unit:assert-equals(
        take(4, (1,2,3)),
        (1,2,3)
    ),        
    unit:assert-equals(
        take(-1, (1,2,3)),
        ()
    )       
};

declare %unit:test function test:drop() {
    unit:assert-equals(
        drop(0, (1,2,3)),
        (1,2,3)
    ),
    unit:assert-equals(
        drop(1, (1,2,3)),
        (2,3)
    ),
    unit:assert-equals(
        drop(2, (1,2,3)), 
        (3)
    ),        
    unit:assert-equals(
        drop(3, (1,2,3)),
        ()
    ),        
    unit:assert-equals(
        drop(4, (1,2,3)), 
        ()
    ),        
    unit:assert-equals(
        drop(-1, (1,2,3)),
        (1,2,3)
    )       
};

(: TODO: I would much rather have [(1,2),(3,4),(5,6)] :)
(: Currently partition is therefore not completely compatible with apply() :)
declare %unit:test function test:partition() {
    unit:assert-equals(partition(2,(1,2,3,4,5,6)), ([1,2],[3,4],[5,6])),
    unit:assert-equals(partition(2,(1,2,3,4,5)), ([1,2],[3,4],[5])),
    unit:assert-equals(partition(2,()), ()),
    unit:assert-equals(partition(4,(1,2)), ([1,2]))    
};

declare %unit:test function test:seq() {
    unit:assert-equals(seq([1,2,3]), (1,2,3)),
    unit:assert-equals(seq([]), ()),
    unit:assert-equals(seq([(1,2),(3,4)]), (1,2,3,4)),
    unit:assert-equals(seq((1,2,3)), (1,2,3))
};

declare %unit:test function test:interleave() {
    unit:assert-equals(interleave((1,2,3),('a','b','c')), (1,'a',2,'b',3,'c')),
    unit:assert-equals(interleave((1,2),('a','b','c')), (1,'a',2,'b','c')),
    unit:assert-equals(interleave((1,2,3),('a','b')), (1,'a',2,'b',3)),
    unit:assert-equals(interleave((),('a','b')), ('a','b')),
    unit:assert-equals(interleave((1,2),()), (1,2)),
    unit:assert-equals(interleave((),()), ())
};

declare %unit:test function test:get-in() {
    unit:assert-equals(
        get-in(map { }, ('a','b'), 'not-found'),
        'not-found'
    ),
    unit:assert-equals(
        get-in(map { 'a': map { 'b': 10 }}, ('a','b'), 'not-found'),
        10
    ),    
    unit:assert-equals(
        get-in(map { 'a': map { 'b': map { 'c': [1,2,3] }}}, ('a','b'), 'not-found'),
        map { 'c': [1,2,3] }
    ),    
    unit:assert-equals(
        get-in(map { 'a': map { 'b': map { 'c': [1,2,3] }}}, ('a', 'b', 'c', 'd'), 'not-found'),
        'not-found'
    )    
};

declare %unit:test function test:merge() {
    unit:assert-equals(
        merge((map { 'a': 1, 'b': 2, 'c': 3 }, map { 'b': 9, 'd': 4 })),
        map { 'a': 1, 'b': 9, 'c': 3, 'd': 4 }
    ),
    unit:assert-equals(
        merge(map { 'a': 1 }),
        map { 'a': 1 }
    ),
    unit:assert-equals(
        merge((map { 'a': 1 }, map { 'a': 2 }, map { 'a': 3 })),
        map { 'a': 3 }
    ),
    unit:assert-equals(
        merge((map { 'a': 1 }, map { 'a': 2 }, map { 'a': 3 })),
        map { 'a': 3 }
    ),
    unit:assert-equals(
        merge(((), map { 'a': 1 })),
        map { 'a': 1 }
    ),    
    unit:assert-equals(
        merge((map { 'a': 1 }, (), map { 'a': 2 })),
        map { 'a': 2 }
    ),    
    unit:assert-equals(
        merge(map { }),
        map { }
    ),    
    unit:assert-equals(
        merge(()),
        ()
    )    
};

declare %unit:test function test:merge-with() {
    unit:assert-equals(
        merge-with(
            function($a,$b) {
                ($a, $b)
            },
            (map { 'a': 1 }, map { 'a': 2 })
        ),
        map { 'a': (1, 2) }
    ),

    unit:assert-equals(
        merge-with(
            cons(?,?),
            (map { 'a': 1 }, map { 'a': 2 }, map { 'a': 3, 'b': 1 })
        ),
        map { 'a': (1, 2, 3), 'b': 1 }
    )

};

declare %unit:test function test:merge-with-sum() {
    unit:assert-equals(
        merge-with(
            add(?,?),
            (map { 'a': 1 }, map { 'a': 2 }, map { 'a': 3 })
        ),
        map { 'a': 6 } 
    )
};

declare %unit:test function test:merge-with-merge() {
    unit:assert-equals(
        merge-with(
            merge(?,?),
            (map { 'a': map { 1: 2, 3: 4 } }, map { 'a': map { 3: 5, 6: 7 } })
        ),
        map { 'a': map { 1: 2, 3: 5, 6: 7 } }
    )
};

declare %unit:test function test:zipmap() {
    unit:assert-equals(zipmap((1,2,3),('a','b','c')), map { 1: 'a', 2: 'b', 3: 'c' }),
    unit:assert-equals(zipmap((1,2),('a','b','c')), map { 1: 'a', 2: 'b' }),
    unit:assert-equals(zipmap((1,2,3),('a','b')), map { 1: 'a', 2: 'b', 3: () }),
    unit:assert-equals(zipmap((),('a','b','c')), map { })
};

declare %unit:test function test:comp() {
    unit:assert-equals(
        comp((
            function($x) { $x * 2 },
            function($x) { $x + 4 }
        ))(10),
        24
    )
};

declare %unit:test function test:comp-with-array() {
    unit:assert-equals(
        comp((
            function($x,$y) { $x * $y },
            function($x) { $x + 4 }
        ))([10,20]),
        204
    )
};

(: Arrow operator is not yet implemented :)
(:
declare %unit:test function test:comp-with-arrow-operator() {
    unit:assert-equals(
        [10,20] => comp((
            function($x, $y) { $x * $y },
            function($x) { $x + 4 }
        )),
        204
    )    
};
:)

declare %unit:test function test:thread() {
    unit:assert-equals(
        thread((
            10,
            function($x) { $x * 2 },
            function($x) { $x + 4 }
        )),
        24
    )    
};

declare %unit:test function test:thread-with-array() {
    unit:assert-equals(
        thread((
            [10,20],
            function($x, $y) { $x * $y },
            function($x) { $x + 4 }
        )),
        204
    )    
};

(: Map destructuring :)
declare %unit:test function test:destruct-map-simple() {
    unit:assert-equals(
        destructure-map(map { 'a': 10, 'b': 20 }, ('b','a')),
        (20,10)
    )
};

declare %unit:test function test:destruct-map-nested() {
    unit:assert-equals(
        destructure-map(map { 'a': map { 'b': map { 'c': 30 }}}, 'a/b/c'),
        30
    )
};

declare %unit:test function test:destruct-map-with-ctx() {
    unit:assert-equals(
        destructure-map(map { 'a': map { 'b': map { 'c': 30 }}}, 'b/c', 'a'),
        30
    ),
    unit:assert-equals(
        destructure-map(map { 'a': map { 'b': map { 'c': 30 }, 'd': 99}}, 'd', 'a'),
        99
    ),    
    unit:assert-equals(
        destructure-map(map { 'a': map { 'b': map { 'c': 30 }, 'd': 99}, 'd': 0}, '/d', 'a'),
        0
    )    
};

declare %unit:test function test:destruct-map-with-cast() {
    let $map := map {
        'a': 'foobar',
        'b': '10',
        'c': '1.5',
        'd': 'true',
        'e': 'false'
    }
    return (
        unit:assert(destructure-map($map, 'a|string') instance of xs:string),
        unit:assert(destructure-map($map, 'b|integer') instance of xs:integer),
        unit:assert(destructure-map($map, 'c|decimal') instance of xs:decimal),
        unit:assert(destructure-map($map, 'd|boolean') instance of xs:boolean),
        unit:assert(destructure-map($map, 'e|boolean') instance of xs:boolean),
        unit:assert(destructure-map($map, ('a|string', 'b|integer'))[1] instance of xs:string),
        unit:assert(destructure-map($map, ('a|string', 'b|integer'))[2] instance of xs:integer)
    )
};

declare %unit:test function test:replace() {
    let $fn := function($str) { fn:upper-case($str) }
    return
        unit:assert-equals(replace('abcdefgh','[bdfh]', $fn), 'aBcDeFgH'),
        
    let $fn := function($str) { fn:upper-case($str) }
    return
        unit:assert-equals(replace('abbbbccdd','([bdfh])+', $fn), 'aBBBBccDD')
};

declare %unit:test function test:re-seq() {
    unit:assert-equals(re-seq('abcdefgh','[bdfh]'), ('b','d','f','h')),
    unit:assert-equals(re-seq('abbbbccdd','([bdfh])+'), ('bbbb','dd'))
};

(: TODO: order of entries is not predictable :)
(:
declare %unit:test function test:to-xml() {
    unit:assert-equals(
        to-xml([]),
        <array/>),
    unit:assert-equals(
        to-xml([1,2,3]),
        <array>
            <entry>1</entry>
            <entry>2</entry>
            <entry>3</entry>
        </array>),
    unit:assert-equals(
        to-xml([1,[2,3],4]),
        <array>
            <entry>1</entry>
            <entry>
                <array>
                    <entry>2</entry>
                    <entry>3</entry>
                </array>
            </entry>
            <entry>4</entry>
        </array>),
    unit:assert-equals(
        to-xml([1,['2',<foo/>],<bar/>]),
        <array>
            <entry>1</entry>
            <entry>
                <array>
                    <entry>2</entry>
                    <entry>
                        <foo/>
                    </entry>
                </array>
            </entry>
            <entry>
                <bar/>
            </entry>
        </array>),
    unit:assert-equals(
        to-xml(map {}),
        <map/>),
    unit:assert-equals(
        to-xml(map {1: 1, 2: 2, 3: 3}),
        <map>
            <entry key="1">1</entry>
            <entry key="2">2</entry>
            <entry key="3">3</entry>
        </map>),
    unit:assert-equals(
        to-xml(map {1: 1, 'm': map {2: 2,3: 3}, 4: 4}),
        <map>
            <entry key="1">1</entry>
            <entry key="4">4</entry>
            <entry key="m">
                <map>
                    <entry key="2">2</entry>
                    <entry key="3">3</entry>
                </map>
            </entry>
        </map>),
    unit:assert-equals(
        to-xml(map {1: ['a','b'], 2: ['c','d']}),
        <map>
            <entry key="1">
                <array>
                    <entry>a</entry>
                    <entry>b</entry>
                </array>
            </entry>
            <entry key="2">
                <array>
                    <entry>c</entry>
                    <entry>d</entry>
                </array>
            </entry>
        </map>)
};
:)

(: TODO: check if we shouldn't use hof:id() for this instead? :)
declare %unit:test function test:constantly() {
    unit:assert-equals(
        constantly(1)('foo'),
        1),
    unit:assert-equals(
        constantly(<foobar/>)('foo'),
        <foobar/>)
};

declare %unit:test function test:parse-date() {
    unit:assert-equals(utils:parse-http-date("Sun, 06 Nov 1994 08:49:37 GMT"), xs:dateTime("1994-11-06T08:49:37Z")),
    unit:assert-equals(utils:parse-http-date("Sunday, 06-Nov-94 08:49:37 GMT"), xs:dateTime("1994-11-06T08:49:37Z")),
    unit:assert-equals(utils:parse-http-date("Sun Nov  6 08:49:37 1994"), xs:dateTime("1994-11-06T08:49:37Z")),
    unit:assert-equals(utils:parse-http-date("'Sun, 06 Nov 1994 08:49:37 GMT'"), xs:dateTime("1994-11-06T08:49:37Z"))   
};

declare %unit:test function test:format-date() {
    unit:assert-equals(utils:format-date(xs:dateTime('1994-11-06T08:49:37Z')), 'Sun, 06 Nov 1994 08:49:37 GMT')
};
