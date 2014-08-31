use strict;
use Irssi 20020101.0250 ();
use vars qw($VERSION %IRSSI); 
use YAML::Syck;

$VERSION = "3";
%IRSSI = (
		authors     => "Timo Sirainen, Ian Peters, David Leadbeater, InitHello",
		contact		=> "tss\@iki.fi", 
		name        => "Nick Color",
		description => "assign a different color for each nick",
		license		=> "Public Domain",
		url			=> "http://irssi.org/",
		changed		=> "2002-03-04T22:47+0100"
);

Irssi::theme_register([
	'pubmsg_hilight', '{pubmsghinick $0 $3 $1}$2'
]);

my %saved_colors;
my %session_colors;

my %colors = (BLUE => '%B', green => '%g', GREEN => '%G', red => '%r', RED => '%R',
			  yellow => '%y', cyan => '%c', CYAN => '%C', magenta => '%m', MAGENTA => '%M',
			  YELLOW => '%Y');

# Additional colors that don't look good in my theme.
#$colors{blue} = '%b';
#$colors{white} = '%w';
#$colors{WHITE} = '%W';

sub load_colors {
	%saved_colors = LoadFile("$ENV{HOME}/.irssi/colors.yml");
}

sub save_colors {
	DumpFile("$ENV{HOME}/.irssi/colors.yml", %saved_colors);
}

# If someone we've colored (either through the saved colors, or the hash
# function) changes their nick, we'd like to keep the same color associated
# with them (but only in the session_colors, ie a temporary mapping).

sub sig_nick {
	my ($server, $newnick, $nick, $address) = @_;
	my $color;
	
	$newnick = substr ($newnick, 1) if ($newnick =~ /^:/);
	
	if ($color = $saved_colors{$nick}) {
		$session_colors{$newnick} = $color;
	} 
	elsif ($color = $session_colors{$nick}) {
		$session_colors{$newnick} = $color;
	}
}

# This gave reasonable distribution values when run across
# /usr/share/dict/words

sub simple_hash {
	my ($string) = @_;
	chomp $string;
	my @chars = split //, $string;
	my $counter;
	my @names = keys %colors;

	foreach my $char (@chars) {
		$counter += ord $char;
	}

	$counter = $names[$counter % $#names];

	return $counter;
}

# FIXME: breaks /HILIGHT etc.
sub sig_public {
#	Irssi::print Dumper(\@_);
	my ($Server, $msg, $nick, $address, $target) = @_;
	my $identity = "$nick!$address";
	my $chanrec = $Server->channel_find($target);
	return if not $chanrec;
	my $nickrec = $chanrec->nick_find($nick);
	return if not $nickrec;
	my $nickmode = $nickrec->{op} ? "@" : $nickrec->{voice} ? "+" : "";

	# Has the user assigned this nick a color?
	my $color = $saved_colors{$nick};

	# Have -we- already assigned this nick a color?
	if (!$color) {
		$color = $session_colors{$nick};
	}

	# Let's assign this nick a color
	if (!$color) {
		$color = simple_hash $identity;
		$session_colors{$nick} = $color;
	}
	
	$Server->command(sprintf '/^format pubmsg {pubmsgnick $2 {pubnick %s$0}}$1', $colors{$color});
}

sub sig_public_action {
	my ($Server, $msg, $nick, $address, $target) = @_;
	my $identity = "$nick!$address";
	my $chanrec = $Server->channel_find($target);
	return if not $chanrec;
	my $nickrec = $chanrec->nick_find($nick);
	return if not $nickrec;
	my $nickmode = $nickrec->{op} ? "@" : $nickrec->{voice} ? "+" : "";

	# Has the user assigned this nick a color?
	my $color = $saved_colors{$nick};

	# Have -we- already assigned this nick a color?
	if (!$color) {
		$color = $session_colors{$nick};
	}

	# Let's assign this nick a color
	if (!$color) {
		$color = simple_hash $address;
		$session_colors{$nick} = $color;
	}
	
	$Server->command(sprintf '/^format action_public {pubaction %s$0}$1', $colors{$color});
}

sub cmd_color {
	my ($data, $server, $witem) = @_;
	my ($op, $nick, $color) = split " ", $data;

	$op = lc $op;
	my @validcolors = keys %colors;

	if (!$op) {
		Irssi::print ("No operation given (save/set/clear/list/preview)");
	}
	elsif ($op eq "save") {
		save_colors;
	}
	elsif ($op eq "set") {
		if (!$nick) {
			Irssi::print ("Nick not given");
		}
		elsif (!$color) {
			Irssi::print ("Color not given");
		}
		elsif (!(grep $_ eq $color, @validcolors)) {
			Irssi::print ("Invalid color. Valid colors are: " . join ', ', map { $colors{$_} . $_ . '%N' } sort(keys %colors));
		}
		else {
			$saved_colors{$nick} = $color;
		}
	} 
	elsif ($op eq "clear") {
		if (!$nick) {
			Irssi::print ("Nick not given");
		}
		else {
			delete ($saved_colors{$nick});
		}
	}
	elsif ($op eq "list") {
		Irssi::print ("\nSaved Colors:");
		foreach my $nick (keys %saved_colors) {
			Irssi::print(chr (3) . "$saved_colors{$nick}$nick" . chr (3) . "1 ($saved_colors{$nick})");
		}
	}
	elsif ($op eq "preview") {
		Irssi::print ("\nAvailable colors:");
		foreach my $i (keys %colors) {
			Irssi::print ("$colors{$i}" . " $i");
		}
	}
}

if (-e "$ENV{HOME}/.irssi/colors.yml") {
	load_colors;
}

Irssi::command_bind('color', 'cmd_color');

Irssi::signal_add('message public', 'sig_public');
Irssi::signal_add('message irc action', 'sig_public_action');
Irssi::signal_add('event nick', 'sig_nick');
Irssi::signal_add('setup saved', 'save_colors');
