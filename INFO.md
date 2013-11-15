# Dependency Matrix

Note: _Used_ refers to the version that would be retrieved from the Chef Server.

## Aligned Servers
Gitlab | Chef Server
------ | -----------
1.10   | 1.10
1.9.7  | 1.9.7
1.9.6  | 1.9.6

Scenario            | Req                 | Used  | Status Req    | Status servers | Remarks
:-                  | :-                  | :-    | :-            | :-             | :-
Behind req.         | = 1.9.6             | 1.9.6 | ! warning-req | √              | You could relax requirements
Last match          | ~> 1.9.6 or = 1.9.7 | 1.9.7 | √             | √              |
Forward req.        | > 1.10 or > 1.9.7   |       | X error       | √              | Version not found

## Gitlab out-of-date
Gitlab | Chef Server
------ | -----------
       | 1.10
1.9.7  | 1.9.7
1.9.6  | 1.9.6

Scenario            | Req                 | Used  | Status Req    | Status servers   | Remarks
:-                  | :-                  | :-    | :-            | :-               | :-
Behind req.         | = 1.9.6             | 1.9.6 | ! warning-req | ! warning-gitlab | You could relax requirements. Gitlab not aligned
Last match gitlab   | ~> 1.9.6 or = 1.9.7 | 1.9.7 | √             | ! warning-gitlab | Gitlab not aligned
Last match Chef     | ~> 1.10             | 1.10  | √             | ! warning-gitlab | Gitlab not aligned
Forward req.        | > 1.10 or > 1.9.7   |       | X error       | ! warning-gitlab | Version not found

## Chef server out-of-date
Gitlab | Chef Server
------ | -----------
1.10   |
1.9.7  | 1.9.7
1.9.6  | 1.9.6

Scenario            | Req                 | Used  | Status Req    | Status servers   | Remarks
:-                  | :-                  | :-    | :-            | :-               | :-
Behind req.         | = 1.9.6             | 1.9.6 | ! warning-req | ! warning-chef   | You could relax requirements. Chef Server not aligned
Last match gitlab   | ~> 1.10             |       | X error       | ! warning-chef   | Chef Server not aligned
Last match Chef     | ~> 1.9.6            | 1.9.7 | √             | ! warning-chef   | Chef Server not aligned
Forward req.        | > 1.10              |       | X error       | ! warning-chef   | Version not found
