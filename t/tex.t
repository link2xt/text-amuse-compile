#!perl

use strict;
use warnings;
use utf8;

use Test::More;
use File::Spec;
use Text::Amuse;
use Text::Amuse::Compile;
use Text::Amuse::Compile::Utils qw/read_file/;

my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';

plan tests => 69;


# this is the test file for the LaTeX output, which is the most
# complicated.

my $file_no_toc = File::Spec->catfile(qw/t tex testing-no-toc.muse/);
my $file_with_toc = File::Spec->catfile(qw/t tex testing.muse/);

test_file($file_no_toc, {
                         division => 9,
                         fontsize => 11,
                         papersize => 'half-lt',
                         nocoverpage => 0,
                        },
          qr/scrbook/,
          qr/DIV=9/,
          qr/fontsize=11pt/,
          qr/mainlanguage\{croatian\}/,
          qr/paper=5.5in:8.5in/,
          qr/\\maketitle\s*\\cleardoublepage/s,
         );

test_file($file_no_toc, {
                         nocoverpage => 1,
                        },
          qr/\\maketitle\s*\w/,
         );

test_file($file_with_toc, {
                           cover => 'prova.pdf',
                          },
          qr/\\end\{center\}\s*\\cleardoublepage\s*\\tableofcontents/s,
         );


test_file($file_with_toc, {
                           papersize => 'generic',
                          },
          qr/scrbook/,
          qr/mainlanguage\{russian\}/,
          qr/\\renewcaptionname\{russian\}\{\\contentsname\}\{Содржина\}/,
          qr/paper=210mm:11in/,
          qr/\\maketitle\s*\\cleardoublepage/s,
         );

test_file($file_with_toc, {
                           papersize => 'half-a4',
                          },
          qr/paper=a5/,
          qr/\\maketitle\s*\\cleardoublepage/s,
         );

test_file({
           path => File::Spec->catfile(qw/t tex/),
           files => [ qw/testing testing-no-toc testing/],
           name => 'merged-1',
           title => 'Merged',
          },
          {
          },
          qr/croatian/,
          qr/russian/,
          qr/Pallino.*Pinco.*Second.*author/s,
          qr/mainlanguage\{russian}.*selectlanguage\{croatian}.*selectlanguage\{russian}/s,
          qr/\\maketitle\s*\\cleardoublepage/s,
          qr/\\setmainlanguage\{russian\}\s*
             \\newfontfamily\s*
             \\russianfont\[Script=Cyrillic\]\{Linux\sLibertine\sO\}\s*
             \\setotherlanguages\{croatian\}\s*
             \\renewcaptionname\{russian\}\{\\contentsname\}\{Содржина\}/sx,
         );

test_file({
           path => File::Spec->catfile(qw/t tex/),
           files => [ qw/testing-no-toc testing testing-no-toc/],
           name => 'merged-2',
           title => 'Merged',
          },
          {
          },
          qr/\\maketitle\s*\\cleardoublepage/s,
          qr/mainlanguage\{croatian}.*selectlanguage\{russian}.*selectlanguage\{croatian}/s,
          qr/Second.*author.*Pallino.*Pinco/s,
          qr/croatian/,
          qr/russian/,
          qr/\\setmainlanguage\{croatian\}\s*
             \\setotherlanguages\{russian\}\s*
             \\newfontfamily\s*
             \\russianfont\[Script=Cyrillic\]\{Linux\sLibertine\sO\}/sx
         );

test_file({
           path => File::Spec->catfile(qw/t tex/),
           files => [ qw/testing testing-no-toc testing headers/ ],
           name => 'merged-3',
           title => 'Merged 3',
          },
          {
          },
          qr/mainlanguage\{russian}.*
             selectlanguage\{croatian}.*
             selectlanguage\{russian}.*
             selectlanguage\{italian}/sx,
          qr/\\setotherlanguages\{croatian,italian\}/,
          qr/textbf{TitleT.*
             textbf{SubtitleT.*
             Large{AuthorT.*
             large{DateT}.*
             SourceT.*
             NotesT/sx,
          );


sub test_file {
    my ($file, $extra, @regexps) = @_;
    my $c = Text::Amuse::Compile->new(tex => 1, extra => $extra);
    $c->compile($file);
    my $out;
    if (ref($file)) {
        $out = File::Spec->catfile($file->{path}, $file->{name} . '.tex');
    }
    else {
        $out = $file;
        $out =~ s/\.muse$/.tex/;
    }
    ok (-f $out, "$out produced");
    my $body = read_file($out);
    # print $body;
    my $error = 0;
    unlike $body, qr/\[%/, "No opening template tokens found";
    unlike $body, qr/%\]/, "No closing template tokens found";
    foreach my $regexp (@regexps) {
        like($body, $regexp, "$regexp matches the body") or $error++;
    }
    if (ref($file)) {
        my $index = 0;
        foreach my $f (@{$file->{files}}) {
            my $fullpath = File::Spec->catfile($file->{path},
                                               $f . '.muse');
            my $muse = Text::Amuse->new(file => $fullpath);
            my $current = index($body, $muse->as_latex, $index);
            ok($current > $index, "$current is greater than $index") or $error++;;
            $index = $current;
        }
    }
    else {
        my $muse = Text::Amuse->new(file => $file);
        my $latex = $muse->as_latex;
        ok ((index($body, $latex) > 0), "Found the body") or $error++;
    }
    unless ($ENV{NO_CLEANUP}) {
        unlink $out unless $error;
        $out =~ s/tex$/status/;
        unlink $out unless $error;
    }
}
