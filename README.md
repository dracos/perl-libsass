CSS::Sass
=========

### Compile .scss and .sass files using libsass

CSS::Sass provides a perl interface to [libsass][1], a fairly complete Sass
compiler written in C++.  It is currently somewhere around ruby sass 3.2/3.3
feature parity and heading towards 3.4. It can compile .scss and .sass files.

[1]: https://github.com/sass/libsass

Installation
------------

[![Build Status](https://travis-ci.org/sass/perl-libsass.svg?branch=master)](https://travis-ci.org/sass/perl-libsass)
[![Coverage Status](https://img.shields.io/coveralls/sass/perl-libsass.svg)](https://coveralls.io/r/sass/perl-libsass?branch=master)
[![CPAN version](https://badge.fury.io/pl/CSS-Sass.svg)](http://badge.fury.io/pl/CSS-Sass)

To install this module type the following:

    perl Build.PL
    ./Build verbose=1
    ./Build test verbose=1
    ./Build install verbose=1

On windows you may need to install [Strawberry Perl](http://strawberryperl.com/).

Documentation
-------------

Before installing:

    perldoc lib/CSS/Sass.pm

After installing:

    man CSS::Sass

Or view [converted markdown version][1]

[1]: https://github.com/sass/perl-libsass/blob/master/lib/CSS/Sass.md

Dependencies
------------

This module requires these other modules and libraries:

  * Module::Build
  * Test::More

Command line utility
--------------------

```
psass [options] [ path_in | - ] [ path_out | - ]
```

```
-v, --version                 print version
-h, --help                    print this help
-w, --watch                   start watchdog mode
-p, --precision               precision for float output
-o, --output-file=file        output file to write result to
-t, --output-style=style      output style [nested|compressed]
-L, --plugin-path=path        plugin load path (repeatable)
-I, --include-path=path       sass include path (repeatable)
-c, --source-comments         enable source debug comments
-e, --source-map-embed        embed source-map in mapping url
-s, --source-map-contents     include original contents
-m, --source-map-file=file    create and write source-map to file
    --no-source-map-url       omit sourceMappingUrl from output
```

Copyright And Licence
---------------------

Copyright © 2013-2014 by David Caldwell  
Copyright © 2014-2016 by Marcel Greter

This library is released under the MIT license.