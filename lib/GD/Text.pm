# $Id: Text.pm,v 1.14 2000/01/09 09:50:17 mgjv Exp $

package GD::Text;

$GD::Text::VERSION = '0.65';

=head1 NAME

GD::Text - Text utilities for use with GD

=head1 SYNOPSIS

  use GD;
  use GD::Text;

  my $gd_text = GD::Text->new() or die GD::Text::error();
  $gd_text->set_font('funny.ttf', 12) or die $gd_text->error;
  $gd_text->set_font(gdTinyFont);
  $gd_text->set_font(GD::Font::Tiny);
  ...
  $gd_text->set_text($string);
  my ($w, $h) = $gd_text->get('width', 'height');

  if ($gd_text->is_ttf)
  {
	  ...
  }

Or alternatively

  my $gd_text = GD::Text->new(
        text => 'Some text',
        font => 'funny.ttf',
        ptsize => 14,
    );

=head1 DESCRIPTION

This module provides a font-independent way of dealing with text in
GD, for use with the GD::Text::* modules and GD::Graph.

=head1 NOTES

As with all Modules for Perl: Please stick to using the interface. If
you try to fiddle too much with knowledge of the internals of this
module, you could get burned. I may change them at any time.

You can only use TrueType fonts with version of GD > 1.20, and then
only if compiled with support for this. If you attempt to do it
anyway, you will get errors.

=head1 METHODS

=cut

use strict;

use GD;
use Carp;

use vars qw($FONT_PATH);
BEGIN
{
	$FONT_PATH =  $ENV{FONT_PATH} || $ENV{TTF_FONT_PATH};
}

my $ERROR;

=head2 GD::Text->new( attrib => value, ... )

Create a new object. See the C<set()> method for attributes.

=cut

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
	my $self = { 
			type   => 'builtin',
			font   => gdSmallFont,
			ptsize => 10,
		};
    bless $self => $class;
	$self->set(@_) or return;
    return $self
}

=head2 GD::Text::error() or $gd_text->error();

Return the last error that occured in the class. This may be
imperfect.

=cut

# XXX This sucks! fix it
sub error { $ERROR };

sub _set_error { $ERROR = shift };

=head2 $gd_text->set_font( font, size )

Set the font to use for this string. The arguments are either a GD
builtin font (like gdSmallFont or GD::Font->Small) or the name of a
TrueType font file and the size of the font to use. See also
L<"font_path">. As an extra, the first argument can be a reference to an
array of fonts. The first font from the array that can be found will be
used. This allows you to do something like

  $gd_text->font_path(
    '/usr/share/fonts:/usr/local/share/fonts');
  $gd_text->set_font(
    ['verdana.ttf', 'arial.ttf', gdMediumBoldFont], 14);

if you'd prefer verdana to be used, would be satisfied with arial, but
if none of that is available just want to make sure you can fall
back on something that will be available.

Returns true on success, false on error.

=cut

sub set_font
{
	my $self = shift;
	my $fonts = shift;
	my $size = shift;

	# Make sure we have a reference to an array
	$fonts = [$fonts] unless ref($fonts) eq 'ARRAY';

	foreach my $font (@{$fonts})
	{
		my $rc = ref($font) && $font->isa('GD::Font') ?
			$self->_set_builtin_font($font) :
			$self->_set_TTF_font($font, $size) ;
		return $rc if $rc;
	}

	return;
}

sub _set_builtin_font
{
	my $self = shift;
	my $font = shift;

	$self->{type}   = 'builtin';
	$self->{font}   = $font;
	$self->{ptsize} = 0;
	$self->_recalc();
	return 1;
}

# XXX Maybe use File::Path to do most of this work?
sub _find_TTF
{
	my $font = shift || return;
	local $FONT_PATH = $FONT_PATH;

	# XXX The following is too risky, and rigid
	#$font = "$font.ttf" unless $font =~ /\.ttf/i;

	# If we don't have a font path set, we just return what we got.
	defined $FONT_PATH or return $font;

	# Is this an absolute path to the font file?
	substr($font, 0, 1) eq '/' and return $font; # unix
	#$font =~ m#^[A-Z]:[\\/]#   and return $font; # dos
	# mac?
	# vms?
	# os2?
	# amiga?

	# We have a font path, and a relative path to the font file. Let's
	# see if the current directory is in the font path. If not, put it
	# at the front.
	$FONT_PATH = ".:$FONT_PATH"
		unless $FONT_PATH eq '.'    || $FONT_PATH =~ /^\.:/ ||
			   $FONT_PATH =~ /:\.$/ || $FONT_PATH =~ /:\.:/;

	# Let's search for it
	# What should the separator be for the various platforms? ':' for
	# unix, ';' for DOS/Win, and the rest?
	for my $path (split /:/, $FONT_PATH)
	{
		my $file = "$path/$font";
		-f $file and return $file;
	}

	return;
}

