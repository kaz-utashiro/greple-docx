=head1 NAME

docx - Greple module for access docx file

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

greple -Mdocx

=head1 IMPORTANT

This module is now moved to App::Greple::msdoc module.
Do not use.

=head1 DESCRIPTION

This module makes it possible to search Microsoft Word docx file.

Docx document is consists of multiple files archived in zip format.
Among those files, document data is stored in "word/document.xml"
file.  This module extracts the content of this file and replaces the
search target data.

=head1 OPTIONS

=over 7

=item B<--indent>

Indent XML document before search.

=item B<--text>

Remove XML markups and extract document text.

=back

=head1 LICENSE

Copyright 2018 Kazumasa Utashiro.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Kazumasa Utashiro

=cut

package App::Greple::docx;

our $VERSION = '0.01';

use strict;
use warnings;

require 5.014;

use Carp;

use utf8;
use Encode;

use Exporter 'import';
our @EXPORT      = ();
our %EXPORT_TAGS = ();
our @EXPORT_OK   = ();

use App::Greple::Common;
use List::Util qw( min max first sum );
use Data::Dumper;

our $document = "word/document.xml";

my $zip_extract;
my $zip_update;
my $zip_write;

BEGIN {
    eval {
	require Archive::Zip;
	import  Archive::Zip qw( :ERROR_CODES :CONSTANTS );
	my $zip;
	$zip_extract = sub {
	    my ($zipdata, $file) = @_;
	    my $zip = Archive::Zip->new();
	    my $fh = new IO::File;
	    $fh->open(\$zipdata, "+<") or die "open: $!\n";
	    $zip->readFromFileHandle($fh, $file) == &AZ_OK
		or die "zip read: $!\n";
	    $fh->close;
	    decode 'utf8', $zip->contents($document);
	};
	$zip_update = sub {
	    my $data = shift;
	    $zip->contents($document, $data);
	};
	$zip_write = sub {
	    my $file = shift;
	    my $status = $zip->writeToFileNamed($file);
	    $status == &AZ_OK;
	};
    } or
    eval {
	require IO::Uncompress::Unzip;
	my $unzip;
	my $document_data;
	$zip_extract = sub {
	    my($zipdata, $file) = @_;
            $unzip = new IO::Uncompress::Unzip \$zipdata,
               or die "IO::Uncompress::Unzip failed.\n";
	    my $status;
	    for ($status = 1; $status > 0; $status = $unzip->nextStream()) {
		my $name = $unzip->getHeaderInfo()->{Name};
		next if $name ne $document;
		return decode 'utf8', do { local $/; <$unzip> };
	    }
	    croak "Error processing $file: $!\n" if $status < 0;
	    carp "No \"$document\" member in \"$file\".\n";
	    undef;
	};
	$zip_update = sub {
	    $document_data = shift;
	};
	$zip_write = sub {
	    croak "Not implemented.\n";
	};
    } or
    croak "No Zip module";
}

my $stdout;

push @EXPORT, '&docx_begin';
sub docx_begin {
    my %arg = @_;
    my $file = delete $arg{&FILELABEL} or die;

    if ($file =~ /\.docx$/ and $_ =~ /\A PK\003\004/x) {
	$_ = $zip_extract->($_, $file);
	binmode STDOUT, ":encoding(utf8)";
    }
}

push @EXPORT, '&docx_divert';
sub docx_divert {
    close STDOUT;
    open STDOUT, ">", \$stdout or die "open: $!\n";
    binmode STDOUT, "encoding(utf8)";
}

push @EXPORT, '&docx_update';
sub docx_update {
    my %arg = @_;
    my $file = delete $arg{&FILELABEL} or die;
    my $newfile = $arg{file};

    if ($stdout eq "") {
	warn "$file: Empty output.";
	warn "$newfile is not created.\n" if $newfile;
	return;
    }

    $zip_update->($stdout);

    if ($newfile) {
	if (-f $newfile and not $arg{force}) {
	    warn "File \"$newfile\" exists.\n";
	    return;
	}
	$zip_write->($newfile) or die "$newfile: $!\n";
    }

    warn "$newfile written.\n";
}

push @EXPORT, '&docx_text';
sub docx_text {
    my %arg = @_;
    my $file = delete $arg{&FILELABEL} or die;
    $file =~ /\.docx$/ or return;

    my @s;
    for (m{<w:p [^>]*>(.*?)</w:p>}g) {
	s{<w:(delText)>.*?</w:\1>}{}g;
	s{<v:numPr>}{・}g;
	s{</?(?:[avw]|wp|pic)\d*:.*?>}{}g;
	push @s, "$_\n";
    }
    $_ = join '', @s if @s;
}

push @EXPORT, '&docx_xml';
sub docx_xml {
    my %arg = @_;
    my $file = delete $arg{&FILELABEL} or die;
    $file =~ /\.docx$/ or return;

    my $level = 0;
    my %nonewline = map { $_ => 1 } qw(t delText);

    my $indent_mark = "| ";
    s{
	(?<mark>
	  (?<single>
	    < w: (?<tag>\w+) [^/>]* />
	  )
	  |
	  (?<open>
	    < w: (?<tag>\w+) [^>]* >
	  )
	  |
	  (?<close>
	    < /w: (?<tag>\w+) >
	  )
	)
    }{
	my $s = "";
	if ($nonewline{$+{tag}}) {
	    $s = join("", $+{open} ? $indent_mark x $level : "",
			  $+{mark},
			  $+{close} ? "\n" : "");
	}
	else {
	    $+{close} and --$level;
	    $s = ($indent_mark x $level) . $+{mark} . "\n";
	    $+{open}  and ++$level;
	}
	$s;
    }gex;
}

1;

__DATA__

option default --persist --begin docx_begin

option --text --begin docx_text

define (#delText) <w:delText>.*?</w:delText>
option --indent --begin docx_xml --exclude (#delText)

option --plain --exclude (#delText) --nonewline

option --unzip \
	--if '/\.docx$/:unzip -p /dev/stdin word/document.xml' \
	--block '(?<=<w:t>).*?(?=</w:t>)'

option --create \
	--noline-number --no-filename --nonewline --all \
	--begin docx_divert \
	--end docx_update(file=$<shift>)
