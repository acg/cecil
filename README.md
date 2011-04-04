# cecil - a web interface for cil #

cecil (prounounced "see-cil") is a web interface for the [cil distributed issue tracker](https://github.com/andychilton/cil) by Andy Chilton. It provides both static html and web app reporting interfaces to a cil `issues/` directory.

## Screenshots ##

### Summary of Issues ###

Here's the main summary page, showing several features in action:

* Search: show only issues matching the text "cil"
* Filtering: show only issues assigned to me, "Alan Grow"
* Sorting: sort by Status, then by Summary text (this is a quick client-side sort)

![The cecil issue summary page](./cecil/raw/master/doc/cecil-summary.png)

### Issue Details ###

![The cecil issue details page](./cecil/raw/master/doc/cecil-issue.png)

## Installation ##

First, install my [patched version of cil](https://github.com/acg/cil/tree/timetrack). This adds time tracking, time zone support in all date fields, parent issue relationships, and some other things. (I hope to get these patches accepted into cil soon.) Note that cil has quite a few cpan dependencies, some of which may not be available in package form for your platform, so you may have to install some things from source. The [local::lib](http://search.cpan.org/~apeiron/local-lib-1.008004/lib/local/lib.pm) module may help.

Now install the perl dependencies for cecil:

    LWP
    URI
    Template

Test that you've satisified dependencies:

    perl -c bin/cecil

In the cecil directory, create a symlink to your cil issues dir:

    ln -s $HOME/myproject/issues

## Option 1: The CGI Web Interface ##

Install [lighttpd](http://www.lighttpd.net/), then

    cd svc/lighttpd
    ./run

Now browse to [http://localhost:8085/](http://localhost:8085/).

## Option 2: The Static Web Interface ##

In the cecil directory:

    make

Now open issues/summary.html in your browser. Note that some things like filtering will not work in the static interface.

## Theming ##

cecil has some basic support for theming via CSS. Two themes are currently included: "forest", and "steelblue". Stay tuned for more details on how to create and configure themes.

