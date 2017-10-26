package Text::Amuse::Compile::TemplateOptions;

use utf8;
use strict;
use warnings FATAL => 'all';
use Types::Standard qw/Str Bool Enum StrMatch/;
use Pod::Usage qw//;
use File::Spec;
use Moo;
use Text::Amuse::Compile::Fonts;

use constant {
    TEX_MEASURE => qr{[0-9]+(\.[0-9]+)?(cm|mm|in|pt)},
};

=head1 NAME

Text::Amuse::Compile::TemplateOptions - parse and validate options for templates

=head2 SYNOPSIS

  use Text::Amuse::Compile::TemplateOptions;
  my $options = Text::Amuse::Compile::TemplateOptions->new(%options);
  my $doc = Text::Amuse->new(file => 'test.muse');
  # and get the hashrefs for the tokens
  my $latex_options = $options->as_latex($doc);

=head1 ACCESSORS

The follow accessors are read-write. The same settings can be passed
to the C<muse-compile.pl> script.

=head2 Paper

=over 4

=item * papersize (common values: a4, a5, letter)

Paper size, like a4, a5 or 210mm:11in. The width and heigth are
swapped in some komascript version. Just keep this in mind and do some
trial and error if you need custom dimensions.

=item * bcor (binding correction for inner margins)

The BCOR of the C<typearea> package. Defaults to 0mm. Go and read the doc.
It expects a TeX dimension like 10mm or 1in or 1.2cm.

B<Please note that this has no effect on the plain PDF output when an
imposed version is also required>, because we force BCOR=0mm
and oneside=true for the planin version in this case.

=item * division (the DIV factor for margin control)

The DIV of the C<typearea> package. Defaults to 12. Go and read the
doc. Sensible values are from 9 to 15. 15 has narrow margins, while in
9 they are pretty generous.

=item * oneside (boolean)

This is the default. Actually, this option doesn't have any use.

=item * twoside (boolean)

Set it to a true value to have a twosided document. Default is false.

B<Please note that this has no effect on the plain PDF output when an
imposed version is also required>, because we force BCOR=0mm
and oneside=true for the planin version in this case.

=item * opening

On which pages the chapters should open: right, left, any. Default:
right. The left one will probably lead to unexpected results (the PDF
will start with an empty page), so use it at your own peril.

=back

=cut

sub _get_papersize {
    my $paper = $_[0];
    my %aliases = (
                   'half-a4' => 'a5',
                   'half-lt' => '5.5in:8.5in',
                   generic => '210mm:11in',
                   a3 => 'a3',
                   a4 => 'a4',
                   a5 => 'a5',
                   a6 => 'a6',
                   b3 => 'b3',
                   b4 => 'b4',
                   b5 => 'b5',
                   b6 => 'b6',
                   letter => 'letter',
                  );
    if ($paper) {
        my $tex_measure = TEX_MEASURE;
        if ($aliases{$paper}) {
            return $aliases{$paper};
        }
        elsif ($paper =~ m/\A$tex_measure:$tex_measure\z/) {
            return $paper;
        }
        else {
            die "papersize $paper is invalid";
        }
    }
    else {
        return '210mm:11in';
    }
}


has papersize  => (is => 'rw',
                   isa => \&_get_papersize,
                   default => sub { '210mm:11in' },
                  );

sub tex_papersize {
    my $self = shift;
    return _get_papersize($self->papersize);
}


has bcor => (is => 'rw',
             isa => sub {
                 die "Bcor $_[0] must be a measure like 11mm"
                   unless $_[0] =~ TEX_MEASURE;                 
             },
             default => sub { '0mm' });

has division   => (is => 'rw',
                   isa => Enum[9..15],
                   default => sub { '12' },
                  );
has oneside => (is => 'rw', isa => Bool);
has twoside => (is => 'rw', isa => Bool);
has opening => (is => 'rw',
                isa => Enum[qw/any right left/],
                default => sub { 'right' });


=head2 Fonts

=over 4

=item * mainfont (grep fc-list -l for the correct name)

The system font name, such as C<Linux Libertine O> or C<Charis SIL>.
This implementation uses XeLaTeX, so we can use system fonts. Defaults
to C<CMU Serif>.

