use strict;
use Irssi;
use Irssi::Irc;
use DateTime;
use Data::Dumper;
use YAML::Syck;

$YAML::Syck::ImplicitUnicode = 1;

my $VERSION = "2.0";
my %IRSSI = (
    authors     => 'InitHello',
    contact     => 'inithello@gmail.com',
    name        => 'duration.pl',
    description => 'Show time elapsed since date.',
    license     => 'BeerWare 2.0 or later',
    url         => 'http://github.com/InitHello/irssi-scripts',
);

my $conf = '$ENV{HOME}/.irssi/durations.yml';
my %durations;
load_durations;

sub plur {
    my ($number, undef) = @_;
    if ($number == 1) {
        return '';
    } 
    return 's';
}

sub show_time {
    my ($server, $window, $label, %starttime) = @_;
    my $duration;
    my @durr;
    my $then = new DateTime(year => $starttime{year}, 
                            month => $starttime{month}, 
                            day => $starttime{day}, 
                            hour => $starttime{hour}, 
                            minute => $starttime{minute}, 
                            second => $starttime{second}, 
                            time_zone => Irssi::settings_get_str('dates_timezone'));
    my $dur = DateTime->now() - $then;
    if ($dur->{months} >= 12) { $dur->{years} = int($dur->{months} / 12); $dur->subtract(months => $dur->{years} * 12); }
    if ($dur->{minutes} >= 60) { $dur->{hours} = int($dur->{minutes} / 60); $dur->subtract(minutes => $dur->{hours} * 60); }
    my ($years, $months, $days, $hours, $minutes, $seconds) = ($dur->{years}, $dur->{months}, $dur->{days}, $dur->{hours}, $dur->{minutes}, $dur->{seconds});
    if ($years > 0) {
        push @durr, "$years year" . plur($years);
    }
    if ($months > 0) {
        push @durr, "$months month" . plur($months);
    }
    if ($days > 0) {
        push @durr, "$days day" . plur($days);
    }
    if ($hours > 0) {
        push @durr, "$hours hour" . plur($hours);
    }
    if ($minutes > 0) {
        push @durr, "$minutes minute" . plur($minutes);
    }
    if ($seconds > 0) {
        push @durr, "$seconds second" . plur($seconds);
    }
    my $durstring;
    if (scalar(@durr) == 2) {
        $durstring = $durr[0] . ' and ' . $durr[1];
    }
    elsif (scalar(@durr) == 1) {
        $durstring = $durr[0];
    }
    else {
        my $last = pop @durr;
        push @durr, "and $last";
        $durstring = join(', ', @durr);
    }
    my $duration = "$label: $durstring.";
    if (defined($window) && ($window->{type} eq 'QUERY' || $window->{type} eq 'CHANNEL')) {
        $window->print($duration);
    }
    else {
        Irssi::print($duration);
    }
}

sub add_duration {
    my ($data, $server, $window, $label) = @_;
    Irssi::print($label);
    return if defined($durations{$label});
    my $now = DateTime->now(time_zone => Irssi::settings_get_str('dates_timezone'));
    my %newstamp;
    $newstamp{year} = $now->year();
    $newstamp{month} = $now->month();
    $newstamp{day} = $now->day();
    $newstamp{hour} = $now->hour();
    $newstamp{minute} = $now->minute();
    $newstamp{second} = $now->second();
    Irssi::print("Timestamp added: $label => " . join('-', $newstamp{year}, $newstamp{month}, $newstamp{day}, $newstamp{hour}, $newstamp{minute}, $newstamp{second}));
    %{$durations{$label}} = %newstamp;
    save_durations();
}

sub duration {
    my ($data, $server, $window) = @_;
    my @args = @_;
    my ($op, $arg, undef) = split / /, $data;
    if ($op eq 'show') {
        push(@args, $arg);
        show_duration(@args);
    }
    elsif ($op eq 'save') {
        save_durations();
    }
    elsif ($op eq 'add') {
        push (@args, $arg);
        add_duration(@args);
    }
    elsif ($op eq 'list') {
        list_durations(@args);
    }
    elsif ($op eq 'load') {
        load_durations();
    }
}

sub show_duration {
    my ($data, $server, $window, $label) = @_;
    if (!defined($durations{$label})) {
        Irssi:print("No datestamp defined for $label.");
        return;
    }
    my %dt = %{$durations{$label}};
    show_time($server, $window, $label, %dt);
}

sub save_durations {
    if (-f $conf) {
        DumpFile($conf, %durations);
    }
}

sub list_durations {
    my ($data, $server, $window) = @_;
    for my $label (keys(%durations)) {
        my %dt = %{$durations{$label}};
        show_time($server, $window, $label, %dt);
    }
}

sub load_durations {
    if (-f $conf) {
        %durations = LoadFile($conf);
    }
}

Irssi::command_bind('dates', \&duration); # show add list load
Irssi::signal_add('setup saved', 'save_durations');
Irssi::signal_add('setup reread', 'load_durations');
Irssi::settings_add_str('misc', 'dates_timezone', 'America/New_York');
