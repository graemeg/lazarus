Welcome to Lazarus
==================

Lazarus is a Rapid Application Development Tool for Free Pascal.
It comes with the LCL - Lazarus component library, which contains platform
independent visual components like buttons, windows, checkbox, treeview and
many, many more. The LCL is platform independent, so you can write an
application once and then compile for various platforms without changing code.

Free Pascal at www.freepascal.org is a fast Object Pascal compiler (and more),
that runs on more than 20 platforms (Linux, Windows, BSD, OS/2, DOS, PowerPC,
and many more).

The LCL currently supports Linux (gtk2 and qt4), all flavors of Windows
(even wince), Mac OS X (carbon, gtk2, qt4), FreeBSD (gtk2).
There is experimental support for:
* gtk3
* Solaris 
The LCL still contains code for gtk1 although that is obsolete.

--------------------------------------------------------------------------------
Compilation:
You don't need ./configure, just do

  []$ make clean bigide

(BSD users: gmake clean bigide)

This will create the Lazarus executable with a lot of packages.
Start it and enjoy.

If the above gives an error, you can try to build a minimal IDE with
  []$ make clean all

(BSD users: gmake clean all)

--------------------------------------------------------------------------------
Installation and Requirements:

See the file docs/INSTALL.

--------------------------------------------------------------------------------
Usage:

Start the IDE with:
  []$ cd your/lazarus/directory
  []$ ./lazarus

--------------------------------------------------------------------------------
Documentation:

The official site is www.lazarus.freepascal.org. There you can find the FAQ -
the frequently asked questions.
Documents about specific topics can be found at 
wiki.freepascal.org/Lazarus_Documentation.
Examples on how to use the LCL can be found in the 'examples' directory.
Help, documents and files about Free Pascal are at www.freepascal.org.


--------------------------------------------------------------------------------
Mailing list:

There is a very active and helpful mailing list for Lazarus, where the
developers interact, share ideas, discuss problems, and of course answer
questions.
You can subscribe at
http://lists.lazarus.freepascal.org/mailman/listinfo/lazarus

--------------------------------------------------------------------------------
How to help Lazarus:

If you find bugs, don't hesitate to use the bug tracking tool at the website,
or send an email to the list.
Patches can be sent as .zip or .tgz attachments directly to the mailing list if
small, or (preferably) to the bug tracker at
http://bugs.freepascal.org/my_view_page.php