=item * sansfont 

The sans serif font to use. This option has some effects only on
slides. Defaults to C<CMU Sans Serif>

=item * monofont 

The monospace font to use. Defaults to C<CMU Typewriter Text>.

=item * fontsize

The size of the body font (9, 10, 11, 12) as integer, meaning points
(pt), defaulting to 10.

=back

=cut

sub serif_fonts {
    my @fonts = map { +{ name => $_->name, desc => $_->desc } }
      Text::Amuse::Compile::Fonts->new->serif_fonts;
    return @fonts;
}
sub mono_fonts {
    my @fonts = map { +{ name => $_->name, desc => $_->desc } }
      Text::Amuse::Compile::Fonts->new->mono_fonts;
    return @fonts;
}
sub sans_fonts {
    my @fonts = map { +{ name => $_->name, desc => $_->desc } }
      Text::Amuse::Compile::Fonts->new->sans_fonts;
    return @fonts;
}

sub all_fonts {
    my @all = map { +{ name => $_->name, desc => $_->desc } }
      Text::Amuse::Compile::Fonts->new->all_fonts;
    return @all;
}

sub default_mainfont {
    return (__PACKAGE__->serif_fonts)[0]->{name};
}

sub default_sansfont {
    return (__PACKAGE__->sans_fonts)[0]->{name};
}

sub default_monofont {
    return (__PACKAGE__->mono_fonts)[0]->{name};
}

has mainfont   => (is => 'rw',
                   isa => StrMatch[ qr{\A[a-zA-Z0-9 ]+\z} ],
                   default => sub { __PACKAGE__->default_mainfont },
                  );
has sansfont   => (is => 'rw',
                   isa => StrMatch[ qr{\A[a-zA-Z0-9 ]+\z} ],
                   default => sub { __PACKAGE__->default_sansfont },
                  );
has monofont   => (is => 'rw',
                   isa => StrMatch[ qr{\A[a-zA-Z0-9 ]+\z} ],
                   default => sub { __PACKAGE__->default_monofont },
                  );

has fontsize   => (is => 'rw',
                   isa => Enum[ __PACKAGE__->all_fontsizes ],
                   default => sub { 10 },
                  );

sub all_fontsizes {
    return (9..14);
}


=head2 Colophon

=over 4

=item * sitename

At the top of the page

=item * siteslogan

At the top, under sitename

=item * logo (filename)

At the top, under siteslogan

=item * site

At the bottom of the page

=back

=cut

sub check_filename {
    my ($filename) = @_;
    # false value, accept, will not be inserted.
    return unless $filename;
    # windows thing, in case
    $filename =~ s!\\!/!g;
    # is a path? test if it exists
    if ($filename =~ m!/!) {
        if (-f $filename and
            $filename =~ m/[a-zA-Z0-9]+\.(pdf|jpe?g|png)\z/ and
            File::Spec->file_name_is_absolute($filename)) {
            return $filename;
        }
        else {
            die "Absolute filename $filename must exist";
        }
    }
    elsif ($filename =~ m/\A
                          (
                              [a-zA-Z0-9]
                              [a-zA-Z0-9-]*
                              [a-zA-Z0-9]
                              (\.(pdf|jpe?g|png))?
                          )
                          \z/x) {
        # sane filename;
        return $1;
    }
    die "$filename is neither absolute and existing or a bare name without special characters";
}

has sitename   => (is => 'rw', isa => Str, default => sub { '' });
has siteslogan => (is => 'rw', isa => Str, default => sub { '' });
has site       => (is => 'rw', isa => Str, default => sub { '' });
has logo       => (is => 'rw',
                   isa => \&check_filename,
                   default => sub { '' },
                  );


=head2 Cover

=over 4

=item * cover (filename for front cover)

When this option is set to a true value, skip the creation of the
title page with \maketitle, and instead build a custome one, with the
cover placed in the middle of the page.

The value can be an absolute path, or a bare filename, which can be
found by C<kpsewhich>. If the path is not valid and sane (from the
LaTeX point of view: no spaces, no strange chars), the value is
ignored.

With EPUB output, the cover is used in the title page.

=item * coverwidth (dimension ratio with the text width, eg. '0.85')

