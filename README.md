# NAME

docx - Greple module for access docx file

# VERSION

Version 0.01

# SYNOPSIS

greple -Mdocx

# DESCRIPTION

This module makes it possible to search Microsoft Word docx file.

Docx document is consists of multiple files archived in zip format.
Among those files, document data is stored in "word/document.xml"
file.  This module extracts the content of this file and replaces the
search target data.

# OPTIONS

- **--indent**

    Indent XML document before search.

- **--text**

    Remove XML markups and extract document text.

# LICENSE

Copyright (C) Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Kazumasa Utashiro
