package Games::Mines;

require 5.005_62;
use strict;
use warnings;
use Carp qw(verbose);

our $VERSION = sprintf("%01d.%02d.%02d", 0,q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);
=head1 NAME

Games::Mines;

=head1 SYNOPSIS

    require Game::Mines;

    # get new 30x40 mine field with 50 mines
    my($game) = Game::Mines->new(30,40,50); 

    # fill with mines, except at the four corners
    $game->fill_mines([0,0],[0,40],[30,0],[30,40]);

=head1 DESCRIPTION

This module is the basis for mine finding game. It contains the basic
methods necessary for a game. 

=cut

# Preloaded methods go here.

# internal:
#       - nothing
#   1-8 - number of mines around that square
#   *   - mine (steped on )
# visible:
#     . - unsteped
#     F - unstepped and flaged
#       - stepped

# 'unstepped' => '.',
# 'flagged'   => 'F',
# 'mine'      => '*',
# 'wrong'     => 'X',
# 'blank'     => ' ',


=head2 Class and object Methods


=over 5

=item $Class->new;

The new method creates a new mine field object. It takes three
arguments: The width of the field, the height of the field, and the
number of mines.  

=cut

sub new {
    my($class) =shift;
    
    my($width,$height,$count,) = @_;
    
    my($mine_field) = {
	'on'      => 0,
	'field'  => undef(),

	# mine count
	'count' => $count,
	'flags' => 0,
	'unknown' => 0,
	
	# game information text
	'why'          => 'not started',
	'running-text' => 'Running',
	'win-text'     => 'You Win!!!',
	'lose-text'    => 'KABOOOOOM!!!',

	# extra field to hold other field information
	'extra'=>{}
    };
    
    bless $mine_field, $class;
    
    $mine_field->_reset($width,$height);
    
    return $mine_field;
}

=item $obj->width

Returns the width of a mine field.

=cut

sub width {
    my($mine_field) = shift;
    return $#{$mine_field->{field} };
}

=item $obj->height

Returns the height of the mine field.

=cut

sub height {
    my($mine_field) = shift;
    return $#{$mine_field->{field}[0]};
}

=item $obj->running

Returns a boolean that says if game play is still possible. Returns
false after field is create, but before fill_mines is called. Also
returns false if the whole field has been solved, or a mine has
been stepped on. 

=cut

sub running {
    my($mine_field) = shift;
    my($test);
    my($w,$h);
    
    if($mine_field->found_all && $mine_field->{on}) {
	$mine_field->{on}=0;
	$mine_field->{why} =  $mine_field->{'win-text'};
    }
    return $mine_field->{on};
}

=item $obj->fill_mines

Randomly fills the field with mines. It takes any number of arguments,
which should be array references to a pair of coordinates of where
I<NOT> to put a mine. 

=cut

sub fill_mines {
    my($mine_field) = shift;
    my(@exclude) = @_;
    my($i,$w,$h);
    
    $mine_field->{why} = $mine_field->{'running-text'};

    for($i = 1; $i<=$mine_field->{count}; $i++) {
	$w = int( rand( $mine_field->width()  +1 ) );
	$h = int( rand( $mine_field->height() +1 ) );
	redo if( $mine_field->_at($w,$h) eq '*');

	redo if( grep { ($_->[0] == $w) && ($_->[1] == $h)} @exclude);

	$mine_field->{field}[$w][$h]{contains} = '*';
	$mine_field->_fill_count($w,$h);
    }
}

=item $obj->at($col,$row)

Returns what is visible at the coordinates given. Takes two arguments:
the col and the row coordinates.

=cut

sub at {
    my($mine_field) = shift;
    my($w,$h) = $mine_field->_limit(@_);
    
    if($mine_field->shown($w,$h)) {
	return $mine_field->_at($w,$h);
    }
    return $mine_field->{field}[$w][$h]{visibility};
}

=item $obj->hidden($col,$row)

