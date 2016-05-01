# lapr
A commandline IDE for writing LaTeX documents.

Description
-----------
lapr is a commandline IDE for LaTeX documents. It features automatic code generation based on templates and package databases.
The main goal is to reduce the amount of management required for LaTeX documents. This is especially useful for complex documents, using many different files and packages. Still, it eases the use of LaTeX also for small documents.

lapr is built similar to a shell: you type in line-based commands at a prompt and receive results. For editing your favorite editor will be started, compiling and viewing will also be done by programs and engines you specify (although there are some sensible defaults).

To help you reducing the writing of redundant or easy code (like inserting several packages for using one command), lapr features 
a growing database which conatains commands and environments and corresponding packages. If a package is unknown, you will be prompted 
for it. This updates your personal database. Ideally, users share their databases with each other and also make submissions to the official database so that sooner or later a lot of standard LaTeX packages should be known to lapr.

lapr includes a mechanism for minimal sandboxes, which gives you the possibility to try out some code without recompiling the whole document. This is for example useful for big documents where you want to draw a tikzpicture. A tikzpicture template will be opened as temporary document and you can start a drawing-compiling-checking cycle.