Option to control the cover width, when is set (ignored otherwise).
Defaults to the full text width (i.e., 1). You have to pass a float
here with the ratio to the text width, like C<0.5>, C<1>.

With EPUB output, this affects the maximum width, not the actual
width.

=item * nocoverpage

Force the use of the LaTeX article class. If there are chapters
present, consider them aliases for a section.

=item * notoc

Do not generate a table of contents, even if the document requires
one.

=item * nofinalpage

Do not produce the last page on the PDF with the
author/title/notes/source/site name.

=item * impressum

Move the notes, which are usually in the last page at the bottom and
centered, on the second page, raggedright, in smaller size.

=item * sansfontsections

Use the default komascript style where chapters and parts have sans
font.

=item * headings

Generate the running headings in the document. Beware that this will
get you overfull headings if you have long titles.

The behaviour changes if it's a oneside document.

Available values:

=over 4

=item * title_subtitle

Title on the left page, subtitle on right page. Oneside: title.

=item * author_title

Author on the left, title on the right. Oneside: title

=item * section_subsection

Section on the left, subsection on the right. Oneside: section name

=item * chapter_section

Chapter on the left, section on the right. Oneside: chapter name

=item * title_section

Title on the left, section on the right. Oneside: section name

=item * title_chapter

Title on the left, chapter on the right. Oneside: chapter name

=back

=back

=cut

has cover      => (is => 'rw',
                   isa => \&check_filename,
                   default => sub { '' },
                  );

sub _check_coverwidth {
    # compare with  MuseHeader
    my $width = $_[0];
    die "$width should be a number" unless $width;
    if ($width =~ m/\A[01](\.[0-9][0-9]?)?\z/) {
        die "coverwidth should be a number minor or equal to 1"
          unless ($width <= 1 && $width > 0);
    }
    else {
        die "coverwidth $width should be a number minor or equal to 1"
    }
}

has coverwidth => (is => 'rw',
                   isa => \&_check_coverwidth,
                   default => sub { 1 });

has nocoverpage => (is => 'rw', isa => Bool, default => sub { 0 });
has notoc       => (is => 'rw', isa => Bool, default => sub { 0 });
has nofinalpage => (is => 'rw', isa => Bool, default => sub { 0 });
has impressum => (is => 'rw', isa => Bool, default => sub { 0 });
has sansfontsections => (is => 'rw', isa => Bool, default => sub { 0 });

sub all_headings {
    my @headings = (
                    {
                     name => '0',
                     desc => 'None',
                    },
                    {
                     name => 'title_subtitle',
                     desc => 'Title and subtitle. If one side document: title.',
                    },
                    {
                     name => 'author_title',
                     desc => 'Author and title. If one side document: title.',
                    },
                    {
                     name => 'chapter_section',
                     desc => 'Chapter and section. If one side document: chapter.',
                    },
                    {
                     name => 'section_subsection',
                     desc => 'Section and subsection. If one side document: section.',
                    },
                    {
                     name => 'title_chapter',
                     desc => 'Title and chapter. If one side document: chapter.',
                    },
                    {
                     name => 'title_section',
                     desc => 'Title and section.  If one side document: section.',
                    },
                    {
                     name => '',
                     desc => '',
                    },
                    {
                     name => 1,
                     desc => '',
                    },
                   );
    return @headings;
}


has headings    => (is => 'rw',
                    isa => Enum[ map { $_->{name} } __PACKAGE__->all_headings ],
                    default => sub { 0 });


=head2 Slides

=over 4

=item * beamertheme

The theme to use with beamer, if and when the slides are produced. See
the beamer manual or L<https://www.hartwork.org/beamer-theme-matrix/>.
Defaults to the default one.

=item * beamercolortheme

