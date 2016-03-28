# lapr
A commandline IDE for writing LaTeX documents.

This project is separated in two modules: project and session
These modules are intended to be independent of each other. project implements the latex project related stuff 
like creating and updating the preamble, adding content and packages and dividing the latex document into several files.
The session module can be used as a library implementing interactive use of other libraries (usable similar to a shell).
These two modules are then used to implement the latex IDE.
