# ARKWEB-3

__ARKWEB-3__ is a simple document processor suitable for creating flat websites
from a collection of pages and templates. __ARKWEB__ supports ERB, Markdown
and the MediaWiki markup language.



# Usage

`ark [options] SITEPATH`, where `SITEPATH` is a path to a valid __ARKWEB__ site
directory. For a list of options use `ark -h`

To get started, give a nonexistent path to `ark` as the SITEPATH, e.g. `ark
/tmp/nonexistent`. If the path does not exist it will be created as a directory,
and populated with a skeletal Site structure which you may edit to your liking.



# Site structure

A valid Site directory take sthe following form. The only required elements are
the header, `header.yaml`, the page template `page.html.erb`  and at least one
page to render.


## Example

    path/to/site/
      header.yaml   -- Required. Contains site metadata. Required fields are `title`,
                       `author`, `tags` and `desc`
      site.html.erb -- Optional. This template is rendered around each page
                       template. The body data is stored in the variable `@body'
      page.html.erb -- Required. This template is rendered around each page. The page data
                       is stored in the variable `@page`
      img/*         -- Optional. Any images to be used in the site
      *.LANG.page   -- Required. Represents a given page, in the given markup language,
                       where LANG is the usual extension for the given markup;
                       erb, md, wiki, or html
      *.{sass,scss} -- Optional. SASS files are rendered automatically.
      *.css         -- Optional. Stylesheets for use.
      html/         -- Default location for renderd output.



# Misc.

__ARKWEB__ is similar to Jekyll, and probably to other tools designed to render
flat websites. ARKWEB differs from Jekyll in it's automatic file handling and
site structure.

__ARKWEB__ is in the early stages of development; it has a very
limited feature set. The author intends for  __ARKWEB__ to remain a simple tool,
but additional featured are planned. See TODO for features to be added.