Returns a boolean saying if the position has not been stepped on and
exposed. Takes two arguments: the col and the row coordinates.

=cut

sub hidden {
    my($mine_field) = shift;
    my($w,$h) = $mine_field->_limit(@_);
    return $mine_field->{field}[$w][$h]{visibility};
}

=item $obj->shown($col,$row)

Returns a boolean saying if the position has been stepped on and
exposed. Takes two arguments: the col and the row coordinates.

=cut

sub shown {
    my($mine_field) = shift;
    my($w,$h) = $mine_field->_limit(@_);
    #print STDERR "getting value w,h: ", $w,", ",$h,"\n";
    return not($mine_field->{field}[$w][$h]{visibility});
}


=item $obj->step($col,$row)

Steps on a particular coordinates, exposing what was underneath. Takes
two arguments: the col and the row coordinates. Note that if the
particular field is blank, indicating it has no mines in any of
the surrounding squares, it will also automatically step on those
squares as well.

=cut

sub step {
    my($mine_field) = shift;
    
    my($w,$h) = $mine_field->_limit(@_);

    return if( $mine_field->shown($w,$h) );
    
    if($mine_field->_at($w,$h) eq '*' ) {
	$mine_field->{field}[$w][$h]{visibility} = 'X';
	$mine_field->{on} = 0;
	$mine_field->{why}= $mine_field->{'lose-text'};
	return $mine_field;
    }
    
    $mine_field->{field}[$w][$h]{visibility} = '';
    $mine_field->{unknown}--;

    if(	$mine_field->_at($w,$h) eq ' ') {
    $mine_field->_neighbors($w, $h, 
			   sub {
			       my($mine_field) = shift;
			       my($w,$h)=$mine_field->_limit(@_);
			       return if( $mine_field->shown($w,$h) );
			       $mine_field->step( $w, $h );
			   }
                          );
}

=item $obj->flag($col,$row)

Place a flag on a particular unexposed square. Takes two arguments:
the col and the row coordinates.

=cut

sub flag {
    my($mine_field) = shift;
    
    my($w,$h) = $mine_field->_limit(@_);
    
    return if( $mine_field->shown($w,$h) );
    return if( $mine_field->flagged($w,$h) );
    $mine_field->{field}[$w][$h]{visibility} = 'F';
    $mine_field->{flags}++;
    $mine_field->{unknown}--;
}

=item $obj->unflag($col,$row)

Removes a flag from a particular unexposed square. Takes two
arguments: the col and the row coordinates. 

=cut

sub unflag {
    my($mine_field) = shift;
    
    my($w,$h) = $mine_field->_limit(@_);
    
    return if( $mine_field->shown($w,$h) );
    return if( not $mine_field->flagged($w,$h) );
    $mine_field->{field}[$w][$h]{visibility} = '.';
    $mine_field->{flags}--;
    $mine_field->{unknown}++;
}


=item $obj->flagged($col,$row)

Returners a boolean based on whether a flag has been placed on a
particular square.  Takes two arguments: the col and the row
coordinates. 

=cut

sub flagged {
    my($mine_field) = shift;
    
    my($w,$h) = $mine_field->_limit(@_);
    
    return if( $mine_field->shown($w,$h) );
    #print STDERR Dumper($mine_field->{field}[$w][$h]{visibility}, $h,$w);
    return $mine_field->{field}[$w][$h]{visibility} eq 'F';
}


=item $obj->found_all

Returners a boolean saying whether all mines have been found or not. 

=cut

sub found_all {
    my($mine_field) = shift;
    
    my($w,$h);
    
    #if(     $mine_field->{flags} == $mine_field->{count} &&
    #$mine_field->{unknown} == 0 ) {
	
    if(     $mine_field->{flags}+$mine_field->{unknown} 
	    == $mine_field->{count} ) {
	
	for($w = 0; $w <= $mine_field->width(); $w++) {
	    for($h = 0; $h<= $mine_field->height(); $h++) {
		if(     $mine_field->at($w,$h) eq 'F' &&
			not ($mine_field->_at($w,$h) eq '*')){
		    return;
		}
	    }
	}
	return 1;
    }
    
    return;
}

=begin for developers

=item $obj->_limit($col,$row)

An internal check to make sure the coordinates given are actually on
the field itself. Will truncate to the field limits and values
that are no.

=cut

sub _limit {
    my($mine_field) = shift;
    my($w,$h,@rest)=@_;

    if( $w<0) {
	$w =0;
    }
    elsif(  $w >= $mine_field->width() ) {
	$w = $mine_field->width();
    }
    
    if($h<0) {
	$h=0;
    }
    elsif( $h >= $mine_field->height() ) {
	$h = $mine_field->height();
    }

    return ($w,$h,@rest);
}


=item $obj->_neighbors($col,$row,\&sub)

An internal method, that applies &sub to each of the surrounding
squares of the given coordinates. Takes three arguments: The width
of the column and row of the coordinates, and a sub reference to
be applied to the surrounding squares.

=cut

# I don't like this. I'm going to replae this as soon as 
# I find a better way to do it.
sub _neighbors {
    my($mine_field) = shift;
    
    my($w,$h,$op) = $mine_field->_limit(@_);
    
    foreach my $dw (-1..1) {
	next if( $w+$dw <0);
	next if( $w+$dw > $mine_field->width());
	    
	    foreach my $dh (-1 ..1) {
		next if($dw ==0 && $dh==0);

		next if( $h+$dh <0);
		next if( $h+$dh > $mine_field->height());
		
		$mine_field->$op( $w+$dw, $h+$dh );
	    }
	}
    }
}

