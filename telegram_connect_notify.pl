#! /usr/bin/perl

use strict;
use warnings;
use POSIX qw(strftime);

# Change as you please
my $telegram_bot_config_path = '/etc/openvpn/server/telegram_bot_config.txt';

#optional
#list of CN one per line
my $client_ignore_path = '/etc/openvpn/server/client_ignore_list.txt';

my $hostname = $ENV{'HOSTNAME'} // '';
my $untrusted_ip = $ENV{'untrusted_ip'} // '';
my $common_name = $ENV{'common_name'} // '';
my $ifconfig_pool_remote_ip = $ENV{'ifconfig_pool_remote_ip'} // '';
my $time_ascii = $ENV{'time_ascii'} // '';
my $time_duration = $ENV{'time_duration'} // '';

# MODE specified in server config
my $mode = shift(@ARGV);

unless (grep { $_ eq $mode } qw!connect disconnect!)
{
	_print("WARNING: Invalid value for first parameter given: '$mode' found excpected 'connect' oder 'disconnect'");
	exit 1;
}

unless (-f $telegram_bot_config_path)
{
	_print("WARNING: Missing telegram bot config");
	exit 2;
}

if (-f $client_ignore_path)
{
	open(my $client_ignore_list_fh, '<', $client_ignore_path);
	my @ignore_clients = ();
	if ($client_ignore_list_fh)
	{
		while (my $row = <$client_ignore_list_fh>)
		{
			chomp($row);
			push @ignore_clients, $row;
		}
		close($client_ignore_list_fh);
	}

	unless (grep { $_ eq $common_name } @ignore_clients)
	{
		send_telegram_msg();
	}
}
else
{
	send_telegram_msg();
}


sub send_telegram_msg
{
	my $request_tool = _find_request_binary();
	return unless $request_tool;

	#read config
	my $config = {};
	open(my $config_fh, '<', $telegram_bot_config_path);
	unless ($config_fh)
	{
		_print($!);
		exit 5;
	}
	while (my $config_row = <$config_fh>)
	{
		chomp($config_row);
		my @parts = split('=', $config_row);
		my $key = trim($parts[0]);
		my $value = trim($parts[1]);
		$config->{$key} = $value;
	}

	foreach my $required_key (qw|bot_id chat_id|)
	{
		my $missing_key_msg = sprintf("WARNING: Missing or empty key: '%s'", $required_key);
		unless (exists($config->{$required_key}))
		{
			_print($missing_key_msg);
			exit 6;
		}
		else
		{
			unless ($config->{$required_key})
			{
				_print($missing_key_msg);
				exit 7;
			}
		}
	}

	my $msg = sprintf('%s %s: %s IP: %s %s', ucfirst($mode), $time_ascii, $common_name, $ifconfig_pool_remote_ip, '%s');
	if ($mode eq 'disconnect')
	{
		$msg = sprintf($msg, sprintf('Connect Time: %s', $time_duration));
	}
	else
	{
		$msg = sprintf($msg, '');
	}
	my $telegram_request_string = 'https://api.telegram.org/%s/sendMessage?chat_id=%s&text=%s';
	$telegram_request_string = sprintf($telegram_request_string, $config->{'bot_id'}, $config->{'chat_id'}, $msg);
	my $cmd = '';
	if ($request_tool =~ m/wget/)
	{
		$cmd = sprintf('wget -q \'%s\'', $telegram_request_string);
	}
	elsif ($request_tool =~ m/curl/)
	{
		$cmd = sprintf('curl -XGET \'%s\' > /dev/null 2>&1', $telegram_request_string);
	}

	if ($cmd)
	{
		system($cmd);
		if ($? > 0)
		{
			_print('WARNING: Failed to send message: ' . $msg);
			exit 3;
		}
	}
	else
	{
		_print('WARNING: Failed to send message: ' . $msg);
		exit 4;
	}
}


sub _find_request_binary 
{
	my @binarys = qw|curl wget|;
	my $return = undef;
	foreach my $bin (@binarys)
	{
		my $shel_out = `which $bin`;
		chomp($shel_out);
		next unless $shel_out;
		if (-x $shel_out)
		{
			$return = $shel_out;
			last;
		}
	}
	return $return;
}

sub _print 
{
	my $msg = shift // '';
	return unless $msg;
	my $timestamp = strftime '%Y-%m-%d %H-%M-%S', localtime();
	print sprintf("%s %s-Script: %s\n", $timestamp, ucfirst($mode), $msg);
}

sub trim {
	my $string = shift // '';
	$string =~ s/^\s+//g;
	$string =~ s/\s+$//g;
	return $string;
}