Same as above, but for the color theme. Defaults to "dove" (b/w theme,
can't see the default purple).

=back

=cut

sub beamer_themes {
    my @themes = (qw/default
                     Bergen
                     Boadilla
                     Madrid
                     AnnArbor
                     CambridgeUS
                     EastLansing
                     Pittsburgh
                     Rochester
                     Antibes
                     JuanLesPins
                     Montpellier
                     Berkeley
                     PaloAlto
                     Goettingen
                     Marburg
                     Hannover
                     Berlin
                     Ilmenau
                     Dresden
                     Darmstadt
                     Frankfurt
                     Singapore
                     Szeged
                     Copenhagen
                     Luebeck
                     Malmoe
                     Warsaw/);
    return @themes;
}

sub default_beamertheme {
    return 'default';
}

has beamertheme => (is => 'rw',
                    isa => Enum[ __PACKAGE__->beamer_themes ],
                    default => sub { __PACKAGE__->default_beamertheme });

sub beamer_colorthemes {
    my @themes = (qw/default
                     albatross
                     beetle
                     crane
                     dove
                     fly
                     monarca
                     seagull
                     wolverine
                     beaver
                     spruce
                     lily
                     orchid
                     rose
                     whale
                     seahorse
                     dolphin/);
    return @themes;
}

sub default_beamercolortheme {
    return 'dove';
}

has beamercolortheme => (is => 'rw',
                         isa => Enum[ __PACKAGE__->beamer_colorthemes ],
                         default => sub { __PACKAGE__->default_beamercolortheme });

=head1 METHODS

=head2 paging

This merges C<oneside> and C<twoside>. If both or none
are set, defaults to C<oneside>.

=head2 tex_papersize

The real name of the papersize, unaliased (so, e.g. C<half-a4> will be
C<a5>).

=head2 config_setters

The list of the values which should be passed to the constructor

=head2 config_output

Return a validated hashref of the options. This is basically the
purpose of this module.

=cut

sub paging {
    my $self = shift;
    my $default = 'oneside';
    if ($self->twoside && $self->oneside) {
        return $default;
    }
    if ($self->twoside) {
        return 'twoside';
    }
    else {
        return $default;
    }
}

sub config_setters {
    return (qw/papersize bcor division oneside twoside
               mainfont sansfont monofont fontsize
               sitename siteslogan site logo
               headings
               cover coverwidth nocoverpage notoc
               nofinalpage
               impressum sansfontsections
               opening beamertheme beamercolortheme/);
}

sub config_output {
    my $self = shift;
    my %out = (
               paging => $self->paging,
              );
    my %replace = (papersize => 'tex_papersize');
    foreach my $method ($self->config_setters) {
        if (my $alias = $replace{$method}) {
            $out{$method} = $self->$alias;
        }
        elsif ($method eq 'headings') {
            # here we pass an hashref for Template::Tiny if there is a value
            if (my $value = $self->headings) {
                if ($value eq '1') {
                    $value = 'author_title';
                }
                $out{headings} = { $value => 1 };
            }
        }
        else {
            $out{$method} = $self->$method;
        }
    }
    return \%out;
}

sub show_options {
    Pod::Usage::pod2usage({ -sections => [qw(ACCESSORS/Paper
                                             ACCESSORS/Fonts
                                             ACCESSORS/Colophon
                                             ACCESSORS/Cover
                                             ACCESSORS/Slides
                                           )],
                            -input => __FILE__,
                            -verbose => 99,
                            -message => "Template extra options to use with --extra option_name=value\n",
                            -exitval => 'NOEXIT' });
}

=head2 Available fonts listing

They return a list of hashrefs, with two keys, C<name> and C<desc>.
The first is the system font name, the second is the description. They
can be called on the class.

=over 4

=item sans_fonts

=item mono_fonts

=item serif_fonts

=item all_fonts

=item all_fontsizes

=back

=head2 Themes listing

The following methods can be called on the class and return lists with
the available Beamer themes and color themes:

=over 4

=item beamer_colorthemes

=item beamer_themes

=back

=head2 Headings style listing

=over 4

=item all_headings

Return a list of hashrefs with C<name> and C<desc>. Legacy options
have an empty description.

=back

=head2 Defaults fonts and themes

=over 4

=item default_mainfont

=item default_sansfont

=item default_monofont

=item default_beamertheme

=item default_beamercolortheme

=back

=head2 Help

=head3 show_options

Print out the relevant stanza of the POD.

=cut

=head1 INTERNALS

=head2 check_filename($filename)

Return true if the path is absolute (and looks like a pdf/jpg/png
file) or if it's a bare filename, even without extension.

=cut

1;

