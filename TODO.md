have a special mode for images, where an image in a dir is treated as a page. a
description can be attached, so image.jpg would have image.md.
image pages are rendered using a special image.html.erb template

alternatively, a gallery mode, where a directory named like `pictures.gallery/`
is treated as a single page. the page will be built from one or more images in
the gallery, plus an optional description.{md,html}[.erb] for text content
describing the gallery. alternatively, use `pagename.image` for single images.
this would use a special `gallery.html.erb` or `image.html.erb` template
supplied in the AW dir.

likewise, a directory format like `title.page/` could be used to create pages
from multiple files, though i think the use cases i had in mind for this have
been solved in other ways already.

make optional dependencies more verbose, especially when their feature are
directly called. add warnings in.

an automatic index should be created for sections if one doesnt exist, which
would list subsections and pages. for this purpose, a special `index.html.erb`
template would be used, rendered within the page template. this could be a
generic template supplied in the program dir, replacable by the user in the AW
dir.

yaml frontmatter on stylseets with heritable attribute

for stylesheets and javascript in the site structure, some way to determine
whether these should be included in a specific page, the entire section, or the
section and any sub-section (heritable). yaml frontmatter might accomplish this.
non-heritable section-wide might be default, or a specific page might be
specified in the frontmatter (`apply_to: pagename.md`), or the heritable
attribute might be given in frontmatter (`apply_to: heritable` or
`heritable: true`)

include feature should support full rendering for whatever files will be
included, but only if the user requests it - this way normal ARKWEB-style pages
can be included and rendered, but complete HTML files from other sources can
also be included without getting wrapped in a template.

apple icon support, windows tile support

when in watch mode, disable message times

move the various helper methods found on Site to Helper

smart rendering: when a template is modified, make sure all pages are
re-rendered

builtin support for a development server
ark serve
ark unserve

smart rendering: make sure autoindices are re-rendered when their collected
pages change

fix version information bug

allow markdown in frontmatter `desc:' fields, since these will be used as
snippets and in autoindices as content.

regarding snippets: barring dependancy cycle checks, allow for snippets to be
taken from pages without an ERB pass (since these can't contain content from
other pages). the #snippet method would fall back on #desc for pages with ERB
passes.

directory-pages will have assets, in the form of any images, css or javascript
alongside the index.x.y, which will be accessible on the page object.
consequently, any such files found in a section will be available to the
section's index as its own assets. by default, styles and scripts will be linked
automatically. heritibility of assets will be controlled with frontmatter on
those assets, and only applies to section-assets. heritable assets will be
accessible on child-pages and child-sections as if those assets existed in every
child page.

support for pages written as plain text without any markup, i.e., `.txt` files

