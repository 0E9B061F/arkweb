# ARKWEB-3

__ARKWEB__ is a document processor suitable for creating flat websites from a
collection of pages, templates, images, and the like.



# Usage

`ark [options] SITEPATH`

where `SITEPATH` is a path to a valid ARKWEB site directory, or a nonexistent
path -- which will be initialized as a bare ARKWEB site. For a full list of
options use `ark -h`

To get started, give a nonexistent path to `ark` as the SITEPATH, e.g. `ark
/tmp/nonexistent`. If the path does not exist it will be created as a directory,
and populated with a skeletal ARKWEB site structure which you may edit to your
liking.



# Site structure

A valid Site directory take sthe following form. The only required elements are
the header, `header.yaml`, the page template `page.html.erb`  and at least one
page to render.


## Example

```
path/to/site/
    ARKWEB/
        header.yaml   -- Required. Contains site metadata. Required fields are `title`,
                         `author`, `tags` and `desc`
        site.html.erb -- Optional. This template is rendered around each page
                         template. The body data is stored in the variable `@body'
        page.html.erb -- Required. This template is rendered around each page. The page data
                         is stored in the variable `@page`
        *.{sass,scss} -- Optional. SASS files are rendered automatically.
        *.css         -- Optional. Stylesheets for use.
        images/       -- Optional. Any images to be used in the site
        output/       -- Default location for renderd output.
        cache/        -- Files cached during processing
        tmp/          -- Temporary files created during processing

    page.html.erb   -- Pages exist under the site root, outside of the ARKWEB
    page.md            directory. Pages are processed according to their
    page.md.erb        extensions; pages ending in `.erb` will be given an ERB
                       pass. Markup that requires further processing will then be
                       rendered to HTML.

    section1/       -- Directories in the site root outside of the ARKWEB
    section2/          directory are called sections. Sections hold all
    section3/          information about any pages and other files they contain.
```


# Using ERB in ARKWEB

An ERB pass can be added to any page file by appending '.erb' to the name. There
are three contexts in which you might use ERB, each with different objects
available:


## ERB in pages

ERB can be used in any page type. There will be three available objects:

* `@site`    -- an ARKWEB::Site instance representing the current site
* `@section` -- an ARKWEB::Section instance representing the current site
                section, ie. subdirectory under the site root
* `@page`    -- an ARKWEB::Page instance for the current page

Additionally, if the given page contains a `collect` directive in its header,
two additinal objects used for pagination will be available:

* `@collection` -- An ARKWEB::Collection instance which holds all pages
                   specified in the `collect` directive
* `@index`      -- A paginated page will be rendered multiple times, once for
                   each pgae in the collection. `@index` is the current page
                   number.


## ERB in templates

The two templates -- `page.html.erb` and `site.html.erb` -- have the same three
objects available to them as pages (but no `@collection` or `@index` object),
with an additional `@body` object. For `page.html.erb`, `@body` will contain the
rendered page. For `site.html.erb`, `@body` will contain the page template
rendered around the page.


## ERB in YAML frontmatter

ERB can be used in YAML frontmatter, with the caveat that only the `@site`
object will be available. This might be useful if, for instance, you wanted to
reference your site's title in a page's title:

```erb
---
title: <%= @site.info(:title) %> Index
description: The main index for <%= @site.info(:title) %>
---
```

The page object itself isn't available because the ERB pass occurs before the
page object is fully initialized.

# Pagination in ARKWEB

Pagination in ARKWEB works be re-rendering the same page multiple times with a
different page index for each render.

Pagination is used by specifying the `collect` and `pagesize` directives in a
page's frontmatter. For instance:

```yaml
---
collect: posts/articles, posts/ideas
pagesize: 5
---
```

This will instruct ARKWEB to supply the page with a collection of all pages in
the `posts/articles` and `posts/ideas` sections. These pages will be stored in a
ARKWEB::Collection object as `@collection`. The current index number will be
given as `@index`.

To create a list of pages for the current pagination index:

```erb
<% @collection.paginate(@index).each do |page| %>
  <%= page.link_to %>
<% end %>
```

To create a set of links to each page:

```erb
<%= @collection.links(@index) %>
```