=item $obj->_reset($width,$height)

This is the method that actually sets up the whole data structure that
represents the field, and fills it with the default values. Takes
two arguments: The width of the column and row of the
coordinates.

=cut

sub _reset {
    my($mine_field) = shift;
    
    my($width,$height) = @_;
    my($w,$h);
    
    $mine_field->{on} =  1;
    
    $mine_field->{field} = [ undef() x $width ];
    for( $w = 0; $w <= $width-1; $w++) {
	$mine_field->{field}[$w] = [ undef() x $height ];
	
	for( $h = 0; $h<= $height-1; $h++) {
	    $mine_field->{field}[$w][$h] =  {
		contains => ' ',
		visibility  => '.',
		};
	}
    }
    $mine_field->{unknown} = $w * $h;
    return;
}


=item $obj->_fill_count($col,$row)

Used to add to the numbers surrounding a mine. Normally called from
fill_mines to fill the field with the mine counts. Takes two
coordinates, the $col and $row coordinates. Assumes there is a
mine at the center.

=cut

sub _fill_count {
    my($mine_field) = shift;
    
    my($w,$h)=$mine_field->_limit(@_);
    
    #print STDERR "setting acounts around : ",$w, ", ", $h,"\n";
    
    $mine_field->_neighbors($w, $h, 
			   sub {
			       my($mine_field) = shift;
			       my($w,$h)=@_;
			       return if( $mine_field->_at($w, $h) eq '*');
			       
			       $mine_field->{field}[ $w ][ $h ]{contains}++;
			   }
                           );
}

=item $obj->_at($col,$row)

Returns what is underneath at the coordinates given, regardless of
weather it is uncovered or not. Takes two arguments: the col and
the row coordinates.

=cut

sub _at {
    my($mine_field) = shift;
    my($w,$h) = $mine_field->_limit(@_);
    return $mine_field->{field}[$w][$h]{contains};
}

=end for developers

=back

=head1 AUTHOR

Martyn W. Peck <mwp@mwpnet.com>

=head1 BUGS

None known. But if you find any, let me know.

=head1 COPYRIGHT

Copyright 2003, Martyn Peck. All Rights Reserves.

This program is free software. You may copy or redistribute 
it under the same terms as Perl itself.

=cut

1;