sub _set_TTF_font
{
	my $self = shift;
	my $font = shift;
	my $size = shift;

	$ERROR = "TrueType fonts require a point size", return 
		unless (defined $size && $size > 0);
	
	return unless $self->can_do_ttf;

	my $font_file = _find_TTF($font) or 
		$ERROR = "Cannot find TTF font: $font", return;

	# Check that the font exists and is a real TTF font
	my @bb = GD::Image->stringTTF(0, $font_file, $size, 0, 0, 0, "foo");
	$ERROR = $@, return unless @bb;

	$self->{type}   = 'ttf';
	$self->{font}   = $font_file;
	$self->{ptsize} = $size;
	$self->_recalc();
	return 1;
}

=head2 $gd_text->set_text('some text')

Set the text to operate on. 
Returns true on success and false on error.

=cut

sub set_text
{
	my $self = shift;
	my $text = shift;

	$ERROR = "No text set", return unless defined $text;

	$self->{text} = $text;
	$self->_recalc_width();
}

=head2 $gd_text->set( attrib => value, ... )

The set method provides a convenience replacement for the various other
C<set_xxx()> methods. Valid attributes are:

=over 4

=item text

The text to operate on, see also C<set_text()>.

=item font, ptsize

The font to use and the point size. The point size is only used for
TrueType fonts. Also see C<set_font()>.

=back

Returns true on success, false on any error, even if it was partially
successful. When an error is returned, no guarantees are given about
the correctness of the attributes.

=cut

# We use this to save a few CPU cycles
my $recalc = 1;

sub set
{
	my $self = shift;
	$ERROR = "Incorrect attribute list", return if @_%2;
	my %args = @_;

	$ERROR = '';

	$recalc = 0;
	foreach (keys %args)
	{
		/^text$/i   and do {
			$self->set_text($args{$_});
			next;
		};
		/^font$/i   and do {
			$self->set_font($args{$_}, $self->{ptsize}) or return;
			next;
		};
		/^ptsize$/i and do {
			$self->{ptsize} = $args{$_};
			next;
		};
		$ERROR .= " '$_'";
	}
	$recalc = 1;
	$self->_recalc();

	if ($ERROR ne '')
	{
		$ERROR = "Illegal attribute(s):$ERROR";
		return;
	}

	return 1;
}

=head2 $gd_text->get( attrib, ... )

Get the value of an attribute.
Return a list of the attribute values in list context, and the value of
the first attribute in scalar context.

The attributes that can be retrieved are all the ones that can be set,
and:

=over 4

=item width, height

The width (height) of the string in pixels

=item space

The width of a space in pixels

=item char_up, char_down

The number of pixels that a character can stick out above and below the
baseline. Note that this is only useful for TrueType fonts. For builtins
char_up is equal to height, and char_down is always 0.

=back

Note that some of these parameters (char_up, char_down and space) are
generic font properties, and not necessarily a property of the text
that is set.

=cut

sub get
{
	my $self = shift;
	my @wanted = map { $self->{$_} } @_;
	wantarray ? @wanted : $wanted[0];
}

=head2 $gd_text->width('string')

Return the length of a string in pixels, without changing the current
value of the text.  Returns the width of 'string' rendered in the
current font and size.  On failure, returns undef.

The use of this method is vaguely deprecated.

=cut

sub width
{
	my $self   = shift;
	my $string = shift;
	my $save   = $self->get('text');

	$self->set_text($string) or return;
	my $w = $self->get('width');
	$self->set_text($save);

	return $w;
}

# Here we do the real work. See the documentation for the get method to
# find out which attributes need to be set and/or reset

sub _recalc_width
{
	my $self = shift;

	return unless $recalc;
	return unless (defined $self->{text} && $self->{font});

	if ($self->is_builtin)
	{
		$self->{width} = $self->{font}->width() * length($self->{text});
	}
	elsif ($self->is_ttf)
	{
		my @bb1 = GD::Image->stringTTF(0, 
			$self->{font}, $self->{ptsize}, 0, 0, 0, $self->{text});
		$self->{width} = $bb1[2] - $bb1[0];
	}
	else
	{
		confess "Impossible error in GD::Text::_recalc.";
	}
}

my ($test_string, $space_string, $n_spaces); 

BEGIN
{
	# Build a string of all characters that are printable, and that are
	# not whitespace.
	eval {
		require POSIX; 
		import POSIX;
		$test_string = join '', grep isgraph($_), map chr($_), (0x00..0xFF);
	};

	if ($@)
	{
		# Most likely POSIX is not available.
		# Let's try to emulate isgraph(). This may be wrong at times.
		$test_string = join '', map chr($_), (0x21..0x7e, 0xa1..0xff);
	}

	$space_string = $test_string;

	# Put a space every 5 characters, and count how many there are
	$n_spaces = $space_string =~ s/(.{5})(.{5})/$1 $2/g;
}

