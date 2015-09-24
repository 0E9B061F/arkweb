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

each section should have its own section.yaml, similar to the site's header.yaml
this could be used to set things like the section title. this is equivalent to
frontmatter for individual pages.

yaml frontmatter on stylseets with heritable attribute

clobbering the output directory should fall back on erasing all files underneath
the output dir if the output dir cannot be deleted (ie, the user has no rights
to)

include feature should support full rendering for whatever files will be
included, but only if the user requests it - this way normal ARKWEB-style pages
can be included and rendered, but complete HTML files from other sources can
also be included without getting wrapped in a template.

apple icon support, windows tile support

decouple deployment configuration from deployment option -- currently,
deployment happens for every render if deployment is configured. instead there
should be a deployment flag which triggers deployment to the configured location
if there is one.

