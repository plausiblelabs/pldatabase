This directory contains source and binary dependencies:

SQLite
    Description:
      An up-to-date embeddedable version of SQLite. Mac OS X and iOS ship SQLite, but it is
      often out-of-date, patched, and often built with unexpected or limited options.

    Version:
      3.7.13 amalgamation downloaded from http://www.sqlite.org/download.html

    License:
      Public Domain

    Modifications:
      The library has not been modified, and built version of the library has been included in the repository.
      To rebuild libsqlite3.a, execute the following from within the SQLite directory:
          make clean && make -j all && make clean-objs