sub _recalc
{
	my $self = shift;

	return unless $recalc;
	return unless $self->{font};

	if ($self->is_builtin)
	{
		$self->{height} =
		$self->{char_up} = $self->{font}->height();
		$self->{char_down} = 0;
		$self->{space} = $self->{font}->width();
	}
	elsif ($self->is_ttf)
	{
		my @bb1 = GD::Image->stringTTF(0, 
			$self->{font}, $self->{ptsize}, 0, 0, 0, $test_string)
				or return;
		my @bb2 = GD::Image->stringTTF(0, 
			$self->{font}, $self->{ptsize}, 0, 0, 0, $space_string);
		$self->{char_up} = -$bb1[7];
		$self->{char_down} = $bb1[1];
		$self->{height} = $self->{char_up} + $self->{char_down};
		# XXX Should we really round this?
		$self->{space} = sprintf "%.0f", 
			(($bb2[2]-$bb2[0]) - ($bb1[2]-$bb1[0]))/$n_spaces;
	}
	else
	{
		confess "Impossible error in GD::Text::_recalc.";
	}

	$self->_recalc_width() if $self->{text};

	return 1;
}

=head2 $gd_text->is_builtin

Returns true if the current object is based on a builtin GD font.

=cut

sub is_builtin
{
	my $self = shift; 
	return $self->{type} eq 'builtin';
}

=head2 $gd_text->is_ttf

Returns true if the current object is based on a TrueType font.

=cut

sub is_ttf
{
	my $self = shift; 
	return $self->{type} eq 'ttf';
}

=head2 $gd_text->can_do_ttf() or GD::Text->can_do_ttf()

Return true if this object can handle TTF fonts.

This depends on whether your version of GD is newer than 1.19 and
has TTF support compiled into it.

=cut

sub can_do_ttf
{
	my $proto = shift;

	# Just see whether there is a stringTTF method at all
	GD::Image->can('stringTTF') or return;

	# Let's check whether TTF support has been compiled in.  We don't
	# need to worry about providing a real font. The following will
	# always fail, but we'll check the message to see why it failed
	GD::Image->stringTTF(0, 'foo', 10, 0, 0, 0, 'foo');

	# Error message: libgd was not built with TrueType font support
	$@ =~ /TrueType font support/i and return;

	# Well.. It all seems to be fine
	return 1;
}

=head2 $gd_text->font_path(path_spec), GD::Text->font_path(path_spec)

This sets the font path for the I<class> (i.e. not just for the object).
The C<set_font> method will search this path to find the font specified
if it is a TrueType font. It should contain a colon separated list of
paths. The current directory is always searched first, unless '.' is
present in FONT_PATH. Examples: 

  GD::Text->font_path('/usr/ttfonts');

Any font name that is not an absolute path will first be looked for in
the current directory, and then in '/usr/ttfonts'.

  GD::Text->font_path('/usr/ttfonts:.:lib/fonts');

Any font name that is not an absolute path will first be looked for in
/usr/ttfonts, then in the current directory. and then in lib/fonts,
relative to the current directory.

  GD::Text->font_path(undef);

Font files are only looked for in the current directory.

FONT_PATH is initialised at module load time from the environment
variables FONT_PATH or, if that's not present, TTF_FONT_PATH.

Returns the value the font path is set to.

If called without arguments C<font_path> returns the current font path.

=cut

sub font_path
{
	my $proto = shift;
	if (@_)
	{
		$FONT_PATH = shift;
		if ($FONT_PATH)
		{
			# clean up a bit
			$FONT_PATH =~ s/^:+//;
			$FONT_PATH =~ s/:+$//;
		}
	}
	$FONT_PATH;
}

=head1 BUGS

This module has only been tested with anglo-centric 'normal' fonts and
encodings.  Fonts that have other characteristics may not work well.
If that happens, please let me know how to make this work better.

The font height gets estimated by building a string with all printable
characters that pass the POSIX::isgraph() test. If your system doesn't
have POSIX, I make an approximation that may be false for your system.

The whole font path thing works well on Unix, but probably not very well
on other OS's. This is only a problem if you try to use a font path. If
you don't use a font path, there should never be a problem. I will try
to expand this in the future, but only if there's a demand for it.
Suggestions welcome.

=head1 COPYRIGHT

copyright 1999
Martien Verbruggen (mgjv@comdyn.com.au)

=head1 SEE ALSO

GD(3), GD::Text::Wrap(3), GD::Text::Align(3)

=cut

1;
