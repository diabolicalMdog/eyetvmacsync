#!/usr/bin/perl

use warnings;
use strict;

#TODO make sure remote file is stable

my $user = 'username';

use Getopt::Long;
use Data::Dumper;

my $debug;
my $sim;
my $patternsFileName;
my $transferLogFileName;
my $localShowsDir;
my $localStagingDir;
my $remoteShowsDir;
my $remoteHost;
my $remoteUser;
my $bytesLeft;

my $ssh_exe = '/usr/bin/ssh';
my $ls_exe = '/bin/ls';
my $du_exe = '/usr/bin/du';
my $rm_exe = '/bin/rm';
my $tar_exe = '/usr/bin/tar';
my $rsync_exe = '/usr/bin/rsync';
my $echo_exe = '/bin/echo';
my $tnot_exe = "/Users/$user/bin/terminal-notifier-1.5.0//terminal-notifier.app/Contents/MacOS/terminal-notifier";
my $mv_exe = '/bin/mv';

sub main
{
	GetOptions("debug" => \$debug, "sim" => \$sim, "patterns-file=s" => \$patternsFileName, "transfer-log=s" => \$transferLogFileName, "local-shows-dir=s", \$localShowsDir, "local-staging-dir=s" => \$localStagingDir,  "remote-shows-dir=s", \$remoteShowsDir, "remote-host=s", \$remoteHost, "remote-user=s" => \$remoteUser, "ssh-exe" => \$ssh_exe, "bytes-left" => \$bytesLeft) or die "Getoptions!";

	usage("patterns-file must be defined!") unless defined $patternsFileName;
	usage("transfer-log must be defined!") unless defined $transferLogFileName;
	usage("local-shows-dir must be defined!") unless defined $localShowsDir;
	usage("local-staging-dir must be defined!") unless defined $localStagingDir;
	usage("remote-shows-dir must be defined!") unless defined $remoteShowsDir;
	usage("remote-host must be defined!") unless defined $remoteHost;
	usage("remote-user must be defined!") unless defined $remoteUser;

	$localShowsDir =~ s/\/*$//;
	$localStagingDir =~ s/\/*$//;
	$remoteShowsDir =~ s/\/*$//;

	die "local-shows-dir must exist ($localShowsDir)!" unless -d $localShowsDir;
	die "local-staging-dir must exist ($localStagingDir)!" unless -d $localStagingDir;

	my @patterns = @{get_list_from_file($patternsFileName)};

	my @transferredList = @{get_list_from_file($transferLogFileName)};
	my %transferred;

	foreach my $str (@transferredList)
	{
		$str =~ s/ *[0-9]*$//; 
		$transferred{$str} = 1;
	}

	$debug and print Dumper(@patterns);
	$debug and print Dumper(%transferred);

	my @remoteShows = `$ssh_exe $remoteUser\@$remoteHost $ls_exe -rt \\\"$remoteShowsDir\\\"`;
	die 'Problem with ssh retreiving remote show list!' if $?;
	chomp @remoteShows;

	my @candidates;

	foreach my $remoteShow (@remoteShows)
	{
		next unless $remoteShow =~ /\.eyetv$/;
		foreach my $pattern (@patterns)
		{
			if ($remoteShow =~ /$pattern/)
			{
				push @candidates, $remoteShow;
				$debug and print "$remoteShow DID match $pattern\n";
				last;
			}
			else
			{
				$debug and print "$remoteShow didn't match $pattern\n";
			}
		}
	}

	foreach my $candidate (@candidates)
	{
		if (exists $transferred{$candidate})
		{
			$debug and print "We already transferred $candidate\n";
		}
		else
		{
			migrate_show($candidate);
		}
	}
}

sub migrate_show
{
	my $remoteShow = shift;

	my $escapedRemoteShowsDir = escape_unix($remoteShowsDir);
	
	my $escapedRemoteShow = escape_unix($remoteShow);

	my $escapedLocalStagingDir = escape_unix($localStagingDir);

	my $escapedLocalShowsDir = escape_unix($localShowsDir);

	if ($sim)
	{
		print "SYSTEM $rsync_exe --partial -r $remoteUser\@$remoteHost:\"$escapedRemoteShowsDir/$escapedRemoteShow\" \"$escapedLocalStagingDir\"\n";
	}
	else
	{
		$debug and print "about to $rsync_exe --partial -r $remoteUser\@$remoteHost:\"$escapedRemoteShowsDir/$escapedRemoteShow\" \"$escapedLocalStagingDir\"\n";
		system("$rsync_exe --partial -r $remoteUser\@$remoteHost:\"$escapedRemoteShowsDir/$escapedRemoteShow\" \"$escapedLocalStagingDir\"");
	}

	if ($?)
	{
		die "rsync returned some kind of error!\n";
	}
	else
	{
		if ($sim)
		{
			print "SYSTEM $mv_exe $escapedLocalStagingDir/$escapedRemoteShow $escapedLocalShowsDir\n";
		}
		else
		{
			$debug and print "rsync went well, executing $mv_exe $escapedLocalStagingDir/$escapedRemoteShow $escapedLocalShowsDir\n";
			system("$mv_exe $escapedLocalStagingDir/$escapedRemoteShow $escapedLocalShowsDir");
		}

		if ($?)
		{
			die "mv didn't work out!";
		}

		add_to_log("$remoteShow");
	}
}

sub get_list_from_file
{
	my $fileName = shift;
	my @list;
	open FILE, "<$fileName" or die "could not open $fileName for reading!";
	while (<FILE>)
	{
		chomp;
		push @list, $_;
	}

	close FILE or die "could not close $fileName!";
	return \@list;
}

sub add_to_log
{
	my $show = shift;
	my $secs = time();
	if ($sim)
	{
		print "SYSTEM $echo_exe \"$show\" $secs >> \"$transferLogFileName\"\n";
	}
	else
	{
		system("$echo_exe \"$show\" $secs >> \"$transferLogFileName\"");
	}

#	system("$tnot_exe -sound default -title \"EyeTv Transfer Complete\" -message \"The show $show has been transferred!\" -activate \"com.elgato.eyetv\"");
	my $shortShow = $show;
	$shortShow =~ s/.eyetv$//;
	system("$tnot_exe -sound default -title \"EyeTv Transfer Complete\" -message \"The show \"$shortShow\" has been transferred!\"");
}

sub usage
{
	my $problem = shift;
	print "$problem\n";
	print "Usage:  $0 --patterns-file PFILE --transfer-log TFILE --local-shows-dir LDIR --remote-shows-dir RDIR --remote-host RHOST --ssh-exe SSHPATH\n";
	exit(1);
}

sub escape_unix
{
	my $str = shift;
	$str =~ s/([|&;<>\(\)\$`\\"' \t])/\\$1/g;
	return $str;
}

main();
