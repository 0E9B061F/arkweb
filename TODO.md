should be able to set default options for a site in its header

have a special mode for images, where an image in a dir is treated as a page. a
description can be attached, so image.jpg would have image.md.
image pages are rendered using a special image.html.erb template

alternatively, a gallery mode, where a directory named like `pictures.gallery/`
is treated as a single page. the page will be built from one or more images in
the gallery, plus an optional description.{md,html}[.erb] for text content
describing the gallery.

likewise, a directory format like `title.page/` could be used to create pages
from multiple files, though i think the use cases i had in mind for this have
been solved in other ways already.

make optional dependencies more verbose, especially when their feature are
directly called. add warnings in.

add header configuration value for google analytics key, which automatically
inserts the google analytics script with the key

add deploy function using rsync and ssh, configured in the site header

an automatic index should be created for sections if one doesnt exist, which
would list subsections and pages

each section should have its own section.yaml, similar to the site's header.yaml
this could be used to set things like the section title. this is equivalent to
frontmatter for individual pages.

smart rendering: only re-render files which have changed since the last rendering.

yaml frontmatter on stylseets with heritable attribute

smarter handling of output files and directories; previously rendered files
should be deleted if the files they were rendered from were deleted. clobbering
the output directory should fall back on erasing all files underneath the output
dir if the output dir cannot be deleted (ie, the user has no rights to)

include feature should support full rendering for whatever files will be
included, but only if the user requests it - this way normal ARKWEB-style pages
can be included and rendered, but complete HTML files from other sources can
also be included without getting wrapped in a template.

before and after hooks - eg, to generate docs before compiling, or to commit the
output to a repository

favicon support

for brevity, rename `ARKWEB` dir to `AW`, for consistency rename `aw` output dir
to `AW`

