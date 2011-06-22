Object::Relation - Advanced Object Relational Mapper
====================================================

Description
-----------

This was an experimental Perl ORM written by [David E.
Wheeler](http://justatheory.com/) and [Curtis
Poe](http://blogs.perl.org/users/ovid/) in 2004-2006. The idea was that it
would create views and rules as an abstract interface over tables, mimicking
and mapping to the separation of public interfaces from implementation in
object oriented programming.

Eventually, however, I (David) decided that all ORMs are basically awful,
including this one, because they can never cover the full range of relational
theory. Better to just use the database as the model in your web MVC app and
not use an ORM at all.

Nevertheless, there are some ideas in here that others might find interesting,
so the code and its history has been migrated from a private Subversion server
to GitHub. Enjoy.

Copyright and License
---------------------

Copyright (c) 2004-2006 [Kineticode, Inc.](http://www.kineticode.com/).

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
